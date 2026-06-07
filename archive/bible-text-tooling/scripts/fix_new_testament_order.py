#!/usr/bin/env python3
"""
Скрипт для исправления порядка книг Нового Завета в JSON файле
Приводит порядок в соответствие с моделью приложения
"""

import json
from collections import OrderedDict

# Пути к файлам
NEW_TESTAMENT_PATH = r"bible_app/assets/bible/new_testament_correct.json"
BACKUP_PATH = r"bible_app/assets/bible/new_testament_correct.json.backup_order"

# Правильный порядок книг Нового Завета (как в модели приложения)
CORRECT_ORDER = [
    "Матфея", "Марка", "Лука", "Иоанна", "Деяния",
    "Римлянам", "1 Коринфянам", "2 Коринфянам", "Галатам", "Ефесянам",
    "Филиппийцам", "Колоссянам", "1 Фессалоникийцам", "2 Фессалоникийцам",
    "1 Тимофею", "2 Тимофею", "Титу", "Филимону", "Евреям",
    "Откровение"
]

def load_json_file(file_path):
    """Загружает JSON файл"""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            return json.load(f, object_pairs_hook=OrderedDict)
    except Exception as e:
        print(f"❌ Ошибка загрузки файла {file_path}: {e}")
        return None

def save_json_file(file_path, data):
    """Сохраняет JSON файл"""
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        return True
    except Exception as e:
        print(f"❌ Ошибка сохранения файла {file_path}: {e}")
        return False

def create_backup():
    """Создает резервную копию файла"""
    import shutil
    try:
        shutil.copy2(NEW_TESTAMENT_PATH, BACKUP_PATH)
        print(f"✅ Резервная копия создана: {BACKUP_PATH}")
        return True
    except Exception as e:
        print(f"❌ Ошибка создания резервной копии: {e}")
        return False

def fix_new_testament_order():
    """Исправляет порядок книг Нового Завета"""
    
    print("🔧 ИСПРАВЛЕНИЕ ПОРЯДКА КНИГ НОВОГО ЗАВЕТА")
    print("=" * 50)
    
    # Создаем резервную копию
    if not create_backup():
        return
    
    # Загружаем текущий файл
    current_data = load_json_file(NEW_TESTAMENT_PATH)
    if not current_data:
        return
    
    print(f"📚 Текущее количество книг: {len(current_data)}")
    
    # Создаем новый упорядоченный словарь
    fixed_data = OrderedDict()
    
    # Добавляем книги в правильном порядке
    books_added = 0
    books_missing = []
    
    for book_name in CORRECT_ORDER:
        if book_name in current_data:
            fixed_data[book_name] = current_data[book_name]
            books_added += 1
            print(f"✅ Добавлена: {book_name}")
        else:
            books_missing.append(book_name)
            print(f"❌ Книга отсутствует: {book_name}")
    
    # Добавляем остальные книги (которые не входят в основной порядок)
    extra_books = 0
    for book_name, book_data in current_data.items():
        if book_name not in CORRECT_ORDER:
            fixed_data[book_name] = book_data
            extra_books += 1
            print(f"📖 Дополнительная книга: {book_name}")
    
    # Сохраняем исправленный файл
    if save_json_file(NEW_TESTAMENT_PATH, fixed_data):
        print(f"\n🎉 ПОРЯДОК ИСПРАВЛЕН!")
        print(f"📊 Книг в правильном порядке: {books_added}")
        print(f"📊 Дополнительных книг: {extra_books}")
        if books_missing:
            print(f"⚠️  Отсутствующие книги: {books_missing}")
        print(f"💾 Файл обновлен: {NEW_TESTAMENT_PATH}")
        print(f"📦 Резервная копия: {BACKUP_PATH}")
    else:
        print("❌ Не удалось сохранить исправленный файл")

if __name__ == "__main__":
    fix_new_testament_order()