# Слой 3: Данные и ассеты (`assets`)

## Папка `assets/bible` (рабочие файлы приложения)

- `assets/bible/old_testament_correct.json` - основной JSON с текстом Ветхого Завета (используется в `BibleService.loadBibleData()`).
- `assets/bible/new_testament_correct.json` - основной JSON с текстом Нового Завета (используется в `BibleService.loadBibleData()`).

## Папка `assets/backup/bible` (архив и резервные копии)

- `assets/backup/bible/correct_bible.json` - архивный объединенный вариант.
- `assets/backup/bible/full_bible.json` - архивный полный JSON.
- `assets/backup/bible/new_testament_correct.json.backup` - общий backup НЗ.
- `assets/backup/bible/new_testament_correct.json.backup2` - backup НЗ, версия 2.
- `assets/backup/bible/new_testament_correct.json.backup3` - backup НЗ, версия 3.
- `assets/backup/bible/new_testament_correct.json.backup_final` - финальный backup НЗ.
- `assets/backup/bible/new_testament_correct.json.backup_formatting` - backup НЗ для форматирования.
- `assets/backup/bible/new_testament_correct.json.backup_james` - backup НЗ, связанный с правками Иакова.
- `assets/backup/bible/new_testament_correct.json.1peter_backup` - backup НЗ по 1 Петра.
- `assets/backup/bible/new_testament_correct.json.2peter_backup` - backup НЗ по 2 Петра.
- `assets/backup/bible/new_testament_correct.json.1john_backup` - backup НЗ по 1 Иоанна.
- `assets/backup/bible/new_testament_correct.json.2john_backup` - backup НЗ по 2 Иоанна.
- `assets/backup/bible/new_testament_correct.json.3john_backup` - backup НЗ по 3 Иоанна.
- `assets/backup/bible/old_testament_correct.json.backup_final` - финальный backup ВЗ.
- `assets/backup/bible/old_testament_correct.json.backup_formatting` - backup ВЗ для форматирования.
- `assets/backup/bible/old_testament_correct.json.backup_psalm3` - backup ВЗ с правками Псалма 3.
- `assets/backup/bible/old_testament_correct.json.backup_psalm3_proper` - альтернативный backup Псалма 3.
- `assets/backup/bible/old_testament_correct.json.backup_all_psalms` - backup блока Псалмов.

## Примечание по использованию

В `pubspec.yaml` в раздел `assets` добавлены только два рабочих файла (`old_testament_correct.json` и `new_testament_correct.json`), поэтому архив из `assets/backup/bible` в сборку приложения не попадает.
