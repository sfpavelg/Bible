import 'dart:convert';
import 'dart:io';

import 'package:bible_app/notebook/notebook_list_item.dart';
import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

Future<NotebookRepository> openNotebookRepository() async {
  final base = await getApplicationDocumentsDirectory();
  final root = Directory(p.join(base.path, 'bible_notebook'));
  if (!await root.exists()) {
    await root.create(recursive: true);
  }
  return NotebookRepositoryIo(root);
}

class NotebookRepositoryIo implements NotebookRepository {
  NotebookRepositoryIo(this._root);

  final Directory _root;

  @override
  bool get isFileSystemBacked => true;

  @override
  Future<void> init() async {}

  String _abs(String rel) {
    final parts = rel
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty && s != '.')
        .toList();
    if (parts.any((s) => s == '..')) {
      throw ArgumentError('Недопустимый путь');
    }
    return p.joinAll([_root.path, ...parts]);
  }

  String _normalizeDir(String relativeDir) {
    final parts = relativeDir
        .replaceAll('\\', '/')
        .split('/')
        .where((s) => s.isNotEmpty && s != '.')
        .toList();
    if (parts.any((s) => s == '..')) {
      throw ArgumentError('Недопустимый путь');
    }
    return parts.join('/');
  }

  @override
  Future<List<NotebookListItem>> listDirectory(String relativeDir) async {
    final norm = _normalizeDir(relativeDir);
    final dir = Directory(_abs(norm));
    if (!await dir.exists()) return [];

    final list = await dir.list(followLinks: false).toList();
    list.sort((a, b) {
      final ad = a is Directory;
      final bd = b is Directory;
      if (ad != bd) return ad ? -1 : 1;
      return p.basename(a.path).toLowerCase().compareTo(
            p.basename(b.path).toLowerCase(),
          );
    });

    return list.map((e) {
      final name = p.basename(e.path);
      final rp = norm.isEmpty ? name : '$norm/$name';
      return NotebookListItem(
        name: name,
        isFolder: e is Directory,
        relativePath: rp,
      );
    }).toList();
  }

  @override
  Future<String> readFile(String relativePath) async {
    final file = File(_abs(relativePath));
    if (!await file.exists()) return '';
    return file.readAsString(encoding: utf8);
  }

  @override
  Future<void> writeFile(String relativePath, String content) async {
    final file = File(_abs(relativePath));
    await file.parent.create(recursive: true);
    await file.writeAsString(content, encoding: utf8, flush: true);
  }

  @override
  Future<void> createFile(String relativePath) async {
    final file = File(_abs(relativePath));
    if (await file.exists()) {
      throw StateError('Файл уже существует');
    }
    await file.parent.create(recursive: true);
    await file.writeAsString('', encoding: utf8, flush: true);
  }

  @override
  Future<void> createFolder(String relativePath) async {
    final dir = Directory(_abs(relativePath));
    if (await dir.exists()) {
      throw StateError('Папка уже существует');
    }
    await dir.create(recursive: true);
  }

  @override
  Future<void> delete(String relativePath) async {
    final path = _abs(relativePath);
    final f = File(path);
    final d = Directory(path);
    if (await f.exists()) {
      await f.delete();
      return;
    }
    if (await d.exists()) {
      final children = await d.list().toList();
      if (children.isNotEmpty) {
        throw StateError('Папка не пуста');
      }
      await d.delete();
    }
  }

  @override
  Future<void> deleteRecursive(String relativePath) async {
    final path = _abs(relativePath);
    final f = File(path);
    final d = Directory(path);
    if (await f.exists()) {
      await f.delete();
      return;
    }
    if (await d.exists()) {
      await d.delete(recursive: true);
    }
  }

  bool _sameIoPath(String a, String b) {
    if (Platform.isWindows) return a.toLowerCase() == b.toLowerCase();
    return a == b;
  }

  @override
  Future<void> rename(String fromRelative, String toRelative) async {
    final from = _abs(fromRelative);
    final to = _abs(toRelative);
    final fromFile = File(from);
    final fromDir = Directory(from);
    if (!_sameIoPath(from, to)) {
      final toFile = File(to);
      final toDir = Directory(to);
      if (await toFile.exists() || await toDir.exists()) {
        throw StateError('Цель уже существует');
      }
    }
    if (await fromFile.exists()) {
      await fromFile.rename(to);
      return;
    }
    if (await fromDir.exists()) {
      await fromDir.rename(to);
    }
  }

  @override
  Future<String?> nativeFilePath(String relativePath) async =>
      _abs(relativePath);
}
