#!/usr/bin/env python3
"""
Детальная проверка всех глав и стихов на ошибки разбивки
"""

import json
import re
from pathlib import Path

def check_all_books(file_path):
    """Проверяет все книги в файле на ошибки разбивки стихов"""
    print(f"\n🔍 Детальная проверка файла: {file_path.name}")
    print("=" * 60)
    
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    total_issues = 0
    books_with_issues = 0
    
    for book_name, book_data in data.items():
        book_issues = 0
        print(f"\n📖 Книга: {book_name}")
        
        for chapter_num, chapter_data in book_data.items():
            if chapter_num.isdigit():
                chapter_issues = []
                
                # Проверяем нумерацию стихов
                verse_numbers = sorted([int(k) for k in chapter_data.keys() if k.isdigit()])
                if verse_numbers:
                    expected_numbers = list(range(1, len(verse_numbers) + 1))
                    
                    if verse_numbers != expected_numbers:
                        chapter_issues.append(f"Неправильная нумерация: {verse_numbers}")
                
                # Проверяем наличие дублированных номеров в тексте
                for verse_num, verse_data in chapter_data.items():
                    if verse_num.isdigit():
                        text = verse_data.get('text', '')
                        
                        # Ищем паттерны типа (X:Y) в тексте
                        verse_refs = re.findall(r'\(\d+:\d+\)', text)
                        if verse_refs:
                            chapter_issues.append(f"Стих {verse_num}: содержит {verse_refs}")
                        
                        # Проверяем, содержит ли стих текст другого стиха
                        if re.search(r'\d+:\d+', text) and not verse_refs:
                            chapter_issues.append(f"Стих {verse_num}: возможное слияние стихов")
                
                if chapter_issues:
                    print(f"   Глава {chapter_num}: обнаружены проблемы:")
                    for issue in chapter_issues:
                        print(f"     ⚠️  {issue}")
                        book_issues += 1
                        total_issues += 1
        
        if book_issues > 0:
            books_with_issues += 1
            print(f"   📊 Всего проблем в книге: {book_issues}")
    
    print(f"\n📊 Итоги по файлу {file_path.name}:")
    print(f"   • Всего книг: {len(data)}")
    print(f"   • Книг с проблемами: {books_with_issues}")
    print(f"   • Всего проблем: {total_issues}")
    
    return total_issues

def main():
    print("🔍 Детальная проверка всех глав и стихов на ошибки")
    print("=" * 60)
    
    # Пути к файлам
    old_testament_path = Path("bible_app/assets/bible/old_testament_correct.json")
    new_testament_path = Path("bible_app/assets/bible/new_testament_correct.json")
    
    total_issues = 0
    
    for file_path in [old_testament_path, new_testament_path]:
        if file_path.exists():
            issues = check_all_books(file_path)
            total_issues += issues
        else:
            print(f"❌ Файл не найден: {file_path}")
    
    print(f"\n🎯 ОБЩИЙ ИТОГ: Всего обнаружено проблем: {total_issues}")
    
    if total_issues == 0:
        print("✅ Отлично! Все стихи проверены, ошибок не найдено!")
    else:
        print("⚠️  Обнаружены проблемы, требующие исправления")

if __name__ == "__main__":
    main()