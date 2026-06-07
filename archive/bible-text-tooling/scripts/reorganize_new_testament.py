import json
import os
from collections import OrderedDict

# Correct book order according to user specification
CORRECT_ORDER = [
    "Матфея",
    "Марка", 
    "Лука",
    "Иоанна",
    "Деяния",
    "Иакова",
    "Римлянам",
    "1 Петра",
    "2 Петра", 
    "1 Иоанна",
    "2 Иоанна",
    "3 Иоанна",
    "Иуды",
    "1 Коринфянам",
    "2 Коринфянам",
    "Галатам",
    "Ефесянам",
    "Филиппийцам",
    "Колоссянам",
    "1 Фессалоникийцам",
    "2 Фессалоникийцам",
    "1 Тимофею",
    "2 Тимофею",
    "Титу",
    "Филимону",
    "Евреям",
    "Откровение"
]

def reorganize_new_testament():
    # Path to the New Testament JSON file
    file_path = r"c:\Project\Bible\bible_app\assets\bible\new_testament_correct.json"
    
    # Create backup
    backup_path = file_path + ".backup"
    if not os.path.exists(backup_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Created backup: {backup_path}")
    
    # Load the JSON data
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    print(f"Original books found: {list(data.keys())}")
    
    # Create ordered dictionary with correct order
    ordered_data = OrderedDict()
    
    # Add books in correct order
    for book_name in CORRECT_ORDER:
        if book_name in data:
            ordered_data[book_name] = data[book_name]
            print(f"Added book: {book_name}")
        else:
            print(f"Warning: Book '{book_name}' not found in original data")
    
    # Add any remaining books that weren't in the correct order list
    for book_name in data:
        if book_name not in CORRECT_ORDER:
            ordered_data[book_name] = data[book_name]
            print(f"Added additional book: {book_name}")
    
    # Save the reorganized data
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(ordered_data, f, ensure_ascii=False, indent=2)
    
    print("New Testament reorganization completed successfully!")
    print(f"Final book order: {list(ordered_data.keys())}")

if __name__ == "__main__":
    reorganize_new_testament()