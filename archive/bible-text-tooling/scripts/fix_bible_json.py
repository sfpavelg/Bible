#!/usr/bin/env python3
"""
Скрипт для исправления JSON файлов Библии:
1. Переносит данные в правильные файлы
2. Исправляет имена книг
3. Убирает дублирование номеров стихов
"""

import json
import re
import os

# Соответствие старых имен книг новым (из bible_model.dart)
BOOK_NAME_MAPPING = {
    # Ветхий Завет
    "Бытие": "Бытие",
    "Исход": "Исход", 
    "Левит": "Левит",
    "Числа": "Числа",
    "Второзаконие": "Второзаконие",
    "Иисус Навин": "Иисус Навин",
    "Судьи": "Судьи",
    "Руфь": "Руфь",
    "1 Царств": "1 Царств",
    "2 Царств": "2 Царств", 
    "3 Царств": "3 Царств",
    "4 Царств": "4 Царств",
    "1 Паралипоменон": "1 Паралипоменон",
    "2 Паралипоменон": "2 Паралипоменон",
    "Езд.": "Ездра",
    "Неемия": "Неемия",
    "Есфирь": "Есфирь",
    "Иов": "Иов",
    "Псалтирь": "Псалтирь",
    "Пр.": "Притчи",
    "Екклесиаст": "Екклесиаст",
    "П.Песней": "Песня Песней",
    "Исаия": "Исаия",
    "Иерем.": "Иеремия",
    "Пл.Иер.": "Плач Иеремии",
    "Иезекииль": "Иезекииль",
    "Даниил": "Даниил",
    "Осия": "Осия",
    "Иоиль": "Иоиль",
    "Амос": "Амос",
    "Авдий": "Авдий",
    "Иона": "Иона",
    "Михея": "Михей",
    "Наума": "Наум",
    "Аввакум": "Аввакум",
    "Софония": "Софония",
    "Аггей": "Аггей",
    "Захария": "Захария",
    "Малахия": "Малахия",
    
    # Новый Завет
    "Мтф.": "Матфея",
    "Марк.": "Марка",
    "Лук.": "Лука",
    "Иоан.": "Иоанна",
    "Деяния": "Деяния",
    "Иакова": "Иакова",
    "1Петр.": "1 Петра",
    "2Петр.": "2 Петра",
    "1Иоан.": "1 Иоанна",
    "2Иоан.": "2 Иоанна",
    "3Иоан.": "3 Иоанна",
    "Иуды": "Иуды",
    "Римлянам": "Римлянам",
    "1 Коринфянам": "1 Коринфянам",
    "2 Коринфянам": "2 Коринфянам",
    "Галатам": "Галатам",
    "Ефесянам": "Ефесянам",
    "Филип.": "Филиппийцам",
    "Колос.": "Колоссянам",
    "1 Фессалоникийцам": "1 Фессалоникийцам",
    "2 Фессалоникийцам": "2 Фессалоникийцам",
    "1 Тимофею": "1 Тимофею",
    "2 Тимофею": "2 Тимофею",
    "Титу": "Титу",
    "Филимону": "Филимону",
    "Евреям": "Евреям",
    "Откровение": "Откровение"
}

def clean_verse_text(text):
    """Убирает дублирование номеров стихов типа (90:3)"""
    # Убираем конструкции типа (90:3) в начале текста
    text = re.sub(r'^\(\d+:\d+\)\s*', '', text)
    # Убираем конструкции типа (90:3) в любом месте текста
    text = re.sub(r'\(\d+:\d+\)', '', text)
    return text.strip()

