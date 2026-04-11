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
    final rightOk = end >= haystackLower.length || !_wordCharAt(haystackLower, end);
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

  Map<String, Map<String, Map<String, dynamic>>> _oldTestament = {};
  Map<String, Map<String, Map<String, dynamic>>> _newTestament = {};

  /// Ошибки загрузки (для отладки); на web часто падает один из крупных JSON.
  String? loadErrorOld;
  String? loadErrorNew;

  Future<void> loadBibleData() async {
    loadErrorOld = null;
    loadErrorNew = null;

    await _loadOldTestament();
    await _loadNewTestament();

    if (_oldTestament.isEmpty && _newTestament.isEmpty) {
      debugPrint('BibleService: оба завета пусты, подставляем тестовые стихи');
      _loadTestData();
    }
  }

  Future<void> _loadOldTestament() async {
    try {
      final oldTestamentData =
          await rootBundle.loadString('assets/bible/old_testament_correct.json');
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
      final newTestamentData =
          await rootBundle.loadString('assets/bible/new_testament_correct.json');
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
            'text':
                'Родословие Иисуса Христа, Сына Давидова, Сына Авраамова.',
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

  List<BibleVerse> search(
    String query, {
    bool includeOldTestament = true,
    bool includeNewTestament = true,
    bool wholeWordsOnly = false,
  }) {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return [];
    final qLower = trimmed.toLowerCase();

    bool verseMatches(String text) {
      final t = text.toLowerCase();
      if (!wholeWordsOnly) {
        return t.contains(qLower);
      }
      final tokens = qLower
          .split(RegExp(r'\s+'))
          .where((e) => e.isNotEmpty)
          .toList();
      if (tokens.isEmpty) return false;
      for (final token in tokens) {
        if (!_containsWholeWord(t, token)) return false;
      }
      return true;
    }

    final List<BibleVerse> results = [];

    void scan(
      Map<String, Map<String, Map<String, dynamic>>> testament,
    ) {
      testament.forEach((book, chapters) {
        chapters.forEach((chapter, verses) {
          verses.forEach((verse, verseData) {
            final vd = verseData is Map<String, dynamic>
                ? verseData
                : <String, dynamic>{};
            final text = (vd['text'] ?? '').toString();
            if (verseMatches(text)) {
              results.add(BibleVerse(
                book: book,
                chapter: int.parse(chapter),
                verse: int.parse(verse),
                text: text,
                type: (vd['type'] ?? 'narrative').toString(),
                speaker: vd['speaker'] as String?,
              ));
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
}
