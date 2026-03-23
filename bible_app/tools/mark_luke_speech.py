import json
from pathlib import Path


NT_PATH = Path("assets/bible/new_testament_correct.json")


JESUS_RANGES = {
    2: [(49, 49)],
    4: [(4, 4), (8, 8), (12, 12), (18, 27), (35, 35), (43, 43)],
    5: [(4, 4), (10, 10), (13, 13), (20, 24), (27, 27), (31, 32), (34, 35), (36, 39)],
    6: [(3, 5), (9, 9), (20, 49)],
    7: [(9, 9), (13, 15), (22, 23), (28, 28), (31, 35), (40, 47), (50, 50)],
    8: [(8, 8), (10, 18), (21, 21), (25, 25), (45, 46), (48, 48), (50, 50), (52, 56)],
    9: [(3, 5), (13, 13), (20, 20), (22, 27), (35, 35), (41, 41), (44, 45), (48, 50), (55, 56), (58, 62)],
    10: [(2, 2), (3, 16), (18, 24), (26, 28), (30, 37), (41, 42)],
    11: [(2, 13), (17, 23), (29, 32), (34, 36), (39, 52)],
    12: [(4, 12), (14, 15), (20, 21), (22, 59)],
    13: [(2, 5), (7, 9), (11, 12), (15, 16), (18, 21), (24, 35)],
    14: [(3, 5), (11, 11), (13, 14), (16, 35)],
    15: [(4, 32)],
    16: [(1, 13), (15, 18), (19, 31)],
    17: [(1, 10), (14, 14), (17, 37)],
    18: [(1, 8), (16, 17), (19, 22), (24, 25), (27, 27), (29, 30), (31, 34), (40, 42)],
    19: [(5, 5), (9, 10), (12, 27), (40, 40), (42, 44), (46, 46)],
    20: [(3, 8), (17, 18), (24, 25), (34, 38), (41, 44)],
    21: [(8, 36)],
    22: [(10, 12), (15, 20), (22, 22), (25, 27), (31, 32), (34, 34), (37, 38), (40, 42), (46, 46), (48, 48), (51, 51), (67, 70)],
    23: [(3, 3), (28, 31), (34, 34), (43, 43), (46, 46)],
    24: [(17, 19), (25, 27), (32, 32), (36, 49)],
}


GOD_RANGES = {
    3: [(22, 22)],
    9: [(35, 35)],
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
    luke = data.get("Лука")
    if not luke:
        raise RuntimeError("Книга 'Лука' не найдена в new_testament_correct.json")

    jesus_updated, jesus_missing = mark_ranges(luke, JESUS_RANGES, "jesus")
    god_updated, god_missing = mark_ranges(luke, GOD_RANGES, "god")

    NT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Updated Jesus verses: {jesus_updated}")
    print(f"Updated God verses: {god_updated}")
    if jesus_missing or god_missing:
        print("Missing verses:")
        for item in jesus_missing + god_missing:
            print(f" - {item}")


if __name__ == "__main__":
    main()
