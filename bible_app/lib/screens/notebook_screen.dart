import 'dart:async';
import 'dart:io';

import 'package:bible_app/notebook/notebook_list_item.dart';
import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:bible_app/notebook/notebook_repository_factory.dart';
import 'package:bible_app/screens/notebook_editor_panel.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:bible_app/widgets/notebook_chrome_dialog_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

/// Сообщение поверх модальных окон (например «файл уже в этой папке» при переносе).
void _showNotebookTopOverlayMessage(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
    return;
  }
  final top = MediaQuery.paddingOf(context).top + 12;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 16,
      right: 16,
      top: top,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(10),
        color: const Color(0xE6323232),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    entry.remove();
  });
}

/// Предупреждение поверх экрана (дубликат имени и т.п.): не сырой текст исключения.
void _showNotebookWarningBanner(
  BuildContext context, {
  required String title,
  String? subtitle,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    final buf = StringBuffer(title);
    if (subtitle != null && subtitle.isNotEmpty) {
      buf.write(' ');
      buf.write(subtitle);
    }
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(buf.toString())),
    );
    return;
  }
  final top = MediaQuery.paddingOf(context).top + 12;
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final barBg = isDark ? const Color(0xFF5D4037) : Colors.amber.shade100;
  final titleColor = isDark ? Colors.amber.shade100 : Colors.brown.shade900;
  final subColor = isDark ? Colors.amber.shade200 : Colors.brown.shade800;
  final iconColor = isDark ? Colors.amber.shade300 : Colors.amber.shade900;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 16,
      right: 16,
      top: top,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(12),
        color: barBg,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.warning_amber_rounded, color: iconColor, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null && subtitle.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: subColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    entry.remove();
  });
}

bool _notebookIsDuplicateNameError(Object e) {
  if (e is! StateError) return false;
  final m = e.message;
  return m == 'Файл уже существует' || m == 'Папка уже существует';
}

bool _notebookRenameCollisionError(Object e) {
  if (e is! StateError) return false;
  final m = e.message;
  return m == 'Цель уже существует' || m == 'Конфликт имён';
}

const int _notebookMaxNameLength = 15;

class _NotebookNameLengthFormatter extends TextInputFormatter {
  _NotebookNameLengthFormatter({
    required this.isFolder,
    required this.onLimitReached,
  });

  final bool isFolder;
  final VoidCallback onLimitReached;

  int _effectiveLength(String text) {
    final trimmed = text.trim();
    if (isFolder) return trimmed.length;
    var stem = trimmed;
    while (stem.toLowerCase().endsWith('.txt') && stem.length > 4) {
      stem = stem.substring(0, stem.length - 4);
    }
    return stem.length;
  }

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_effectiveLength(newValue.text) <= _notebookMaxNameLength) {
      return newValue;
    }
    onLimitReached();
    return oldValue;
  }
}

bool _notebookPosixPathsEqualInsensitive(String a, String b) {
  final na = p.posix.normalize(a);
  final nb = p.posix.normalize(b);
  return na.toLowerCase() == nb.toLowerCase();
}

/// Имя `toRel` уже занято другим элементом (не тем же, что `fromRel`).
Future<bool> _notebookRenameTargetTaken(
  NotebookRepository repo,
  NotebookListItem item,
  String toRel,
) async {
  if (_notebookPosixPathsEqualInsensitive(toRel, item.relativePath)) {
    return false;
  }
  final parent = p.posix.dirname(toRel);
  final parentDir = parent == '.' ? '' : parent;
  final base = p.posix.basename(toRel);
  final items = await repo.listDirectory(parentDir);
  if (item.isFolder) {
    for (final e in items) {
      if (!e.isFolder) continue;
      if (e.name != base && e.name.toLowerCase() != base.toLowerCase()) {
        continue;
      }
      if (!_notebookPosixPathsEqualInsensitive(
          e.relativePath, item.relativePath)) {
        return true;
      }
    }
    return false;
  }
  for (final e in items) {
    if (e.isFolder) continue;
    if (e.name != base && e.name.toLowerCase() != base.toLowerCase()) {
      continue;
    }
    if (!_notebookPosixPathsEqualInsensitive(
        e.relativePath, item.relativePath)) {
      return true;
    }
  }
  return false;
}

/// Сегменты пути под папку перемещения (без «корня»): `a/b` → `['a','b']`.
List<String> _notebookMoveDialogPathSegments(String browseDir) {
  if (browseDir.isEmpty) return const [];
  final norm = p.posix.normalize(browseDir);
  if (norm == '.' || norm.isEmpty) return const [];
  return p.posix.split(norm).where((e) => e.isNotEmpty && e != '.').toList();
}

/// Префикс ветки дерева для уровня 1…[deepest] (корень — уровень 0, без префикса).
String _notebookMoveDialogTreePrefix(int treeLevel, int deepestLevel) {
  if (treeLevel <= 0 || deepestLevel <= 0) return '';
  final indent = '  ' * (treeLevel - 1);
  return '$indent↳';
}

/// Префикс для i-й вложенной папки в списке (siblingCount детей у текущей папки).
String _notebookMoveDialogChildBranchPrefix(
  int index,
  int siblingCount,
  int segmentDepth,
) {
  if (siblingCount <= 0) return '';
  final indent = '  ' * segmentDepth;
  return '$indent↳';
}

class NotebookScreen extends StatefulWidget {
  const NotebookScreen({super.key});

  @override
  State<NotebookScreen> createState() => _NotebookScreenState();
}

class _NotebookScreenState extends State<NotebookScreen> {
  NotebookRepository? _repo;
  bool _loading = true;
  String? _error;
  String _currentDir = '';
  List<NotebookListItem> _items = [];

  String? _editingPath;
  GlobalKey<NotebookEditorPanelState>? _editorKey;

  /// Есть ли в хранилище хотя бы одна папка (для пункта «Переместить в…»).
  bool _notebookHasFolders = false;

  /// Долгое нажатие: панель действий вверху справа; для файла — ещё и выбор .txt для удаления.
  NotebookListItem? _fileActionsAnchor;

  /// Выбранные в текущей папке .txt (режим после долгого нажатия на файл).
  final Set<String> _bulkSelectedFilePaths = <String>{};
  DateTime? _lastNameLimitWarningAt;
  bool _editorClipboardHasText = false;
  Timer? _clipboardPollTimer;
  final ScrollController _folderPathScrollController = ScrollController();
  bool _folderPathHasOverflow = false;

  bool get _fileBulkSelectionUi =>
      _fileActionsAnchor != null && !_fileActionsAnchor!.isFolder;

  /// Пути выбранных .txt в порядке строк списка (для пакетного переноса).
  List<String> _orderedBulkSelectedFilePaths() {
    if (_bulkSelectedFilePaths.isEmpty) return const [];
    final ordered = _items
        .where(
          (it) =>
              !it.isFolder && _bulkSelectedFilePaths.contains(it.relativePath),
        )
        .map((it) => it.relativePath)
        .toList();
    final inList = ordered.toSet();
    final rest = _bulkSelectedFilePaths.difference(inList).toList()..sort();
    return [...ordered, ...rest];
  }

  static const _appBarBgLight = Color(0xFFB3E5FC);
  static const _buttonBgLight = Color(0xFFE1F5FE);
  static const _appBarBgDark = Color(0xFF37474F);
  static const _buttonBgDark = Color(0xFF455A64);
  static const _chromeFgLight = Colors.black;

  @override
  void initState() {
    super.initState();
    _startClipboardPolling();
    _openRepo();
  }

  @override
  void dispose() {
    _clipboardPollTimer?.cancel();
    _folderPathScrollController.dispose();
    super.dispose();
  }

  void _startClipboardPolling() {
    _clipboardPollTimer?.cancel();
    _clipboardPollTimer = Timer.periodic(
      const Duration(milliseconds: 700),
      (_) => unawaited(_refreshEditorClipboardState()),
    );
    unawaited(_refreshEditorClipboardState());
  }

