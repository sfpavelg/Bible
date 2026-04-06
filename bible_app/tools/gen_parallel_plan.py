# -*- coding: utf-8 -*-
"""Генерирует lib/journal/parallel_reading_plan_data.dart из tools/parallel_plan_input.txt"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
INPUT = ROOT / "tools" / "parallel_plan_input.txt"
OUT = ROOT / "lib" / "journal" / "parallel_reading_plan_data.dart"

MONTHS = (
    "ЯНВАРЯ|ФЕВРАЛЯ|МАРТА|АПРЕЛЯ|МАЯ|ИЮНЯ|ИЮЛЯ|АВГУСТА|"
    "СЕНТЯБРЯ|ОКТЯБРЯ|НОЯБРЯ|ДЕКАБРЯ"
)
LINE_HDR = re.compile(rf"^(\d{{1,2}})\s+({MONTHS})\b\s*", re.M)

REPL = [
    (r"1-е\s+", "1 "),
    (r"2-е\s+", "2 "),
    (r"3-е\s+", "3 "),
    (r"1-я\s+Царств", "1 Царств"),
    (r"2-я\s+Царств", "2 Царств"),
    (r"3-я\s+Царств", "3 Царств"),
    (r"4-я\s+Царств", "4 Царств"),
    (r"1-я\s+Паралипоменон", "1 Паралипоменон"),
    (r"2-я\s+Паралипоменон", "2 Паралипоменон"),
    (r"От\s+Матфея", "Матфея"),
    (r"От\s+Марка", "Марка"),
    (r"От\s+Луки", "Луки"),
    (r"К\s+Титу", "Титу"),
    (r"К\s+Филимону", "Филимону"),
    (r"Даниила", "Даниил"),
]


def normalize_line(s: str) -> str:
    s = s.strip()
    for pat, rep in REPL:
        s = re.sub(pat, rep, s, flags=re.I)
    s = re.sub(r"Откровение\s+21-2\b", "Откровение 21-22", s)
    return s


def parse_days(raw: str) -> list[list[str]]:
    headers = list(LINE_HDR.finditer(raw))
    days: list[list[str]] = []
    for j, m in enumerate(headers):
        start = m.end()
        end = headers[j + 1].start() if j + 1 < len(headers) else len(raw)
        chunk = raw[start:end].strip()
        lines = [normalize_line(x) for x in chunk.splitlines() if x.strip()]
        if not lines:
            lines = ["—"]
        days.append(lines)
    return days


def main() -> None:
    if not INPUT.exists():
        print("Нет файла", INPUT, file=sys.stderr)
        sys.exit(1)
    raw = INPUT.read_text(encoding="utf-8")
    days = parse_days(raw)
    if len(days) != 365:
        print(f"ожидалось 365 дней, распознано {len(days)}", file=sys.stderr)
        sys.exit(1)

    lines_out = [
        "// Автогенерация: python tools/gen_parallel_plan.py",
        "// План параллельного чтения (порядковые дни 1…365, не календарь).",
        "",
        "class ParallelPlanDay {",
        "  const ParallelPlanDay(this.lines);",
        "  final List<String> lines;",
        "}",
        "",
        "const List<ParallelPlanDay> kParallelReadingPlan365 = [",
    ]
    for d in days:
        esc = []
        for s in d:
            e = s.replace("\\", "\\\\").replace("'", "\\'")
            esc.append(f"'{e}'")
        lines_out.append(f"  ParallelPlanDay([{', '.join(esc)}]),")
    lines_out.append("];")
    lines_out.append("")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text("\n".join(lines_out), encoding="utf-8")
    print("OK", OUT, "days=", len(days))


if __name__ == "__main__":
    main()
