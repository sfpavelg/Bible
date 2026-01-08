#!/usr/bin/env python3
"""
Скрипт для исправления Псалма 3 в old_testament_correct.json
"""

import json
import re
from pathlib import Path

def fix_psalm_3():
    """Исправляет Псалом 3 в old_testament_correct.json"""
    file_path = Path("bible_app/assets/bible/old_testament_correct.json")
    
    if not file_path.exists():
        print("❌ Файл не найден:", file_path)
        return False
    
    print("📖 Загрузка файла для исправления Псалма 3...")
    
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Проверяем наличие Псалтири и Псалма 3
    if 'Псалтирь' not in data:
        print("❌ Книга Псалтирь не найдена")
        return False
    
    if '3' not in data['Псалтирь']:
        print("❌ Псалом 3 не найден")
        return False
    
    psalm_3 = data['Псалтирь']['3']
    
    print("🔍 Анализ текущей структуры Псалма 3:")
    print(f"   Текущее количество стихов: {len(psalm_3)}")
    
    # Проверяем стих 1
    verse_1_text = psalm_3.get('1', {}).get('text', '')
    print(f"   Стих 1: {verse_1_text[:100]}...")
    
    # Если стих 1 содержит два стиха (заголовок + стих 2)
    if "Господи! как умножились враги мои!" in verse_1_text:
        print("⚠️  Обнаружена ошибка: стих 1 содержит два стиха!")
        
        # Разделяем текст на заголовок и стих 2
        # Ищем начало второго стиха
        parts = verse_1_text.split("Господи! как умножились враги мои!", 1)
        
        if len(parts) == 2:
            header_text = parts[0].strip()
            verse_2_text = "Господи! как умножились враги мои!" + parts[1].strip()
            
            print("✅ Разделение текста:")
            print(f"   Заголовок: {header_text}")
            print(f"   Стих 2: {verse_2_text[:50]}...")
            
            # Обновляем стих 1 (только заголовок)
            psalm_3['1']['text'] = header_text
            
            # Сдвигаем все стихи на один вперед
            current_verses = sorted([int(k) for k in psalm_3.keys() if k.isdigit()])
            
            for i in range(len(current_verses), 0, -1):
                if str(i) in psalm_3:
                    psalm_3[str(i+1)] = psalm_3[str(i)]
            
            # Вставляем правильный стих 2
            psalm_3['2'] = {
                'text': verse_2_text,
                'type': 'narrative'
            }
            
            print("✅ Псалом 3 исправлен!")
            print(f"   Новое количество стихов: {len(psalm_3)}")
            
            # Сохраняем исправленный файл
            with open(file_path, 'w', encoding='utf-8') as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            
            print("💾 Файл успешно сохранен с исправлениями")
            return True
        else:
            print("❌ Не удалось разделить текст стиха 1")
            return False
    else:
        print("✅ Псалом 3 уже исправлен")
        return True

def main():
    print("🔧 Исправление Псалма 3 в old_testament_correct.json")
    print("=" * 60)
    
    success = fix_psalm_3()
    
    if success:
        print("\n🎯 Исправление завершено успешно!")
    else:
        print("\n❌ Исправление не удалось")

if __name__ == "__main__":
    main()