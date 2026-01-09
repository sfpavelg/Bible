import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  
  factory DatabaseHelper() => _instance;
  
  DatabaseHelper._internal() {
    // Инициализация для web-сборки
    if (kIsWeb) {
      // Для web используем databaseFactoryFfiWeb
      databaseFactory = databaseFactoryFfiWeb;
    }
    // Для нативных платформ используем стандартную инициализацию
  }
  
  static Database? _database;
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
  
  Future<Database> _initDatabase() async {
    String path;
    
    if (kIsWeb) {
      // Для web используем in-memory базу данных
      path = ':memory:';
    } else {
      // Для нативных платформ используем файловую базу
      path = join(await getDatabasesPath(), 'bible_app.db');
    }
    
    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDatabase,
    );
  }
  
  Future<void> _createDatabase(Database db, int version) async {
    // Таблица для заметок блокнота
    await db.execute('''
      CREATE TABLE notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_favorite INTEGER DEFAULT 0
      )
    ''');
    
    // Таблица для журнала прочтения
    await db.execute('''
      CREATE TABLE reading_logs(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse_from INTEGER,
        verse_to INTEGER,
        date_read INTEGER NOT NULL,
        notes TEXT,
        questions TEXT,
        insights TEXT
      )
    ''');
    
    // Таблица для закладок
    await db.execute('''
      CREATE TABLE bookmarks(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        book TEXT NOT NULL,
        chapter INTEGER NOT NULL,
        verse INTEGER,
        created_at INTEGER NOT NULL,
        note TEXT
      )
    ''');
    
    // Таблица для планов чтения
    await db.execute('''
      CREATE TABLE reading_plans(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        start_date INTEGER NOT NULL,
        end_date INTEGER,
        books TEXT NOT NULL,
        is_completed INTEGER DEFAULT 0
      )
    ''');
  }
  
  // Методы для работы с заметками
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db.insert('notes', note);
  }
  
  Future<List<Map<String, dynamic>>> getNotes() async {
    final db = await database;
    return await db.query('notes', orderBy: 'updated_at DESC');
  }
  
  Future<int> updateNote(int id, Map<String, dynamic> note) async {
    final db = await database;
    return await db.update('notes', note, where: 'id = ?', whereArgs: [id]);
  }
  
  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }
  
  // Методы для работы с журналом прочтения
  Future<int> insertReadingLog(Map<String, dynamic> log) async {
    final db = await database;
    return await db.insert('reading_logs', log);
  }
  
  Future<List<Map<String, dynamic>>> getReadingLogs() async {
    final db = await database;
    return await db.query('reading_logs', orderBy: 'date_read DESC');
  }
  
  // Методы для работы с закладками
  Future<int> insertBookmark(Map<String, dynamic> bookmark) async {
    final db = await database;
    return await db.insert('bookmarks', bookmark);
  }
  
  Future<List<Map<String, dynamic>>> getBookmarks() async {
    final db = await database;
    return await db.query('bookmarks', orderBy: 'created_at DESC');
  }
  
  Future<int> deleteBookmark(int id) async {
    final db = await database;
    return await db.delete('bookmarks', where: 'id = ?', whereArgs: [id]);
  }
}