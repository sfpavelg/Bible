import 'package:flutter/foundation.dart';

/// Глобальный запрос на переключение вкладки в [MainScreen]:
/// 0 — Библия, 1 — Блокнот, 2 — План.
final ValueNotifier<int?> appTabSwitchRequest = ValueNotifier<int?>(null);

/// Вкладка «Библия» сейчас видима (не Offstage). [BibleScreen] обрабатывает
/// [bibleVerseJumpRequest] только при true.
final ValueNotifier<bool> bibleTabIsActive = ValueNotifier<bool>(true);

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

/// Переключить на «Библию» и доставить переход к стиху (push, план, избранное).
void requestOpenBibleVerse(BibleVerseJumpRequest request) {
  bibleVerseJumpRequest.value = request;
}

/// Повторно уведомить слушателей (после смены вкладки на Библию).
void renotifyBibleVerseJumpRequest() {
  final r = bibleVerseJumpRequest.value;
  if (r == null) return;
  bibleVerseJumpRequest.value = null;
  bibleVerseJumpRequest.value = r;
}
