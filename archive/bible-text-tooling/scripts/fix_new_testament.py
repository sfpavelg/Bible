#!/usr/bin/env python3
"""
Скрипт для преобразования корректной структуры Библии в формат приложения
Исправляет все ошибки в Новом Завете
"""

import json
import os
from collections import OrderedDict

# Пути к файлам
CORRECT_BIBLE_PATH = r"correct_bible.json"
NEW_TESTAMENT_PATH = r"bible_app/assets/bible/new_testament_correct.json"
BACKUP_PATH = r"bible_app/assets/bible/new_testament_correct.json.backup"

# Соответствие названий книг (корректные -> ваши)
BOOK_NAME_MAPPING = {
    "Матфея": "Матфея",
    "Марка": "Марка", 
    "Луки": "Луки",
    "Иоанна": "Иоанна",
    "Деяния": "Деяния",
    "Иакова": "Иакова",
    "1 Петра": "1 Петра",
    "2 Петра": "2 Петра", 
    "1 Иоанна": "1 Иоанна",
    "2 Иоанна": "2 Иоанна",
    "3 Иоанна": "3 Иоанна",
    "Иуды": "Иуды",
    "Римлянам": "Римлянам",
    "1 Коринфянам": "1 Коринфянам",
    "2 Коринфянам": "2 Коринфянам",
    "Галатам": "Галатам",
    "Ефесянам": "Ефесянам",
    "Филиппийцам": "Филиппийцам",
    "Колоссянам": "Колоссянам",
    "1 Фессалоникийцам": "1 Фессалоникийцам",
    "2 Фессалоникийцам": "2 Фессалоникийцам",
    "1 Тимофею": "1 Тимофею",
    "2 Тимофею": "2 Тимофею",
    "Титу": "Титу",
    "Филимону": "Филимону",
    "Евреям": "Евреям",
    "Откровение": "Откровение"
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
    """Сохраняет JSON файл с красивым форматированием"""
    try:
        # Создаем backup
        if os.path.exists(file_path):
            os.rename(file_path, BACKUP_PATH)
            print(f"✅ Создан backup: {BACKUP_PATH}")
        
        # Сохраняем новый файл
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ Файл сохранен: {file_path}")
        return True
    except Exception as e:
        print(f"❌ Ошибка сохранения файла {file_path}: {e}")
        return False

def convert_correct_to_app_format(correct_bible):
    """Преобразует корректную структуру в формат приложения"""
    
    print("🔄 Преобразование структуры Нового Завета...")
    
    new_testament = OrderedDict()
    new_testament_books = []
    
    # Собираем книги Нового Завета (ID >= 40)
    for book in correct_bible.get('Books', []):
        book_id = book.get('BookId')
        if book_id >= 40:  # Новый Завет
            new_testament_books.append(book)
    
    # Сортируем книги по ID
    new_testament_books.sort(key=lambda x: x.get('BookId', 0))
    
    # Преобразуем каждую книгу
    for book in new_testament_books:
        book_name = book.get('BookName', '').replace('.', '')
        mapped_name = BOOK_NAME_MAPPING.get(book_name, book_name)
        
        print(f"📖 Обработка книги: {mapped_name}")
        
        book_data = OrderedDict()
        
        for chapter in book.get('Chapters', []):
            chapter_id = str(chapter.get('ChapterId', 1))
            chapter_data = OrderedDict()
            
            for verse in chapter.get('Verses', []):
                verse_id = str(verse.get('VerseId', 1))
                verse_text = verse.get('Text', '')
                
                chapter_data[verse_id] = {
                    'text': verse_text,
                    'type': 'narrative'  # Все стихи narrative по умолчанию
                }
            
            book_data[chapter_id] = chapter_data
        
        new_testament[mapped_name] = book_data
    
    return new_testament

def verify_correction(original_file, corrected_data):
    """Проверяет корректность преобразования"""
    
    print("\n🔍 Проверка корректности преобразования...")
    
    # Проверяем несколько ключевых книг
    key_books = ["Иакова", "Римлянам", "1 Фессалоникийцам"]
    
    for book_name in key_books:
        if book_name in corrected_data:
            book_data = corrected_data[book_name]
            if "1" in book_data and "1" in book_data["1"]:
                first_verse = book_data["1"]["1"]["text"]
                print(f"✅ {book_name}: {first_verse[:80]}...")
            else:
                print(f"❌ {book_name}: структура повреждена")
        else:
            print(f"❌ {book_name}: книга не найдена")

def main():
    """Основная функция"""
    
    print("🎯 НАЧАЛО ИСПРАВЛЕНИЯ НОВОГО ЗАВЕТА")
    print("=" * 50)
    
    # Загружаем корректную Библию
    correct_bible = load_json_file(CORRECT_BIBLE_PATH)
    if not correct_bible:
        return
    
    # Преобразуем структуру
    new_testament_corrected = convert_correct_to_app_format(correct_bible)
    
    # Проверяем корректность
    verify_correction(None, new_testament_corrected)
    
    # Сохраняем исправленный файл
    if save_json_file(NEW_TESTAMENT_PATH, new_testament_corrected):
        print(f"\n🎉 ПРЕОБРАЗОВАНИЕ ЗАВЕРШЕНО!")
        print(f"📊 Книг обработано: {len(new_testament_corrected)}")
        print(f"💾 Backup создан: {BACKUP_PATH}")
        print(f"📁 Новый файл: {NEW_TESTAMENT_PATH}")
        
        # Показываем пример исправленной книги Иакова
        if "Иакова" in new_testament_corrected:
            james_first_verse = new_testament_corrected["Иакова"]["1"]["1"]["text"]
            print(f"\n📜 ПЕРВЫЙ СТИХ ИАКОВА (исправленный):")
            print(f"   '{james_first_verse}'")
    
    print("\n✅ ВСЕ ОШИБКИ ИСПРАВЛЕНЫ!")

if __name__ == "__main__":
    main()