  void _recomputeFolderPathOverflow() {
    final c = _folderPathScrollController;
    if (!c.hasClients || !c.position.hasContentDimensions) return;
    final hasOverflow = c.position.maxScrollExtent > 0;
    if (hasOverflow == _folderPathHasOverflow || !mounted) return;
    setState(() => _folderPathHasOverflow = hasOverflow);
  }

  Future<void> _refreshEditorClipboardState() async {
    if (!mounted) return;
    if (_editingPath == null || _editorKey?.currentState == null) {
      if (_editorClipboardHasText) {
        setState(() => _editorClipboardHasText = false);
      }
      return;
    }
    final data = await Clipboard.getData('text/plain');
    final hasText = (data?.text ?? '').isNotEmpty;
    if (!mounted || hasText == _editorClipboardHasText) return;
    setState(() => _editorClipboardHasText = hasText);
  }

  Future<void> _pasteFromClipboardToEditor() async {
    final editor = _editorKey?.currentState;
    if (editor == null) return;
    final data = await Clipboard.getData('text/plain');
    final text = data?.text ?? '';
    if (text.isEmpty) {
      if (_editorClipboardHasText) {
        setState(() => _editorClipboardHasText = false);
      }
      return;
    }
    editor.insertTextAtCursor(text);
    await Clipboard.setData(const ClipboardData(text: ''));
    if (!mounted) return;
    setState(() => _editorClipboardHasText = false);
  }

  Future<void> _openRepo() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = await createNotebookRepository();
      await repo.init();
      _repo = repo;
      await _refresh();
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Обход каталогов: true, если существует хотя бы одна папка.
  Future<bool> _repoAnyFolderExists(NotebookRepository repo) async {
    final queue = <String>[''];
    final visited = <String>{''};
    while (queue.isNotEmpty) {
      final dir = queue.removeAt(0);
      final items = await repo.listDirectory(dir);
      for (final i in items) {
        if (i.isFolder) return true;
      }
      for (final i in items) {
        if (i.isFolder && visited.add(i.relativePath)) {
          queue.add(i.relativePath);
        }
      }
    }
    return false;
  }

