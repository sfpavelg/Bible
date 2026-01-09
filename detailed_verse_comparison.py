#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Детальное сравнение стихов Ветхого Завета для выявления склеивания
"""

import json
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

def find_book_in_correct_bible(correct_data: Dict, book_short_name: str) -> Dict:
    """Находит книгу в correct_bible.json по короткому имени"""
    for book in correct_data.get("Books", []):
        if book.get("BookName") == book_short_name:
            return book
    return {}

def get_correct_verse_text(correct_book: Dict, chapter_num: str, verse_num: str) -> str:
    """Получает правильный текст стиха из correct_bible.json"""
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

def check_specific_books():
    """Проверяет конкретные книги на склеивание стихов"""
    
    print("🔍 ДЕТАЛЬНАЯ ПРОВЕРКА СКЛЕИВАНИЯ СТИХОВ")
    print("=" * 50)
    
    # Загружаем файлы
    old_testament_data = load_json_file(OLD_TESTAMENT_PATH)
    correct_bible_data = load_json_file(CORRECT_BIBLE_PATH)
    
    if not old_testament_data or not correct_bible_data:
        print("❌ Не удалось загрузить файлы")
        return
    
    # Проверяем Бытие - первые несколько глав
    print("\n📖 ПРОВЕРКА БЫТИЯ (первые главы):")
    print("-" * 40)
    
    correct_book = find_book_in_correct_bible(correct_bible_data, "Быт.")
    
    for chapter in ["1", "2", "3"]:
        print(f"\nГлава {chapter}:")
        for verse in ["1", "2", "3"]:
            current_text = old_testament_data["Бытие"][chapter][verse]["text"].strip()
            correct_text = get_correct_verse_text(correct_book, chapter, verse)
            
            print(f"  {verse}: {'✅' if current_text == correct_text else '❌'}")
            if current_text != correct_text:
                print(f"    Текущий: {current_text}")
                print(f"    Правильный: {correct_text}")
                print(f"    Длина: {len(current_text)} vs {len(correct_text)}")
    
    # Проверяем Псалтирь (где вы заметили проблему)
    print("\n📖 ПРОВЕРКА ПСАЛТИРИ (глава 3):")
    print("-" * 40)
    
    correct_book = find_book_in_correct_bible(correct_bible_data, "Пс.")
    
    if "Псалтирь" in old_testament_data and "3" in old_testament_data["Псалтирь"]:
        for verse in ["1", "2", "3", "4", "5", "6", "7", "8", "9"]:
            if verse in old_testament_data["Псалтирь"]["3"]:
                current_text = old_testament_data["Псалтирь"]["3"][verse]["text"].strip()
                correct_text = get_correct_verse_text(correct_book, "3", verse)
                
                print(f"  {verse}: {'✅' if current_text == correct_text else '❌'}")
                if current_text != correct_text:
                    print(f"    Текущий: {current_text}")
                    print(f"    Правильный: {correct_text}")
                    print(f"    Разница: {abs(len(current_text) - len(correct_text))} символов")
    
    # Проверяем другие проблемные книги
    problem_books = ["Исход", "Левит", "Числа"]
    
    for book_name in problem_books:
        print(f"\n📖 ПРОВЕРКА {book_name.upper()} (первые стихи):")
        print("-" * 40)
        
        book_short_name = "Исх." if book_name == "Исход" else "Лев." if book_name == "Левит" else "Чис."
        correct_book = find_book_in_correct_bible(correct_bible_data, book_short_name)
        
        if book_name in old_testament_data and "1" in old_testament_data[book_name]:
            for verse in ["1", "2", "3"]:
                if verse in old_testament_data[book_name]["1"]:
                    current_text = old_testament_data[book_name]["1"][verse]["text"].strip()
                    correct_text = get_correct_verse_text(correct_book, "1", verse)
                    
                    print(f"  {verse}: {'✅' if current_text == correct_text else '❌'}")
                    if current_text != correct_text:
                        print(f"    Текущий: {current_text}")
                        print(f"    Правильный: {correct_text}")

if __name__ == "__main__":
    check_specific_books()