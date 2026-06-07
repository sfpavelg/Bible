import json
import os

def fix_2john_book():
    """Fix the content of 2 John book in new_testament_correct.json"""
    
    file_path = r"c:\Project\Bible\bible_app\assets\bible\new_testament_correct.json"
    backup_path = file_path + ".2john_backup"
    
    # Create backup if it doesn't exist
    if not os.path.exists(backup_path):
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        with open(backup_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"Created backup at: {backup_path}")
    
    # Load the JSON data
    with open(file_path, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    # Correct content for 2 John (Второе послание Иоанна)
    correct_2john_content = {
        "1": {
            "1": {"text": "Старец – избранной госпоже и детям ее, которых я люблю по истине, и не только я, но и все, познавшие истину,", "type": "narrative"},
            "2": {"text": "ради истины, которая пребывает в нас и будет с нами вовек.", "type": "narrative"},
            "3": {"text": "Да будет с вами благодать, милость, мир от Бога Отца и от Господа Иисуса Христа, Сына Отчего, в истине и любви.", "type": "narrative"},
            "4": {"text": "Я весьма обрадовался, что нашел из детей твоих, ходящих в истине, как мы получили заповедь от Отца.", "type": "narrative"},
            "5": {"text": "И ныне прошу тебя, госпожа, не как новую заповедь предписывая тебе, но ту, которую имеем от начала, чтобы мы любили друг друга.", "type": "narrative"},
            "6": {"text": "Любовь же состоит в том, чтобы мы поступали по заповедям Его. Это та заповедь, которую вы слышали от начала, чтобы поступали по ней.", "type": "narrative"},
            "7": {"text": "Ибо многие обольстители вошли в мир, не исповедующие Иисуса Христа, пришедшего во плоти: такой [человек] есть обольститель и антихрист.", "type": "narrative"},
            "8": {"text": "Наблюдайте за собою, чтобы нам не потерять того, над чем мы трудились, но чтобы получить полную награду.", "type": "narrative"},
            "9": {"text": "Всякий, преступающий учение Христово и не пребывающий в нем, не имеет Бога; пребывающий в учении Христовом имеет и Отца и Сына.", "type": "narrative"},
            "10": {"text": "Кто приходит к вам и не приносит сего учения, того не принимайте в дом и не приветствуйте его.", "type": "narrative"},
            "11": {"text": "Ибо приветствующий его участвует в злых делах его.", "type": "narrative"},
            "12": {"text": "Многое имею писать вам, но не хочу на бумаге чернилами, а надеюсь прийти к вам и говорить устами к устам, чтобы радость ваша была полна.", "type": "narrative"},
            "13": {"text": "Приветствуют тебя дети сестры твоей избранной. Аминь.", "type": "narrative"}
        }
    }
    
    # Replace the content
    data["2 Иоанна"] = correct_2john_content
    
    # Save the updated data
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print("Successfully fixed 2 John book content!")
    print("2 Иоанна now contains correct content with 1 chapter and 13 verses")

if __name__ == "__main__":
    fix_2john_book()