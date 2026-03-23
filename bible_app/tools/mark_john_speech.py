import json
from pathlib import Path


NT_PATH = Path("assets/bible/new_testament_correct.json")


JESUS_RANGES = {
    1: [(38, 39), (42, 42), (43, 43), (47, 51)],
    2: [(4, 4), (7, 8), (16, 16), (19, 19)],
    3: [(3, 8), (10, 10), (12, 12), (14, 21), (27, 27)],
    4: [(7, 7), (10, 10), (13, 14), (16, 18), (21, 26), (32, 32), (34, 34), (35, 38), (48, 53)],
    5: [(6, 8), (14, 14), (17, 47)],
    6: [(5, 5), (10, 13), (20, 20), (26, 27), (29, 29), (32, 33), (35, 35), (37, 40), (43, 44), (47, 47), (50, 58), (61, 65), (67, 70)],
    7: [(6, 8), (16, 19), (21, 24), (28, 29), (33, 34), (37, 38)],
    8: [(7, 11), (14, 19), (21, 24), (26, 29), (31, 32), (34, 38), (42, 47), (49, 51), (54, 58)],
    9: [(3, 5), (7, 7), (35, 41)],
    10: [(1, 18), (25, 30), (32, 38)],
    11: [(4, 4), (9, 15), (23, 26), (34, 34), (39, 40), (41, 42)],
    12: [(7, 8), (23, 28), (30, 32), (35, 36), (44, 50)],
    13: [(7, 11), (16, 20), (21, 21), (26, 27), (31, 32), (33, 33), (36, 38)],
    14: [(1, 31)],
    15: [(1, 27)],
    16: [(1, 33)],
    17: [(1, 26)],
    18: [(4, 8), (11, 11), (20, 21), (23, 23), (34, 34), (36, 37)],
    19: [(11, 11), (26, 27), (28, 28), (30, 30)],
    20: [(15, 17), (19, 23), (26, 29)],
    21: [(5, 7), (10, 10), (12, 12), (15, 19), (22, 23)],
}


GOD_RANGES = {
    12: [(28, 28)],
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
    john = data.get("Иоанна")
    if not john:
        raise RuntimeError("Книга 'Иоанна' не найдена в new_testament_correct.json")

    jesus_updated, jesus_missing = mark_ranges(john, JESUS_RANGES, "jesus")
    god_updated, god_missing = mark_ranges(john, GOD_RANGES, "god")

    NT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Updated Jesus verses: {jesus_updated}")
    print(f"Updated God verses: {god_updated}")
    if jesus_missing or god_missing:
        print("Missing verses:")
        for item in jesus_missing + god_missing:
            print(f" - {item}")


if __name__ == "__main__":
    main()
