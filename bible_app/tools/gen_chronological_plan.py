# -*- coding: utf-8 -*-
"""Генерирует lib/journal/chronological_reading_plan_data.dart из tools/chronological_plan_input.txt"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
INPUT = ROOT / "tools" / "chronological_plan_input.txt"
OUT = ROOT / "lib" / "journal" / "chronological_reading_plan_data.dart"

LINE_RE = re.compile(r"^\s*(\d+)\s+(.+?)\s*$")


def split_lines(content: str) -> list[str]:
    parts = re.split(r"\s*;\s*", content.strip())
    return [p.strip() for p in parts if p.strip()] or ["—"]


def parse_days(raw: str) -> list[list[str]]:
    by_num: dict[int, str] = {}
    for line in raw.splitlines():
        line = line.strip()
        if not line:
            continue
        m = LINE_RE.match(line)
        if not m:
            print("строка не распознана:", repr(line), file=sys.stderr)
            sys.exit(1)
        n = int(m.group(1))
        text = m.group(2)
        if n in by_num:
            print("дубликат дня", n, file=sys.stderr)
            sys.exit(1)
        by_num[n] = text
    missing = [i for i in range(1, 366) if i not in by_num]
    if missing:
        print("нет дней:", missing[:20], "...", file=sys.stderr)
        sys.exit(1)
    return [split_lines(by_num[i]) for i in range(1, 366)]


def main() -> None:
    if not INPUT.exists():
        print("Нет файла", INPUT, file=sys.stderr)
        sys.exit(1)
    raw = INPUT.read_text(encoding="utf-8")
    days = parse_days(raw)
    if len(days) != 365:
        print(f"ожидалось 365 дней, получено {len(days)}", file=sys.stderr)
        sys.exit(1)

    lines_out = [
        "// Автогенерация: python tools/gen_chronological_plan.py",
        "// Хронологический план чтения (порядковые дни 1…365).",
        "",
        "class ChronologicalPlanDay {",
        "  const ChronologicalPlanDay(this.lines);",
        "  final List<String> lines;",
        "}",
        "",
        "const List<ChronologicalPlanDay> kChronologicalReadingPlan365 = [",
    ]
    for d in days:
        esc = []
        for s in d:
            e = s.replace("\\", "\\\\").replace("'", "\\'")
            esc.append(f"'{e}'")
        lines_out.append(f"  ChronologicalPlanDay([{', '.join(esc)}]),")
    lines_out.append("];")
    lines_out.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines_out), encoding="utf-8")
    print("OK", OUT, "days=", len(days))


if __name__ == "__main__":
    main()
