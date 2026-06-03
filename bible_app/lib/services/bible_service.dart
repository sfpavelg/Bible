import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:bible_app/models/bible_model.dart';

bool _wordCharAt(String s, int i) {
  if (i < 0 || i >= s.length) return false;
  final c = s.codeUnitAt(i);
  if (c >= 0x30 && c <= 0x39) return true;
  if (c >= 0x41 && c <= 0x5A) return true;
  if (c >= 0x61 && c <= 0x7A) return true;
  if (c >= 0x0410 && c <= 0x044F) return true;
  if (c == 0x0401 || c == 0x0451) return true;
  return false;
}

bool _containsWholeWord(String haystackLower, String wordLower) {
  if (wordLower.isEmpty) return false;
  var from = 0;
  while (from < haystackLower.length) {
    final i = haystackLower.indexOf(wordLower, from);
    if (i == -1) return false;
    final end = i + wordLower.length;
    final leftOk = i == 0 || !_wordCharAt(haystackLower, i - 1);
    final rightOk =
        end >= haystackLower.length || !_wordCharAt(haystackLower, end);
    if (leftOk && rightOk) return true;
    from = i + 1;
  }
  return false;
}

/// Совпадения сегментов запроса в тексте (подсветка в поиске).
List<({int start, int end})> bibleMergedQueryMatches(
  String text,
  List<String> segmentsLower, {
  required bool wholeWordsOnly,
}) {
  if (text.isEmpty || segmentsLower.isEmpty) return [];
  final lowerText = text.toLowerCase();
  final matches = <({int start, int end})>[];
  for (final segment in segmentsLower) {
    if (segment.isEmpty) continue;
    var from = 0;
    while (from < lowerText.length) {
      final i = lowerText.indexOf(segment, from);
      if (i == -1) break;
      final end = i + segment.length;
      final ok = !wholeWordsOnly ||
          ((i == 0 || !_wordCharAt(lowerText, i - 1)) &&
              (end >= lowerText.length || !_wordCharAt(lowerText, end)));
      if (ok) matches.add((start: i, end: end));
      from = i + 1;
    }
  }
  if (matches.isEmpty) return [];
  matches.sort((a, b) => a.start.compareTo(b.start));
  final merged = <({int start, int end})>[];
  for (final m in matches) {
    if (merged.isEmpty || m.start > merged.last.end) {
      merged.add(m);
    } else if (m.end > merged.last.end) {
      merged[merged.length - 1] = (start: merged.last.start, end: m.end);
    }
  }
  return merged;
}

class BibleService {
  static final BibleService _instance = BibleService._internal();

  factory BibleService() => _instance;

  BibleService._internal();

  static final RegExp _septuagintBracketChunk = RegExp(r'\[[^\[\]]*\]');
  static final RegExp _readingModeAlternativeChunk = RegExp(
    r'\[([^|\[\]]+)\|([^\[\]]+)\]',
  );
  static final RegExp _inlineNoteTag =
      RegExp(r'<note>.*?</note>', dotAll: true);
  static final Set<String> _alwaysUnwrapSquareBracketVerses = <String>{
    'Судьи|20|27',
    'Судьи|20|28',
    'Псалтирь|67|23',
    'Псалтирь|67|24',
    'Притчи|29|6',
  };

  static String _verseKey(String book, int chapter, int verse) =>
      '$book|$chapter|$verse';

  static bool _isAlwaysUnwrapSquareBrackets(
    String book,
    int chapter,
    int verse,
  ) {
    return _alwaysUnwrapSquareBracketVerses.contains(
      _verseKey(book, chapter, verse),
    );
  }

  static bool _isFullSeptuagintVerse(
    String book,
    int chapter,
    int verse,
  ) {
    if (book == 'Иисус Навин' && chapter == 24 && verse >= 34 && verse <= 36) {
      return true;
    }
    if (book == 'Даниил' && chapter == 3 && verse >= 24 && verse <= 90) {
      return true;
    }
    return false;
  }

  /// Удаляет вставки Септуагинты в квадратных скобках вместе со скобками.
  static String stripSeptuagintBracketedText(String text) {
    if (text.isEmpty) return text;
    var out = text.replaceAll(_septuagintBracketChunk, '');
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
    out = out.replaceAllMapped(
      RegExp(r'\s+([,.;:!?])'),
      (m) => m.group(1) ?? '',
    );
    return out.trim();
  }

  /// Декодирует простые HTML-сущности тегов из источника.
  static String decodeInlineTagEntities(String text) {
    if (text.isEmpty) return text;
    if (!text.contains('&')) return text;
    return text
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&amp;', '&');
  }

