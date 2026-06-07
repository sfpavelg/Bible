#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
ПРАВИЛЬНЫЙ скрипт для исправления Псалтири, глава 3
Извлекает чистый текст из correct_bible.json и создает каноническую структуру
"""

import json
import shutil
import re
from typing import Dict, Any

# Пути к файлам
OLD_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\old_testament_correct.json"
CORRECT_BIBLE_PATH = r"c:\Project\Bible\correct_bible.json"

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
    """Находит книгу в correct_bible.json по короткому имени"""
    for book in correct_data.get("Books", []):
        if book.get("BookName") == book_short_name:
            return book
    return {}

def extract_clean_psalm_text():
    """Извлекает чистый текст Псалтири 3 из correct_bible.json"""
    
    correct_bible_data = load_json_file(CORRECT_BIBLE_PATH)
    if not correct_bible_data:
        return {}
    
    # Находим Псалтирь
    correct_book = find_book_in_correct_bible(correct_bible_data, "Пс.")
    if not correct_book:
        return {}
    
    # Извлекаем текст главы 3
    clean_verses = {}
    
    for chapter in correct_book.get("Chapters", []):
        if chapter.get("ChapterId") == 3:
            for verse in chapter.get("Verses", []):
                verse_id = verse.get("VerseId")
                text = verse.get("Text", "").strip()
                
                # Убираем номера стихов в скобках (например "(3:2)")
                clean_text = re.sub(r'\(\d+:\d+\)\s*', '', text)
                
                # Для стиха 1 убираем только номер, оставляя заголовок
                if verse_id == 1:
                    # Стих 1 содержит заголовок + начало текста
                    clean_text = text
                    # Убираем только номер если он есть в середине
                    clean_text = re.sub(r'\s*\(\d+:\d+\)\s*', ' ', clean_text)
                
                clean_verses[str(verse_id)] = clean_text.strip()
    
    return clean_verses

def fix_psalm_3_proper():
    """Правильно исправляет Псалтирь, главу 3"""
    
    print("🔧 ПРАВИЛЬНОЕ ИСПРАВЛЕНИЕ ПСАЛТИРИ, ГЛАВА 3")
    print("=" * 50)
    
    # Создаем резервную копию
    backup_path = f"{OLD_TESTAMENT_PATH}.backup_psalm3_proper"
    try:
        shutil.copy2(OLD_TESTAMENT_PATH, backup_path)
        print(f"📦 Резервная копия создана: {backup_path}")
    except Exception as e:
        print(f"❌ Ошибка создания резервной копии: {e}")
        return
    
    # Загружаем файл
    old_testament_data = load_json_file(OLD_TESTAMENT_PATH)
    if not old_testament_data:
        print("❌ Не удалось загрузить old_testament_correct.json")
        return
    
    # Извлекаем чистый текст
    clean_verses = extract_clean_psalm_text()
    if not clean_verses:
        print("❌ Не удалось извлечь чистый текст из correct_bible.json")
        return
    
    print(f"📖 Найдено {len(clean_verses)} чистых стихов в correct_bible.json")
    
    # Проверяем, что Псалтирь существует
    if "Псалтирь" not in old_testament_data:
        print("❌ Псалтирь не найдена")
        return
    
    if "3" not in old_testament_data["Псалтирь"]:
        print("❌ Глава 3 не найдена")
        return
    
    # Исправляем главу 3
    psalm_3_chapter = old_testament_data["Псалтирь"]["3"]
    
    # Удаляем все существующие стихи
    for verse_num in list(psalm_3_chapter.keys()):
        del psalm_3_chapter[verse_num]
    
    # Создаем правильные стихи
    for verse_num, clean_text in clean_verses.items():
        psalm_3_chapter[verse_num] = {"text": clean_text}
        print(f"✅ Создан стих {verse_num}: {clean_text[:50]}...")
    
    # Сохраняем исправленный файл
    save_json_file(OLD_TESTAMENT_PATH, old_testament_data)
    
    print(f"\n🎯 ПСАЛТИРЬ 3 ПРАВИЛЬНО ИСПРАВЛЕНА!")
    print("=" * 50)
    print("✅ Удалены все старые стихи")
    print("✅ Созданы новые стихи из чистого текста")
    print("✅ Убраны неправильные номера в скобках")
    print(f"📦 Резервная копия: {backup_path}")

if __name__ == "__main__":
    fix_psalm_3_proper()