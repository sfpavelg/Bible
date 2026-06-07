#!/usr/bin/env python3
"""
Ручное исправление порядка книг Нового Завета
Исправляет ошибку в RST переводе
"""

import json
import os
from collections import OrderedDict

# Пути к файлам
NEW_TESTAMENT_PATH = r"bible_app/assets/bible/new_testament_correct.json"
BACKUP_PATH = r"bible_app/assets/bible/new_testament_correct.json.backup3"

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

def manual_reorder_books():
    """Вручную исправляет порядок книг"""
    
    print("🔧 РУЧНОЕ ИСПРАВЛЕНИЕ ПОРЯДКА КНИГ")
    print("=" * 50)
    
    # Загружаем текущий файл
    current_data = load_json_file(NEW_TESTAMENT_PATH)
    if not current_data:
        return None
    
    # Правильный порядок книг с соответствующими текстами
    correct_order = OrderedDict()
    
    # 1. Римлянам (должен быть первым из посланий Павла)
    correct_order["Римлянам"] = current_data["Римлянам"]
    print("✅ Римлянам: установлен правильный текст")
    
    # 2. 1 Коринфянам
    correct_order["1 Коринфянам"] = current_data["1 Коринфянам"]
    print("✅ 1 Коринфянам: установлен правильный текст")
    
    # 3. 2 Коринфянам  
    correct_order["2 Коринфянам"] = current_data["2 Коринфянам"]
    print("✅ 2 Коринфянам: установлен правильный текст")
    
    # 4. Галатам
    correct_order["Галатам"] = current_data["Галатам"]
    print("✅ Галатам: установлен правильный текст")
    
    # 5. Ефесянам
    correct_order["Ефесянам"] = current_data["Ефесянам"]
    print("✅ Ефесянам: установлен правильный текст")
    
    # 6. Филиппийцам
    correct_order["Филиппийцам"] = current_data["Филиппийцам"]
    print("✅ Филиппийцам: установлен правильный текст")
    
    # 7. Колоссянам
    correct_order["Колоссянам"] = current_data["Колоссянам"]
    print("✅ Колоссянам: установлен правильный текст")
    
    # 8. 1 Фессалоникийцам - ЭТО ВАЖНО! Сейчас здесь неправильный текст
    # Берем текст из текущей "Иакова" (которая на самом деле 1 Фессалоникийцам)
    correct_order["1 Фессалоникийцам"] = current_data["Иакова"]
    print("✅ 1 Фессалоникийцам: исправлен текст (взят из 'Иакова')")
    
    # 9. 2 Фессалоникийцам
    correct_order["2 Фессалоникийцам"] = current_data["2 Фессалоникийцам"]
    print("✅ 2 Фессалоникийцам: установлен правильный текст")
    
    # 10. 1 Тимофею
    correct_order["1 Тимофею"] = current_data["1 Тимофею"]
    print("✅ 1 Тимофею: установлен правильный текст")
    
    # 11. 2 Тимофею
    correct_order["2 Тимофею"] = current_data["2 Тимофею"]
    print("✅ 2 Тимофею: установлен правильный текст")
    
    # 12. Титу
    correct_order["Титу"] = current_data["Титу"]
    print("✅ Титу: установлен правильный текст")
    
    # 13. Филимону
    correct_order["Филимону"] = current_data["Филимону"]
    print("✅ Филимону: установлен правильный текст")
    
    # 14. Евреям
    correct_order["Евреям"] = current_data["Евреям"]
    print("✅ Евреям: установлен правильный текст")
    
    # 15. Иакова - ЭТО ВАЖНО! Сейчас здесь неправильный текст  
    # Берем текст из текущего "1 Фессалоникийцам" (которое на самом деле Иакова)
    correct_order["Иакова"] = current_data["1 Фессалоникийцам"]
    print("✅ Иакова: исправлен текст (взят из '1 Фессалоникийцам')")
    
    # 16. 1 Петра
    correct_order["1 Петра"] = current_data["1 Петра"]
    print("✅ 1 Петра: установлен правильный текст")
    
    # 17. 2 Петра
    correct_order["2 Петра"] = current_data["2 Петра"]
    print("✅ 2 Петра: установлен правильный текст")
    
    # 18. 1 Иоанна
    correct_order["1 Иоанна"] = current_data["1 Иоанна"]
    print("✅ 1 Иоанна: установлен правильный текст")
    
    # 19. 2 Иоанна
    correct_order["2 Иоанна"] = current_data["2 Иоанна"]
    print("✅ 2 Иоанна: установлен правильный текст")
    
    # 20. 3 Иоанна
    correct_order["3 Иоанна"] = current_data["3 Иоанна"]
    print("✅ 3 Иоанна: установлен правильный текст")
    
    # 21. Иуды
    correct_order["Иуды"] = current_data["Иуды"]
    print("✅ Иуды: установлен правильный текст")
    
    # 22. Откровение
    correct_order["Откровение"] = current_data["Откровение"]
    print("✅ Откровение: установлен правильный текст")
    
    # Добавляем остальные книги (Евангелия и Деяния) в правильном порядке
    other_books = ["Матфея", "Марка", "Луки", "Иоанна", "Деяния"]
    for book in other_books:
        if book in current_data:
            correct_order[book] = current_data[book]
            print(f"✅ {book}: установлен правильный текст")
    
    # Переупорядочиваем словарь чтобы Евангелия были первыми
    final_order = OrderedDict()
    for book in ["Матфея", "Марка", "Луки", "Иоанна", "Деяния"]:
        if book in correct_order:
            final_order[book] = correct_order[book]
    
    # Добавляем остальные книги
    for book, data in correct_order.items():
        if book not in final_order:
            final_order[book] = data
    
    return final_order

