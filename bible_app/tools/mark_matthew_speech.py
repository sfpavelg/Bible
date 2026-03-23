import json
from pathlib import Path


NT_PATH = Path("assets/bible/new_testament_correct.json")


JESUS_RANGES = {
    3: [(15, 15)],
    4: [(4, 4), (7, 7), (10, 10), (17, 17), (19, 19)],
    5: [(3, 48)],
    6: [(1, 34)],
    7: [(1, 29)],
    8: [(3, 4), (7, 7), (10, 13), (20, 20), (22, 22), (26, 26), (32, 32)],
    9: [(2, 2), (4, 6), (9, 9), (12, 13), (15, 17), (22, 22), (24, 24), (28, 30), (37, 38)],
    10: [(5, 42)],
    11: [(4, 6), (7, 19), (21, 30)],
    12: [(3, 8), (11, 13), (25, 26), (28, 28), (30, 31), (34, 37), (39, 42), (43, 45), (48, 50)],
    13: [(3, 9), (11, 23), (24, 33), (37, 43), (47, 52), (57, 57)],
    14: [(16, 16), (18, 18), (27, 27), (29, 29), (31, 31)],
    15: [(3, 9), (10, 11), (13, 14), (16, 20), (24, 24), (26, 26), (28, 28), (32, 34)],
    16: [(2, 3), (6, 6), (8, 11), (13, 19), (23, 28)],
    17: [(7, 7), (11, 12), (17, 17), (20, 20), (22, 23), (25, 27)],
    18: [(3, 35)],
    19: [(4, 6), (8, 9), (11, 12), (14, 14), (17, 19), (21, 21), (23, 24), (26, 26), (28, 29)],
    20: [(1, 16), (17, 19), (21, 23), (25, 28), (32, 34)],
    21: [(2, 3), (13, 13), (16, 16), (19, 19), (21, 22), (24, 24), (27, 27), (30, 31), (40, 44)],
    22: [(2, 14), (18, 21), (29, 32), (37, 40), (42, 45)],
    23: [(2, 39)],
    24: [(2, 2), (4, 51)],
    25: [(1, 46)],
    26: [(2, 2), (10, 13), (18, 18), (21, 21), (23, 24), (25, 29), (31, 32), (34, 34), (36, 38), (40, 41), (45, 46), (50, 50), (52, 56), (64, 64)],
    27: [(11, 11), (46, 46)],
    28: [(9, 10), (18, 20)],
}


GOD_RANGES = {
    3: [(17, 17)],
    17: [(5, 5)],
}


def mark_ranges(book_data, ranges_by_chapter, speaker):
    updated = 0
    missing = []
    for chapter, ranges in ranges_by_chapter.items():
        chapter_key = str(chapter)
        chapter_data = book_data.get(chapter_key)
        if not chapter_data:
            missing.append(f"{chapter_key}:*")
            continue
        for start, end in ranges:
            for verse in range(start, end + 1):
                verse_key = str(verse)
                verse_data = chapter_data.get(verse_key)
                if not verse_data:
                    missing.append(f"{chapter_key}:{verse_key}")
                    continue
                verse_data["type"] = "speech"
                verse_data["speaker"] = speaker
                updated += 1
    return updated, missing


def main():
    data = json.loads(NT_PATH.read_text(encoding="utf-8"))
    matthew = data.get("Матфея")
    if not matthew:
        raise RuntimeError("Книга 'Матфея' не найдена в new_testament_correct.json")

    jesus_updated, jesus_missing = mark_ranges(matthew, JESUS_RANGES, "jesus")
    god_updated, god_missing = mark_ranges(matthew, GOD_RANGES, "god")

    NT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Готово. Обновлено стихов Иисуса: {jesus_updated}")
    print(f"Готово. Обновлено стихов Бога Отца: {god_updated}")
    if jesus_missing or god_missing:
        print("Отсутствующие стихи (проверь структуру):")
        for item in jesus_missing + god_missing:
            print(f" - {item}")


if __name__ == "__main__":
    main()
