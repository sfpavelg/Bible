/// Общая структура строки и дня для тематических планов («Вера», «Надежда», …).

class ThematicReadingRow {
  const ThematicReadingRow({
    required this.refDisplay,
    required this.book,
    required this.chapter,
    required this.startVerse,
    required this.idea,
  });

  final String refDisplay;
  final String book;
  final int chapter;
  final int startVerse;
  final String idea;

  String get itemKey => '$book|$chapter|$refDisplay';
}

class ThematicReadingDay {
  const ThematicReadingDay({
    required this.theme,
    required this.rows,
  });

  final String theme;
  final List<ThematicReadingRow> rows;
}
