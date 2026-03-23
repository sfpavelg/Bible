import json
import os
import re

# Карта соответствия сокращений полным названиям книг
BOOK_NAME_MAP = {
    "Быт.": "Бытие",
    "Исх.": "Исход", 
    "Лев.": "Левит",
    "Чис.": "Числа",
    "Втор.": "Второзаконие",
    "Ис.Нав.": "Иисус Навин",
    "Суд.": "Судьи",
    "Руфь": "Руфь",
    "1Цар.": "1 Царств",
    "2Цар.": "2 Царств",
    "3Цар.": "3 Царств", 
    "4Цар.": "4 Царств",
    "1Пар.": "1 Паралипоменон",
    "2Пар.": "2 Паралипоменон",
    "Ездр.": "Ездра",
    "Неем.": "Неемия",
    "Есф.": "Есфирь",
    "Иов": "Иов",
    "Пс.": "Псалтирь",
    "Прит.": "Притчи",
    "Еккл.": "Екклесиаст",
    "П.Песн.": "Песня Песней",
    "Ис.": "Исаия",
    "Иер.": "Иеремия",
    "Плач": "Плач Иеремии",
    "Иез.": "Иезекииль",
    "Дан.": "Даниил",
    "Ос.": "Осия",
    "Иоил.": "Иоиль",
    "Ам.": "Амос",
    "Авд.": "Авдий",
    "Ион.": "Иона",
    "Мих.": "Михей",
    "Наум": "Наум",
    "Авв.": "Аввакум",
    "Соф.": "Софония",
    "Агг.": "Аггей",
    "Зах.": "Захария",
    "Мал.": "Малахия",
    "Мф.": "Матфея",
    "Мк.": "Марка",
    "Лк.": "Луки",
    "Ин.": "Иоанна",
    "Деян.": "Деяния",
    "Иак.": "Иакова",
    "1Пет.": "1 Петра",
    "2Пет.": "2 Петра",
    "1Ин.": "1 Иоанна",
    "2Ин.": "2 Иоанна",
    "3Ин.": "3 Иоанна",
    "Иуд.": "Иуды",
    "Рим.": "Римлянам",
    "1Кор.": "1 Коринфянам",
    "2Кор.": "2 Коринфянам",
    "Гал.": "Галатам",
    "Еф.": "Ефесянам",
    "Флп.": "Филиппийцам",
    "Кол.": "Колоссянам",
    "1Фес.": "1 Фессалоникийцам",
    "2Фес.": "2 Фессалоникийцам",
    "1Тим.": "1 Тимофею",
    "2Тим.": "2 Тимофею",
    "Тит.": "Титу",
    "Флм.": "Филимону",
    "Евр.": "Евреям",
    "Откр.": "Откровение"
}

def convert_bible_format():
    # Читаем исходный файл
    with open('assets/backup/bible/full_bible.json', 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Создаем новую структуру
    old_testament = {}
    new_testament = {}
    
    # Определяем какие книги к какому завету относятся
    old_testament_books = list(BOOK_NAME_MAP.values())[:39]  # Первые 39 книг - Ветхий Завет
    
    for book in data['Books']:
        book_name_short = book['BookName']
        full_name = BOOK_NAME_MAP.get(book_name_short, book_name_short)
        
        # Создаем структуру для книги
        book_data = {}
        
        for chapter in book['Chapters']:
            chapter_num = chapter['ChapterId']
            verses_data = {}
            
            for verse in chapter['Verses']:
                verse_num = verse['VerseId']
                verse_text = verse['Text']
                
                # Анализируем стих для определения типа контента
                verse_info = analyze_verse_text(full_name, chapter_num, verse_num, verse_text)
                verses_data[str(verse_num)] = verse_info
            
            book_data[str(chapter_num)] = verses_data
        
        # Определяем к какому завету относится книга
        if book_name_short in old_testament_books:
            old_testament[full_name] = book_data
        else:
            new_testament[full_name] = book_data
    
    # Сохраняем Ветхий Завет
    with open('assets/backup/bible/old_testament_full.json', 'w', encoding='utf-8') as f:
        json.dump(old_testament, f, ensure_ascii=False, indent=2)
    
    # Сохраняем Новый Завет  
    with open('assets/backup/bible/new_testament_full.json', 'w', encoding='utf-8') as f:
        json.dump(new_testament, f, ensure_ascii=False, indent=2)
    
    print("Конвертация завершена!")
    print(f"Ветхий Завет: {len(old_testament)} книг")
    print(f"Новый Завет: {len(new_testament)} книг")

def analyze_verse_text(book_name, chapter_num, verse_num, text):
    """Анализирует текст стиха и определяет тип контента и говорящего"""
    
    # Для Нового Завета - определяем слова Иисуса
    if book_name in ["Матфея", "Марка", "Луки", "Иоанна"]:
        # Паттерны для определения слов Иисуса
        jesus_patterns = [
            r'Иисус(?: сказал| отвечал| говорил| учил| возгласил| произнес)',
            r'Он (?:сказал|отвечал|говорил|учил|возгласил|произнес)',
            r'сказал (?:им|им Иисус|ученикам|народу)',
            r'отвечал (?:им|Иисус)',
            r'говорил (?:им|Иисус)',
        ]
        
        for pattern in jesus_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return {
                    "text": text,
                    "type": "speech",
                    "speaker": "jesus"
                }
    
    # Для Ветхого Завета - определяем слова Бога
    elif book_name in ["Бытие", "Исход", "Левит", "Числа", "Второзаконие", 
                     "Иисус Навин", "Судьи", "1 Царств", "2 Царств", "3 Царств", "4 Царств",
                     "Исаия", "Иеремия", "Иезекииль", "Даниил", "Осия", "Иоиль", "Амос",
                     "Авдий", "Иона", "Михей", "Наум", "Аввакум", "Софония", "Аггей",
                     "Захария", "Малахия"]:
        
        # Паттерны для определения слов Бога
        god_patterns = [
            r'Господь (?:сказал|говорил|воззвал|повелел)',
            r'Бог (?:сказал|говорил|воззвал|повелел)',
            r'сказал Господь',
            r'говорил Господь',
            r'так говорит Господь',
            r'слово Господне',
        ]
        
        for pattern in god_patterns:
            if re.search(pattern, text, re.IGNORECASE):
                return {
                    "text": text,
                    "type": "speech", 
                    "speaker": "god"
                }
    
    # По умолчанию - повествовательный текст
    return {
        "text": text,
        "type": "narrative"
    }

if __name__ == "__main__":
    convert_bible_format()