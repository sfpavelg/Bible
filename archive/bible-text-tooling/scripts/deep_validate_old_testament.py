#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Глубокая проверка Ветхого Завета на склеивание стихов и системные ошибки
"""

import json
import re
from typing import Dict, Any, List, Tuple

# Пути к файлам
OLD_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\old_testament_correct.json"
CORRECT_BIBLE_PATH = r"c:\Project\Bible\correct_bible.json"

# Маппинг книг Ветхого Завета (согласно correct_bible.json)
OLD_TESTAMENT_BOOK_MAPPING = {
    "Бытие": "Быт.",
    "Исход": "Исх.",
    "Левит": "Лев.",
    "Числа": "Чис.",
    "Второзаконие": "Втор.",
    "Иисус Навин": "Ис.Нав.",
    "Судьи": "Суд.",
    "Руфь": "Руфь",
    "1 Царств": "1Цар.",
    "2 Царств": "2Цар.",
    "3 Царств": "3Цар.",
    "4 Царств": "4Цар.",
    "1 Паралипоменон": "1Пар.",
    "2 Паралипоменон": "2Пар.",
    "Ездра": "Езд.",
    "Неемия": "Неем.",
    "Есфирь": "Есф.",
    "Иов": "Иов",
    "Псалтирь": "Пс.",
    "Притчи": "Пр.",
    "Екклесиаст": "Еккл.",
    "Песня Песней": "П.Песней",
    "Исаия": "Ис.",
    "Иеремия": "Иерем.",
    "Плач Иеремии": "Пл.Иер.",
    "Иезекииль": "Иез.",
    "Даниил": "Дан.",
    "Осия": "Осия",
    "Иоиль": "Иоиль",
    "Амос": "Амос",
    "Авдий": "Авдий",
    "Иона": "Иона",
    "Михей": "Михея",
    "Наум": "Наума",
    "Аввакум": "Аввакум",
    "Софония": "Софония",
    "Аггей": "Аггей",
    "Захария": "Зах.",
    "Малахия": "Малахия"
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

def check_for_merged_verses(old_testament_data: Dict, correct_bible_data: Dict):
    """Проверяет Ветхий Завет на склеенные стихи"""
    
    print("🔍 ГЛУБОКАЯ ПРОВЕРКА ВЕТХОГО ЗАВЕТА НА СКЛЕИВАНИЕ СТИХОВ")
    print("=" * 70)
    
    total_errors = 0
    merged_verse_errors = 0
    
    for book_full_name, book_short_name in OLD_TESTAMENT_BOOK_MAPPING.items():
        print(f"\n📖 Проверяю книгу: {book_full_name} ({book_short_name})")
        
        # Находим книгу в correct_bible.json
        correct_book = find_book_in_correct_bible(correct_bible_data, book_short_name)
        if not correct_book:
            print(f"   ⚠️  Книга {book_short_name} не найдена в correct_bible.json")
            continue
        
        # Проверяем книгу в old_testament_correct.json
        if book_full_name not in old_testament_data:
            print(f"   ⚠️  Книга {book_full_name} не найдена в old_testament_correct.json")
            continue
        
        book_data = old_testament_data[book_full_name]
        book_errors = 0
        
        # Проверяем каждую главу
        for chapter_num, chapter_data in book_data.items():
            if not isinstance(chapter_data, dict):
                continue
                
            # Проверяем каждый стих
            for verse_num, verse_data in chapter_data.items():
                if not isinstance(verse_data, dict) or "text" not in verse_data:
                    continue
                
                current_text = verse_data["text"].strip()
                correct_text = get_correct_verse_text(correct_book, chapter_num, verse_num)
                
                if not correct_text:
                    continue
                
                # Проверяем, не содержит ли текущий текст несколько стихов
                if current_text != correct_text:
                    # Проверяем, не склеен ли текущий стих с следующим
                    next_verse_num = str(int(verse_num) + 1)
                    next_correct_text = get_correct_verse_text(correct_book, chapter_num, next_verse_num)
                    
                    if next_correct_text and next_correct_text in current_text:
                        print(f"   ❌ Глава {chapter_num}:{verse_num} - стих склеен со следующим!")
                        print(f"      Текущий: {current_text[:100]}...")
                        print(f"      Должен быть: {correct_text}")
                        print(f"      Следующий стих: {next_correct_text}")
                        book_errors += 1
                        merged_verse_errors += 1
                    
                    # Проверяем другие возможные склеивания
                    elif len(current_text) > len(correct_text) * 1.5:  # Текст значительно длиннее
                        print(f"   ⚠️  Глава {chapter_num}:{verse_num} - возможное склеивание стихов")
                        print(f"      Длина: {len(current_text)} vs ожидаемая {len(correct_text)}")
                        print(f"      Текст: {current_text[:150]}...")
                        book_errors += 1
        
        if book_errors > 0:
            print(f"   📊 Найдено ошибок в {book_full_name}: {book_errors}")
            total_errors += book_errors
    
    print(f"\n📊 ИТОГО:")
    print(f"   Всего ошибок склеивания: {merged_verse_errors}")
    print(f"   Всего возможных проблем: {total_errors}")
    
    return total_errors, merged_verse_errors

def main():
    """Основная функция"""
    
    # Загружаем файлы
    print("📂 Загружаю файлы...")
    old_testament_data = load_json_file(OLD_TESTAMENT_PATH)
    correct_bible_data = load_json_file(CORRECT_BIBLE_PATH)
    
    if not old_testament_data or not correct_bible_data:
        print("❌ Не удалось загрузить файлы")
        return
    
    # Проводим глубокую проверку
    total_errors, merged_errors = check_for_merged_verses(old_testament_data, correct_bible_data)
    
    if total_errors == 0:
        print("\n✅ Склеенных стихов не обнаружено!")
    else:
        print(f"\n🚨 Обнаружено {total_errors} потенциальных проблем со склеиванием стихов!")
        print("💡 Рекомендуется создать скрипт для автоматического разделения склеенных стихов")

if __name__ == "__main__":
    main()