#!/usr/bin/env python3
"""
Скрипт для проверки структуры Ветхого Завета
"""

import json
import os

# Пути к файлам
CORRECT_BIBLE_PATH = r"correct_bible.json"
OLD_TESTAMENT_PATH = r"bible_app/assets/bible/old_testament_correct.json"

# Соответствие названий книг Ветхого Завета (корректные -> ваши)
OLD_TESTAMENT_BOOK_MAPPING = {
    "Быт.": "Бытие",
    "Исх.": "Исход", 
    "Лев.": "Левит",
    "Числ.": "Числа",
    "Втор.": "Второзаконие",
    "ИисНав.": "Иисус Навин",
    "Суд.": "Судей",
    "Руфь": "Руфь",
    "1Цар.": "1 Царств",
    "2Цар.": "2 Царств", 
    "3Цар.": "3 Царств",
    "4Цар.": "4 Царств",
    "1Пар.": "1 Паралипоменон",
    "2Пар.": "2 Паралипоменон",
    "Езд.": "Ездра",
    "Неем.": "Неемия",
    "Есф.": "Есфирь",
    "Иов": "Иов",
    "Пс.": "Псалтирь",
    "Притч.": "Притчи",
    "Еккл.": "Екклесиаст",
    "Песн.": "Песнь Песней",
    "Ис.": "Исаия",
    "Иер.": "Иеремия",
    "Плач": "Плач Иеремии",
    "Иез.": "Иезекииль",
    "Дан.": "Даниил",
    "Ос.": "Осия",
    "Иоил.": "Иоиль",
    "Амос": "Амос",
    "Авд.": "Авдий",
    "Иона": "Иона",
    "Мих.": "Михей",
    "Наум": "Наум",
    "Авв.": "Аввакум",
    "Соф.": "Софония",
    "Агг.": "Аггей",
    "Зах.": "Захария",
    "Мал.": "Малахия"
}

def load_json_file(file_path):
    """Загружает JSON файл"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Ошибка загрузки файла {file_path}: {e}")
        return None

def extract_first_verse_text(book_data):
    """Извлекает текст первого стиха из книги"""
    try:
        if isinstance(book_data, dict):
            first_chapter = next(iter(book_data.values()))
            first_verse = next(iter(first_chapter.values()))
            return first_verse.get('text', '')
    except:
        pass
    return ""

def check_old_testament_structure():
    """Проверяет структуру Ветхого Завета"""
    
    print("🔍 ПРОВЕРКА СТРУКТУРЫ ВЕТХОГО ЗАВЕТА")
    print("=" * 60)
    
    # Загружаем файлы
    correct_bible = load_json_file(CORRECT_BIBLE_PATH)
    old_testament = load_json_file(OLD_TESTAMENT_PATH)
    
    if not correct_bible or not old_testament:
        return
    
    # Создаем словарь с правильными первыми стихами
    correct_first_verses = {}
    
    for book in correct_bible.get('Books', []):
        book_id = book.get('BookId')
        book_name = book.get('BookName', '')
        
        if book_id < 40:  # Ветхий Завет (ID 1-39)
            full_name = OLD_TESTAMENT_BOOK_MAPPING.get(book_name, book_name)
            
            if book.get('Chapters'):
                first_chapter = book['Chapters'][0]
                if first_chapter.get('Verses'):
                    first_verse = first_chapter['Verses'][0]['Text']
                    correct_first_verses[full_name] = first_verse
    
    # Проверяем книги в вашем файле
    errors = []
    
    for book_name in old_testament.keys():
        your_first_verse = extract_first_verse_text(old_testament[book_name])
        correct_first_verse = correct_first_verses.get(book_name, "")
        
        if correct_first_verse and your_first_verse != correct_first_verse:
            errors.append({
                'book': book_name,
                'your_text': your_first_verse[:80] + "..." if len(your_first_verse) > 80 else your_first_verse,
                'correct_text': correct_first_verse[:80] + "..." if len(correct_first_verse) > 80 else correct_first_verse,
                'status': '❌ ОШИБКА'
            })
        elif correct_first_verse:
            errors.append({
                'book': book_name, 
                'your_text': your_first_verse[:80] + "..." if len(your_first_verse) > 80 else your_first_verse,
                'correct_text': correct_first_verse[:80] + "..." if len(correct_first_verse) > 80 else correct_first_verse,
                'status': '✅ OK'
            })
        else:
            errors.append({
                'book': book_name,
                'your_text': your_first_verse[:80] + "..." if len(your_first_verse) > 80 else your_first_verse,
                'correct_text': 'НЕ НАЙДЕНО',
                'status': '⚠️  НЕИЗВЕСТНА'
            })
    
    # Выводим результаты
    print(f"\n📊 РЕЗУЛЬТАТЫ ПРОВЕРКИ ({len(errors)} книг):")
    print("-" * 120)
    print(f"{'КНИГА':<20} {'СТАТУС':<10} {'ВАШ ПЕРВЫЙ СТИХ':<50} {'ПРАВИЛЬНЫЙ ПЕРВЫЙ СТИХ':<50}")
    print("-" * 120)
    
    for error in errors:
        print(f"{error['book']:<20} {error['status']:<10} {error['your_text']:<50} {error['correct_text']:<50}")
    
    # Подсчет ошибок
    error_count = sum(1 for e in errors if 'ОШИБКА' in e['status'])
    ok_count = sum(1 for e in errors if 'OK' in e['status'])
    unknown_count = sum(1 for e in errors if 'НЕИЗВЕСТНА' in e['status'])
    
    print("-" * 120)
    print(f"📈 ИТОГО: ✅ {ok_count} правильных, ❌ {error_count} ошибок, ⚠️  {unknown_count} неизвестных")
    
    return errors

if __name__ == "__main__":
    check_old_testament_structure()