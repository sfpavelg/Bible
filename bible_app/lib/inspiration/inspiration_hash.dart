/// Детерминированный псевдослучайный индекс без хранения списка на год.

int inspirationHash32(String input) {
  var hash = 0;
  for (final codeUnit in input.codeUnits) {
    hash = (hash * 31 + codeUnit) & 0x7fffffff;
  }
  return hash;
}

int inspirationPickIndex(String seed, int length) {
  if (length <= 0) return 0;
  var h = inspirationHash32(seed);
  h = inspirationHash32('mix|$h|$seed');
  h = inspirationHash32('pick|$h');
  return h % length;
}

String inspirationDateSeed(DateTime date) {
  final y = date.year;
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