  /// Убирает служебную разметку стихов:
  /// - `<note>...</note>` удаляется целиком (вместе с текстом пометки),
  /// - остальные теги снимаются, сохраняя внутренний текст.
  static String stripInlineMarkupTags(String text) {
    if (text.isEmpty) return text;
    if (!text.contains('<') && !text.contains('&lt;')) return text;
    var out = decodeInlineTagEntities(text);
    out = out.replaceAll(_inlineNoteTag, '');
    out = out.replaceAll(RegExp(r'</?[^>]+>'), '');
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
    out = out.replaceAllMapped(
      RegExp(r'\s+([,.;:!?])'),
      (m) => m.group(1) ?? '',
    );
    return out.trim();
  }

  static String _removeSquareBracketsOnly(String text) {
    if (text.isEmpty) return text;
    if (!text.contains('[') && !text.contains(']')) return text;
    var out = text.replaceAll('[', '').replaceAll(']', '');
    out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
    out = out.replaceAllMapped(
      RegExp(r'\s+([,.;:!?])'),
      (m) => m.group(1) ?? '',
    );
    return out.trim();
  }

  /// Выбирает вариант из аннотации `[септуагинта|без_септуагинты]`.
  static String _resolveReadingModeAlternatives(
    String text, {
    required bool showSeptuagintText,
  }) {
    if (text.isEmpty || !text.contains('[') || !text.contains('|')) return text;
    return text.replaceAllMapped(_readingModeAlternativeChunk, (m) {
      final withSeptuagint = (m.group(1) ?? '').trim();
      final withoutSeptuagint = (m.group(2) ?? '').trim();
      return showSeptuagintText ? withSeptuagint : withoutSeptuagint;
    });
  }

  /// Нормализация текста стиха по правилам Септуагинты и служебной разметки.
  static String normalizeVerseTextForDisplay(
    String book,
    int chapter,
    int verse,
    String rawText, {
    required bool showSeptuagintText,
    bool stripMarkup = true,
  }) {
    var text = rawText;
    final hasTagEntities = text.contains('&lt;') || text.contains('&gt;');
    final hasRawTags = text.contains('<') || text.contains('>');

    if (hasTagEntities) {
      text = decodeInlineTagEntities(text);
    }
    text = _resolveReadingModeAlternatives(
      text,
      showSeptuagintText: showSeptuagintText,
    );
    final hasSquare = text.contains('[') || text.contains(']');
    if (_isAlwaysUnwrapSquareBrackets(book, chapter, verse)) {
      text = _removeSquareBracketsOnly(text);
    } else if (!showSeptuagintText && hasSquare) {
      text = showSeptuagintText ? text : stripSeptuagintBracketedText(text);
    }
    if (stripMarkup && (hasRawTags || hasTagEntities)) {
      text = stripInlineMarkupTags(text);
    }
    return text;
  }

  /// Скрыть ли стих целиком, если Септуагинта выключена.
  static bool shouldHideVerseForSeptuagintToggle(
    String book,
    int chapter,
    int verse, {
    required bool showSeptuagintText,
  }) {
    if (showSeptuagintText) return false;
    return _isFullSeptuagintVerse(book, chapter, verse);
  }

  /// Применяет правила отображения по Септуагинте для выбранной главы.
  List<BibleVerse> adaptVersesForDisplay(
    List<BibleVerse> source, {
    required bool showSeptuagintText,
  }) {
    if (source.isEmpty) return source;
    final out = <BibleVerse>[];
    for (final v in source) {
      if (shouldHideVerseForSeptuagintToggle(
        v.book,
        v.chapter,
        v.verse,
        showSeptuagintText: showSeptuagintText,
      )) {
        continue;
      }
      var newVerseNum = v.verse;
      if (!showSeptuagintText &&
          v.book == 'Даниил' &&
          v.chapter == 3 &&
          v.verse >= 91) {
        newVerseNum = v.verse - 67;
      }
      final normalizedText = normalizeVerseTextForDisplay(
        v.book,
        v.chapter,
        v.verse,
        v.text,
        showSeptuagintText: showSeptuagintText,
        stripMarkup: false,
      );
      out.add(
        BibleVerse(
          book: v.book,
          chapter: v.chapter,
          verse: newVerseNum,
          text: normalizedText,
          type: v.type,
          speaker: v.speaker,
        ),
      );
    }
    return out;
  }

  Map<String, Map<String, Map<String, dynamic>>> _oldTestament = {};
  Map<String, Map<String, Map<String, dynamic>>> _newTestament = {};

  /// Ошибки загрузки (для отладки); на web часто падает один из крупных JSON.
  String? loadErrorOld;
  String? loadErrorNew;

  Future<void> loadBibleData() async {
    loadErrorOld = null;
    loadErrorNew = null;
    _globalVerseIndex = null;

    await _loadOldTestament();
    await _loadNewTestament();

    if (_oldTestament.isEmpty && _newTestament.isEmpty) {
      debugPrint('BibleService: оба завета пусты, подставляем тестовые стихи');
      _loadTestData();
    }
  }

