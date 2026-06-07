#!/usr/bin/env python3
"""
Скрипт для проверки и исправления ошибок разбивки стихов в JSON файлах Библии
"""

import json
import re
from pathlib import Path

def check_and_fix_psalm_3(book_data):
    """Проверяет и исправляет Псалом 3"""
    if 'Псалтирь' in book_data and '3' in book_data['Псалтирь']:
        psalm_3 = book_data['Псалтирь']['3']
        
        # Проверяем текущую структуру
        print("📖 Анализ Псалма 3:")
        print(f"   Текущее количество стихов: {len(psalm_3)}")
        
        # Проверяем стих 1 - должен содержать только заголовок
        verse_1_text = psalm_3.get('1', {}).get('text', '')
        if '(3:2)' in verse_1_text:
            print("⚠️  Обнаружена ошибка: стих 1 содержит два стиха!")
            
            # Разделяем текст на заголовок и стих 2
            parts = verse_1_text.split('(3:2)', 1)
            if len(parts) == 2:
                header_text = parts[0].strip()
                verse_2_text = '(3:2)' + parts[1].strip()
                
                # Обновляем стих 1 (только заголовок)
                psalm_3['1']['text'] = header_text
                
                # Сдвигаем все стихи на один вперед
                for i in range(len(psalm_3), 1, -1):
                    if str(i) in psalm_3:
                        psalm_3[str(i+1)] = psalm_3[str(i)]
                
                # Вставляем правильный стих 2
                psalm_3['2'] = {
                    'text': verse_2_text,
                    'type': 'narrative'
                }
                
                print("✅ Псалом 3 исправлен: добавлен недостающий стих 2")
                print(f"   Новое количество стихов: {len(psalm_3)}")
                return True
    
    return False

def check_chapter_structure(book_name, chapter_data, chapter_num):
    """Проверяет структуру главы на ошибки"""
    issues = []
    
    # Проверяем нумерацию стихов
    verse_numbers = sorted([int(k) for k in chapter_data.keys() if k.isdigit()])
    expected_numbers = list(range(1, len(verse_numbers) + 1))
    
    if verse_numbers != expected_numbers:
        issues.append(f"Неправильная нумерация стихов: {verse_numbers} vs {expected_numbers}")
    
    # Проверяем наличие дублированных номеров стихов в тексте
    for verse_num, verse_data in chapter_data.items():
        if verse_num.isdigit():
            text = verse_data.get('text', '')
            # Ищем паттерны типа (X:Y) в тексте
            verse_refs = re.findall(r'\(\d+:\d+\)', text)
            if verse_refs:
                issues.append(f"Стих {verse_num}: содержит ссылки на другие стихи: {verse_refs}")
    
    return issues

def main():
    print("🔍 Проверка ошибок разбивки стихов в JSON файлах Библии")
    print("=" * 60)
    
    # Пути к файлам
    old_testament_path = Path("bible_app/assets/bible/old_testament_correct.json")
    new_testament_path = Path("bible_app/assets/bible/new_testament_correct.json")
    
    for file_path in [old_testament_path, new_testament_path]:
        if file_path.exists():
            print(f"\n📚 Анализ файла: {file_path.name}")
            
            with open(file_path, 'r', encoding='utf-8') as f:
                data = json.load(f)
            
            total_issues = 0
            
            for book_name, book_data in data.items():
                print(f"\n📖 Книга: {book_name}")
                
                for chapter_num, chapter_data in book_data.items():
                    if chapter_num.isdigit():
                        issues = check_chapter_structure(book_name, chapter_data, int(chapter_num))
                        
                        if issues:
                            print(f"   Глава {chapter_num}: обнаружены проблемы:")
                            for issue in issues:
                                print(f"     ⚠️  {issue}")
                                total_issues += 1
            
            print(f"\n📊 Итого в {file_path.name}: {total_issues} проблем")
            
            # Специальная проверка для Псалма 3
            if 'Псалтирь' in data:
                print(f"\n🔍 Специальная проверка Псалма 3:")
                if check_and_fix_psalm_3(data):
                    # Сохраняем исправленный файл
                    with open(file_path, 'w', encoding='utf-8') as f:
                        json.dump(data, f, ensure_ascii=False, indent=2)
                    print(f"💾 Файл {file_path.name} обновлен с исправлениями")
        else:
            print(f"❌ Файл не найден: {file_path}")

if __name__ == "__main__":
    main()