def process_bible_data():
    """Основная функция обработки данных"""
    
    # Загружаем исходные данные
    with open('bible_app/assets/bible/new_testament.json', 'r', encoding='utf-8') as f:
        full_bible_data = json.load(f)
    
    with open('bible_app/assets/bible/old_testament.json', 'r', encoding='utf-8') as f:
        old_testament_partial = json.load(f)
    
    # Создаем словари для новых данных
    old_testament_correct = {}
    new_testament_correct = {}
    
    # Список книг Ветхого Завета из bible_model.dart
    old_testament_books = [
        "Бытие", "Исход", "Левит", "Числа", "Второзаконие", "Иисус Навин", "Судьи", "Руфь",
        "1 Царств", "2 Царств", "3 Царств", "4 Царств", "1 Паралипоменон", "2 Паралипоменон",
        "Ездра", "Неемия", "Есфирь", "Иов", "Псалтирь", "Притчи", "Екклесиаст", "Песня Песней",
        "Исаия", "Иеремия", "Плач Иеремии", "Иезекииль", "Даниил", "Осия", "Иоиль", "Амос",
        "Авдий", "Иона", "Михей", "Наум", "Аввакум", "Софония", "Аггей", "Захария", "Малахия"
    ]
    
    # Список книг Нового Завета из bible_model.dart
    new_testament_books = [
        "Матфея", "Марка", "Лука", "Иоанна", "Деяния", "Иакова", "1 Петра", "2 Петра",
        "1 Иоанна", "2 Иоанна", "3 Иоанна", "Иуды", "Римлянам", "1 Коринфянам", "2 Коринфянам",
        "Галатам", "Ефесянам", "Филиппийцам", "Колоссянам", "1 Фессалоникийцам", "2 Фессалоникийцам",
        "1 Тимофею", "2 Тимофею", "Титу", "Филимону", "Евреям", "Откровение"
    ]
    
    # Обрабатываем данные из full_bible_data (содержит почти всю Библию)
    for old_book_name, book_data in full_bible_data.items():
        new_book_name = BOOK_NAME_MAPPING.get(old_book_name, old_book_name)
        
        # Очищаем текст стихов
        cleaned_book_data = {}
        for chapter_num, chapter_data in book_data.items():
            cleaned_chapter = {}
            for verse_num, verse_data in chapter_data.items():
                if 'text' in verse_data:
                    verse_data['text'] = clean_verse_text(verse_data['text'])
                cleaned_chapter[verse_num] = verse_data
            cleaned_book_data[chapter_num] = cleaned_chapter
        
        # Распределяем по заветам
        if new_book_name in old_testament_books:
            old_testament_correct[new_book_name] = cleaned_book_data
        elif new_book_name in new_testament_books:
            new_testament_correct[new_book_name] = cleaned_book_data
    
    # Добавляем недостающие книги из old_testament_partial
    for old_book_name, book_data in old_testament_partial.items():
        new_book_name = BOOK_NAME_MAPPING.get(old_book_name, old_book_name)
        
        # Очищаем текст стихов
        cleaned_book_data = {}
        for chapter_num, chapter_data in book_data.items():
            cleaned_chapter = {}
            for verse_num, verse_data in chapter_data.items():
                if 'text' in verse_data:
                    verse_data['text'] = clean_verse_text(verse_data['text'])
                cleaned_chapter[verse_num] = verse_data
            cleaned_book_data[chapter_num] = cleaned_chapter
        
        if new_book_name in old_testament_books:
            old_testament_correct[new_book_name] = cleaned_book_data
    
    # Сохраняем исправленные файлы
    with open('bible_app/assets/bible/old_testament_correct.json', 'w', encoding='utf-8') as f:
        json.dump(old_testament_correct, f, ensure_ascii=False, indent=2)
    
    with open('bible_app/assets/bible/new_testament_correct.json', 'w', encoding='utf-8') as f:
        json.dump(new_testament_correct, f, ensure_ascii=False, indent=2)
    
    print("✅ Обработка завершена!")
    print(f"📖 Ветхий Завет: {len(old_testament_correct)} книг")
    print(f"📖 Новый Завет: {len(new_testament_correct)} книг")

if __name__ == "__main__":
    process_bible_data()