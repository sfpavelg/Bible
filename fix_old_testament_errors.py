#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Скрипт для исправления ошибок в Ветхом Завете на основе эталонного текста
"""

import json
import os
import shutil
from typing import Dict, List, Any

# Пути к файлам
OLD_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\old_testament_correct.json"
CORRECT_BIBLE_PATH = r"c:\Project\Bible\correct_bible.json"
BACKUP_PATH = r"c:\Project\Bible\bible_app\assets\bible\old_testament_correct.json.backup_final"

# Словарь для соответствия названий книг Ветхого Завета
OLD_TESTAMENT_BOOK_MAPPING = {
    "Бытие": "Быт.",
    "Исход": "Исх.",
    "Левит": "Лев.",
    "Числа": "Чис.",
    "Второзаконие": "Втор.",
    "Иисус Навин": "Нав.",
    "Судьи": "Суд.",
    "Руфь": "Руфь",
    "1 Царств": "1Цар.",
    "2 Царств": "2Цар.",
    "3 Царств": "3Цар.",
    "4 Царств": "4Цар.",
    "1 Паралипоменon": "1Пар.",
    "2 Паралипоменon": "2Пар.",
    "Ездра": "Ездр.",
    "Неемия": "Неем.",
    "Есфирь": "Есф.",
    "Иов": "Иов",
    "Псалтирь": "Пс.",
    "Притчи": "Прит.",
    "Екклесиаст": "Еккл.",
    "Песнь песней": "Песн.",
    "Исаия": "Ис.",
    "Иеремия": "Иер.",
    "Плач Иеремии": "Плач",
    "Иезекииль": "Иез.",
    "Даниил": "Дан.",
    "Осия": "Ос.",
    "Иоиль": "Иоил.",
    "Амос": "Ам.",
    "Авдий": "Авд.",
    "Иона": "Иона",
    "Михей": "Мих.",
    "Наум": "Наум",
    "Аввакум": "Авв.",
    "Софония": "Соф.",
    "Аггей": "Агг.",
    "Захария": "Зах.",
    "Малахия": "Мал."
}

def load_json_file(file_path: str) -> Any:
    """Загружает JSON файл"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Ошибка загрузки файла {file_path}: {e}")
        return None

def save_json_file(file_path: str, data: Any):
    """Сохраняет JSON файл"""
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ Файл сохранен: {file_path}")
    except Exception as e:
        print(f"❌ Ошибка сохранения файла {file_path}: {e}")

def find_book_in_correct_bible(correct_data: Dict, book_short_name: str) -> Dict:
    """Находит книгу в correct_bible.json по сокращенному названию"""
    for book in correct_data.get("Books", []):
        if book.get("BookName") == book_short_name:
            return book
    return {}

def get_correct_verse_text(correct_book: Dict, chapter_num: str, verse_num: str) -> str:
    """Получает текст стиха из correct_bible.json"""
    try:
        chapter_num_int = int(chapter_num)
        verse_num_int = int(verse_num)
        
        for chapter in correct_book.get("Chapters", []):
            if chapter.get("ChapterId") == chapter_num_int:
                for verse in chapter.get("Verses", []):
                    if verse.get("VerseId") == verse_num_int:
                        return verse.get("Text", "").strip()
        return ""
    except ValueError:
        return ""

def fix_old_testament():
    """Основная функция исправления Ветхого Завета"""
    
    print("🔧 ИСПРАВЛЕНИЕ ВЕТХОГО ЗАВЕТА")
    print("=" * 50)
    
    # Создаем резервную копию
    print("📦 Создаю резервную копию...")
    try:
        shutil.copy2(OLD_TESTAMENT_PATH, BACKUP_PATH)
        print(f"✅ Резервная копия создана: {BACKUP_PATH}")
    except Exception as e:
        print(f"❌ Ошибка создания резервной копии: {e}")
        return
    
    print("📖 Загружаю файлы...")
    
    # Загружаем файлы
    old_testament_data = load_json_file(OLD_TESTAMENT_PATH)
    correct_bible_data = load_json_file(CORRECT_BIBLE_PATH)
    
    if not old_testament_data or not correct_bible_data:
        return
    
    print("🔄 Исправляю книги...")
    
    fixed_books = 0
    total_books = 0
    fixed_verses = 0
    
    # Исправляем каждую книгу Ветхого Завета
    for book_full_name, book_short_name in OLD_TESTAMENT_BOOK_MAPPING.items():
        if book_full_name not in old_testament_data:
            print(f"⚠️  Книга {book_full_name} отсутствует в old_testament_correct.json")
            continue
            
        total_books += 1
        
        # Находим книгу в эталонном файле
        correct_book = find_book_in_correct_bible(correct_bible_data, book_short_name)
        if not correct_book:
            print(f"⚠️  Книга {book_full_name} ({book_short_name}) не найдена в correct_bible.json")
            continue
        
        # Получаем главы из нашего файла
        our_chapters = old_testament_data[book_full_name]
        
        book_fixed_verses = 0
        
        # Исправляем каждую главу
        for chapter_num, chapter_data in our_chapters.items():
            # Исправляем каждый стих
            for verse_num, verse_data in chapter_data.items():
                correct_text = get_correct_verse_text(correct_book, chapter_num, verse_num)
                
                if correct_text:
                    our_text = verse_data.get("text", "").strip()
                    
                    # Если текст отличается, исправляем
                    if our_text != correct_text:
                        verse_data["text"] = correct_text
                        book_fixed_verses += 1
                        fixed_verses += 1
        
        if book_fixed_verses > 0:
            print(f"✅ Исправлена: {book_full_name} ({book_fixed_verses} стихов)")
            fixed_books += 1
        else:
            print(f"✓ Проверена: {book_full_name} (ошибок не найдено)")
    
    # Сохраняем исправленный файл
    print("💾 Сохраняю исправленный файл...")
    save_json_file(OLD_TESTAMENT_PATH, old_testament_data)
    
    print("\n🎯 ИСПРАВЛЕНИЕ ЗАВЕРШЕНО!")
    print("=" * 50)
    print(f"📖 Исправлено книг: {fixed_books}/{total_books}")
    print(f"📝 Исправлено стихов: {fixed_verses}")
    print(f"📦 Резервная копия: {BACKUP_PATH}")
    print(f"📄 Исправленный файл: {OLD_TESTAMENT_PATH}")

if __name__ == "__main__":
    fix_old_testament()