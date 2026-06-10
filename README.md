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

## Обновления после RuStore

Первая публикация в RuStore: **1.1.1 (33)**. Дальнейшие релизы — тот же цикл, финальный шаг в [консоли RuStore](https://console.rustore.ru/).

1. Правки в коде, тест на телефоне.
2. Bump `pubspec.yaml` (`version: 1.1.1+N`, **N** строго больше предыдущего).
3. `CHANGELOG.md`, `assets/version/changelog.json`, `release-manifests/latest.json` (+ архив `1.1.1+N/`).
4. `git commit` + `git push`.
5. `cd bible_app` → `flutter build apk --release` (тот же keystore в `android/key.properties`).
6. Консоль → **Приложения → Библия → Загрузить версию** → APK, «Что нового» из CHANGELOG → модерация.

| Не менять | Зачем |
|-----------|--------|
| `ru.februaryidea.bible` | иначе это новое приложение, не обновление |
| upload-keystore | иначе RuStore не примет APK поверх установленной версии |

**Google Drive** (манифест в репозитории) — по желанию, для старых пользователей; `versionCode` и подпись должны совпадать с RuStore. Актуальный канал для пользователей — **RuStore**.

Старый APK с `com.example.bible_app` поверх RuStore-версии **не обновляется** — отдельная установка.

## Подробная документация

Вся инструкция по разработке, эмулятору, обновлениям и RuStore — в **[bible_app/README.md](bible_app/README.md)**.
