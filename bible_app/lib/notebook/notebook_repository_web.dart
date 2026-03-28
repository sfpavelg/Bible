import 'dart:convert';

import 'package:bible_app/notebook/notebook_list_item.dart';
import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefsKey = 'notebook_web_files_v1';

Future<NotebookRepository> openNotebookRepository() async {
  final prefs = await SharedPreferences.getInstance();
  return NotebookRepositoryWeb(prefs);
}

class NotebookRepositoryWeb implements NotebookRepository {
  NotebookRepositoryWeb(this._prefs);

  final SharedPreferences _prefs;

  Map<String, String> _files = {};

  @override
  bool get isFileSystemBacked => false;

  @override
  Future<void> init() async {
    final raw = _prefs.getString(_prefsKey);
    if (raw == null || raw.isEmpty) {
      _files = {};
      return;
    }
    try {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      _files = decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      _files = {};
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(_prefsKey, jsonEncode(_files));
  }

  static List<String> _parts(String rel) => rel
      .replaceAll('\\', '/')
      .split('/')
      .where((s) => s.isNotEmpty && s != '.')
      .toList();

  static String _join(List<String> parts) => parts.join('/');

  static void _assertSafe(String rel) {
    if (_parts(rel).any((s) => s == '..')) {
      throw ArgumentError('Недопустимый путь');
    }
  }

  @override
  Future<List<NotebookListItem>> listDirectory(String relativeDir) async {
    _assertSafe(relativeDir);
    final dirNorm = _join(_parts(relativeDir));
    final prefix = dirNorm.isEmpty ? '' : '$dirNorm/';

    final dirNames = <String>{};
    final fileNames = <String>{};

    for (final key in _files.keys) {
      if (key.endsWith('/.folder_placeholder')) {
        final fp = key.substring(0, key.length - '/.folder_placeholder'.length);
        if (fp.isEmpty) continue;
        if (dirNorm.isEmpty) {
          dirNames.add(fp.split('/').first);
        } else if (fp == dirNorm) {
          continue;
        } else if (fp.startsWith('$dirNorm/')) {
          final rest = fp.substring(dirNorm.length + 1);
          if (rest.isNotEmpty) {
            dirNames.add(rest.split('/').first);
          }
        }
        continue;
      }

      if (dirNorm.isNotEmpty && !key.startsWith(prefix)) continue;
      if (dirNorm.isEmpty && key.startsWith('/')) continue;

      final rest = dirNorm.isEmpty ? key : key.substring(prefix.length);
      if (rest.isEmpty) continue;
      final seg = rest.split('/');
      if (seg.length == 1) {
        fileNames.add(seg[0]);
      } else {
        dirNames.add(seg[0]);
      }
    }

    final items = <NotebookListItem>[];
    for (final d in dirNames) {
      final rp = dirNorm.isEmpty ? d : '$dirNorm/$d';
      items.add(NotebookListItem(name: d, isFolder: true, relativePath: rp));
    }
    for (final f in fileNames) {
      if (!f.toLowerCase().endsWith('.txt')) continue;
      final rp = dirNorm.isEmpty ? f : '$dirNorm/$f';
      items.add(NotebookListItem(name: f, isFolder: false, relativePath: rp));
    }
    items.sort((a, b) {
      if (a.isFolder != b.isFolder) return a.isFolder ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  @override
  Future<String> readFile(String relativePath) async {
    _assertSafe(relativePath);
    return _files[relativePath] ?? '';
  }

  @override
  Future<void> writeFile(String relativePath, String content) async {
    _assertSafe(relativePath);
    _files[relativePath] = content;
    await _persist();
  }

  @override
  Future<void> createFile(String relativePath) async {
    _assertSafe(relativePath);
    if (_files.containsKey(relativePath)) {
      throw StateError('Файл уже существует');
    }
    _files[relativePath] = '';
    await _persist();
  }

  @override
  Future<void> createFolder(String relativePath) async {
    _assertSafe(relativePath);
    final marker = '$relativePath/.folder_placeholder';
    if (_files.containsKey(marker)) {
      throw StateError('Папка уже существует');
    }
    _files[marker] = '';
    await _persist();
  }

  @override
  Future<void> delete(String relativePath) async {
    _assertSafe(relativePath);
    final dirMarker = '$relativePath/.folder_placeholder';
    final prefix = '$relativePath/';

    if (_files.containsKey(relativePath) &&
        relativePath.toLowerCase().endsWith('.txt')) {
      _files.remove(relativePath);
      await _persist();
      return;
    }

    final under = _files.keys
        .where((k) => k.startsWith(prefix) && k != dirMarker)
        .toList();
    if (under.isNotEmpty) {
      throw StateError('Папка не пуста');
    }
    if (_files.containsKey(dirMarker)) {
      _files.remove(dirMarker);
      await _persist();
      return;
    }

    throw StateError('Не найдено');
  }

  @override
  Future<void> rename(String fromRelative, String toRelative) async {
    _assertSafe(fromRelative);
    _assertSafe(toRelative);

    if (_files.containsKey(toRelative) ||
        _files.containsKey('$toRelative/.folder_placeholder') ||
        _files.keys.any((k) => k.startsWith('$toRelative/'))) {
      throw StateError('Цель уже существует');
    }

    final fromPrefix = '$fromRelative/';
    final updates = <String, String>{};
    final remove = <String>[];

    for (final e in _files.entries) {
      if (e.key == fromRelative || e.key.startsWith(fromPrefix)) {
        remove.add(e.key);
        final suffix =
            e.key == fromRelative ? '' : e.key.substring(fromRelative.length);
        final newKey = suffix.isEmpty
            ? toRelative
            : '$toRelative${suffix.startsWith('/') ? '' : '/'}$suffix'
                .replaceAll('//', '/');
        if (updates.containsKey(newKey) || _files.containsKey(newKey)) {
          throw StateError('Конфликт имён');
        }
        updates[newKey] = e.value;
      }
    }

    if (remove.isEmpty) {
      throw StateError('Не найдено');
    }

    for (final k in remove) {
      _files.remove(k);
    }
    _files.addAll(updates);
    await _persist();
  }

  @override
  Future<String?> nativeFilePath(String relativePath) async => null;
}
