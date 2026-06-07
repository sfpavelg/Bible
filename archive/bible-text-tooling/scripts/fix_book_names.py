#!/usr/bin/env python3
"""
Скрипт для исправления соответствия названий книг между форматами
"""

import json
import os

# Пути к файлам
CORRECT_BIBLE_PATH = r"correct_bible.json"
NEW_TESTAMENT_PATH = r"bible_app/assets/bible/new_testament_correct.json"

# Правильное соответствие названий (корректные -> ваши)
CORRECT_BOOK_NAME_MAPPING = {
    "Мтф": "Матфея",
    "Марк": "Марка", 
    "Лук": "Луки",
    "Иоан": "Иоанна",
    "Деян": "Деяния",
    "Иакова": "Иакова",
    "1Петр": "1 Петра",
    "2Петр": "2 Петра", 
    "1Иоан": "1 Иоанна",
    "2Иоан": "2 Иоанна", 
    "3Иоан": "3 Иоанна",
    "Иуды": "Иуды",
    "Рим": "Римлянам",
    "1Кор": "1 Коринфянам",
    "2Кор": "2 Коринфянам",
    "Гал": "Галатам",
    "Ефесянам": "Ефесянам",
    "Филип": "Филиппийцам",
    "Колос": "Колоссянам",
    "1Фес": "1 Фессалоникийцам",
    "2Фес": "2 Фессалоникийцам",
    "1Тим": "1 Тимофею",
    "2Тим": "2 Тимофею",
    "Титу": "Титу",
    "Филимону": "Филимону",
    "Евр": "Евреям",
    "Откр": "Откровение"
}

def load_json_file(file_path):
    """Загружает JSON файл"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f)
    except Exception as e:
        print(f"❌ Ошибка загрузки файла {file_path}: {e}")
        return None

def get_correct_book_names():
    """Получает правильные названия книг из корректного файла"""
    
    correct_bible = load_json_file(CORRECT_BIBLE_PATH)
    if not correct_bible:
        return {}
    
    book_names = {}
    
    for book in correct_bible.get('Books', []):
        book_id = book.get('BookId')
        if book_id >= 40:  # Новый Завет
            book_name = book.get('BookName', '')
            book_names[book_name] = book_id
    
    return book_names

def fix_book_names_in_file():
    """Исправляет названия книг в файле"""
    
    print("🔧 ИСПРАВЛЕНИЕ НАЗВАНИЙ КНИГ")
    print("=" * 40)
    
    # Загружаем текущий файл
    current_data = load_json_file(NEW_TESTAMENT_PATH)
    if not current_data:
        return
    
    # Получаем правильные названия из корректного файла
    correct_names = get_correct_book_names()
    print(f"📚 Найдено книг в корректном файле: {len(correct_names)}")
    
    # Создаем новый словарь с правильными названиями
    fixed_data = {}
    
    for correct_name, book_id in correct_names.items():
        mapped_name = CORRECT_BOOK_NAME_MAPPING.get(correct_name, correct_name)
        
        # Ищем книгу в текущем файле
        found = False
        for current_name in list(current_data.keys()):
            if current_name in correct_name or correct_name in current_name:
                fixed_data[mapped_name] = current_data[current_name]
                print(f"✅ {correct_name} -> {mapped_name}")
                found = True
                break
        
        if not found:
            print(f"❌ Книга не найдена: {correct_name} ({mapped_name})")
    
    # Сохраняем исправленный файл
    with open(NEW_TESTAMENT_PATH, 'w', encoding='utf-8') as f:
        json.dump(fixed_data, f, ensure_ascii=False, indent=2)
    
    print(f"\n🎉 НАЗВАНИЯ ИСПРАВЛЕНЫ!")
    print(f"📊 Книг обработано: {len(fixed_data)}")
    print(f"📁 Файл обновлен: {NEW_TESTAMENT_PATH}")

def verify_fix():
    """Проверяет исправление"""
    
    print("\n🔍 ПРОВЕРКА ИСПРАВЛЕНИЙ")
    print("=" * 30)
    
    data = load_json_file(NEW_TESTAMENT_PATH)
    if not data:
        return
    
    # Проверяем ключевые книги
    key_books = ["Иакова", "Римлянам", "1 Фессалоникийцам"]
    
    for book_name in key_books:
        if book_name in data:
            if "1" in data[book_name] and "1" in data[book_name]["1"]:
                first_verse = data[book_name]["1"]["1"]["text"]
                print(f"✅ {book_name}: {first_verse[:70]}...")
            else:
                print(f"❌ {book_name}: повреждена структура")
        else:
            print(f"❌ {book_name}: не найдена")

if __name__ == "__main__":
    fix_book_names_in_file()
    verify_fix()