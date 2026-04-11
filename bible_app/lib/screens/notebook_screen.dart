import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io';

import 'package:bible_app/notebook/notebook_list_item.dart';
import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:bible_app/notebook/notebook_repository_factory.dart';
import 'package:bible_app/screens/notebook_editor_panel.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:bible_app/widgets/notebook_chrome_dialog_button.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

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

  Future<void> _exportNotebookFile(String relativePath) async {
    final repo = _repo;
    if (repo == null) return;
    final name = p.basename(relativePath);
    if (kIsWeb) {
      await _shareNotebookFile(relativePath);
      return;
    }
    try {
      final text = await repo.readFile(relativePath);
      final path = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить документ',
        fileName: name.toLowerCase().endsWith('.txt') ? name : '$name.txt',
        type: FileType.any,
      );
      if (path == null) return;
      final file = File(path);
      await file.writeAsString(text, encoding: utf8, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл записан: $path')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить: $e')),
        );
      }
    }
  }

  Future<void> _showListItemFileMenu(
    BuildContext menuContext,
    NotebookListItem item,
    Offset globalPosition,
  ) async {
    const fg = Color(0xDD000000);
    final overlay =
        Overlay.of(menuContext).context.findRenderObject()! as RenderBox;
    final oSize = overlay.size;
    const menuW = 280.0;
    const pad = 8.0;
    final left = (oSize.width - menuW - pad).clamp(pad, oSize.width - menuW - pad);
    final top = globalPosition.dy.clamp(pad, oSize.height - pad);

    final choice = await showMenu<String>(
      context: menuContext,
      position: RelativeRect.fromLTRB(left, top, oSize.width - pad, top + 1),
      color: Colors.white,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (!item.isFolder) ...[
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
        ],
        PopupMenuItem<String>(
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
          value: 'rename',
          child: chromePopupMenuChoiceTile(
            label: 'Переименовать',
            icon: Icons.drive_file_rename_outline,
            iconColor: fg,
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<String>(
          padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
          value: 'del',
          child: chromePopupMenuChoiceTile(
            label: item.isFolder ? 'Удалить папку' : 'Удалить документ',
            icon: Icons.delete_outline,
            iconColor: fg,
          ),
        ),
      ],
    );
    if (!menuContext.mounted || choice == null) return;
    switch (choice) {
      case 'share':
        await _shareNotebookFile(item.relativePath);
        return;
      case 'export':
        await _exportNotebookFile(item.relativePath);
        return;
      case 'rename':
        await _renameItem(item);
        return;
      case 'del':
        await _deleteItem(item);
        return;
    }
  }

  Widget _buildNotebookPathStrip({
    required String label,
    required String pathValue,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? const Color(0xFF455A64) : const Color(0xFFE1F5FE);
    final labelColor = isDark ? Colors.white70 : Colors.black54;
    final valueColor = isDark ? Colors.white : Colors.black87;
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final labelSize = (chrome * 0.36).clamp(12.0, 20.0);
    final valueSize = (chrome * 0.38).clamp(13.0, 17.0);
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

  Future<void> _createDocument() async {
    final repo = _repo;
    if (repo == null) return;
    final ctrl = TextEditingController(text: 'заметка');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: Text('Новый документ')),
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
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(border: OutlineInputBorder()),
          autofocus: true,
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
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Expanded(child: Text('Удалить?')),
            NotebookChromeDialogCloseButton(
              onPressed: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
        content: Text(
          item.isFolder
              ? 'Папка «${item.name}» должна быть пустой.'
              : 'Файл «${item.name}» будет удалён.',
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
                                    style:
                                        TextStyle(color: Colors.grey.shade700),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _items.length,
                                  itemBuilder: (listContext, i) {
                                    final item = _items[i];
                                    return GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () => _openItem(item),
                                      onLongPressStart: (details) {
                                        unawaited(
                                          _showListItemFileMenu(
                                            listContext,
                                            item,
                                            details.globalPosition,
                                          ),
                                        );
                                      },
                                      child: ListTile(
                                        leading: Icon(
                                          item.isFolder
                                              ? Icons.folder_outlined
                                              : Icons.description_outlined,
                                        ),
                                        title: Text(item.name),
                                      ),
                                    );
                                  },
                                ),
                        ),
                        if (_currentDir.isNotEmpty) _buildListFolderFooter(),
                      ],
                    ),
    );
  }
}
