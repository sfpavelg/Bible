// Последовательный план чтения: все главы Библии по порядку (ВЗ → НЗ),
// равномерно на 365 дней. Не зависит от параллельного и хронологического планов.

import 'package:bible_app/models/bible_model.dart';

/// Число дней плана (как у других планов в журнале).
const int kSequentialReadingPlanDayCount = 365;

/// Одна глава в последовательном плане (канонический порядок [BibleBook.books]).
class SequentialPlanChapterRef {
  const SequentialPlanChapterRef({
    required this.book,
    required this.chapter,
  });

  final String book;
  final int chapter;
}

/// Все главы подряд: Бытие 1 … Откровение 22.
List<SequentialPlanChapterRef> sequentialPlanAllChaptersInOrder() {
  final out = <SequentialPlanChapterRef>[];
  for (final b in BibleBook.books) {
    for (var ch = 1; ch <= b.chapters; ch++) {
      out.add(SequentialPlanChapterRef(book: b.name, chapter: ch));
    }
  }
  return out;
}

/// Равномерное распределение глав по 365 дням (первые [extra] дней на одну главу больше).
List<List<SequentialPlanChapterRef>> buildSequentialReadingPlanChaptersByDay() {
  final all = sequentialPlanAllChaptersInOrder();
  final totalChapters = all.length;
  const days = kSequentialReadingPlanDayCount;
  if (totalChapters == 0) {
    return List<List<SequentialPlanChapterRef>>.generate(
      days,
      (_) => const [],
      growable: false,
    );
  }
  final base = totalChapters ~/ days;
  final extra = totalChapters % days;
  final out = <List<SequentialPlanChapterRef>>[];
  var cursor = 0;
  for (var d = 0; d < days; d++) {
    final count = base + (d < extra ? 1 : 0);
    out.add(all.sublist(cursor, cursor + count));
    cursor += count;
  }
  return out;
}
