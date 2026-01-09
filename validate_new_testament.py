#!/usr/bin/env python3
"""
Скрипт для полной проверки всех книг Нового Завета
Сравнивает new_testament_correct.json с correct_bible.json
"""

import json
import os
from collections import defaultdict

# Пути к файлам
NEW_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\new_testament_correct.json"
CORRECT_BIBLE_PATH = r"c:\Project\Bible\correct_bible.json"
OUTPUT_REPORT_PATH = r"c:\Project\Bible\new_testament_validation_report.txt"

# Словарь для соответствия названий книг между двумя форматами
# (полные названия -> сокращения в correct_bible.json)
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
        print(f"Ошибка загрузки файла {file_path}: {e}")
        return None

def find_book_in_correct_bible(correct_data, book_short_name):
    """Находит книгу в correct_bible.json по сокращенному названию"""
    for book in correct_data.get("Books", []):
        # Ищем по полю BookName (содержит сокращения типа "Мтф", "Марк" и т.д.)
        if book.get("BookName") == book_short_name:
            return book
    return None

def validate_new_testament():
    """Основная функция проверки"""
    print("Загрузка файлов...")
    
    # Загружаем файлы
    new_testament = load_json_file(NEW_TESTAMENT_PATH)
    correct_bible = load_json_file(CORRECT_BIBLE_PATH)
    
    if not new_testament or not correct_bible:
        return
    
    print("Начинаем проверку всех книг Нового Завета...")
    
    # Статистика
    stats = {
        'total_books': 0,
        'books_checked': 0,
        'books_with_errors': 0,
        'total_verses': 0,
        'verses_with_errors': 0,
        'missing_books': [],
        'errors_by_book': defaultdict(list)
    }
    
    # Проверяем каждую книгу в new_testament_correct.json
    for book_name in new_testament.keys():
        stats['total_books'] += 1
        
        # Получаем правильное название книги для поиска в correct_bible.json
        correct_book_name = BOOK_NAME_MAPPING.get(book_name)
        if not correct_book_name:
            print(f"⚠️  Неизвестное название книги: {book_name}")
            stats['missing_books'].append(book_name)
            continue
        
        # Ищем книгу в correct_bible.json
        correct_book = find_book_in_correct_bible(correct_bible, correct_book_name)
        if not correct_book:
            print(f"❌ Книга не найдена в correct_bible.json: {correct_book_name}")
            stats['missing_books'].append(book_name)
            continue
        
        stats['books_checked'] += 1
        print(f"\n📖 Проверяем книгу: {book_name}")
        
        # Проверяем главы и стихи
        book_data = new_testament[book_name]
        book_has_errors = False
        
        for chapter_num, chapter_data in book_data.items():
            chapter_num = int(chapter_num)
            
            # Находим соответствующую главу в correct_bible.json
            correct_chapter = None
            for chap in correct_book.get("Chapters", []):
                if chap.get("ChapterId") == chapter_num:
                    correct_chapter = chap
                    break
            
            if not correct_chapter:
                print(f"  ❌ Глава {chapter_num} не найдена в correct_bible.json")
                stats['errors_by_book'][book_name].append(f"Глава {chapter_num} не найдена")
                book_has_errors = True
                continue
            
            # Проверяем стихи
            for verse_num, verse_data in chapter_data.items():
                verse_num = int(verse_num)
                stats['total_verses'] += 1
                
                # Находим соответствующий стих в correct_bible.json
                correct_verse = None
                for verse in correct_chapter.get("Verses", []):
                    if verse.get("VerseId") == verse_num:
                        correct_verse = verse
                        break
                
                if not correct_verse:
                    print(f"    ❌ Стих {chapter_num}:{verse_num} не найден")
                    stats['errors_by_book'][book_name].append(f"Стих {chapter_num}:{verse_num} не найден")
                    stats['verses_with_errors'] += 1
                    book_has_errors = True
                    continue
                
                # Сравниваем текст
                our_text = verse_data.get("text", "").strip()
                correct_text = correct_verse.get("Text", "").strip()
                
                if our_text != correct_text:
                    print(f"    ❌ Ошибка в стихе {chapter_num}:{verse_num}")
                    print(f"      Наш текст: {our_text}")
                    print(f"      Правильный: {correct_text}")
                    stats['errors_by_book'][book_name].append(f"Стих {chapter_num}:{verse_num}: '{our_text}' != '{correct_text}'")
                    stats['verses_with_errors'] += 1
                    book_has_errors = True
        
        if book_has_errors:
            stats['books_with_errors'] += 1
    
    # Генерируем отчет
    generate_report(stats)
    
    return stats

def generate_report(stats):
    """Генерирует подробный отчет"""
    with open(OUTPUT_REPORT_PATH, 'w', encoding='utf-8') as f:
        f.write("ОТЧЕТ ПРОВЕРКИ НОВОГО ЗАВЕТА\n")
        f.write("=" * 50 + "\n\n")
        
        f.write(f"Всего книг: {stats['total_books']}\n")
        f.write(f"Проверено книг: {stats['books_checked']}\n")
        f.write(f"Книг с ошибками: {stats['books_with_errors']}\n")
        f.write(f"Всего стихов: {stats['total_verses']}\n")
        f.write(f"Стихов с ошибками: {stats['verses_with_errors']}\n")
        f.write(f"Процент ошибок: {stats['verses_with_errors']/max(stats['total_verses'], 1) * 100:.2f}%\n\n")
        
        if stats['missing_books']:
            f.write("❌ Отсутствующие книги:\n")
            for book in stats['missing_books']:
                f.write(f"  - {book}\n")
            f.write("\n")
        
        if stats['errors_by_book']:
            f.write("📋 Детальные ошибки по книгам:\n")
            for book_name, errors in stats['errors_by_book'].items():
                f.write(f"\n📖 {book_name}: {len(errors)} ошибок\n")
                for error in errors[:10]:  # Показываем первые 10 ошибок на книгу
                    f.write(f"  - {error}\n")
                if len(errors) > 10:
                    f.write(f"  ... и еще {len(errors) - 10} ошибок\n")
    
    print(f"\n✅ Отчет сохранен в: {OUTPUT_REPORT_PATH}")

if __name__ == "__main__":
    validate_new_testament()