  Future<void> _loadOldTestament() async {
    try {
      final oldTestamentData = await rootBundle
          .loadString('assets/bible/old_testament_correct.json');
      final oldTestamentJson =
          json.decode(oldTestamentData) as Map<String, dynamic>;
      _oldTestament = _convertJsonToBibleData(oldTestamentJson);
      debugPrint('BibleService: ВЗ загружен, книг: ${_oldTestament.length}');
    } catch (e, st) {
      loadErrorOld = e.toString();
      _oldTestament = {};
      debugPrint('BibleService: ошибка ВЗ: $e\n$st');
    }
  }

  Future<void> _loadNewTestament() async {
    try {
      final newTestamentData = await rootBundle
          .loadString('assets/bible/new_testament_correct.json');
      final newTestamentJson =
          json.decode(newTestamentData) as Map<String, dynamic>;
      _newTestament = _convertJsonToBibleData(newTestamentJson);
      debugPrint('BibleService: НЗ загружен, книг: ${_newTestament.length}');
    } catch (e, st) {
      loadErrorNew = e.toString();
      _newTestament = {};
      debugPrint('BibleService: ошибка НЗ: $e\n$st');
    }
  }

  /// Минимум текста, если бандл не прочитался (web, отсутствие asset и т.д.)
  void _loadTestData() {
    _oldTestament = {
      'Бытие': {
        '1': {
          '1': {
            'text': 'В начале сотворил Бог небо и землю.',
            'type': 'narrative'
          },
          '2': {
            'text':
                'Земля же была безвидна и пуста, и тьма над бездною, и Дух Божий носился над водою.',
            'type': 'narrative'
          },
        },
      },
    };
    _newTestament = {
      'Матфея': {
        '1': {
          '1': {
            'text': 'Родословие Иисуса Христа, Сына Давидова, Сына Авраамова.',
            'type': 'narrative'
          },
          '2': {
            'text':
                'Авраам родил Исаака; Исаак родил Иакова; Иаков родил Иуду и братьев его;',
            'type': 'narrative'
          },
          '3': {
            'text':
                'Иуда родил Фареса и Зару от Фамари; Фарес родил Есрома; Есром родил Арама;',
            'type': 'narrative'
          },
        },
      },
    };
  }

  List<BibleBook> getBooks(String testament) {
    return BibleBook.books
        .where((book) => book.testament == testament)
        .toList();
  }

  List<BibleVerse> getVerses(String book, int chapter) {
    if (_oldTestament.containsKey(book)) {
      final bookData = _oldTestament[book];
      if (bookData == null) return [];

      final chapterData = bookData[chapter.toString()];
      if (chapterData == null) return [];

      final list = chapterData.entries.map((entry) {
        final verseData = entry.value as Map<String, dynamic>;
        return BibleVerse(
          book: book,
          chapter: chapter,
          verse: int.parse(entry.key),
          text: verseData['text'] ?? '',
          type: verseData['type'] ?? 'narrative',
          speaker: verseData['speaker'],
        );
      }).toList();
      list.sort((a, b) => a.verse.compareTo(b.verse));
      return list;
    }

    if (_newTestament.containsKey(book)) {
      final bookData = _newTestament[book];
      if (bookData == null) return [];

      final chapterData = bookData[chapter.toString()];
      if (chapterData == null) return [];

      final list = chapterData.entries.map((entry) {
        final verseData = entry.value as Map<String, dynamic>;
        return BibleVerse(
          book: book,
          chapter: chapter,
          verse: int.parse(entry.key),
          text: verseData['text'] ?? '',
          type: verseData['type'] ?? 'narrative',
          speaker: verseData['speaker'],
        );
      }).toList();
      list.sort((a, b) => a.verse.compareTo(b.verse));
      return list;
    }

    return [];
  }

  Map<String, Map<String, Map<String, dynamic>>> _convertJsonToBibleData(
    Map<String, dynamic> jsonData,
  ) {
    final result = <String, Map<String, Map<String, dynamic>>>{};

    jsonData.forEach((book, chapters) {
      final chaptersMap = <String, Map<String, dynamic>>{};

      if (chapters is Map<String, dynamic>) {
        chapters.forEach((chapter, verses) {
          final versesMap = <String, dynamic>{};

          if (verses is Map<String, dynamic>) {
            verses.forEach((verse, verseData) {
              versesMap[verse] = verseData;
            });
          }

          chaptersMap[chapter] = versesMap;
        });
      }

      result[book] = chaptersMap;
    });

    return result;
  }