def verify_correction(corrected_data):
    """Проверяет корректность исправления"""
    
    print("\n🔍 ПРОВЕРКА ИСПРАВЛЕНИЙ")
    print("=" * 30)
    
    # Ключевые книги для проверки
    key_books = {
        "Иакова": "Иаков, раб Бога и Господа Иисуса Христа",
        "Римлянам": "Павел, раб Иисуса Христа, призванный Апостол", 
        "1 Фессалоникийцам": "Павел и Силуан и Тимофей"
    }
    
    for book_name, expected_start in key_books.items():
        if book_name in corrected_data:
            book_data = corrected_data[book_name]
            if "1" in book_data and "1" in book_data["1"]:
                first_verse = book_data["1"]["1"]["text"]
                if expected_start in first_verse:
                    print(f"✅✅ {book_name}: КОРРЕКТНЫЙ ТЕКСТ!")
                    print(f"   {first_verse[:80]}...")
                else:
                    print(f"❌ {book_name}: НЕПРАВИЛЬНЫЙ ТЕКСТ!")
                    print(f"   Начинается с: {first_verse[:80]}...")
                    print(f"   Ожидалось: {expected_start}...")
            else:
                print(f"❌ {book_name}: повреждена структура")
        else:
            print(f"❌ {book_name}: не найдена")

def main():
    """Основная функция"""
    
    print("🎯 РУЧНОЕ ИСПРАВЛЕНИЕ ПОРЯДКА КНИГ НОВОГО ЗАВЕТА")
    print("=" * 60)
    
    # Исправляем порядок книг
    corrected_data = manual_reorder_books()
    if not corrected_data:
        return
    
    # Проверяем корректность
    verify_correction(corrected_data)
    
    # Сохраняем результат
    if save_json_file(NEW_TESTAMENT_PATH, corrected_data):
        print(f"\n🎉 ПОРЯДОК КНИГ ИСПРАВЛЕН!")
        print(f"📊 Книг обработано: {len(corrected_data)}")
        print(f"💾 Backup создан: {BACKUP_PATH}")
        print(f"📁 Файл обновлен: {NEW_TESTAMENT_PATH}")

if __name__ == "__main__":
    main()