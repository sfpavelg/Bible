class NotebookListItem {
  final String name;
  final bool isFolder;
  final String relativePath;

  const NotebookListItem({
    required this.name,
    required this.isFolder,
    required this.relativePath,
  });
}

/// Имя файла для подписей в интерфейсе (расширение `.txt` внутреннее).
String notebookFileDisplayName(String fileName) {
  if (fileName.length > 4 && fileName.toLowerCase().endsWith('.txt')) {
    return fileName.substring(0, fileName.length - 4);
  }
  return fileName;
}

String notebookItemDisplayName(NotebookListItem item) {
  if (item.isFolder) return item.name;
  return notebookFileDisplayName(item.name);
}
