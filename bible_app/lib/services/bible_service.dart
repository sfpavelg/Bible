import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:bible_app/models/bible_model.dart';

class BibleService {
  static final BibleService _instance = BibleService._internal();
  
  factory BibleService() => _instance;
  
  BibleService._internal();
  
  Map<String, Map<String, Map<String, dynamic>>> _oldTestament = {};
  Map<String, Map<String, Map<String, dynamic>>> _newTestament = {};
  
  Future<void> loadBibleData() async {
    try {
      // Загрузка Ветхого Завета
      String oldTestamentData = await rootBundle.loadString('assets/bible/old_testament_correct.json');
      final oldTestamentJson = json.decode(oldTestamentData) as Map<String, dynamic>;
      _oldTestament = _convertJsonToBibleData(oldTestamentJson);
      
      // Загрузка Нового Заветa
      String newTestamentData = await rootBundle.loadString('assets/bible/new_testament_correct.json');
      final newTestamentJson = json.decode(newTestamentData) as Map<String, dynamic>;
      _newTestament = _convertJsonToBibleData(newTestamentJson);
      
      print('Данные Библии успешно загружены');
      print('Ветхий Завет: ${_oldTestament.length} книг');
      print('Новый Завет: ${_newTestament.length} книг');
      
    } catch (e) {
      print('Ошибка загрузки данных Библии: $e');
      // Временные тестовые данные для отладки
      _loadTestData();
    }
  }
  
  void _loadTestData() {
    // Простые тестовые данные для отладки
    _oldTestament = {};
    _newTestament = {
      'Матфея': {
        '1': {
          '1': {'text': 'Родословие Иисуса Христа, Сына Давидова, Сына Авраамова.', 'type': 'narrative'},
          '2': {'text': 'Авраам родил Исаака; Исаак родил Иакова; Иаков родил Иуду и братьев его;', 'type': 'narrative'},
          '3': {'text': 'Иуда родил Фареса и Зару от Фамари; Фарес родил Есрома; Есром родил Арама;', 'type': 'narrative'}
        }
      }
    };
  }
  
  List<BibleBook> getBooks(String testament) {
    return BibleBook.books.where((book) => book.testament == testament).toList();
  }
  
  List<BibleVerse> getVerses(String book, int chapter) {
    // Проверяем сначала Ветхий Завет
    if (_oldTestament.containsKey(book)) {
      final bookData = _oldTestament[book];
      if (bookData == null) return [];
      
      final chapterData = bookData[chapter.toString()];
      if (chapterData == null) return [];
      
      return chapterData.entries.map((entry) {
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
    }
    
    // Проверяем Новый Завет
    if (_newTestament.containsKey(book)) {
      final bookData = _newTestament[book];
      if (bookData == null) return [];
      
      final chapterData = bookData[chapter.toString()];
      if (chapterData == null) return [];
      
      return chapterData.entries.map((entry) {
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
    }
    
    // Книга не найдена
    return [];
  }

  // Преобразование JSON данных в структурированный формат
  Map<String, Map<String, Map<String, dynamic>>> _convertJsonToBibleData(Map<String, dynamic> jsonData) {
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
    return verses.firstWhere((v) => v.verse == verse, orElse: () => verses.isNotEmpty ? verses.first : BibleVerse(book: book, chapter: chapter, verse: verse, text: 'Стих не найден'));
  }
  
  List<BibleVerse> search(
    String query, {
    bool includeOldTestament = true,
    bool includeNewTestament = true,
  }) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return [];

    List<BibleVerse> results = [];

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
            if (text.toLowerCase().contains(q)) {
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
  
  // Получение количества глав в книге
  int getChapterCount(String book) {
    final bookObj = BibleBook.books.firstWhere((b) => b.name == book, orElse: () => BibleBook.books.first);
    return bookObj.chapters;
  }

  // Получение сокращенного названия книги
  String getBookAbbreviation(String book) {
    final bookObj = BibleBook.books.firstWhere((b) => b.name == book, orElse: () => BibleBook.books.first);
    return bookObj.abbreviation;
  }
}