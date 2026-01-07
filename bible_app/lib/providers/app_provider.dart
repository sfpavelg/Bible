import 'package:flutter/material.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/database/database_helper.dart';

class AppProvider with ChangeNotifier {
  final BibleService _bibleService = BibleService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  
  // Текущая тема
  ThemeMode _themeMode = ThemeMode.light;
  
  // Текущий размер шрифта
  double _fontSize = 16.0;
  
  // Текущая книга и глава
  String _currentBook = 'Бытие';
  int _currentChapter = 1;
  
  // Загрузка данных
  bool _isLoading = false;
  
  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  String get currentBook => _currentBook;
  int get currentChapter => _currentChapter;
  bool get isLoading => _isLoading;
  
  // Инициализация приложения
  Future<void> initializeApp() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      // Загрузка данных Библии
      await _bibleService.loadBibleData();
      
      // Инициализация базы данных
      await _databaseHelper.database;
      
      // Загрузка настроек из SharedPreferences
      // TODO: Добавить загрузку настроек
      
    } catch (e) {
      print('Ошибка инициализации приложения: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Смена темы
  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    // TODO: Сохранить настройки темы
  }
  
  // Изменение размера шрифта
  void changeFontSize(double size) {
    _fontSize = size;
    notifyListeners();
    // TODO: Сохранить настройки шрифта
  }
  
  // Смена книги и главы
  void changeBookAndChapter(String book, int chapter) {
    _currentBook = book;
    _currentChapter = chapter;
    notifyListeners();
    // TODO: Сохранить последнюю позицию
  }
  
  // Получение списка книг
  List<String> getBooks(String testament) {
    return _bibleService.getBooks(testament).map((book) => book.name).toList();
  }
  
  // Получение стихов текущей главы
  List<Map<String, dynamic>> getCurrentVerses() {
    final verses = _bibleService.getVerses(_currentBook, _currentChapter);
    return verses.map((verse) => verse.toMap()).toList();
  }
  
  // Поиск по Библии
  List<Map<String, dynamic>> searchBible(String query) {
    final results = _bibleService.search(query);
    return results.map((verse) => verse.toMap()).toList();
  }
  
  // Методы для работы с заметками
  Future<List<Map<String, dynamic>>> getNotes() async {
    return await _databaseHelper.getNotes();
  }
  
  Future<int> addNote(String title, String content) async {
    final note = {
      'title': title,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    return await _databaseHelper.insertNote(note);
  }
  
  // Методы для работы с журналом прочтения
  Future<List<Map<String, dynamic>>> getReadingLogs() async {
    return await _databaseHelper.getReadingLogs();
  }
  
  Future<int> addReadingLog(String book, int chapter, String notes) async {
    final log = {
      'book': book,
      'chapter': chapter,
      'date_read': DateTime.now().millisecondsSinceEpoch,
      'notes': notes,
    };
    return await _databaseHelper.insertReadingLog(log);
  }
}