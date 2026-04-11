import 'package:bible_app/notebook/notebook_list_item.dart';

abstract class NotebookRepository {
  bool get isFileSystemBacked;

  Future<void> init();

  Future<List<NotebookListItem>> listDirectory(String relativeDir);

  Future<String> readFile(String relativePath);

  Future<void> writeFile(String relativePath, String content);

  Future<void> createFile(String relativePath);

  Future<void> createFolder(String relativePath);

  Future<void> delete(String relativePath);

  /// Удалить папку со всем содержимым (файлы и вложенные каталоги).
  Future<void> deleteRecursive(String relativePath);

  Future<void> rename(String fromRelative, String toRelative);

  Future<String?> nativeFilePath(String relativePath);
}
