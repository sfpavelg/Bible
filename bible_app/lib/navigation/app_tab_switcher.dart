import 'package:flutter/foundation.dart';

/// Глобальный запрос на переключение вкладки в [MainScreen]:
/// 0 — Библия, 1 — Блокнот, 2 — План.
final ValueNotifier<int?> appTabSwitchRequest = ValueNotifier<int?>(null);

/// Запрос открыть главу (уже выставленную через [AppProvider]) и кратко подсветить стих —
/// как при выборе результата поиска (план «Вера» и др. ссылки на диапазон стихов).
class BibleVerseJumpRequest {
  const BibleVerseJumpRequest({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  final String book;
  final int chapter;
  final int verse;
}

final ValueNotifier<BibleVerseJumpRequest?> bibleVerseJumpRequest =
    ValueNotifier<BibleVerseJumpRequest?>(null);

