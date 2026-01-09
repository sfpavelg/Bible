import json
import os

def fix_3john_book():
    """Fix the content of 3 John book in new_testament_correct.json"""
    
    file_path = r"c:\Project\Bible\bible_app\assets\bible\new_testament_correct.json"
    backup_path = file_path + ".3john_backup"
    
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
    
    # Correct content for 3 John (Третье послание Иоанна)
    correct_3john_content = {
        "1": {
            "1": {"text": "Старец – возлюбленному Гаию, которого я люблю по истине.", "type": "narrative"},
            "2": {"text": "Возлюбленный! молюсь, чтобы ты здравствовал и преуспевал во всем, как преуспевает душа твоя.", "type": "narrative"},
            "3": {"text": "Ибо я весьма обрадовался, когда пришли братия и засвидетельствовали о твоей верности, как ты ходишь в истине.", "type": "narrative"},
            "4": {"text": "Для меня нет большей радости, как слышать, что дети мои ходят в истине.", "type": "narrative"},
            "5": {"text": "Возлюбленный! ты как верный поступаешь в том, что делаешь для братьев и для странников.", "type": "narrative"},
            "6": {"text": "Они засвидетельствовали перед церковью о твоей любви. Ты хорошо поступишь, если отпустишь их, как должно ради Бога,", "type": "narrative"},
            "7": {"text": "ибо они ради имени Его пошли, не взяв ничего от язычников.", "type": "narrative"},
            "8": {"text": "Итак мы должны принимать таковых, чтобы сделаться споспешниками истины.", "type": "narrative"},
            "9": {"text": "Я писал церкви; но Диотреф, любящий между ними первенствовать, не принимает нас.", "type": "narrative"},
            "10": {"text": "Посему, если я приду, то напомню о делах, которые он делает, понося нас злыми словами, и не довольствуясь тем, и сам не принимает братьев, и запрещает желающим, и изгоняет из церкви.", "type": "narrative"},
            "11": {"text": "Возлюбленный! не подражай злу, но добру. Кто делает добро, тот от Бога; а кто делает зло, тот не видел Бога.", "type": "narrative"},
            "12": {"text": "О Димитрии засвидетельствовано всеми и самою истиною; свидетельствуем также и мы, и вы знаете, что свидетельство наше истинно.", "type": "narrative"},
            "13": {"text": "Многое имел я писать; но не хочу писать к тебе чернилами и тростью,", "type": "narrative"},
            "14": {"text": "а надеюсь скоро увидеть тебя, и поговорим устами к устам.", "type": "narrative"},
            "15": {"text": "Мир тебе. Приветствуют тебя друзья; приветствуй друзей поименно. Аминь.", "type": "narrative"}
        }
    }
    
    # Replace the content
    data["3 Иоанна"] = correct_3john_content
    
    # Save the updated data
    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    
    print("Successfully fixed 3 John book content!")
    print("3 Иоанна now contains correct content with 1 chapter and 15 verses")

if __name__ == "__main__":
    fix_3john_book()