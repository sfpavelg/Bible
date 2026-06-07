# Библия — мобильное приложение

Flutter-приложение для чтения Священного Писания на русском (Синодальный перевод): поиск, избранное, блокнот, планы чтения, «Стих для вдохновения».

| | |
|---|---|
| **Версия** | 1.1.1+33 |
| **Package (Android)** | `ru.februaryidea.bible` |
| **Платформа** | Android (основная), iOS/Web — в репозитории |
| **Контакты** | februaryidea7@gmail.com |

## Структура репозитория

```
Bible/
├── README.md                 ← этот файл (обзор)
├── bible_app/                ← исходный код Flutter-приложения
│   ├── README.md             ← сборка, эмулятор, релизный pipeline
│   ├── docs/                 ← политика конфиденциальности, RuStore, ТЗ
│   └── assets/bible/         ← актуальные JSON с текстом Библии
└── archive/
    └── bible-text-tooling/   ← архив скриптов подготовки текстов (не для релиза)
```

## Быстрый старт

```bash
cd bible_app
flutter pub get
flutter build apk --release
```

APK: `bible_app/build/app/outputs/flutter-apk/app-release.apk`

Подпись release: `android/key.properties` по образцу `android/key.properties.example` (файл не коммитится).

## Документы для публикации

| Документ | Путь |
|----------|------|
| Политика конфиденциальности (URL для RuStore) | https://github.com/sfpavelg/Bible/blob/main/bible_app/docs/privacy_policy.html |
| Тексты карточки RuStore | [bible_app/docs/rustore-store-listing.md](bible_app/docs/rustore-store-listing.md) |
| История изменений | [bible_app/CHANGELOG.md](bible_app/CHANGELOG.md) |

Политика опубликована в публичном репозитории — для RuStore используйте URL из таблицы выше.

## Подробная документация

Вся инструкция по разработке, эмулятору, обновлениям и RuStore — в **[bible_app/README.md](bible_app/README.md)**.