  BibleVerse? getVerse(String book, int chapter, int verse) {
    final verses = getVerses(book, chapter);
    return verses.firstWhere(
      (v) => v.verse == verse,
      orElse: () => verses.isNotEmpty
          ? verses.first
          : BibleVerse(
              book: book,
              chapter: chapter,
              verse: verse,
              text: 'Стих не найден',
            ),
    );
  }

  /// Верхняя граница выдачи: полный обход Библии при «л» даёт десятки тысяч строк.
  static const int searchResultsCap = 512;

  List<BibleVerse> search(
    String query, {
    bool includeOldTestament = true,
    bool includeNewTestament = true,
    bool wholeWordsOnly = false,
    bool includeSeptuagintText = true,
    int maxResults = searchResultsCap,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final qLower = trimmed.toLowerCase();

    bool verseMatches(String text) {
      final t = text.toLowerCase();
      if (!wholeWordsOnly) {
        return t.contains(qLower);
      }
      final tokens =
          qLower.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
      if (tokens.isEmpty) return false;
      for (final token in tokens) {
        if (!_containsWholeWord(t, token)) return false;
      }
      return true;
    }

    final List<BibleVerse> results = [];
    var scanComplete = false;

    void scan(
      Map<String, Map<String, Map<String, dynamic>>> testament,
    ) {
      if (scanComplete) return;
      testament.forEach((book, chapters) {
        if (scanComplete) return;
        chapters.forEach((chapter, verses) {
          if (scanComplete) return;
          verses.forEach((verse, verseData) {
            if (scanComplete) return;
            final vd = verseData is Map<String, dynamic>
                ? verseData
                : <String, dynamic>{};
            final chapterNum = int.parse(chapter);
            final verseNum = int.parse(verse);
            if (shouldHideVerseForSeptuagintToggle(
              book,
              chapterNum,
              verseNum,
              showSeptuagintText: includeSeptuagintText,
            )) {
              return;
            }
            final sourceText = (vd['text'] ?? '').toString();
            final text = normalizeVerseTextForDisplay(
              book,
              chapterNum,
              verseNum,
              sourceText,
              showSeptuagintText: includeSeptuagintText,
              stripMarkup: true,
            );
            if (verseMatches(text)) {
              var outVerseNum = verseNum;
              if (!includeSeptuagintText &&
                  book == 'Даниил' &&
                  chapterNum == 3 &&
                  verseNum >= 91) {
                outVerseNum = verseNum - 67;
              }
              results.add(BibleVerse(
                book: book,
                chapter: chapterNum,
                verse: outVerseNum,
                text: text,
                type: (vd['type'] ?? 'narrative').toString(),
                speaker: vd['speaker'] as String?,
              ));
              if (results.length >= maxResults) {
                scanComplete = true;
              }
            }
          });
        });
      });
    }

    if (includeOldTestament) scan(_oldTestament);
    if (includeNewTestament) scan(_newTestament);

    return results;
  }

  /// Число глав по фактически загруженным данным; иначе из [BibleBook.books].
  int getChapterCount(String book) {
    final fromData = _maxChapterInLoadedBook(book);
    if (fromData != null && fromData > 0) {
      return fromData;
    }
    final bookObj = BibleBook.books.firstWhere(
      (b) => b.name == book,
      orElse: () => BibleBook.books.first,
    );
    return bookObj.chapters;
  }

  int? _maxChapterInLoadedBook(String book) {
    final Map<String, Map<String, dynamic>>? data =
        _oldTestament[book] ?? _newTestament[book];
    if (data == null || data.isEmpty) return null;
    var maxC = 0;
    for (final k in data.keys) {
      final n = int.tryParse(k);
      if (n != null && n > maxC) maxC = n;
    }
    return maxC;
  }

  String getBookAbbreviation(String book) {
    final bookObj = BibleBook.books.firstWhere(
      (b) => b.name == book,
      orElse: () => BibleBook.books.first,
    );
    return bookObj.abbreviation;
  }

  List<BibleVersePointer>? _globalVerseIndex;

  void _ensureGlobalVerseIndex() {
    if (_globalVerseIndex != null) return;
    final list = <BibleVersePointer>[];
    for (final book in BibleBook.books) {
      for (var ch = 1; ch <= book.chapters; ch++) {
        for (final v in getVerses(book.name, ch)) {
          list.add(
            BibleVersePointer(
              book: book.name,
              chapter: ch,
              verse: v.verse,
            ),
          );
        }
      }
    }
    _globalVerseIndex = list;
  }

  int get totalVerseCount {
    _ensureGlobalVerseIndex();
    return _globalVerseIndex!.length;
  }

  BibleVersePointer? verseAtGlobalIndex(int index) {
    _ensureGlobalVerseIndex();
    final list = _globalVerseIndex!;
    if (index < 0 || index >= list.length) return null;
    return list[index];
  }
}
