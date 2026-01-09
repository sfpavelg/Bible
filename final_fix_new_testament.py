#!/usr/bin/env python3
"""
ФИНАЛЬНЫЙ скрипт для полного исправления Нового Завета
С правильными названиями книг и структурой
"""

import json
import os
from collections import OrderedDict

# Пути к файлам
CORRECT_BIBLE_PATH = r"correct_bible.json"
NEW_TESTAMENT_PATH = r"bible_app/assets/bible/new_testament_correct.json"
BACKUP_PATH = r"bible_app/assets/bible/new_testament_correct.json.backup2"

# Правильное соответствие названий (корректные сокращения -> полные названия)
BOOK_NAME_MAPPING = {
    "Мтф.": "Матфея",
    "Марк.": "Марка", 
    "Лук.": "Луки",
    "Иоан.": "Иоанна",
    "Деян.": "Деяния",
    "Иакова": "Иакова",
    "1Петр.": "1 Петра",
    "2Петр.": "2 Петра", 
    "1Иоан.": "1 Иоанна",
    "2Иоан.": "2 Иоанна",
    "3Иоан.": "3 Иоанна", 
    "Иуды": "Иуды",
    "Рим.": "Римлянам",
    "1Кор.": "1 Коринфянам",
    "2Кор.": "2 Коринфянам",
    "Гал.": "Галатам",
    "Ефесянам": "Ефесянам",
    "Филип.": "Филиппийцам",
    "Колос.": "Колоссянам",
    "1Фес.": "1 Фессалоникийцам",
    "2Фес.": "2 Фессалоникийцам",
    "1Тим.": "1 Тимофею",
    "2Тим.": "2 Тимофею",
    "Титу": "Титу",
    "Филимону": "Филимону",
    "Евр.": "Евреям",
    "Откр.": "Откровение"
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
    """Сохраняет JSON файл"""
    try:
        # Создаем backup
        if os.path.exists(file_path):
            os.rename(file_path, BACKUP_PATH)
            print(f"✅ Создан backup: {BACKUP_PATH}")
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        return True
    except Exception as e:
        print(f"❌ Ошибка сохранения файла {file_path}: {e}")
        return False

def convert_new_testament():
    """Преобразует Новый Завет в правильный формат"""
    
    print("🎯 НАЧАЛО ПРЕОБРАЗОВАНИЯ НОВОГО ЗАВЕТА")
    print("=" * 50)
    
    # Загружаем корректную Библию
    correct_bible = load_json_file(CORRECT_BIBLE_PATH)
    if not correct_bible:
        return None
    
    new_testament = OrderedDict()
    
    # Обрабатываем книги Нового Завета (ID >= 40)
    for book in correct_bible.get('Books', []):
        book_id = book.get('BookId')
        if book_id < 40:
            continue
            
        original_name = book.get('BookName', '')
        full_name = BOOK_NAME_MAPPING.get(original_name, original_name)
        
        print(f"📖 Обработка: {original_name} -> {full_name}")
        
        book_data = OrderedDict()
        
        # Обрабатываем главы
        for chapter in book.get('Chapters', []):
            chapter_id = str(chapter.get('ChapterId', 1))
            chapter_data = OrderedDict()
            
            # Обрабатываем стихи
            for verse in chapter.get('Verses', []):
                verse_id = str(verse.get('VerseId', 1))
                verse_text = verse.get('Text', '')
                
                chapter_data[verse_id] = {
                    'text': verse_text,
                    'type': 'narrative'
                }
            
            book_data[chapter_id] = chapter_data
        
        new_testament[full_name] = book_data
    
    return new_testament

def verify_correction(corrected_data):
    """Проверяет корректность преобразования"""
    
    print("\n🔍 ПРОВЕРКА КОРРЕКТНОСТИ")
    print("=" * 30)
    
    key_books = ["Иакова", "Римлянам", "1 Фессалоникийцам", "Матфея"]
    
    for book_name in key_books:
        if book_name in corrected_data:
            book_data = corrected_data[book_name]
            if "1" in book_data and "1" in book_data["1"]:
                first_verse = corrected_data[book_name]["1"]["1"]["text"]
                status = "✅"
                # Проверяем содержание
                if "Иаков, раб Бога" in first_verse and book_name == "Иакова":
                    status = "✅✅"
                elif "Павел, раб Иисуса Христа" in first_verse and book_name == "Римлянам":
                    status = "✅✅"
                print(f"{status} {book_name}: {first_verse[:60]}...")
            else:
                print(f"❌ {book_name}: повреждена структура")
        else:
            print(f"❌ {book_name}: не найдена")

def main():
    """Основная функция"""
    
    # Преобразуем Новый Завет
    new_testament_corrected = convert_new_testament()
    if not new_testament_corrected:
        return
    
    # Проверяем корректность
    verify_correction(new_testament_corrected)
    
    # Сохраняем результат
    if save_json_file(NEW_TESTAMENT_PATH, new_testament_corrected):
        print(f"\n🎉 ПРЕОБРАЗОВАНИЕ ЗАВЕРШЕНО!")
        print(f"📊 Книг обработано: {len(new_testament_corrected)}")
        print(f"💾 Backup создан: {BACKUP_PATH}")
        print(f"📁 Новый файл: {NEW_TESTAMENT_PATH}")
        
        # Показываем ключевые исправления
        print(f"\n📜 КЛЮЧЕВЫЕ ИСПРАВЛЕНИЯ:")
        for book in ["Иакова", "Римлянам", "1 Фессалоникийцам"]:
            if book in new_testament_corrected:
                first_verse = new_testament_corrected[book]["1"]["1"]["text"]
                print(f"   {book}: {first_verse[:50]}...")

if __name__ == "__main__":
    main()