import 'package:bible_app/notebook/notebook_list_item.dart';
import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:bible_app/notebook/notebook_repository_factory.dart';
import 'package:bible_app/screens/notebook_editor_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
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
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => NotebookEditorScreen(repo: repo, relativePath: rel),
        ),
      );
      await _refresh();
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Создать'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final seg = _sanitizeSegment(ctrl.text);
    if (seg.isEmpty) return;
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
    await Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (_) =>
            NotebookEditorScreen(repo: repo, relativePath: item.relativePath),
      ),
    );
    await _refresh();
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Сохранить'),
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.delete(item.relativePath);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _currentDir.isEmpty
        ? (kIsWeb
            ? 'Хранение в браузере (SharedPreferences)'
            : 'Папка приложения: Documents/bible_notebook')
        : _currentDir.replaceAll('/', ' / ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Блокнот'),
        leading: _currentDir.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: _goUp,
              ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'doc') _createDocument();
              if (v == 'folder') _createFolder();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'doc', child: Text('Новый документ .txt')),
              PopupMenuItem(value: 'folder', child: Text('Новая папка')),
            ],
          ),
        ],
      ),
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
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              subtitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blueGrey.shade800,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Долгий тап — переименовать или удалить.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: _items.isEmpty
                          ? Center(
                              child: Text(
                                _currentDir.isEmpty
                                    ? 'Нет документов.\nСоздайте новый через меню «⋯».'
                                    : 'Папка пуста.',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey.shade700),
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
                                                Icons.drive_file_rename_outline,
                                              ),
                                              title: const Text('Переименовать'),
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
