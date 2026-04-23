import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/database/database_helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_app/models/bible_model.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class AppProvider with ChangeNotifier {
  /// Ключи в prefs: `sans` | `serif`.
  static const Map<String, String> verseFontLabels = {
    'sans': 'Без засечек',
    'serif': 'С засечками',
  };

  static const double chromeButtonSizeMin = 32.0;
  static const double chromeButtonSizeMax = 56.0;

  /// Высота AppBar с кнопками хрома: [chrome] + поля по вертикали.
  /// Нижняя граница ниже [kToolbarHeight] Material, чтобы шапка сжималась вместе
  /// с уменьшением «Размер кнопок», как нижняя полоса вкладок.
  static double toolbarHeightForChrome(double chrome) =>
      (chrome + 10).clamp(chromeButtonSizeMin + 8, chromeButtonSizeMax + 22);

  final BibleService _bibleService = BibleService();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  ThemeMode _themeMode = ThemeMode.light;
  double _fontSize = 16.0;
  double _lineHeight = 1.35;
  double _verseSpacing = 6.0;
  double _chromeButtonSize = 40.0;
  String _verseFontPreset = 'sans';
  bool _showSeptuagintText = false;
  bool _keepScreenOn = true;

  String _currentBook;
  int _currentChapter;

  SharedPreferences? _prefs;
  bool _isLoading = false;

  ThemeMode get themeMode => _themeMode;
  double get fontSize => _fontSize;
  double get lineHeight => _lineHeight;
  double get verseSpacing => _verseSpacing;
  String get verseFontPreset => _verseFontPreset;
  bool get showSeptuagintText => _showSeptuagintText;
  bool get keepScreenOn => _keepScreenOn;
  double get chromeButtonSize => _chromeButtonSize;
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
      await _syncWakelock();

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
      await _ensureReadableChapter();
      await _databaseHelper.database;
    } catch (e) {
      print('Ошибка инициализации приложения: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Если JSON не загрузился (часто на web), в коде остаётся минимальный тестовый набор
  /// (напр. только «Матфея»), а last_book указывает на «Бытие» — список пустой.
  /// Сбрасываем на первую доступную главу.
  Future<void> _ensureReadableChapter() async {
    if (_bibleService.getVerses(_currentBook, _currentChapter).isNotEmpty) {
      return;
    }
    const fallbacks = <(String, int)>[
      ('Бытие', 1),
      ('Матфея', 1),
    ];
    for (final e in fallbacks) {
      if (_bibleService.getVerses(e.$1, e.$2).isNotEmpty) {
        _currentBook = e.$1;
        _currentChapter = e.$2;
        await _saveLastPosition();
        return;
      }
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

    final septuagint = prefs.getBool('ui_show_septuagint_text');
    if (septuagint != null) {
      _showSeptuagintText = septuagint;
    }

    final verseSpacing = prefs.getDouble('ui_verse_spacing');
    if (verseSpacing != null && verseSpacing >= 0 && verseSpacing <= 32) {
      _verseSpacing = verseSpacing;
    }

    final stored = prefs.getString('ui_verse_font_preset');
    final migrated = _migrateVerseFontPreset(stored);
    _verseFontPreset = migrated;
    if (stored != migrated) {
      prefs.setString('ui_verse_font_preset', migrated);
    }

    final keepOn = prefs.getBool('ui_keep_screen_on');
    if (keepOn != null) {
      _keepScreenOn = keepOn;
    }

    final theme = prefs.getString('ui_theme_mode');
    if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.light;
    }

    final chrome = prefs.getDouble('ui_chrome_button_size');
    if (chrome != null &&
        chrome >= chromeButtonSizeMin &&
        chrome <= chromeButtonSizeMax) {
      _chromeButtonSize = chrome;
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
    _themeMode =
        _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
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

  void changeChromeButtonSize(double size) {
    final v = size.clamp(chromeButtonSizeMin, chromeButtonSizeMax);
    _chromeButtonSize = v;
    notifyListeners();
    _saveChromeButtonSize();
  }

  Future<void> _saveChromeButtonSize() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setDouble('ui_chrome_button_size', _chromeButtonSize);
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

  void setShowSeptuagintText(bool enabled) {
    _showSeptuagintText = enabled;
    notifyListeners();
    _saveShowSeptuagintText();
  }

  Future<void> _saveShowSeptuagintText() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool('ui_show_septuagint_text', _showSeptuagintText);
  }

  void changeVerseSpacing(double value) {
    _verseSpacing = value;
    notifyListeners();
    _saveVerseSpacing();
  }

  Future<void> _saveVerseSpacing() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setDouble('ui_verse_spacing', _verseSpacing);
  }

  void setVerseFontPreset(String presetId) {
    if (!verseFontLabels.containsKey(presetId)) return;
    _verseFontPreset = presetId;
    notifyListeners();
    _saveVerseFontPreset();
  }

  Future<void> _saveVerseFontPreset() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setString('ui_verse_font_preset', _verseFontPreset);
  }

  /// Встроенные шрифты (из assets), одинаково работают на Android/Web/Windows.
  String? get verseFontFamily {
    if (_verseFontPreset == 'serif') return 'AppSerif';
    return 'AppSans';
  }

  List<String> get verseFontFallback {
    return const [];
  }

  /// Серия гарнитур имеет разные метрики (x-height/ширина), поэтому на Windows
  /// одинаковый кегль может выглядеть "меньше" после переключения на засечки.
  /// Небольшая компенсация выравнивает визуальный размер между пресетами.
  double get verseFontSizeScale {
    if (_verseFontPreset == 'serif') return 1.06;
    return 1.0;
  }

  TextStyle bibleVerseTextStyle({
    required Color color,
    required FontWeight fontWeight,
  }) {
    return TextStyle(
      inherit: false,
      fontFamily: verseFontFamily,
      fontFamilyFallback: verseFontFallback,
      fontSize: _fontSize * verseFontSizeScale,
      height: _lineHeight,
      color: color,
      fontWeight: fontWeight,
    );
  }

  /// Старые ключи: system, openSans, tinos, merriweather.
  static String _migrateVerseFontPreset(String? raw) {
    if (raw != null && verseFontLabels.containsKey(raw)) {
      return raw;
    }
    switch (raw) {
      case 'tinos':
      case 'merriweather':
        return 'serif';
      case 'openSans':
      case 'system':
        return 'sans';
      default:
        return 'sans';
    }
  }

  Future<void> setKeepScreenOn(bool enabled) async {
    _keepScreenOn = enabled;
    notifyListeners();
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setBool('ui_keep_screen_on', enabled);
    await _syncWakelock();
  }

  Future<void> _syncWakelock() async {
    if (kIsWeb) return;
    try {
      if (_keepScreenOn) {
        await WakelockPlus.enable();
      } else {
        await WakelockPlus.disable();
      }
    } catch (e, st) {
      debugPrint('WakelockPlus: $e\n$st');
    }
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

  /// Есть ли куда листать назад (не первая глава «Бытие»).
  bool get canGoPrevBible {
    if (_currentChapter > 1) return true;
    return _prevBook() != null;
  }

  /// Есть ли куда листать вперёд (не последняя глава «Откровение»).
  bool get canGoNextBible {
    final currentObj = _currentBookObj();
    final chapterCount =
        currentObj?.chapters ?? _bibleService.getChapterCount(_currentBook);
    if (_currentChapter < chapterCount) return true;
    return _nextBook() != null;
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
    final adapted = _bibleService.adaptVersesForDisplay(
      verses,
      showSeptuagintText: _showSeptuagintText,
    );
    return adapted.map((verse) => verse.toMap()).toList();
  }

  List<Map<String, dynamic>> searchBible(
    String query, {
    bool includeOldTestament = true,
    bool includeNewTestament = true,
    bool wholeWordsOnly = false,
  }) {
    final results = _bibleService.search(
      query,
      includeOldTestament: includeOldTestament,
      includeNewTestament: includeNewTestament,
      wholeWordsOnly: wholeWordsOnly,
      includeSeptuagintText: _showSeptuagintText,
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
