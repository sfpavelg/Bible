#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Собирает assets/bible/new_testament_correct.json из .dat файлов репозитория
https://github.com/bibleonline/rst (parsed66) — полный русский синодальный текст.

Локальный assets/backup/bible/full_bible.json обрезан (мало глав у Павла и др.),
поэтому раньше после 1-й главы многих книг НЗ список стихов был пустой.
"""

from __future__ import annotations

import json
import os
import re
import ssl
import urllib.request
from typing import Dict

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(SCRIPT_DIR)

# Номер файла parsed66 (52…78) -> имя в bible_model (порядок как в приложении)
NT_FILE_NUM_TO_APP: Dict[int, str] = {
    52: "Матфея",
    53: "Марка",
    54: "Луки",
    55: "Иоанна",
    56: "Деяния",
    57: "Иакова",
    58: "1 Петра",
    59: "2 Петра",
    60: "1 Иоанна",
    61: "2 Иоанна",
    62: "3 Иоанна",
    63: "Иуды",
    64: "Римлянам",
    65: "1 Коринфянам",
    66: "2 Коринфянам",
    67: "Галатам",
    68: "Ефесянам",
    69: "Филиппийцам",
    70: "Колоссянам",
    71: "1 Фессалоникийцам",
    72: "2 Фессалоникийцам",
    73: "1 Тимофею",
    74: "2 Тимофею",
    75: "Титу",
    76: "Филимону",
    77: "Евреям",
    78: "Откровение",
}

NT_SLUGS: Dict[int, str] = {
    52: "matthew",
    53: "mark",
    54: "luke",
    55: "john",
    56: "acts",
    57: "james",
    58: "1peter",
    59: "2peter",
    60: "1john",
    61: "2john",
    62: "3john",
    63: "jude",
    64: "romans",
    65: "1corinthians",
    66: "2corinthians",
    67: "galatians",
    68: "ephesians",
    69: "philippians",
    70: "colossians",
    71: "1thessalonians",
    72: "2thessalonians",
    73: "1timothy",
    74: "2timothy",
    75: "titus",
    76: "philemon",
    77: "hebrews",
    78: "revelation",
}

BASE_URL = (
    "https://raw.githubusercontent.com/bibleonline/rst/master/parsed66/{num}-{slug}.dat"
)
VERSE_RE = re.compile(r"^#(\d+):(\d+)#(.+)$")


def parse_dat(raw: str) -> dict[str, dict[str, dict]]:
    chapters: dict[str, dict[str, dict]] = {}
    for line in raw.splitlines():
        s = line.strip()
        if not s or s == "#p#":
            continue
        m = VERSE_RE.match(s)
        if not m:
            continue
        ch, vs, txt = m.group(1), m.group(2), m.group(3).strip()
        chapters.setdefault(ch, {})[vs] = {"text": txt, "type": "narrative"}
    return chapters


def annotate_evangelists_gospels(app_name: str, book: dict[str, dict[str, dict]]) -> None:
    """Как в convert_bible.py: слова Христа в Евангелиях для красных букв."""
    if app_name not in ("Матфея", "Марка", "Луки", "Иоанна"):
        return
    jesus_patterns = [
        r"Иисус(?: сказал| отвечал| говорил| учил| возгласил| произнес)",
        r"Он (?:сказал|отвечал|говорил|учил|возгласил|произнес)",
        r"сказал (?:им|им Иисус|ученикам|народу)",
        r"отвечал (?:им|Иисус)",
        r"говорил (?:им|Иисус)",
    ]
    for ch_map in book.values():
        for vd in ch_map.values():
            t = vd.get("text", "")
            if not isinstance(t, str):
                continue
            for pat in jesus_patterns:
                if re.search(pat, t, re.IGNORECASE):
                    vd["type"] = "speech"
                    vd["speaker"] = "jesus"
                    break


def fetch(url: str) -> str:
    ctx = ssl.create_default_context()
    req = urllib.request.Request(url, headers={"User-Agent": "bible_app-rebuild-nt/1.0"})
    with urllib.request.urlopen(req, context=ctx, timeout=120) as r:
        return r.read().decode("utf-8")


def main() -> None:
    dst = os.path.join(ROOT, "assets", "bible", "new_testament_correct.json")
    new_testament: dict[str, dict] = {}

    for num in range(52, 79):
        slug = NT_SLUGS[num]
        app = NT_FILE_NUM_TO_APP[num]
        url = BASE_URL.format(num=num, slug=slug)
        raw = fetch(url)
        book = parse_dat(raw)
        if not book:
            raise SystemExit(f"Пустая книга после разбора: {app} ({url})")
        annotate_evangelists_gospels(app, book)
        new_testament[app] = book

    heb = new_testament["Евреям"]
    assert len(heb) == 13, f"Евреям: ожидается 13 глав, получено {len(heb)}"
    tit = new_testament["Титу"]
    assert len(tit) == 3, f"Титу: ожидается 3 главы, получено {len(tit)}"
    tim = new_testament["1 Тимофею"]
    assert len(tim) == 6, f"1 Тимофею: ожидается 6 глав, получено {len(tim)}"
    rom = new_testament["Римлянам"]
    assert len(rom) == 16, f"Римлянам: ожидается 16 глав, получено {len(rom)}"

    with open(dst, "w", encoding="utf-8") as f:
        json.dump(new_testament, f, ensure_ascii=False, indent=2)

    print(f"OK: {len(new_testament)} книг -> {dst}")


if __name__ == "__main__":
    main()
