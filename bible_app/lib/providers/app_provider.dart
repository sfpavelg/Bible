import 'package:flutter/material.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_app/models/bible_model.dart';

class AppProvider with ChangeNotifier {
  final BibleService _bibleService = BibleService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  ThemeMode _themeMode = ThemeMode.light;
  double _fontSize = 16.0;
  double _lineHeight = 1.35;
  bool _redLettersEnabled = true;

  String _currentBook;
  int _currentChapter;

  SharedPreferences? _prefs;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  bool get redLettersEnabled => _redLettersEnabled;
  String get currentBook => _currentBook;
  int get currentChapter => _currentChapter;
  bool get isLoading => _isLoading;

  AppProvider({
    String initialBook = 'Бытие',
    int initialChapter = 1,
    SharedPreferences? prefs,
  })  : _currentBook = initialBook,
        _currentChapter = initialChapter,
        _prefs = prefs;

  Future<void> initializeApp() async {
    _isLoading = true;
    notifyListeners();

    try {
      _prefs ??= await SharedPreferences.getInstance();
      _loadUiSettings();

      final lastBook = _prefs!.getString('last_book');
      final lastChapter = _prefs!.getInt('last_chapter');
      if (lastBook != null &&
          lastBook.isNotEmpty &&
          lastChapter != null &&
          lastChapter > 0) {
        _currentBook = lastBook;
        _currentChapter = lastChapter;
      }

      await _bibleService.loadBibleData();
      await _databaseHelper.database;
    } catch (e) {
      print('Ошибка инициализации приложения: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _loadUiSettings() {
    final prefs = _prefs;
    if (prefs == null) return;

    final fontSize = prefs.getDouble('ui_font_size');
    if (fontSize != null && fontSize >= 10 && fontSize <= 40) {
      _fontSize = fontSize;
    }

    final lineHeight = prefs.getDouble('ui_line_height');
    if (lineHeight != null && lineHeight >= 1.0 && lineHeight <= 2.2) {
      _lineHeight = lineHeight;
    }

    final redLetters = prefs.getBool('ui_red_letters_enabled');
    if (redLetters != null) {
      _redLettersEnabled = redLetters;
    }

    final theme = prefs.getString('ui_theme_mode');
    if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final value = mode == ThemeMode.dark ? 'dark' : 'light';
    await prefs.setString('ui_theme_mode', value);
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    _saveThemeModeLegacy();
  }

  Future<void> _saveThemeModeLegacy() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final value = _themeMode == ThemeMode.dark ? 'dark' : 'light';
    await prefs.setString('ui_theme_mode', value);
  }

  void changeFontSize(double size) {
    _fontSize = size;
    notifyListeners();
    _saveFontSize();
  }

  Future<void> _saveFontSize() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setDouble('ui_font_size', _fontSize);
  }

  void changeLineHeight(double value) {
    _lineHeight = value;
    notifyListeners();
    _saveLineHeight();
  }

  Future<void> _saveLineHeight() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setDouble('ui_line_height', _lineHeight);
  }

  void setRedLettersEnabled(bool enabled) {
    _redLettersEnabled = enabled;
    notifyListeners();
    _saveRedLettersEnabled();
  }

  Future<void> _saveRedLettersEnabled() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool('ui_red_letters_enabled', _redLettersEnabled);
  }

  Future<void> changeBookAndChapter(String book, int chapter) async {
    _currentBook = book;
    _currentChapter = chapter;
    notifyListeners();
    await _saveLastPosition();
  }

  BibleBook? _currentBookObj() {
    try {
      return BibleBook.books.firstWhere((b) => b.name == _currentBook);
    } catch (_) {
      return null;
    }
  }

  BibleBook? _nextBook() {
    final idx = BibleBook.books.indexWhere((b) => b.name == _currentBook);
    if (idx == -1) return null;
    if (idx + 1 >= BibleBook.books.length) return null;
    return BibleBook.books[idx + 1];
  }

  BibleBook? _prevBook() {
    final idx = BibleBook.books.indexWhere((b) => b.name == _currentBook);
    if (idx <= 0) return null;
    return BibleBook.books[idx - 1];
  }

  Future<void> goNext() async {
    final currentObj = _currentBookObj();
    final chapterCount =
        currentObj?.chapters ?? _bibleService.getChapterCount(_currentBook);

    if (_currentChapter < chapterCount) {
      await changeBookAndChapter(_currentBook, _currentChapter + 1);
      return;
    }

    final next = _nextBook();
    if (next == null) return;
    await changeBookAndChapter(next.name, 1);
  }

  Future<void> goPrev() async {
    if (_currentChapter > 1) {
      await changeBookAndChapter(_currentBook, _currentChapter - 1);
      return;
    }

    final prev = _prevBook();
    if (prev == null) return;
    await changeBookAndChapter(prev.name, prev.chapters);
  }

  Future<void> _saveLastPosition() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('last_book', _currentBook);
    await prefs.setInt('last_chapter', _currentChapter);
  }

  Future<void> persistLastPosition() async {
    await _saveLastPosition();
  }

  List<String> getBooks(String testament) {
    return _bibleService.getBooks(testament).map((book) => book.name).toList();
  }

  List<Map<String, dynamic>> getCurrentVerses() {
    final verses = _bibleService.getVerses(_currentBook, _currentChapter);
    return verses.map((verse) => verse.toMap()).toList();
  }

  List<Map<String, dynamic>> searchBible(
    String query, {
    bool includeOldTestament = true,
    bool includeNewTestament = true,
  }) {
    final results = _bibleService.search(
      query,
      includeOldTestament: includeOldTestament,
      includeNewTestament: includeNewTestament,
    );
    return results.map((verse) => verse.toMap()).toList();
  }

  Future<List<Map<String, dynamic>>> getNotes() async {
    return _databaseHelper.getNotes();
  }

  Future<int> addNote(String title, String content) async {
    final note = {
      'title': title,
      'content': content,
      'created_at': DateTime.now().millisecondsSinceEpoch,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    return _databaseHelper.insertNote(note);
  }

  Future<List<Map<String, dynamic>>> getReadingLogs() async {
    return _databaseHelper.getReadingLogs();
  }

  Future<int> addReadingLog(String book, int chapter, String notes) async {
    final log = {
      'book': book,
      'chapter': chapter,
      'date_read': DateTime.now().millisecondsSinceEpoch,
      'notes': notes,
    };
    return _databaseHelper.insertReadingLog(log);
  }
}
