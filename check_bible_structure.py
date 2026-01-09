#!/usr/bin/env python3
"""
Скрипт для проверки структуры и содержания файлов Библии
Сравнивает текущие JSON файлы с корректной версией
"""

import json
import os
from collections import defaultdict

# Пути к файлам
CORRECT_BIBLE_PATH = r"correct_bible.json"
NEW_TESTAMENT_PATH = r"bible_app/assets/bible/new_testament_correct.json"
OLD_TESTAMENT_PATH = r"bible_app/assets/bible/old_testament_correct.json"

# Правильный порядок книг Нового Завета с их ID
NEW_TESTAMENT_BOOKS = {
    "Матфея": 40,
    "Марка": 41, 
    "Луки": 42,
    "Иоанна": 43,
    "Деяния": 44,
    "Иакова": 59,
    "1 Петра": 60,
    "2 Петра": 61,
    "1 Иоанна": 62,
    "2 Иоанна": 63,
    "3 Иоанна": 64,
    "Иуды": 65,
    "Римлянам": 45,
    "1 Коринфянам": 46,
    "2 Коринфянам": 47,
    "Галатам": 48,
    "Ефесянам": 49,
    "Филиппийцам": 50,
    "Колоссянам": 51,
    "1 Фессалоникийцам": 52,
    "2 Фессалоникийцам": 53,
    "1 Тимофею": 54,
    "2 Тимофею": 55,
    "Титу": 56,
    "Филимону": 57,
    "Евреям": 58,
    "Откровение": 66
}

def load_json_file(file_path):
    """Загружает JSON файл"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"Ошибка загрузки файла {file_path}: {e}")
        return None

def extract_first_verse_text(book_data):
    """Извлекает текст первого стиха из книги"""
    try:
        if isinstance(book_data, dict):
            # Для вашего формата: книга -> глава -> стих
            first_chapter = next(iter(book_data.values()))
            first_verse = next(iter(first_chapter.values()))
            return first_verse.get('text', '')
    except:
        pass
    return ""

def check_new_testament_structure():
    """Проверяет структуру Нового Завета"""
    
    print("🔍 ПРОВЕРКА СТРУКТУРЫ НОВОГО ЗАВЕТА")
    print("=" * 60)
    
    # Загружаем файлы
    correct_bible = load_json_file(CORRECT_BIBLE_PATH)
    new_testament = load_json_file(NEW_TESTAMENT_PATH)
    
    if not correct_bible or not new_testament:
        return
    
    # Создаем словарь с правильными первыми стихами
    correct_first_verses = {}
    
    for book in correct_bible.get('Books', []):
        book_id = book.get('BookId')
        book_name = book.get('BookName', '').replace('.', '')
        
        if book_id >= 40:  # Новый Завет начинается с ID 40
            if book.get('Chapters'):
                first_chapter = book['Chapters'][0]
                if first_chapter.get('Verses'):
                    first_verse = first_chapter['Verses'][0]['Text']
                    correct_first_verses[book_name] = first_verse
    
    # Проверяем книги в вашем файле
    errors = []
    
    for book_name in new_testament.keys():
        your_first_verse = extract_first_verse_text(new_testament[book_name])
        correct_first_verse = correct_first_verses.get(book_name, "")
        
        if correct_first_verse and your_first_verse != correct_first_verse:
            errors.append({
                'book': book_name,
                'your_text': your_first_verse[:100] + "..." if len(your_first_verse) > 100 else your_first_verse,
                'correct_text': correct_first_verse[:100] + "..." if len(correct_first_verse) > 100 else correct_first_verse,
                'status': '❌ ОШИБКА'
            })
        elif correct_first_verse:
            errors.append({
                'book': book_name, 
                'your_text': your_first_verse[:100] + "..." if len(your_first_verse) > 100 else your_first_verse,
                'correct_text': correct_first_verse[:100] + "..." if len(correct_first_verse) > 100 else correct_first_verse,
                'status': '✅ OK'
            })
        else:
            errors.append({
                'book': book_name,
                'your_text': your_first_verse[:100] + "..." if len(your_first_verse) > 100 else your_first_verse,
                'correct_text': 'НЕ НАЙДЕНО',
                'status': '⚠️  НЕИЗВЕСТНА'
            })
    
    # Выводим результаты
    print(f"\n📊 РЕЗУЛЬТАТЫ ПРОВЕРКИ ({len(errors)} книг):")
    print("-" * 120)
    print(f"{'КНИГА':<15} {'СТАТУС':<10} {'ВАШ ПЕРВЫЙ СТИХ':<50} {'ПРАВИЛЬНЫЙ ПЕРВЫЙ СТИХ':<50}")
    print("-" * 120)
    
    for error in errors:
        print(f"{error['book']:<15} {error['status']:<10} {error['your_text']:<50} {error['correct_text']:<50}")
    
    # Подсчет ошибок
    error_count = sum(1 for e in errors if 'ОШИБКА' in e['status'])
    ok_count = sum(1 for e in errors if 'OK' in e['status'])
    unknown_count = sum(1 for e in errors if 'НЕИЗВЕСТНА' in e['status'])
    
    print("-" * 120)
    print(f"📈 ИТОГО: ✅ {ok_count} правильных, ❌ {error_count} ошибок, ⚠️  {unknown_count} неизвестных")
    
    return errors

if __name__ == "__main__":
    check_new_testament_structure()