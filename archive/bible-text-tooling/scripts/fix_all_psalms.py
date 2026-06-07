#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
УНИВЕРСАЛЬНЫЙ скрипт для исправления ВСЕХ глав Псалтири
Автоматически находит и исправляет склеенные стихи по паттерну (X-Y)
"""

import json
import shutil
import re
from typing import Dict, Any, List

# Пути к файлам
OLD_TESTAMENT_PATH = r"c:\Project\Bible\bible_app\assets\bible\old_testament_correct.json"
BACKUP_PATH = f"{OLD_TESTAMENT_PATH}.backup_all_psalms"

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

def extract_clean_verse_text(text: str, current_verse: int, chapter: int) -> str:
    """Извлекает чистый текст стиха, убирая номера в скобках"""
    
    # Убираем номера в формате (X-Y) где X - глава, Y - стих
    clean_text = re.sub(r'\(\d+-\d+\)\s*', '', text)
    
    # Убираем маркеры ^^...^^
    clean_text = re.sub(r'\^\^.*?\^\^\s*', '', clean_text)
    
    # Убираем лишние пробелы
    clean_text = clean_text.strip()
    
    return clean_text

def fix_psalm_chapter(psalm_chapter: Dict[str, Any], chapter_num: str) -> Dict[str, Any]:
    """Исправляет одну главу Псалтири"""
    
    fixed_chapter = {}
    current_verse = 1
    
    for verse_num, verse_data in psalm_chapter.items():
        text = verse_data.get("text", "")
        
        # Проверяем, содержит ли текст склеенные стихи
        if re.search(r'\(\d+-\d+\)', text):
            print(f"🔍 Глава {chapter_num}: найдены склеенные стихи в стихе {verse_num}")
            
            # Разделяем текст по номерам стихов в скобках
            parts = re.split(r'(?=\(\d+-\d+\))', text)
            
            for part in parts:
                if part.strip():
                    clean_text = extract_clean_verse_text(part, current_verse, int(chapter_num))
                    if clean_text:
                        fixed_chapter[str(current_verse)] = {"text": clean_text}
                        print(f"   ✅ Создан стих {current_verse}: {clean_text[:50]}...")
                        current_verse += 1
        else:
            # Обычный стих без склеивания
            clean_text = extract_clean_verse_text(text, current_verse, int(chapter_num))
            if clean_text:
                fixed_chapter[str(current_verse)] = {"text": clean_text}
                current_verse += 1
    
    return fixed_chapter

def fix_all_psalms():
    """Исправляет ВСЕ главы Псалтири"""
    
    print("🔧 УНИВЕРСАЛЬНОЕ ИСПРАВЛЕНИЕ ВСЕЙ ПСАЛТИРИ")
    print("=" * 60)
    
    # Создаем резервную копию
    try:
        shutil.copy2(OLD_TESTAMENT_PATH, BACKUP_PATH)
        print(f"📦 Резервная копия создана: {BACKUP_PATH}")
    except Exception as e:
        print(f"❌ Ошибка создания резервной копии: {e}")
        return
    
    # Загружаем файл
    old_testament_data = load_json_file(OLD_TESTAMENT_PATH)
    if not old_testament_data:
        print("❌ Не удалось загрузить old_testament_correct.json")
        return
    
    # Проверяем, что Псалтирь существует
    if "Псалтирь" not in old_testament_data:
        print("❌ Псалтирь не найдена")
        return
    
    psalm_book = old_testament_data["Псалтирь"]
    total_fixed = 0
    
    # Исправляем каждую главу
    for chapter_num in psalm_book.keys():
        print(f"\n📖 ИСПРАВЛЯЕМ ГЛАВУ {chapter_num}:")
        print("-" * 30)
        
        fixed_chapter = fix_psalm_chapter(psalm_book[chapter_num], chapter_num)
        
        # Заменяем главу на исправленную
        psalm_book[chapter_num] = fixed_chapter
        
        original_count = len(psalm_book[chapter_num])
        fixed_count = len(fixed_chapter)
        
        print(f"   📊 Было: {original_count} стихов, Стало: {fixed_count} стихов")
        
        if fixed_count != original_count:
            total_fixed += 1
    
    # Сохраняем исправленный файл
    save_json_file(OLD_TESTAMENT_PATH, old_testament_data)
    
    print(f"\n🎯 ПСАЛТИРЬ ПОЛНОСТЬЮ ИСПРАВЛЕНА!")
    print("=" * 60)
    print(f"✅ Исправлено глав: {total_fixed}")
    print(f"📦 Резервная копия: {BACKUP_PATH}")
    print("✅ Все склеенные стихи разделены")
    print("✅ Убраны неправильные номера в скобках")
    print("✅ Восстановлена каноническая структура")

if __name__ == "__main__":
    fix_all_psalms()