  Future<void> _refresh() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final list = await repo.listDirectory(_currentDir);
      final hasFolders = await _repoAnyFolderExists(repo);
      if (mounted) {
        setState(() {
          _items = list;
          _notebookHasFolders = hasFolders;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка списка: $e')),
        );
      }
    }
  }

  Future<void> _closeEditor() async {
    await _editorKey?.currentState?.flushSave();
    if (!mounted) return;
    setState(() {
      _editingPath = null;
      _editorKey = null;
      _editorClipboardHasText = false;
    });
    await _refresh();
  }

  void _openEditor(String relativePath) {
    setState(() {
      _editingPath = relativePath;
      _editorKey = GlobalKey<NotebookEditorPanelState>();
    });
    unawaited(_refreshEditorClipboardState());
  }

  /// Цепочка папок и файла для подписи внизу экрана (от корня блокнота).
  String _notebookPathForDisplay(String posixRel) {
    if (posixRel.isEmpty) return '';
    final norm = p.posix.normalize(posixRel);
    if (norm == '.' || norm.isEmpty) return '';
    final parts = p.posix.split(norm);
    return parts.join(' / ');
  }

  Future<void> _shareNotebookFile(String relativePath) async {
    final repo = _repo;
    if (repo == null) return;
    final name = p.basename(relativePath);
    try {
      final text = await repo.readFile(relativePath);
      if (repo.isFileSystemBacked) {
        final path = await repo.nativeFilePath(relativePath);
        if (path != null && File(path).existsSync()) {
          await Share.shareXFiles(
            [XFile(path, mimeType: 'text/plain', name: name)],
            text: name,
          );
          return;
        }
      }
      await Share.share(text, subject: name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось поделиться: $e')),
        );
      }
    }
  }

  String _suggestedCopyFileName(String fileName) {
    if (fileName.toLowerCase().endsWith('.txt')) {
      final stem = fileName.substring(0, fileName.length - 4);
      return '$stem (копия).txt';
    }
    return '$fileName (копия)';
  }

  /// Имя файла (как ввёл пользователь) или null при отмене.
  Future<String?> _promptNotebookFileNameDialog({
    required String title,
    required String initialValue,
    required String confirmLabel,
  }) async {
    final ctrl = TextEditingController(text: initialValue);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: Text(title)),
              NotebookChromeDialogCloseButton(
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              labelText: 'Имя файла',
              hintText: 'например: размышления.txt',
              border: OutlineInputBorder(),
            ),
            inputFormatters: [
              _NotebookNameLengthFormatter(
                isFolder: false,
                onLimitReached: () =>
                    _showTypingNameLimitWarning(isFolder: false),
              ),
            ],
            autofocus: true,
            onSubmitted: (_) => Navigator.pop(ctx, true),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerRight,
                child: NotebookChromeDialogButton(
                  expandWidth: false,
                  label: confirmLabel,
                  onPressed: () => Navigator.pop(ctx, true),
                  style: NotebookDialogActionStyle.confirm,
                ),
              ),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return null;
      return ctrl.text;
    } finally {
      ctrl.dispose();
    }
  }

  Future<bool> _notebookTxtFileExists(
    NotebookRepository repo,
    String relativePath,
  ) async {
    final parent = p.posix.dirname(relativePath);
    final parentDir = parent == '.' ? '' : parent;
    final base = p.posix.basename(relativePath);
    final items = await repo.listDirectory(parentDir);
    return items.any((e) => !e.isFolder && e.name == base);
  }

  Future<bool> _confirmOverwriteNotebookFile() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(
              child: Text('Файл уже существует'),
            ),
            NotebookChromeDialogCloseButton(
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
        content: const Text(
          'Файл с таким именем уже существует. Перезаписать?',
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                NotebookChromeDialogButton(
                  expandWidth: false,
                  label: 'Отмена',
                  onPressed: () => Navigator.pop(ctx, false),
                  style: NotebookDialogActionStyle.cancel,
                ),
                NotebookChromeDialogButton(
                  expandWidth: false,
                  label: 'Перезаписать',
                  onPressed: () => Navigator.pop(ctx, true),
                  style: NotebookDialogActionStyle.danger,
                ),
              ],
            ),
          ),
        ],
      ),
    );
    return ok == true;
  }

  Future<bool> _copyDocumentAs(NotebookListItem item) async {
    final repo = _repo;
    if (repo == null || item.isFolder) return false;
    final raw = await _promptNotebookFileNameDialog(
      title: 'Копия документа',
      initialValue: _suggestedCopyFileName(item.name),
      confirmLabel: 'Копировать',
    );
    if (raw == null) return false;
    final destName = _ensureTxtName(raw);
    if (_isFileStemTooLong(destName)) {
      _showNameTooLongWarning(isFolder: false);
      return false;
    }
    final parent = p.posix.dirname(item.relativePath);
    final destRel = parent == '.' ? destName : p.posix.join(parent, destName);
    final srcNorm = p.posix.normalize(item.relativePath);
    final dstNorm = p.posix.normalize(destRel);
    if (dstNorm == srcNorm) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Укажите другое имя файла')),
        );
      }
      return false;
    }
    try {
      final exists = await _notebookTxtFileExists(repo, destRel);
      if (exists) {
        final go = await _confirmOverwriteNotebookFile();
        if (!go || !mounted) return false;
      }
      final text = await repo.readFile(item.relativePath);
      await repo.writeFile(destRel, text);
      await _refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Сохранено: $destName')),
        );
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось скопировать: $e')),
        );
      }
      return false;
    }
  }

  void _closeFileActionsPanel() {
    if (_fileActionsAnchor == null && _bulkSelectedFilePaths.isEmpty) return;
    setState(() {
      _fileActionsAnchor = null;
      _bulkSelectedFilePaths.clear();
    });
  }

  void _openFileActionsPanel(NotebookListItem item) {
    setState(() {
      _fileActionsAnchor = item;
      if (!item.isFolder) {
        _bulkSelectedFilePaths
          ..clear()
          ..add(item.relativePath);
      } else {
        _bulkSelectedFilePaths.clear();
      }
    });
  }

  NotebookListItem? _listItemForPath(String relativePath) {
    for (final it in _items) {
      if (it.relativePath == relativePath) return it;
    }
    return null;
  }

  Future<void> _runPanelShare() async {
    final a = _fileActionsAnchor;
    if (a == null || a.isFolder) return;
    await _shareNotebookFile(a.relativePath);
    _closeFileActionsPanel();
  }

  Future<void> _runPanelSaveAs() async {
    final a = _fileActionsAnchor;
    if (a == null || a.isFolder) return;
    if (await _copyDocumentAs(a)) _closeFileActionsPanel();
  }

  Future<void> _runPanelMoveTo() async {
    final a = _fileActionsAnchor;
    if (a == null || a.isFolder) return;
    final paths = _orderedBulkSelectedFilePaths();
    if (paths.isEmpty) return;
    if (await _showMoveToFolderDialog(paths)) _closeFileActionsPanel();
  }

  Future<void> _runPanelRename() async {
    final a = _fileActionsAnchor;
    if (a == null) return;
    if (await _renameItem(a)) _closeFileActionsPanel();
  }

  Future<void> _runPanelDelete() async {
    final a = _fileActionsAnchor;
    if (a == null) return;
    if (a.isFolder) {
      if (await _deleteItem(a)) _closeFileActionsPanel();
      return;
    }
    if (_bulkSelectedFilePaths.length > 1) {
      await _deleteBulkSelectedFiles();
      return;
    }
    final only = _bulkSelectedFilePaths.isNotEmpty
        ? _listItemForPath(_bulkSelectedFilePaths.first)
        : a;
    if (only != null && await _deleteItem(only)) {
      _closeFileActionsPanel();
    }
  }

  Future<void> _deleteBulkSelectedFiles() async {
    final repo = _repo;
    if (repo == null || _bulkSelectedFilePaths.isEmpty) return;
    final paths = List<String>.from(_bulkSelectedFilePaths);
    final ep = _editingPath;
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text('Удалить ${paths.length} файлов?')),
            NotebookChromeDialogCloseButton(
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final rel in paths)
                Text(
                  '• ${p.basename(rel)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerRight,
              child: NotebookChromeDialogButton(
                expandWidth: false,
                label: 'Удалить',
                onPressed: () => Navigator.pop(ctx, true),
                style: NotebookDialogActionStyle.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      for (final p in paths) {
        await repo.delete(p);
      }
      if (ep != null && paths.contains(ep)) {
        await _closeEditor();
      } else {
        await _refresh();
      }
      _closeFileActionsPanel();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить: $e')),
        );
      }
    }
  }

  Widget _buildNotebookFileActionsPanel() {
    final a = _fileActionsAnchor!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final halfScreen = MediaQuery.sizeOf(context).width * 0.5;
    final delCount = a.isFolder ? 1 : _bulkSelectedFilePaths.length;
    final canBulkDelete = a.isFolder || delCount > 0;
    final delLabel = a.isFolder
        ? 'Удалить папку'
        : (delCount > 1 ? 'Удалить ($delCount)' : 'Удалить');
    final canRename = a.isFolder || _bulkSelectedFilePaths.length <= 1;
    final canSaveAs = _bulkSelectedFilePaths.length <= 1;
    final canMoveBulk =
        _bulkSelectedFilePaths.isNotEmpty && _notebookHasFolders;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(12),
      color: isDark ? _appBarBgDark : Colors.white,
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: halfScreen),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, 2),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NotebookChromeDialogCloseButton(
                    onPressed: _closeFileActionsPanel,
                  ),
                ],
              ),
            ),
            if (!a.isFolder)
              _NotebookChromePanelActionButton(
                icon: Icons.share_outlined,
                label: 'Поделиться…',
                onTap: () => unawaited(_runPanelShare()),
              )
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
                child: Text(
                  'Папка: ${a.name}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
              Divider(
                height: 1,
                color: isDark ? Colors.white24 : null,
              ),
            ],
            if (!a.isFolder)
              Divider(
                height: 1,
                color: isDark ? Colors.white24 : null,
              ),
            if (!a.isFolder)
              IgnorePointer(
                ignoring: !canSaveAs,
                child: Opacity(
                  opacity: canSaveAs ? 1 : 0.4,
                  child: _NotebookChromePanelActionButton(
                    icon: Icons.file_copy_outlined,
                    label: 'Сохранить как…',
                    onTap: () => unawaited(_runPanelSaveAs()),
                  ),
                ),
              ),
            if (!a.isFolder && _notebookHasFolders)
              IgnorePointer(
                ignoring: !canMoveBulk,
                child: Opacity(
                  opacity: canMoveBulk ? 1 : 0.4,
                  child: _NotebookChromePanelActionButton(
                    icon: Icons.drive_file_move_outline,
                    label: _bulkSelectedFilePaths.length > 1
                        ? 'Переместить в… (${_bulkSelectedFilePaths.length})'
                        : 'Переместить в…',
                    onTap: () => unawaited(_runPanelMoveTo()),
                  ),
                ),
              ),
            IgnorePointer(
              ignoring: !canRename,
              child: Opacity(
                opacity: canRename ? 1 : 0.4,
                child: _NotebookChromePanelActionButton(
                  icon: Icons.drive_file_rename_outline,
                  label: 'Переименовать',
                  onTap: () => unawaited(_runPanelRename()),
                ),
              ),
            ),
            Divider(
              height: 1,
              color: isDark ? Colors.white24 : null,
            ),
            IgnorePointer(
              ignoring: !canBulkDelete,
              child: Opacity(
                opacity: canBulkDelete ? 1 : 0.4,
                child: _NotebookChromePanelActionButton(
                  icon: Icons.delete_outline,
                  label: delLabel,
                  onTap: () => unawaited(_runPanelDelete()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotebookPathStrip({
    required String label,
    required String pathValue,
    Widget? pathWidget,
    EdgeInsetsGeometry contentPadding =
        const EdgeInsets.fromLTRB(12, 8, 12, 10),
    bool showLabel = true,
    double gapAfterLabel = 4,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF455A64) : const Color(0xFFE1F5FE);
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final valueColor = isDark ? Colors.white : Colors.black87;
    final fs = context.watch<AppProvider>().fontSize;
    final labelSize = (fs * 0.88).clamp(11.0, 32.0);
    final valueSize = fs.clamp(12.0, 40.0);
    return Material(
      color: barBg,
      child: SafeArea(
        top: false,
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: Color(0x44000000), width: 1)),
          ),
          padding: contentPadding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLabel) ...[
                Text(
                  label,
                  style: TextStyle(
                    color: labelColor,
                    fontWeight: FontWeight.w600,
                    fontSize: labelSize,
                  ),
                ),
                SizedBox(height: gapAfterLabel),
              ],
              pathWidget ??
                  SelectableText(
                    pathValue,
                    style: TextStyle(
                      color: valueColor,
                      fontWeight: FontWeight.w500,
                      fontSize: valueSize,
                      height: 1.3,
                    ),
                  ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFolderPathBreadcrumb() {
    final fs = context.watch<AppProvider>().fontSize;
    final app = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final segs = _notebookMoveDialogPathSegments(_currentDir);
    final crumbFs = fs.clamp(12.0, 40.0);
    final activeColor = isDark ? Colors.white : Colors.black87;
    final inactiveColor = isDark ? Colors.white70 : Colors.black54;

    final chips = <Widget>[
      InkWell(
        onTap: () {
          if (_currentDir.isEmpty) return;
          setState(() => _currentDir = '');
          unawaited(_refresh());
          _closeFileActionsPanel();
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          child: Text(
            'Корень',
            style: TextStyle(
              color: _currentDir.isEmpty ? activeColor : inactiveColor,
              fontWeight: FontWeight.w600,
              fontSize: crumbFs,
              height: 1.2,
            ),
          ),
        ),
      ),
    ];

    for (var i = 0; i < segs.length; i++) {
      final path = segs.sublist(0, i + 1).join('/');
      final isActive = path == _currentDir;
      chips.add(
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            '/',
            style: TextStyle(
              color: inactiveColor,
              fontWeight: FontWeight.w600,
              fontSize: crumbFs,
              height: 1.2,
            ),
          ),
        ),
      );
      chips.add(
        InkWell(
          onTap: isActive
              ? null
              : () {
                  setState(() => _currentDir = path);
                  unawaited(_refresh());
                  _closeFileActionsPanel();
                },
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Text(
              segs[i],
              style: TextStyle(
                color: isActive ? activeColor : inactiveColor,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                fontSize: crumbFs,
                height: 1.2,
              ),
            ),
          ),
        ),
      );
    }

    final rowHeight = crumbFs * 1.2;
    final maxPathHeight = rowHeight * 2;
    final railSize = (app.chromeButtonSize * 0.68).clamp(26.0, 36.0);
    final railTrack = isDark
        ? Colors.blueGrey.shade700.withValues(alpha: 0.9)
        : Colors.blue.shade100.withValues(alpha: 0.75);
    final railThumb = isDark ? _buttonBgDark : _buttonBgLight;
    final railBg = isDark
        ? const Color(0xFF263238)
        : const Color(0xFFE1F5FE);
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _recomputeFolderPathOverflow());
    return SizedBox(
      height: maxPathHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Scrollbar(
              controller: _folderPathScrollController,
              thumbVisibility: false,
              child: SingleChildScrollView(
                controller: _folderPathScrollController,
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: chips,
                ),
              ),
            ),
          ),
          if (_folderPathHasOverflow) ...[
            const SizedBox(width: 2),
            Container(
              width: railSize,
              color: railBg,
              child: _NotebookPathScrollRail(
                controller: _folderPathScrollController,
                thumbSize: railSize,
                thumbColor: railThumb,
                trackHintColor: railTrack,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEditorDocumentFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final valueColor = isDark ? Colors.white : Colors.black87;
    final fs = context.watch<AppProvider>().fontSize;
    final valueSize = fs.clamp(12.0, 40.0);
    final fileName = p.posix.basename(_editingPath ?? '');
    return _buildNotebookPathStrip(
      label: '',
      pathValue: '',
      showLabel: false,
      gapAfterLabel: 0,
      contentPadding: const EdgeInsets.fromLTRB(8, 4, 8, 6),
      pathWidget: Text(
        fileName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: valueColor,
          fontWeight: FontWeight.w600,
          fontSize: valueSize,
          height: 1.15,
        ),
      ),
    );
  }

  Widget _buildListFolderFooter() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pathAreaBg = isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    return _buildNotebookPathStrip(
      label: 'Папка:',
      pathValue: '',
      pathWidget: Container(
        color: pathAreaBg,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: _buildFolderPathBreadcrumb(),
      ),
      // Небольшой левый отступ + минимальный правый, чтобы скроллбар прижимался вправо.
      contentPadding: const EdgeInsets.fromLTRB(8, 8, 0, 10),
    );
  }

  Widget _buildDocumentPathBreadcrumb() {
    final fs = context.watch<AppProvider>().fontSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final crumbFs = fs.clamp(12.0, 40.0);
    final activeColor = isDark ? Colors.white : Colors.black87;
    final pathText = _notebookPathForDisplay(_editingPath ?? '');

    if (pathText.isEmpty) {
      return const SizedBox.shrink();
    }

    final rowHeight = crumbFs * 1.2;
    final maxPathHeight = rowHeight * 2;

    return SizedBox(
      height: maxPathHeight,
      child: Scrollbar(
        thumbVisibility: true,
        interactive: true,
        child: SingleChildScrollView(
          child: Text(
            pathText,
            style: TextStyle(
              color: activeColor,
              fontWeight: FontWeight.w600,
              fontSize: crumbFs,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  String _sanitizeSegment(String raw) {
    var s = raw.trim();
    const bad = r'\/:*?"<>|';
    for (var i = 0; i < bad.length; i++) {
      s = s.replaceAll(bad[i], '_');
    }
    return s;
  }

  String _ensureTxtName(String raw) {
    final s = _sanitizeSegment(raw);
    if (s.isEmpty) return 'заметка.txt';
    return s.toLowerCase().endsWith('.txt') ? s : '$s.txt';
  }

  bool _isFolderNameTooLong(String folderName) {
    return folderName.length > _notebookMaxNameLength;
  }

  bool _isFileStemTooLong(String fileName) {
    final stem = _notebookTxtStemForRename(fileName);
    return stem.length > _notebookMaxNameLength;
  }

  bool _showNameTooLongWarning({required bool isFolder}) {
    if (!mounted) return false;
    final target = isFolder ? 'папки' : 'файла';
    _showNotebookWarningBanner(
      context,
      title: 'Слишком длинное имя $target',
      subtitle: 'Максимум: $_notebookMaxNameLength символов.',
    );
    return true;
  }

  void _showTypingNameLimitWarning({required bool isFolder}) {
    final now = DateTime.now();
    final last = _lastNameLimitWarningAt;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 800)) {
      return;
    }
    _lastNameLimitWarningAt = now;
    _showNameTooLongWarning(isFolder: isFolder);
  }

  /// Имя без «.txt» для поля переименования (расширение всегда .txt).
  String _notebookTxtStemForRename(String fileName) {
    if (fileName.toLowerCase().endsWith('.txt') && fileName.length > 4) {
      return fileName.substring(0, fileName.length - 4);
    }
    return fileName;
  }

  /// Итоговое имя файла из ввода только стебла (убирает лишние «.txt» в конце).
  String _finalTxtNameFromRenameField(String fieldText) {
    var base = _sanitizeSegment(fieldText);
    while (base.toLowerCase().endsWith('.txt') && base.length > 4) {
      base = base.substring(0, base.length - 4);
    }
    return _ensureTxtName(base);
  }

  Future<void> _createDocument() async {
    final repo = _repo;
    if (repo == null) return;
    final raw = await _promptNotebookFileNameDialog(
      title: 'Новый документ',
      initialValue: 'заметка',
      confirmLabel: 'Создать',
    );
    if (raw == null) return;
    final name = _ensureTxtName(raw);
    if (_isFileStemTooLong(name)) {
      _showNameTooLongWarning(isFolder: false);
      return;
    }
    final rel = _currentDir.isEmpty ? name : p.posix.join(_currentDir, name);
    try {
      await repo.createFile(rel);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      if (_notebookIsDuplicateNameError(e)) {
        _showNotebookWarningBanner(
          context,
          title: 'Файл с таким именем уже есть',
          subtitle:
              'Выберите другое имя или удалите существующий файл в этой папке.',
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать: $e')),
      );
    }
  }

  Future<void> _createFolder() async {
    final repo = _repo;
    if (repo == null) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: Text('Новая папка')),
            NotebookChromeDialogCloseButton(
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Имя папки',
            border: OutlineInputBorder(),
          ),
          inputFormatters: [
            _NotebookNameLengthFormatter(
              isFolder: true,
              onLimitReached: () => _showTypingNameLimitWarning(isFolder: true),
            ),
          ],
          autofocus: true,
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerRight,
              child: NotebookChromeDialogButton(
                expandWidth: false,
                label: 'Создать',
                onPressed: () => Navigator.pop(ctx, true),
                style: NotebookDialogActionStyle.confirm,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final seg = _sanitizeSegment(ctrl.text);
    if (seg.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Введите имя папки')),
        );
      }
      return;
    }
    if (_isFolderNameTooLong(seg)) {
      _showNameTooLongWarning(isFolder: true);
      return;
    }
    final rel = _currentDir.isEmpty ? seg : p.posix.join(_currentDir, seg);
    try {
      await repo.createFolder(rel);
      await _refresh();
    } catch (e) {
      if (!mounted) return;
      if (_notebookIsDuplicateNameError(e)) {
        _showNotebookWarningBanner(
          context,
          title: 'Папка с таким именем уже есть',
          subtitle:
              'Выберите другое имя или удалите существующую папку в этой директории.',
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось создать папку: $e')),
      );
    }
  }

  Future<void> _openItem(NotebookListItem item) async {
    final repo = _repo;
    if (repo == null) return;
    if (item.isFolder) {
      setState(() => _currentDir = item.relativePath);
      await _refresh();
      return;
    }
    _openEditor(item.relativePath);
  }

  void _goUp() {
    if (_currentDir.isEmpty) return;
    _closeFileActionsPanel();
    final parent = p.posix.dirname(_currentDir);
    setState(() {
      _currentDir = parent == '.' ? '' : parent;
    });
    _refresh();
  }

  Future<bool> _moveFileToFolder(
    String sourcePath,
    String destParentDir, {
    bool topOverlayMessages = false,
    bool suppressSuccessSnack = false,
    bool suppressListRefresh = false,
  }) async {
    final repo = _repo;
    if (repo == null) return false;
    final base = p.posix.basename(sourcePath);
    final destRel =
        destParentDir.isEmpty ? base : p.posix.join(destParentDir, base);
    final srcNorm = p.posix.normalize(sourcePath);
    final dstNorm = p.posix.normalize(destRel);
    void feedback(String text, {bool preferOverlay = false}) {
      if (!mounted) return;
      if (preferOverlay && topOverlayMessages) {
        _showNotebookTopOverlayMessage(context, text);
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(text)));
      }
    }

    if (srcNorm == dstNorm) {
      feedback(
        'Файл уже в этой папке',
        preferOverlay: true,
      );
      return false;
    }
    try {
      if (await _notebookTxtFileExists(repo, destRel)) {
        final go = await _confirmOverwriteNotebookFile();
        if (!go || !mounted) return false;
        await repo.delete(destRel);
      }
      if (_editingPath == sourcePath) {
        await _editorKey?.currentState?.flushSave();
        if (!mounted) return false;
      }
      await repo.rename(sourcePath, destRel);
      if (!mounted) return false;
      setState(() {
        if (_editingPath == sourcePath) {
          _editingPath = destRel;
          _editorKey = GlobalKey<NotebookEditorPanelState>();
        }
      });
      if (!suppressListRefresh) await _refresh();
      if (mounted && !suppressSuccessSnack) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Перемещено: $base')),
        );
      }
      return true;
    } catch (e) {
      feedback(
        'Не удалось переместить: $e',
        preferOverlay: true,
      );
      return false;
    }
  }

  Future<bool> _showMoveToFolderDialog(List<String> sourcePaths) async {
    final repo = _repo;
    if (repo == null || sourcePaths.isEmpty) return false;
    final bulk = sourcePaths.length > 1;
    final primaryName = p.posix.basename(sourcePaths.first);
    final moved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _NotebookMoveFileDialog(
        repo: repo,
        sourcePaths: sourcePaths,
        fileCount: sourcePaths.length,
        primaryFileName: primaryName,
        onMoveTo: (destParent) async {
          var allOk = true;
          for (final path in sourcePaths) {
            final ok = await _moveFileToFolder(
              path,
              destParent,
              topOverlayMessages: true,
              suppressSuccessSnack: bulk,
              suppressListRefresh: true,
            );
            if (!ok) allOk = false;
          }
          if (mounted) await _refresh();
          if (mounted && allOk && bulk) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Перемещено файлов: ${sourcePaths.length}',
                ),
              ),
            );
          }
          return allOk;
        },
      ),
    );
    return moved == true;
  }

  Future<bool> _renameItem(NotebookListItem item) async {
    final repo = _repo;
    if (repo == null) return false;
    final ctrl = TextEditingController(
      text: item.isFolder ? item.name : _notebookTxtStemForRename(item.name),
    );
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  item.isFolder ? 'Переименовать папку' : 'Переименовать файл',
                ),
              ),
              NotebookChromeDialogCloseButton(
                onPressed: () => Navigator.pop(ctx, false),
              ),
            ],
          ),
          content: item.isFolder
              ? TextField(
                  controller: ctrl,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                  inputFormatters: [
                    _NotebookNameLengthFormatter(
                      isFolder: true,
                      onLimitReached: () =>
                          _showTypingNameLimitWarning(isFolder: true),
                    ),
                  ],
                  autofocus: true,
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(
                          labelText: 'Имя файла',
                          hintText: 'например: размышления',
                          border: OutlineInputBorder(),
                        ),
                        inputFormatters: [
                          _NotebookNameLengthFormatter(
                            isFolder: false,
                            onLimitReached: () =>
                                _showTypingNameLimitWarning(isFolder: false),
                          ),
                        ],
                        autofocus: true,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 8, bottom: 14),
                      child: Text(
                        '.txt',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Theme.of(ctx).colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: Align(
                alignment: Alignment.centerRight,
                child: NotebookChromeDialogButton(
                  expandWidth: false,
                  label: 'Сохранить',
                  onPressed: () => Navigator.pop(ctx, true),
                  style: NotebookDialogActionStyle.confirm,
                ),
              ),
            ),
          ],
        ),
      );
      if (ok != true) return false;
      late final String newName;
      if (item.isFolder) {
        final newSeg = _sanitizeSegment(ctrl.text);
        if (newSeg.isEmpty) return false;
        if (_isFolderNameTooLong(newSeg)) {
          _showNameTooLongWarning(isFolder: true);
          return false;
        }
        newName = newSeg;
      } else {
        newName = _finalTxtNameFromRenameField(ctrl.text);
        if (_isFileStemTooLong(newName)) {
          _showNameTooLongWarning(isFolder: false);
          return false;
        }
      }
      final parent = p.posix.dirname(item.relativePath);
      final toRel = parent == '.' ? newName : p.posix.join(parent, newName);
      if (await _notebookRenameTargetTaken(repo, item, toRel)) {
        if (mounted) {
          if (item.isFolder) {
            _showNotebookWarningBanner(
              context,
              title: 'Папка с таким именем уже есть',
              subtitle:
                  'Выберите другое имя или удалите существующую папку в этой директории.',
            );
          } else {
            _showNotebookWarningBanner(
              context,
              title: 'Файл с таким именем уже есть',
              subtitle:
                  'Выберите другое имя или удалите существующий файл в этой папке.',
            );
          }
        }
        return false;
      }
      try {
        await repo.rename(item.relativePath, toRel);
        if (mounted) {
          setState(() {
            if (_editingPath == item.relativePath) _editingPath = toRel;
          });
        }
        await _refresh();
        return true;
      } catch (e) {
        if (mounted) {
          if (_notebookRenameCollisionError(e)) {
            if (item.isFolder) {
              _showNotebookWarningBanner(
                context,
                title: 'Папка с таким именем уже есть',
                subtitle:
                    'Выберите другое имя или удалите существующую папку в этой директории.',
              );
            } else {
              _showNotebookWarningBanner(
                context,
                title: 'Файл с таким именем уже есть',
                subtitle:
                    'Выберите другое имя или удалите существующий файл в этой папке.',
              );
            }
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Не удалось переименовать: $e')),
            );
          }
        }
        return false;
      }
    } finally {
      ctrl.dispose();
    }
  }

  Future<void> _afterDeleteNavigate(NotebookListItem item) async {
    final deleted = item.relativePath;
    final ep = _editingPath;
    if (ep != null) {
      if (!item.isFolder) {
        if (ep == deleted) {
          await _closeEditor();
          return;
        }
      } else {
        final prefix = deleted.isEmpty ? '' : '$deleted/';
        if (ep == deleted || (prefix.isNotEmpty && ep.startsWith(prefix))) {
          await _closeEditor();
          return;
        }
      }
    }
    if (item.isFolder) {
      final prefix = deleted.isEmpty ? '' : '$deleted/';
      if (_currentDir == deleted ||
          (prefix.isNotEmpty && _currentDir.startsWith(prefix))) {
        final parent = p.posix.dirname(deleted);
        setState(() => _currentDir = parent == '.' ? '' : parent);
      }
    }
    await _refresh();
  }

  Future<bool> _deleteItem(NotebookListItem item) async {
    final repo = _repo;
    if (repo == null) return false;

    var folderHasContents = false;
    if (item.isFolder) {
      try {
        final kids = await repo.listDirectory(item.relativePath);
        folderHasContents = kids.isNotEmpty;
      } catch (_) {
        folderHasContents = true;
      }
    }
    if (!mounted) return false;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: Text('Удалить?')),
            NotebookChromeDialogCloseButton(
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
        content: item.isFolder
            ? (folderHasContents
                ? Text(
                    'Папка не пустая! Удалить?',
                    style: TextStyle(
                      color: Colors.red.shade700,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  )
                : Text('Папка «${item.name}» будет удалена.'))
            : Text('Файл «${item.name}» будет удалён.'),
        actions: [
          SizedBox(
            width: double.infinity,
            child: Align(
              alignment: Alignment.centerRight,
              child: NotebookChromeDialogButton(
                expandWidth: false,
                label: 'Удалить',
                onPressed: () => Navigator.pop(ctx, true),
                style: NotebookDialogActionStyle.danger,
              ),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    try {
      if (item.isFolder && folderHasContents) {
        await repo.deleteRecursive(item.relativePath);
      } else {
        await repo.delete(item.relativePath);
      }
      await _afterDeleteNavigate(item);
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить: $e')),
        );
      }
      return false;
    }
  }

  Widget _chromeIconButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
    required Color chromeFg,
    required Color buttonBg,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: ChromeIconButton(
        icon: icon,
        tooltip: tooltip,
        onPressed: onPressed,
        foregroundColor: chromeFg,
        backgroundColor: buttonBg,
      ),
    );
  }

  PreferredSizeWidget _buildListAppBar() {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final toolbarH = AppProvider.toolbarHeightForChrome(chrome);
    final rightInset = (chrome * 0.12).clamp(4.0, 10.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? _appBarBgDark : _appBarBgLight;
    final buttonBg = isDark ? _buttonBgDark : _buttonBgLight;
    final chromeFg = isDark ? Colors.white : _chromeFgLight;
    final leadingSlotWidth = (chrome + 8).clamp(52.0, 90.0);
    return AppBar(
      backgroundColor: appBarBg,
      surfaceTintColor: appBarBg,
      foregroundColor: chromeFg,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: toolbarH,
      automaticallyImplyLeading: false,
      leadingWidth: leadingSlotWidth,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      leading: Align(
        alignment: Alignment.center,
        child: _currentDir.isEmpty
            ? SizedBox(
                width: chrome,
                height: chrome,
              )
            : ChromeIconButton(
                icon: Icons.arrow_back,
                tooltip: 'Назад',
                onPressed: _goUp,
                foregroundColor: chromeFg,
                backgroundColor: buttonBg,
              ),
      ),
      titleSpacing: 8,
      title: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _chromeIconButton(
              icon: Icons.create_new_folder_outlined,
              tooltip: 'Новая папка',
              onPressed: _createFolder,
              chromeFg: chromeFg,
              buttonBg: buttonBg,
            ),
            _chromeIconButton(
              icon: Icons.note_add_outlined,
              tooltip: 'Новый документ',
              onPressed: _createDocument,
              chromeFg: chromeFg,
              buttonBg: buttonBg,
            ),
          ],
        ),
      ),
      actions: [
        Padding(
          padding: EdgeInsets.only(right: rightInset),
          child: AppChromeOverflowMenu(
            iconColor: chromeFg,
            backgroundColor: buttonBg,
          ),
        ),
      ],
    );
  }

  PreferredSizeWidget _buildEditorAppBar() {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final toolbarH = AppProvider.toolbarHeightForChrome(chrome);
    final rightInset = (chrome * 0.12).clamp(4.0, 10.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? _appBarBgDark : _appBarBgLight;
    final buttonBg = isDark ? _buttonBgDark : _buttonBgLight;
    final chromeFg = isDark ? Colors.white : _chromeFgLight;
    return AppBar(
      backgroundColor: appBarBg,
      surfaceTintColor: appBarBg,
      foregroundColor: chromeFg,
      elevation: 0,
      scrolledUnderElevation: 0,
      toolbarHeight: toolbarH,
      leadingWidth: (chrome + 8).clamp(52.0, 90.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      leading: Align(
        alignment: Alignment.center,
        child: ChromeIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Закрыть',
          onPressed: _closeEditor,
          foregroundColor: chromeFg,
          backgroundColor: buttonBg,
        ),
      ),
      title: const SizedBox.shrink(),
      actions: [
        Builder(
          builder: (context) {
            final uc = _editorKey?.currentState?.undoHistoryController;
            if (uc == null) return const SizedBox.shrink();
            return ListenableBuilder(
              listenable: uc,
              builder: (context, _) {
                final v = uc.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Opacity(
                      opacity: v.canUndo ? 1 : 0.38,
                      child: ChromeIconButton(
                        icon: Icons.undo,
                        tooltip: 'Шаг назад',
                        onPressed: v.canUndo ? () => uc.undo() : null,
                        foregroundColor: chromeFg,
                        backgroundColor: buttonBg,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: v.canRedo ? 1 : 0.38,
                      child: ChromeIconButton(
                        icon: Icons.redo,
                        tooltip: 'Шаг вперёд',
                        onPressed: v.canRedo ? () => uc.redo() : null,
                        foregroundColor: chromeFg,
                        backgroundColor: buttonBg,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Opacity(
                      opacity: _editorClipboardHasText ? 1 : 0.38,
                      child: ChromeIconButton(
                        icon: Icons.content_paste,
                        tooltip: _editorClipboardHasText
                            ? 'Вставить из буфера'
                            : 'Буфер пуст',
                        onPressed: _editorClipboardHasText
                            ? () => unawaited(_pasteFromClipboardToEditor())
                            : null,
                        foregroundColor: chromeFg,
                        backgroundColor: buttonBg,
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                );
              },
            );
          },
        ),
        ChromeIconButton(
          icon: Icons.save_outlined,
          tooltip: 'Сохранить',
          onPressed: () => _editorKey?.currentState?.saveNow(),
          foregroundColor: chromeFg,
          backgroundColor: buttonBg,
        ),
        const SizedBox(width: 4),
        AppChromeOverflowMenu(
          iconColor: chromeFg,
          backgroundColor: buttonBg,
        ),
        SizedBox(width: rightInset),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editingPath != null && _editorKey != null && _repo != null;
    final app = context.watch<AppProvider>();
    final uiListFontSize = app.fontSize;
    final uiLineHeight = app.lineHeight;
    final chromeBtnSize = app.chromeButtonSize;
    final listIconSize = (24.0 * uiListFontSize / 16.0).clamp(20.0, 48.0);
    final listCheckVisualSize = (uiListFontSize * 0.72).clamp(9.0, 20.0);
    final listCheckScale = (listCheckVisualSize / 18.0).clamp(0.5, 1.15);
    final listCbBox = (listCheckVisualSize * 2.4).clamp(30.0, 56.0);

    return Scaffold(
      appBar: editing ? _buildEditorAppBar() : _buildListAppBar(),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Не удалось открыть хранилище:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : editing
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: NotebookEditorPanel(
                            key: _editorKey,
                            repo: _repo!,
                            relativePath: _editingPath!,
                            onDocumentDeleted: () {
                              _closeEditor();
                            },
                          ),
                        ),
                        _buildEditorDocumentFooter(),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _items.isEmpty
                              ? Center(
                                  child: Text(
                                    _currentDir.isEmpty
                                        ? 'Нет документов.\nСоздайте через иконки вверху.'
                                        : 'Папка пуста.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: (uiListFontSize * 0.95)
                                          .clamp(13.0, 28.0),
                                      height: 1.35,
                                    ),
                                  ),
                                )
                              : Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.topRight,
                                  children: [
                                    Positioned.fill(
                                      child: ListView.builder(
                                        itemCount: _items.length,
                                        itemBuilder: (listContext, i) {
                                          final item = _items[i];
                                          final bulk = _fileBulkSelectionUi &&
                                              !item.isFolder;
                                          final sel = _bulkSelectedFilePaths
                                              .contains(item.relativePath);
                                          final isDark =
                                              Theme.of(context).brightness ==
                                                  Brightness.dark;
                                          final tileBg = bulk && sel
                                              ? (isDark
                                                  ? Colors.blueGrey.shade700
                                                      .withValues(alpha: 0.45)
                                                  : Colors.amber.shade100)
                                              : null;

                                          void onTap() {
                                              if (bulk) {
                                                setState(() {
                                                  if (sel) {
                                                    _bulkSelectedFilePaths
                                                        .remove(
                                                            item.relativePath);
                                                  } else {
                                                    _bulkSelectedFilePaths
                                                        .add(item.relativePath);
                                                  }
                                                });
                                                return;
                                              }
                                              if (_fileActionsAnchor != null &&
                                                  item.isFolder) {
                                                _closeFileActionsPanel();
                                              }
                                              _openItem(item);
                                          }

                                          return Material(
                                            color: tileBg,
                                            child: InkWell(
                                              onTap: onTap,
                                              onLongPress: () =>
                                                  _openFileActionsPanel(item),
                                              child: Padding(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 2,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.end,
                                                  children: [
                                                    SizedBox(
                                                      width: bulk
                                                          ? listCbBox
                                                          : listIconSize,
                                                      height: bulk
                                                          ? listCbBox
                                                          : listIconSize,
                                                      child: bulk
                                                          ? Align(
                                                              alignment: Alignment
                                                                  .bottomCenter,
                                                              child: SizedBox(
                                                                width: listCbBox,
                                                                height: listCbBox,
                                                                child: Transform
                                                                    .scale(
                                                                  scale:
                                                                      listCheckScale,
                                                                  alignment:
                                                                      Alignment
                                                                          .bottomCenter,
                                                                  child:
                                                                      Checkbox(
                                                                    value: sel,
                                                                    onChanged:
                                                                        (v) {
                                                                      setState(
                                                                        () {
                                                                          if (v ==
                                                                              true) {
                                                                            _bulkSelectedFilePaths.add(
                                                                              item.relativePath,
                                                                            );
                                                                          } else {
                                                                            _bulkSelectedFilePaths.remove(
                                                                              item.relativePath,
                                                                            );
                                                                          }
                                                                        },
                                                                      );
                                                                    },
                                                                  ),
                                                                ),
                                                              ),
                                                            )
                                                          : Align(
                                                              alignment: Alignment
                                                                  .bottomCenter,
                                                              child: Icon(
                                                                item.isFolder
                                                                    ? Icons
                                                                        .folder_outlined
                                                                    : Icons
                                                                        .description_outlined,
                                                                size:
                                                                    listIconSize,
                                                              ),
                                                            ),
                                                    ),
                                                    const SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        item.name,
                                                        maxLines: 2,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style: TextStyle(
                                                          fontSize:
                                                              uiListFontSize,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          height: uiLineHeight
                                                              .clamp(
                                                            1.15,
                                                            1.45,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    if (_fileActionsAnchor != null)
                                      Positioned(
                                        top: 4,
                                        right: 6,
                                        child: SafeArea(
                                          left: false,
                                          bottom: false,
                                          child: TapRegion(
                                            onTapOutside: (_) {
                                              // В режиме выбора нескольких .txt тап по строкам
                                              // списка считается «снаружи» панели — не закрывать,
                                              // иначе сброс выбора и открытие файла.
                                              if (!_fileBulkSelectionUi) {
                                                _closeFileActionsPanel();
                                              }
                                            },
                                            child:
                                                _buildNotebookFileActionsPanel(),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                        ),
                        if (_currentDir.isNotEmpty) _buildListFolderFooter(),
                      ],
                    ),
    );
  }
}

class _NotebookPathScrollRail extends StatefulWidget {
  const _NotebookPathScrollRail({
    required this.controller,
    required this.thumbSize,
    required this.thumbColor,
    required this.trackHintColor,
  });

  final ScrollController controller;
  final double thumbSize;
  final Color thumbColor;
  final Color trackHintColor;

  @override
  State<_NotebookPathScrollRail> createState() => _NotebookPathScrollRailState();
}

class _NotebookPathScrollRailState extends State<_NotebookPathScrollRail> {
  bool get _hasMetrics =>
      widget.controller.hasClients && widget.controller.position.hasContentDimensions;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _NotebookPathScrollRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  void _jumpToLocalY(double localY, double trackH, double ts, double travel) {
    final c = widget.controller;
    if (!_hasMetrics || travel <= 0) return;
    final maxExt = c.position.maxScrollExtent;
    if (maxExt <= 0) {
      c.jumpTo(0);
      return;
    }
    final targetTop = (localY - ts / 2).clamp(0.0, travel);
    final pixels = (targetTop / travel) * maxExt;
    c.jumpTo(pixels.clamp(0.0, maxExt));
  }

  Widget _gripLine(double width) => Container(
        width: width,
        height: 2.5,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(1.25),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final ts = widget.thumbSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final travel = (h - ts).clamp(0.0, double.infinity);
        final c = widget.controller;
        double thumbTop = 0;
        if (_hasMetrics && travel > 0) {
          final pos = c.position;
          final maxExt = pos.maxScrollExtent;
          if (maxExt > 0) {
            thumbTop = (pos.pixels / maxExt) * travel;
            thumbTop = thumbTop.clamp(0.0, travel);
          }
        }
        return SizedBox(
          width: ts,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) => _jumpToLocalY(d.localPosition.dy, h, ts, travel),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 4,
                    height: (h - 8).clamp(0.0, double.infinity),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.trackHintColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: thumbTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    if (!_hasMetrics || travel <= 0) return;
                    final pos = c.position;
                    final maxExt = pos.maxScrollExtent;
                    if (maxExt <= 0) return;
                    final next = pos.pixels + details.delta.dy * maxExt / travel;
                    c.jumpTo(next.clamp(0.0, maxExt));
                  },
                  child: Material(
                    color: widget.thumbColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: ChromeOutline.side,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: ts,
                      height: ts,
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _gripLine((ts * 0.55).clamp(14.0, 24.0)),
                            SizedBox(height: (ts * 0.1).clamp(3.0, 6.0)),
                            _gripLine((ts * 0.55).clamp(14.0, 24.0)),
                            SizedBox(height: (ts * 0.1).clamp(3.0, 6.0)),
                            _gripLine((ts * 0.55).clamp(14.0, 24.0)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Прямоугольная плашка как [NotebookChromeDialogCloseButton]: высота
/// [AppProvider.chromeButtonSize], скругление 8, подпись и иконка масштабируются с [chrome].
class _NotebookChromePanelActionButton extends StatelessWidget {
  const _NotebookChromePanelActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.padding = const EdgeInsets.fromLTRB(6, 2, 6, 2),
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final iconSz = (chrome * 0.5).clamp(18.0, 30.0);
    final fontSize = (chrome * 0.34).clamp(12.0, 16.0);
    final hPad = (chrome * 0.28).clamp(8.0, 14.0);
    final gap = (chrome * 0.18).clamp(8.0, 12.0);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: ChromeOutline.side,
    );
    final rowBg = NotebookChromeUi.secondaryButtonBackground(context);
    final rowFg = NotebookChromeUi.secondaryButtonForeground(context);
    return Padding(
      padding: padding,
      child: SizedBox(
        width: double.infinity,
        child: Material(
          color: rowBg,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            customBorder: shape,
            child: SizedBox(
              height: chrome,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad),
                child: Row(
                  children: [
                    Icon(icon, color: rowFg, size: iconSz),
                    SizedBox(width: gap),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: rowFg,
                          fontWeight: FontWeight.w600,
                          fontSize: fontSize,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotebookMoveFileDialog extends StatefulWidget {
  const _NotebookMoveFileDialog({
    required this.repo,
    required this.sourcePaths,
    required this.fileCount,
    required this.primaryFileName,
    required this.onMoveTo,
  });

  final NotebookRepository repo;
  final List<String> sourcePaths;
  final int fileCount;
  final String primaryFileName;
  final Future<bool> Function(String destParentDir) onMoveTo;

  @override
  State<_NotebookMoveFileDialog> createState() =>
      _NotebookMoveFileDialogState();
}

class _NotebookMoveFileDialogState extends State<_NotebookMoveFileDialog> {
  late String _browseDir;
  List<NotebookListItem> _folders = [];
  bool _loading = true;

  Set<String> get _sourceParentDirs {
    final dirs = <String>{};
    for (final src in widget.sourcePaths) {
      final par = p.posix.dirname(src);
      dirs.add(par == '.' ? '' : par);
    }
    return dirs;
  }

  String _initialBrowseDir() {
    if (widget.sourcePaths.isEmpty) return '';
    final first = widget.sourcePaths.first;
    final parent = p.posix.dirname(first);
    return parent == '.' ? '' : parent;
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final all = await widget.repo.listDirectory(_browseDir);
      final folders = all.where((e) => e.isFolder).toList();
      if (!mounted) return;
      setState(() {
        _folders = folders;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _browseDir = _initialBrowseDir();
    _reload();
  }

  Future<void> _moveHere() async {
    final ok = await widget.onMoveTo(_browseDir);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  void _navigateBrowseTo(String path) {
    if (_browseDir == path) return;
    setState(() => _browseDir = path);
    unawaited(_reload());
  }

  Widget _moveYouAreHereChip(bool isDark, double uiFs) {
    final fg = isDark ? const Color(0xFF90CAF9) : Colors.blue.shade800;
    final fill = fg.withValues(alpha: isDark ? 0.16 : 0.11);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (uiFs * 0.34).clamp(6.0, 12.0),
        vertical: (uiFs * 0.1).clamp(2.0, 5.0),
      ),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: fg.withValues(alpha: 0.38)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.arrow_back,
            size: (uiFs * 0.72).clamp(12.0, 17.0),
            color: fg,
          ),
          SizedBox(width: (uiFs * 0.12).clamp(3.0, 5.0)),
          Text(
            'Вы здесь',
            style: TextStyle(
              color: fg,
              fontWeight: FontWeight.w600,
              fontSize: (uiFs * 0.7).clamp(10.0, 14.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _movePathTreeRow({
    required bool isDark,
    required double uiFs,
    required double monoFs,
    required double rowIcon,
    required String prefix,
    required String label,
    required String targetPath,
    required bool isCurrent,
    required bool isRoot,
  }) {
    final monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: monoFs,
      height: 1.0,
      color: isDark ? Colors.white38 : Colors.black45,
    );
    final nameStyle = TextStyle(
      fontSize: uiFs,
      height: 1.0,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.white : Colors.black87,
    );
    final isSourceParent = _sourceParentDirs.contains(targetPath);
    final rowIconData = isRoot
        ? Icons.home_outlined
        : (isSourceParent ? Icons.folder : Icons.folder_outlined);
    return Material(
      color: isSourceParent
          ? (isDark
              ? Colors.grey.shade700.withValues(alpha: 0.5)
              : Colors.grey.shade300.withValues(alpha: 0.72))
          : isCurrent
              ? (isDark
                  ? Colors.blueGrey.shade700.withValues(alpha: 0.42)
                  : Colors.blue.shade50.withValues(alpha: 0.92))
              : Colors.transparent,
      child: InkWell(
        onTap: () => _navigateBrowseTo(targetPath),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: (uiFs * 0.05).clamp(1.0, 3.0),
            horizontal: 4,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (prefix.isNotEmpty) Text(prefix, style: monoStyle),
              Icon(
                rowIconData,
                size: rowIcon,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              Expanded(
                child: Text(label, style: nameStyle, maxLines: 2),
              ),
              if (isCurrent) ...[
                SizedBox(width: (uiFs * 0.2).clamp(4.0, 8.0)),
                Flexible(
                  fit: FlexFit.loose,
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: _moveYouAreHereChip(isDark, uiFs),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _moveChildFolderRow({
    required bool isDark,
    required double uiFs,
    required double monoFs,
    required double rowIcon,
    required String prefix,
    required NotebookListItem folder,
  }) {
    final monoStyle = TextStyle(
      fontFamily: 'monospace',
      fontSize: monoFs,
      height: 1.0,
      color: isDark ? Colors.white38 : Colors.black45,
    );
    final nameStyle = TextStyle(
      fontSize: uiFs,
      height: 1.0,
      color: isDark ? Colors.white : Colors.black87,
    );
    final isSourceParent = _sourceParentDirs.contains(folder.relativePath);
    final rowIconData = isSourceParent ? Icons.folder : Icons.folder_outlined;
    return Material(
      color: isSourceParent
          ? (isDark
              ? Colors.grey.shade700.withValues(alpha: 0.5)
              : Colors.grey.shade300.withValues(alpha: 0.72))
          : Colors.transparent,
      child: InkWell(
        onTap: () => _navigateBrowseTo(folder.relativePath),
        child: Padding(
          padding: EdgeInsets.symmetric(
            vertical: (uiFs * 0.05).clamp(1.0, 3.0),
            horizontal: 4,
          ),
          child: Row(
            children: [
              if (prefix.isNotEmpty) Text(prefix, style: monoStyle),
              Icon(
                rowIconData,
                size: rowIcon,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
              Expanded(
                child: Text(
                  folder.name,
                  style: nameStyle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _moveScrollableBody(bool isDark, double uiFs, double rowIcon) {
    final parts = _notebookMoveDialogPathSegments(_browseDir);
    final deep = parts.length;
    final monoFs = (uiFs * 0.84).clamp(11.0, 17.0);
    final children = <Widget>[
      _movePathTreeRow(
        isDark: isDark,
        uiFs: uiFs,
        monoFs: monoFs,
        rowIcon: rowIcon,
        prefix: '',
        label: 'Корень',
        targetPath: '',
        isCurrent: deep == 0,
        isRoot: true,
      ),
    ];
    for (var i = 0; i < parts.length; i++) {
      children.add(
        _movePathTreeRow(
          isDark: isDark,
          uiFs: uiFs,
          monoFs: monoFs,
          rowIcon: rowIcon,
          prefix: _notebookMoveDialogTreePrefix(i + 1, deep),
          label: parts[i],
          targetPath: parts.sublist(0, i + 1).join('/'),
          isCurrent: i == parts.length - 1,
          isRoot: false,
        ),
      );
    }
    if (_folders.isNotEmpty) {
      children.add(SizedBox(height: (uiFs * 0.18).clamp(3.0, 6.0)));
      children.add(
        Divider(
          height: 1,
          thickness: 1,
          color: isDark ? Colors.white24 : Colors.black12,
        ),
      );
      children.add(SizedBox(height: (uiFs * 0.12).clamp(2.0, 4.0)));
      children.add(
        Text(
          'Вложенные папки',
          style: TextStyle(
            fontSize: (uiFs * 0.78).clamp(11.0, 16.0),
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
      );
      final n = _folders.length;
      final depth = parts.length;
      for (var i = 0; i < n; i++) {
        children.add(
          _moveChildFolderRow(
            isDark: isDark,
            uiFs: uiFs,
            monoFs: monoFs,
            rowIcon: rowIcon,
            prefix: _notebookMoveDialogChildBranchPrefix(i, n, depth),
            folder: _folders[i],
          ),
        );
      }
    } else if (_browseDir.isNotEmpty) {
      children.add(SizedBox(height: (uiFs * 0.15).clamp(3.0, 6.0)));
      children.add(
        Text(
          'Нет вложенных папок',
          style: TextStyle(
            color: isDark ? Colors.white54 : Colors.black45,
            fontSize: (uiFs * 0.88).clamp(12.0, 20.0),
          ),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final app = context.watch<AppProvider>();
    final uiFs = app.fontSize;
    final chrome = app.chromeButtonSize;
    final rowIcon = (24.0 * uiFs / 16.0).clamp(20.0, 48.0);
    final treePanelBg =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5);
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              widget.fileCount > 1
                  ? 'Переместить выбранные файлы (${widget.fileCount})'
                  : 'Переместить «${widget.primaryFileName}»',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          NotebookChromeDialogCloseButton(
            onPressed: () => Navigator.of(context).pop(false),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(height: (uiFs * 0.25).clamp(6.0, 10.0)),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: treePanelBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: ChromeOutline.color,
                    width: ChromeOutline.width,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _moveScrollableBody(isDark, uiFs, rowIcon),
                ),
              ),
            ),
            SizedBox(height: (uiFs * 0.25).clamp(6.0, 10.0)),
            _NotebookChromePanelActionButton(
              icon: Icons.drive_file_move_outline,
              label: 'Переместить сюда',
              onTap: () => unawaited(_moveHere()),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
      ),
    );
  }
}
