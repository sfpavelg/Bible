#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Скрипт для очистки текстов Библии от вставок типа (3:3) в стихах
"""

import json
import os
import re
import shutil
from typing import Dict, Any

# Пути к файлам
OLD_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\old_testament_correct.json"
NEW_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\new_testament_correct.json"
CORRECT_BIBLE_PATH = r"c:\Project\Bible\correct_bible.json"

# Регулярное выражение для поиска вставок типа (3:3)
VERSE_INSERT_PATTERN = re.compile(r'\(\d+:\d+\)\s*')

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

def clean_verse_text(text: str) -> str:
    """Очищает текст стиха от вставок типа (3:3)"""
    if not text:
        return text
    
    # Удаляем вставки типа (3:3) из начала текста
    cleaned_text = VERSE_INSERT_PATTERN.sub('', text)
    
    # Также проверяем, если вставка находится в середине текста
    # (например, в 3 Иоанна 1:15)
    cleaned_text = re.sub(r'\s*\(\d+:\d+\)\s*', ' ', cleaned_text)
    
    return cleaned_text.strip()

def clean_bible_file(file_path: str, file_type: str):
    """Очищает файл Библии от вставок"""
    
    backup_path = f"{file_path}.backup_formatting"
    
    print(f"🔧 Очищаю {file_type}...")
    
    # Создаем резервную копию
    try:
        shutil.copy2(file_path, backup_path)
        print(f"📦 Резервная копия создана: {backup_path}")
    except Exception as e:
        print(f"❌ Ошибка создания резервной копии: {e}")
        return
    
    # Загружаем данные
    bible_data = load_json_file(file_path)
    if not bible_data:
        return
    
    cleaned_verses = 0
    
    # Очищаем Ветхий Завет
    if file_type == "Ветхий Завет":
        for book_name, book_data in bible_data.items():
            if isinstance(book_data, dict):
                for chapter_num, chapter_data in book_data.items():
                    if isinstance(chapter_data, dict):
                        for verse_num, verse_data in chapter_data.items():
                            if isinstance(verse_data, dict) and "text" in verse_data:
                                old_text = verse_data["text"]
                                new_text = clean_verse_text(old_text)
                                if old_text != new_text:
                                    verse_data["text"] = new_text
                                    cleaned_verses += 1
    
    # Очищаем Новый Завет
    elif file_type == "Новый Завет":
        for book_name, book_data in bible_data.items():
            if isinstance(book_data, dict):
                for chapter_num, chapter_data in book_data.items():
                    if isinstance(chapter_data, dict):
                        for verse_num, verse_data in chapter_data.items():
                            if isinstance(verse_data, dict) and "text" in verse_data:
                                old_text = verse_data["text"]
                                new_text = clean_verse_text(old_text)
                                if old_text != new_text:
                                    verse_data["text"] = new_text
                                    cleaned_verses += 1
    
    # Сохраняем очищенный файл
    if cleaned_verses > 0:
        save_json_file(file_path, bible_data)
        print(f"✅ Очищено стихов: {cleaned_verses}")
    else:
        print(f"✓ Вставок не найдено")

def main():
    """Основная функция"""
    
    print("🔧 ОЧИСТКА БИБЛИИ ОТ НЕПРАВИЛЬНЫХ ВСТАВОК")
    print("=" * 60)
    
    # Очищаем Ветхий Завет
    clean_bible_file(OLD_TESTAMENT_PATH, "Ветхий Завет")
    print()
    
    # Очищаем Новый Завет
    clean_bible_file(NEW_TESTAMENT_PATH, "Новый Завет")
    print()
    
    print("🎯 ОЧИСТКА ЗАВЕРШЕНА!")
    print("=" * 60)
    print("✅ Все файлы проверены и очищены от вставок типа (3:3)")
    print("📦 Созданы резервные копии перед очисткой")

if __name__ == "__main__":
    main()