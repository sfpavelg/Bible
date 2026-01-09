#!/usr/bin/env python3
"""
Скрипт для исправления ошибок в Новом Завете на основе проверки
Восстанавливает правильный порядок текста между книгами
"""

import json
import os
from collections import OrderedDict

# Пути к файлам
NEW_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\new_testament_correct.json"
CORRECT_BIBLE_PATH = r"c:\Project\Bible\correct_bible.json"
BACKUP_PATH = r"c:\Project\Bible\bible_app\assets\bible\new_testament_correct.json.backup_final"

# Соответствие названий книг
BOOK_NAME_MAPPING = {
    "Матфея": "Мтф.",
    "Марка": "Марк.", 
    "Луки": "Лук.",
    "Иоанна": "Иоан.",
    "Деяния": "Деян.",
    "Иакова": "Иакова",
    "1 Петра": "1Петр.",
    "2 Петра": "2Петр.", 
    "1 Иоанна": "1Иоан.",
    "2 Иоанна": "2Иоан.",
    "3 Иоанна": "3Иоан.",
    "Иуды": "Иуды",
    "Римлянам": "Рим.",
    "1 Коринфянам": "1Кор.",
    "2 Коринфянам": "2Кор.",
    "Галатам": "Гал.",
    "Ефесянам": "Ефесянам",
    "Филиппийцам": "Филип.",
    "Колоссянам": "Колос.",
    "1 Фессалоникийцам": "1Фес.",
    "2 Фессалоникийцам": "2Фес.",
    "1 Тимофею": "1Тим.",
    "2 Тимофею": "2Тим.",
    "Титу": "Титу",
    "Филимону": "Филимону",
    "Евреям": "Евр.",
    "Откровение": "Откр."
}

def load_json_file(file_path):
    """Загружает JSON файл"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Ошибка загрузки файла {file_path}: {e}")
        return None

def save_json_file(file_path, data):
    """Сохраняет JSON файл"""
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ Файл сохранен: {file_path}")
    except Exception as e:
        print(f"❌ Ошибка сохранения файла {file_path}: {e}")

def find_book_in_correct_bible(correct_data, book_short_name):
    """Находит книгу в correct_bible.json"""
    for book in correct_data.get("Books", []):
        if book.get("BookName") == book_short_name:
            return book
    return None

def extract_correct_text_structure(correct_book):
    """Извлекает правильную структуру текста из correct_bible.json"""
    book_structure = {}
    
    for chapter in correct_book.get("Chapters", []):
        chapter_num = chapter.get("ChapterId")
        chapter_data = {}
        
        for verse in chapter.get("Verses", []):
            verse_num = verse.get("VerseId")
            verse_text = verse.get("Text", "")
            
            chapter_data[str(verse_num)] = {
                "text": verse_text,
                "type": "narrative"  # Стандартный тип для большинства стихов
            }
        
        book_structure[str(chapter_num)] = chapter_data
    
    return book_structure

def create_backup():
    """Создает резервную копию текущего файла"""
    print("📦 Создаю резервную копию...")
    
    current_data = load_json_file(NEW_TESTAMENT_PATH)
    if current_data:
        save_json_file(BACKUP_PATH, current_data)
        print("✅ Резервная копия создана")
    else:
        print("❌ Не удалось создать резервную копию")

def fix_new_testament():
    """Основная функция исправления Нового Завета"""
    print("🔧 ИСПРАВЛЕНИЕ НОВОГО ЗАВЕТА")
    print("=" * 50)
    
    # Создаем резервную копию
    create_backup()
    
    # Загружаем файлы
    print("📖 Загружаю файлы...")
    correct_bible = load_json_file(CORRECT_BIBLE_PATH)
    current_data = load_json_file(NEW_TESTAMENT_PATH)
    
    if not correct_bible or not current_data:
        return
    
    # Создаем новый исправленный словарь
    fixed_data = OrderedDict()
    
    # Правильный порядок книг Нового Завета
    correct_order = [
        "Матфея", "Марка", "Луки", "Иоанна", "Деяния",
        "Римлянам", "1 Коринфянам", "2 Коринфянам", "Галатам", "Ефесянам",
        "Филиппийцам", "Колоссянам", "1 Фессалоникийцам", "2 Фессалоникийцам",
        "1 Тимофею", "2 Тимофею", "Титу", "Филимону", "Евреям",
        "Иакова", "1 Петра", "2 Петра", "1 Иоанна", "2 Иоанна",
        "3 Иоанна", "Иуды", "Откровение"
    ]
    
    print("🔄 Исправляю книги...")
    
    for book_name in correct_order:
        if book_name not in current_data:
            print(f"⚠️  Книга не найдена: {book_name}")
            continue
            
        book_short_name = BOOK_NAME_MAPPING.get(book_name)
        if not book_short_name:
            print(f"⚠️  Неизвестное сокращение для: {book_name}")
            continue
        
        # Находим правильную книгу
        correct_book = find_book_in_correct_bible(correct_bible, book_short_name)
        if not correct_book:
            print(f"❌ Книга не найдена в correct_bible.json: {book_name} ({book_short_name})")
            continue
        
        # Извлекаем правильную структуру текста
        correct_structure = extract_correct_text_structure(correct_book)
        
        # Сохраняем исправленную книгу
        fixed_data[book_name] = correct_structure
        print(f"✅ Исправлена: {book_name}")
    
    # Сохраняем исправленный файл
    print("💾 Сохраняю исправленный файл...")
    save_json_file(NEW_TESTAMENT_PATH, fixed_data)
    
    print("\n🎯 ИСПРАВЛЕНИЕ ЗАВЕРШЕНО!")
    print("=" * 50)
    print(f"📖 Исправлено книг: {len(fixed_data)}/{len(correct_order)}")
    print(f"💾 Резервная копия: {BACKUP_PATH}")
    print(f"📄 Исправленный файл: {NEW_TESTAMENT_PATH}")
    
    return fixed_data

if __name__ == "__main__":
    fix_new_testament()