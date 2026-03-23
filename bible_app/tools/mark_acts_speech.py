import json
from pathlib import Path


NT_PATH = Path("assets/bible/new_testament_correct.json")


# Консервативная разметка: только прямые слова Господа/Иисуса в тексте Деяний.
JESUS_RANGES = {
    1: [(4, 5), (7, 8)],
    9: [(4, 6), (10, 16)],
    18: [(9, 10)],
    22: [(7, 10), (18, 21)],
    23: [(11, 11)],
    26: [(14, 18)],
}


GOD_RANGES = {
    10: [(13, 16), (19, 20)],
    11: [(7, 10), (12, 12)],
}


def mark_ranges(book_data, ranges_by_chapter, speaker):
    updated = 0
    missing = []
    marked_refs = []
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
                marked_refs.append(f"{chapter_key}:{verse_key}")
    return updated, missing, marked_refs


def main():
    data = json.loads(NT_PATH.read_text(encoding="utf-8"))
    acts = data.get("Деяния")
    if not acts:
        raise RuntimeError("Книга 'Деяния' не найдена в new_testament_correct.json")

    jesus_updated, jesus_missing, jesus_refs = mark_ranges(acts, JESUS_RANGES, "jesus")
    god_updated, god_missing, god_refs = mark_ranges(acts, GOD_RANGES, "god")

    NT_PATH.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")

    print(f"Updated Jesus verses: {jesus_updated}")
    print(f"Updated God verses: {god_updated}")
    print("Jesus refs:", ", ".join(jesus_refs))
    print("God refs:", ", ".join(god_refs))
    if jesus_missing or god_missing:
        print("Missing verses:")
        for item in jesus_missing + god_missing:
            print(f" - {item}")


if __name__ == "__main__":
    main()
