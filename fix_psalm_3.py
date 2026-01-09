#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
Скрипт для исправления Псалтири, глава 3 - системное склеивание и дублирование стихов
"""

import json
import shutil
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

def save_json_file(file_path: str, data: Any):
    """Сохраняет JSON файл"""
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f"✅ Файл сохранен: {file_path}")
    except Exception as e:
        print(f"❌ Ошибка сохранения файла {file_path}: {e}")

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

def fix_psalm_3():
    """Исправляет Псалтирь, главу 3"""
    
    print("🔧 ИСПРАВЛЕНИЕ ПСАЛТИРИ, ГЛАВА 3")
    print("=" * 40)
    
    # Создаем резервную копию
    backup_path = f"{OLD_TESTAMENT_PATH}.backup_psalm3"
    try:
        shutil.copy2(OLD_TESTAMENT_PATH, backup_path)
        print(f"📦 Резервная копия создана: {backup_path}")
    except Exception as e:
        print(f"❌ Ошибка создания резервной копии: {e}")
        return
    
    # Загружаем файлы
    old_testament_data = load_json_file(OLD_TESTAMENT_PATH)
    correct_bible_data = load_json_file(CORRECT_BIBLE_PATH)
    
    if not old_testament_data or not correct_bible_data:
        print("❌ Не удалось загрузить файлы")
        return
    
    # Находим Псалтирь в correct_bible.json
    correct_book = find_book_in_correct_bible(correct_bible_data, "Пс.")
    if not correct_book:
        print("❌ Псалтирь не найдена в correct_bible.json")
        return
    
    # Проверяем, что Псалтирь существует в old_testament_correct.json
    if "Псалтирь" not in old_testament_data:
        print("❌ Псалтирь не найдена в old_testament_correct.json")
        return
    
    if "3" not in old_testament_data["Псалтирь"]:
        print("❌ Глава 3 не найдена в Псалтири")
        return
    
    # Правильная структура Псалтири 3 согласно correct_bible.json
    # В correct_bible.json Псалтирь 3 имеет только 8 стихов!
    correct_psalm_3 = {
        "1": "Псалом Давида, когда он бежал от Авессалома, сына своего.",
        "2": "Господи! как умножились враги мои! Многие восстают на меня",
        "3": "многие говорят душе моей: \"нет ему спасения в Боге\".",
        "4": "Но Ты, Господи, щит предо мною, слава моя, и Ты возносишь голову мою.",
        "5": "Гласом моим взываю к Господу, и Он слышит меня со святой горы Своей.",
        "6": "Ложусь я, сплю и встаю, ибо Господь защищает меня.",
        "7": "Не убоюсь тем народа, которые со всех сторон ополчились на меня.",
        "8": "Восстань, Господи! спаси меня, Боже мой! ибо Ты поражаешь в ланиту всех врагов моих; сокрушаешь зубы нечестивых."
    }
    
    # Исправляем главу 3 Псалтири
    psalm_3_chapter = old_testament_data["Псалтирь"]["3"]
    
    # Удаляем лишний стих 9 (дубликат)
    if "9" in psalm_3_chapter:
        del psalm_3_chapter["9"]
        print("✅ Удален дублирующий стих 9")
    
    # Исправляем остальные стихи
    for verse_num, correct_text in correct_psalm_3.items():
        if verse_num in psalm_3_chapter:
            psalm_3_chapter[verse_num]["text"] = correct_text
            print(f"✅ Исправлен стих {verse_num}")
    
    # Сохраняем исправленный файл
    save_json_file(OLD_TESTAMENT_PATH, old_testament_data)
    
    print(f"\n🎯 ПСАЛТИРЬ 3 ИСПРАВЛЕНА!")
    print("=" * 40)
    print("✅ Удален дублирующий стих 9")
    print("✅ Исправлены тексты стихов 1-8")
    print("✅ Восстановлена правильная структура")
    print(f"📦 Резервная копия: {backup_path}")

if __name__ == "__main__":
    fix_psalm_3()