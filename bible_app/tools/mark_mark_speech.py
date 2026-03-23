import json
from pathlib import Path


NT_PATH = Path("assets/bible/new_testament_correct.json")


JESUS_RANGES = {
    1: [(15, 15), (17, 17), (25, 25), (38, 38), (44, 44)],
    2: [(5, 5), (8, 11), (14, 14), (17, 17), (19, 22), (25, 28)],
    3: [(3, 5), (11, 12), (23, 29), (33, 35)],
    4: [(3, 9), (11, 20), (21, 25), (26, 29), (30, 32), (34, 35), (39, 40)],
    5: [(8, 8), (19, 19), (30, 30), (34, 34), (36, 36), (39, 39), (41, 41), (43, 43)],
    6: [(4, 4), (10, 11), (31, 31), (37, 38), (50, 50), (56, 56)],
    7: [(6, 23), (27, 27), (29, 29), (34, 34)],
    8: [(12, 12), (15, 15), (17, 21), (27, 27), (29, 29), (31, 31), (33, 38)],
    9: [(1, 1), (12, 13), (16, 16), (19, 19), (23, 23), (25, 25), (29, 29), (31, 31), (35, 35), (37, 37), (39, 41), (42, 50)],
    10: [(3, 3), (5, 9), (11, 12), (14, 15), (18, 19), (21, 21), (23, 25), (27, 27), (29, 31), (32, 34), (36, 36), (38, 39), (42, 45), (48, 49), (51, 52)],
    11: [(2, 3), (14, 14), (17, 17), (22, 25), (29, 33)],
    12: [(9, 11), (15, 17), (24, 27), (29, 31), (34, 35), (37, 40), (43, 44)],
    13: [(2, 2), (5, 37)],
    14: [(6, 9), (13, 15), (18, 18), (20, 21), (22, 25), (27, 28), (30, 30), (32, 32), (34, 34), (36, 38), (41, 42), (48, 49), (62, 62)],
    15: [(2, 2), (34, 34)],
    16: [(15, 18)],
}


GOD_RANGES = {
    1: [(11, 11)],
    9: [(7, 7)],
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
    mark = data.get("Марка")
    if not mark:
        raise RuntimeError("Книга 'Марка' не найдена в new_testament_correct.json")

    jesus_updated, jesus_missing = mark_ranges(mark, JESUS_RANGES, "jesus")
    god_updated, god_missing = mark_ranges(mark, GOD_RANGES, "god")

    NT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Updated Jesus verses: {jesus_updated}")
    print(f"Updated God verses: {god_updated}")
    if jesus_missing or god_missing:
        print("Missing verses:")
        for item in jesus_missing + god_missing:
            print(f" - {item}")


if __name__ == "__main__":
    main()
