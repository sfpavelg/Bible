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
  bool _editorDirty = false;

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

  Future<void> _refresh() async {
    final repo = _repo;
    if (repo == null) return;
    try {
      final list = await repo.listDirectory(_currentDir);
      if (mounted) setState(() => _items = list);
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
      _editorDirty = false;
    });
    await _refresh();
  }

  void _openEditor(String relativePath) {
    setState(() {
      _editingPath = relativePath;
      _editorKey = GlobalKey<NotebookEditorPanelState>();
      _editorDirty = false;
    });
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

  Future<void> _createDocument() async {
    final repo = _repo;
    if (repo == null) return;
    final ctrl = TextEditingController(text: 'заметка');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новый документ'),
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
          NotebookChromeDialogActions(
            startLabel: 'Отмена',
            onStart: () => Navigator.pop(ctx, false),
            startStyle: NotebookDialogActionStyle.cancel,
            endLabel: 'Создать',
            onEnd: () => Navigator.pop(ctx, true),
            endStyle: NotebookDialogActionStyle.confirm,
          ),
        ],
      ),
    );
    if (ok != true) return;
    final name = _ensureTxtName(ctrl.text);
    final rel = _currentDir.isEmpty ? name : p.posix.join(_currentDir, name);
    try {
      await repo.createFile(rel);
      await _refresh();
      if (!mounted) return;
      _openEditor(rel);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать: $e')),
        );
      }
    }
  }

  Future<void> _createFolder() async {
    final repo = _repo;
    if (repo == null) return;
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Новая папка'),
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
          NotebookChromeDialogActions(
            startLabel: 'Отмена',
            onStart: () => Navigator.pop(ctx, false),
            startStyle: NotebookDialogActionStyle.cancel,
            endLabel: 'Создать',
            onEnd: () => Navigator.pop(ctx, true),
            endStyle: NotebookDialogActionStyle.confirm,
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать папку: $e')),
        );
      }
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

  Future<void> _renameItem(NotebookListItem item) async {
    final repo = _repo;
    if (repo == null) return;
    final ctrl = TextEditingController(text: item.name);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.isFolder ? 'Переименовать папку' : 'Переименовать файл'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
        ),
        actions: [
          NotebookChromeDialogActions(
            startLabel: 'Отмена',
            onStart: () => Navigator.pop(ctx, false),
            startStyle: NotebookDialogActionStyle.cancel,
            endLabel: 'Сохранить',
            onEnd: () => Navigator.pop(ctx, true),
            endStyle: NotebookDialogActionStyle.confirm,
          ),
        ],
      ),
    );
    if (ok != true) return;
    final newSeg = _sanitizeSegment(ctrl.text);
    if (newSeg.isEmpty) return;
    final newName = item.isFolder ? newSeg : _ensureTxtName(newSeg);
    final parent = p.posix.dirname(item.relativePath);
    final toRel =
        parent == '.' ? newName : p.posix.join(parent, newName);
    try {
      await repo.rename(item.relativePath, toRel);
      if (_editingPath == item.relativePath) {
        setState(() => _editingPath = toRel);
      }
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось переименовать: $e')),
        );
      }
    }
  }

  Future<void> _deleteItem(NotebookListItem item) async {
    final repo = _repo;
    if (repo == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить?'),
        content: Text(
          item.isFolder
              ? 'Папка «${item.name}» должна быть пустой.'
              : 'Файл «${item.name}» будет удалён.',
        ),
        actions: [
          NotebookChromeDialogActions(
            startLabel: 'Отмена',
            onStart: () => Navigator.pop(ctx, false),
            startStyle: NotebookDialogActionStyle.cancel,
            endLabel: 'Удалить',
            onEnd: () => Navigator.pop(ctx, true),
            endStyle: NotebookDialogActionStyle.danger,
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.delete(item.relativePath);
      if (_editingPath == item.relativePath) {
        await _closeEditor();
      } else {
        await _refresh();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить: $e')),
        );
      }
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
    final toolbarH = (chrome + 10).clamp(kToolbarHeight, 78.0);
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
      leadingWidth: _currentDir.isEmpty
          ? null
          : (chrome + 8).clamp(52.0, 90.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
      ),
      leading: _currentDir.isEmpty
          ? null
          : Align(
              alignment: Alignment.center,
              child: ChromeIconButton(
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
            _chromeIconButton(
              icon: Icons.refresh,
              tooltip: 'Обновить список',
              onPressed: _refresh,
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
    final name = p.basename(_editingPath!);
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final toolbarH = (chrome + 10).clamp(kToolbarHeight, 78.0);
    final menuIcon = (chrome * 0.5).clamp(18.0, 30.0);
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
      title: Text(
        name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: chromeFg, fontSize: 18),
      ),
      actions: [
        if (_editorDirty)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Center(
              child: Text(
                '…',
                style: TextStyle(
                  fontSize: (chrome * 0.42).clamp(14.0, 22.0),
                  color: Colors.orange,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
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
        SizedBox(
          width: chrome,
          height: chrome,
          child: Material(
            color: buttonBg,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: ChromeOutline.side,
            ),
            clipBehavior: Clip.antiAlias,
            child: Theme(
              data: ThemeData.light(useMaterial3: true).copyWith(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
                popupMenuTheme: const PopupMenuThemeData(
                  surfaceTintColor: Colors.transparent,
                ),
              ),
              child: PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                icon: Icon(Icons.more_horiz, color: chromeFg, size: menuIcon),
                tooltip: 'Действия с документом',
                position: PopupMenuPosition.under,
                offset: const Offset(0, 8),
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 4,
                onSelected: (v) =>
                    _editorKey?.currentState?.runEditorMenuAction(v),
                itemBuilder: (context) {
                  const fg = Color(0xDD000000);
                  return [
                    PopupMenuItem<String>(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 3),
                      value: 'share',
                      child: chromePopupMenuChoiceTile(
                        label: 'Поделиться…',
                        icon: Icons.share_outlined,
                        iconColor: fg,
                      ),
                    ),
                    PopupMenuItem<String>(
                      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                      value: 'export',
                      child: chromePopupMenuChoiceTile(
                        label: 'Сохранить в файл…',
                        icon: Icons.save_alt_outlined,
                        iconColor: fg,
                      ),
                    ),
                    PopupMenuItem<String>(
                      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                      value: 'copy',
                      child: chromePopupMenuChoiceTile(
                        label: 'Копировать весь текст',
                        icon: Icons.copy_all_outlined,
                        iconColor: fg,
                      ),
                    ),
                    PopupMenuItem<String>(
                      padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                      value: 'mail',
                      child: chromePopupMenuChoiceTile(
                        label: 'Отправить на почту…',
                        icon: Icons.mail_outline,
                        iconColor: fg,
                      ),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem<String>(
                      padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
                      value: 'del',
                      child: chromePopupMenuChoiceTile(
                        label: 'Удалить документ',
                        icon: Icons.delete_outline,
                        iconColor: fg,
                      ),
                    ),
                  ];
                },
              ),
            ),
          ),
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
                  ? NotebookEditorPanel(
                      key: _editorKey,
                      repo: _repo!,
                      relativePath: _editingPath!,
                      onDirtyChanged: (d) {
                        if (mounted) setState(() => _editorDirty = d);
                      },
                      onDocumentDeleted: () {
                        _closeEditor();
                      },
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
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _items.length,
                                  itemBuilder: (context, i) {
                                    final item = _items[i];
                                    return ListTile(
                                      leading: Icon(
                                        item.isFolder
                                            ? Icons.folder_outlined
                                            : Icons.description_outlined,
                                      ),
                                      title: Text(item.name),
                                      onTap: () => _openItem(item),
                                      onLongPress: () {
                                        showModalBottomSheet<void>(
                                          context: context,
                                          showDragHandle: true,
                                          builder: (ctx) => SafeArea(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons
                                                        .drive_file_rename_outline,
                                                  ),
                                                  title: const Text(
                                                    'Переименовать',
                                                  ),
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    _renameItem(item);
                                                  },
                                                ),
                                                ListTile(
                                                  leading: const Icon(
                                                    Icons.delete_outline,
                                                    color: Colors.red,
                                                  ),
                                                  title: const Text('Удалить'),
                                                  onTap: () {
                                                    Navigator.pop(ctx);
                                                    _deleteItem(item);
                                                  },
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
    );
  }
}
