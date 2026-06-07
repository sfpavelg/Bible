#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Скрипт для проверки Ветхого Завета на соответствие эталонному тексту
"""

import json
import os
from typing import Dict, List, Any

# Пути к файлам
OLD_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\old_testament_correct.json"
CORRECT_BIBLE_PATH = r"c:\Project\Bible\correct_bible.json"
REPORT_PATH = r"c:\Project\Bible\old_testament_validation_report.txt"

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
    "1 Паралипоменон": "1Пар.",
    "2 Паралипоменон": "2Пар.",
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

def validate_old_testament():
    """Основная функция проверки Ветхого Завета"""
    
    print("Загрузка файлов...")
    
    # Загружаем файлы
    old_testament_data = load_json_file(OLD_TESTAMENT_PATH)
    correct_bible_data = load_json_file(CORRECT_BIBLE_PATH)
    
    if not old_testament_data or not correct_bible_data:
        return
    
    print("Начинаем проверку всех книг Ветхого Завета...\n")
    
    total_books = 0
    books_with_errors = 0
    total_verses = 0
    verses_with_errors = 0
    
    error_details = []
    
    # Проверяем каждую книгу Ветхого Завета
    for book_full_name, book_short_name in OLD_TESTAMENT_BOOK_MAPPING.items():
        print(f"📖 Проверяем книгу: {book_full_name}")
        
        if book_full_name not in old_testament_data:
            error_details.append(f"❌ Книга {book_full_name} отсутствует в old_testament_correct.json")
            continue
            
        total_books += 1
        
        # Находим книгу в эталонном файле
        correct_book = find_book_in_correct_bible(correct_bible_data, book_short_name)
        if not correct_book:
            error_details.append(f"❌ Книга {book_full_name} ({book_short_name}) не найдена в correct_bible.json")
            books_with_errors += 1
            continue
        
        # Получаем главы из нашего файла
        our_chapters = old_testament_data[book_full_name]
        
        book_has_errors = False
        
        # Проверяем каждую главу
        for chapter_num, chapter_data in our_chapters.items():
            # Проверяем каждый стих
            for verse_num, verse_data in chapter_data.items():
                total_verses += 1
                
                our_text = verse_data.get("text", "").strip()
                correct_text = get_correct_verse_text(correct_book, chapter_num, verse_num)
                
                if not correct_text:
                    error_details.append(f"❌ Стих {chapter_num}:{verse_num} отсутствует в correct_bible.json для книги {book_full_name}")
                    verses_with_errors += 1
                    book_has_errors = True
                    continue
                    
                # Сравниваем текст
                if our_text != correct_text:
                    error_details.append(f"❌ Ошибка в стихе {chapter_num}:{verse_num} ({book_full_name})")
                    error_details.append(f"   Наш текст: {our_text}")
                    error_details.append(f"   Правильный: {correct_text}")
                    error_details.append("   ---")
                    verses_with_errors += 1
                    book_has_errors = True
        
        if book_has_errors:
            books_with_errors += 1
    
    # Создаем отчет
    error_percentage = (verses_with_errors / total_verses * 100) if total_verses > 0 else 0
    
    report_lines = [
        "ОТЧЕТ ПРОВЕРКИ ВЕТХОГО ЗАВЕТА",
        "=" * 50,
        f"Всего книг: {total_books}",
        f"Книг с ошибками: {books_with_errors}",
        f"Всего стихов: {total_verses}",
        f"Стихов с ошибками: {verses_with_errors}",
        f"Процент ошибок: {error_percentage:.2f}%",
        "\nДЕТАЛИ ОШИБОК:",
        "=" * 50
    ]
    
    if error_details:
        report_lines.extend(error_details)
    else:
        report_lines.append("✅ Ошибок не обнаружено!")
    
    # Сохраняем отчет
    with open(REPORT_PATH, 'w', encoding='utf-8') as f:
        f.write('\n'.join(report_lines))
    
    print(f"\n✅ Отчет сохранен в: {REPORT_PATH}")
    
    # Выводим краткую статистику
    print(f"\n📊 СТАТИСТИКА ПРОВЕРКИ:")
    print(f"📖 Всего книг: {total_books}")
    print(f"❌ Книг с ошибками: {books_with_errors}")
    print(f"📝 Всего стихов: {total_verses}")
    print(f"❌ Стихов с ошибками: {verses_with_errors}")
    print(f"📊 Процент ошибок: {error_percentage:.2f}%")

if __name__ == "__main__":
    validate_old_testament()