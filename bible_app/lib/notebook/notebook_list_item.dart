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
