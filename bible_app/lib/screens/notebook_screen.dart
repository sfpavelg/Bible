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
      if (!_notebookPosixPathsEqualInsensitive(e.relativePath, item.relativePath)) {
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
    if (!_notebookPosixPathsEqualInsensitive(e.relativePath, item.relativePath)) {
      return true;
    }
  }
  return false;
}

String _notebookMoveDialogPathCaption(String posixDir) {
  if (posixDir.isEmpty) return '(корень)';
  final norm = p.posix.normalize(posixDir);
  if (norm == '.' || norm.isEmpty) return '(корень)';
  final parts =
      p.posix.split(norm).where((e) => e.isNotEmpty && e != '.').toList();
  if (parts.isEmpty) return '(корень)';
  return '(корень)/${parts.join('/')}';
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

  bool get _fileBulkSelectionUi =>
      _fileActionsAnchor != null && !_fileActionsAnchor!.isFolder;

  /// Пути выбранных .txt в порядке строк списка (для пакетного переноса).
  List<String> _orderedBulkSelectedFilePaths() {
    if (_bulkSelectedFilePaths.isEmpty) return const [];
    final ordered = _items
        .where(
          (it) => !it.isFolder && _bulkSelectedFilePaths.contains(it.relativePath),
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
    _openRepo();
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
    });
    await _refresh();
  }

  void _openEditor(String relativePath) {
    setState(() {
      _editingPath = relativePath;
      _editorKey = GlobalKey<NotebookEditorPanelState>();
    });
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
    final parent = p.posix.dirname(item.relativePath);
    final destRel =
        parent == '.' ? destName : p.posix.join(parent, destName);
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
    final canRename =
        a.isFolder || _bulkSelectedFilePaths.length <= 1;
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
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: labelSize,
                ),
              ),
              const SizedBox(height: 4),
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

  Widget _buildEditorDocumentFooter() {
    return _buildNotebookPathStrip(
      label: 'Документ:',
      pathValue: _notebookPathForDisplay(_editingPath!),
    );
  }

  Widget _buildListFolderFooter() {
    return _buildNotebookPathStrip(
      label: 'Папка:',
      pathValue: _notebookPathForDisplay(_currentDir),
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
    final destRel = destParentDir.isEmpty
        ? base
        : p.posix.join(destParentDir, base);
    final srcNorm = p.posix.normalize(sourcePath);
    final dstNorm = p.posix.normalize(destRel);
    void feedback(String text, {bool preferOverlay = false}) {
      if (!mounted) return;
      if (preferOverlay && topOverlayMessages) {
        _showNotebookTopOverlayMessage(context, text);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
    final primaryName =
        p.posix.basename(sourcePaths.first);
    final moved = await showDialog<bool>(
      context: context,
      builder: (ctx) => _NotebookMoveFileDialog(
        repo: repo,
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
        newName = newSeg;
      } else {
        newName = _finalTxtNameFromRenameField(ctrl.text);
      }
      final parent = p.posix.dirname(item.relativePath);
      final toRel =
          parent == '.' ? newName : p.posix.join(parent, newName);
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
        AppChromeOverflowMenu(
          iconColor: chromeFg,
          backgroundColor: buttonBg,
        ),
      ],
    );
  }

  PreferredSizeWidget _buildEditorAppBar() {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final toolbarH = AppProvider.toolbarHeightForChrome(chrome);
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
        AppChromeOverflowMenu(
          iconColor: chromeFg,
          backgroundColor: buttonBg,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = _editingPath != null && _editorKey != null && _repo != null;
    final uiListFontSize = context.watch<AppProvider>().fontSize;
    final listIconSize = (24.0 * uiListFontSize / 16.0).clamp(20.0, 48.0);
    const listCbBox = 48.0;

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
                                          final bulk =
                                              _fileBulkSelectionUi &&
                                                  !item.isFolder;
                                          final sel = _bulkSelectedFilePaths
                                              .contains(item.relativePath);
                                          final isDark = Theme.of(context)
                                                  .brightness ==
                                              Brightness.dark;
                                          final tileBg = bulk && sel
                                              ? (isDark
                                                  ? Colors.blueGrey.shade700
                                                      .withValues(alpha: 0.45)
                                                  : Colors.amber.shade100)
                                              : null;

                                          return ListTile(
                                            dense: true,
                                            minVerticalPadding: 0,
                                            visualDensity: const VisualDensity(
                                              horizontal: 0,
                                              vertical: -4,
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 1,
                                            ),
                                            tileColor: tileBg,
                                            minLeadingWidth: bulk
                                                ? listIconSize * 1.15
                                                : listIconSize + 12,
                                            leading: bulk
                                                ? SizedBox(
                                                    width: listIconSize * 1.2,
                                                    height: listIconSize * 1.2,
                                                    child: Center(
                                                      child: FittedBox(
                                                        fit: BoxFit.contain,
                                                        child: SizedBox(
                                                          width: listCbBox,
                                                          height: listCbBox,
                                                          child: Checkbox(
                                                            value: sel,
                                                            onChanged: (v) {
                                                              setState(() {
                                                                if (v == true) {
                                                                  _bulkSelectedFilePaths
                                                                      .add(item
                                                                          .relativePath);
                                                                } else {
                                                                  _bulkSelectedFilePaths
                                                                      .remove(item
                                                                          .relativePath);
                                                                }
                                                              });
                                                            },
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  )
                                                : Icon(
                                                    item.isFolder
                                                        ? Icons.folder_outlined
                                                        : Icons
                                                            .description_outlined,
                                                    size: listIconSize,
                                                  ),
                                            title: Text(
                                              item.name,
                                              style: TextStyle(
                                                fontSize: uiListFontSize,
                                                fontWeight: FontWeight.w500,
                                                height: 1.0,
                                              ),
                                            ),
                                            onTap: () {
                                              if (bulk) {
                                                setState(() {
                                                  if (sel) {
                                                    _bulkSelectedFilePaths
                                                        .remove(item
                                                            .relativePath);
                                                  } else {
                                                    _bulkSelectedFilePaths.add(
                                                        item.relativePath);
                                                  }
                                                });
                                                return;
                                              }
                                              if (_fileActionsAnchor !=
                                                      null &&
                                                  item.isFolder) {
                                                _closeFileActionsPanel();
                                              }
                                              _openItem(item);
                                            },
                                            onLongPress: () =>
                                                _openFileActionsPanel(item),
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
    required this.fileCount,
    required this.primaryFileName,
    required this.onMoveTo,
  });

  final NotebookRepository repo;
  final int fileCount;
  final String primaryFileName;
  final Future<bool> Function(String destParentDir) onMoveTo;

  @override
  State<_NotebookMoveFileDialog> createState() => _NotebookMoveFileDialogState();
}

class _NotebookMoveFileDialogState extends State<_NotebookMoveFileDialog> {
  String _browseDir = '';
  List<NotebookListItem> _folders = [];
  bool _loading = true;

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
    _reload();
  }

  void _goUp() {
    if (_browseDir.isEmpty) return;
    final par = p.posix.dirname(_browseDir);
    setState(() => _browseDir = par == '.' ? '' : par);
    unawaited(_reload());
  }

  Future<void> _moveHere() async {
    final ok = await widget.onMoveTo(_browseDir);
    if (ok && mounted) Navigator.of(context).pop(true);
  }

  Widget _pathStrip(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF455A64) : const Color(0xFFE1F5FE);
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final valueColor = isDark ? Colors.white : Colors.black87;
    final fs = context.watch<AppProvider>().fontSize;
    final labelSize = (fs * 0.88).clamp(11.0, 32.0);
    final valueSize = fs.clamp(12.0, 40.0);
    final shown = _notebookMoveDialogPathCaption(_browseDir);
    return Material(
      color: barBg,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0x44000000), width: 1),
        ),
        child: SelectableText.rich(
          TextSpan(
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w500,
              fontSize: valueSize,
              height: 1.35,
            ),
            children: [
              TextSpan(
                text: 'Папка: ',
                style: TextStyle(
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  fontSize: labelSize,
                ),
              ),
              TextSpan(text: shown),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final uiFs = context.watch<AppProvider>().fontSize;
    final rowIcon = (24.0 * uiFs / 16.0).clamp(20.0, 48.0);
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
        height: 300,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Выберите папку в списке, затем нажмите «Переместить сюда».',
              style: TextStyle(
                fontSize: (uiFs * 0.88).clamp(12.0, 22.0),
                height: 1.3,
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            _pathStrip(context),
            Divider(
              height: 10,
              thickness: 1,
              color: isDark ? Colors.white24 : null,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      children: [
                        if (_browseDir.isNotEmpty)
                          ListTile(
                            dense: true,
                            minVerticalPadding: 0,
                            visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -4,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 1,
                            ),
                            minLeadingWidth: rowIcon + 12,
                            leading: Icon(
                              Icons.arrow_upward,
                              size: rowIcon,
                              color:
                                  isDark ? Colors.white : Colors.black87,
                            ),
                            title: Text(
                              'Вверх',
                              style: TextStyle(
                                fontSize: uiFs,
                                height: 1.0,
                                color:
                                    isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            onTap: _goUp,
                          ),
                        if (!_loading &&
                            _folders.isEmpty &&
                            _browseDir.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                            child: Text(
                              'Нет вложенных папок.',
                              style: TextStyle(
                                color: isDark ? Colors.white54 : Colors.black45,
                                fontSize: (uiFs * 0.92).clamp(12.0, 24.0),
                              ),
                            ),
                          ),
                        for (final f in _folders)
                          ListTile(
                            dense: true,
                            minVerticalPadding: 0,
                            visualDensity: const VisualDensity(
                              horizontal: 0,
                              vertical: -4,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 1,
                            ),
                            minLeadingWidth: rowIcon + 12,
                            leading: Icon(
                              Icons.folder_outlined,
                              size: rowIcon,
                              color:
                                  isDark ? Colors.white : Colors.black87,
                            ),
                            title: Text(
                              f.name,
                              style: TextStyle(
                                fontSize: uiFs,
                                height: 1.0,
                                color:
                                    isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            onTap: () {
                              setState(() => _browseDir = f.relativePath);
                              unawaited(_reload());
                            },
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 8),
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
