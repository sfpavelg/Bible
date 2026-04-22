# Changelog

All notable changes to this project are documented in this file.

## 1.1.1+4 - 2026-04-24

- Техподдержка при доступном обновлении: сначала строка о версии и кнопка «Скачать обновление», список изменений из облака — в свёрнутом блоке «Описание обновления» (проверить видимость кнопки без прокрутки и раскрытие списка).
- По «Скачать обновление» показывается короткое предупреждение про менеджер установки ОС и само закрывается после передачи ссылки; при ошибке открытия ссылки — snackbar.

## 1.1.1+3 - 2026-04-23

- Техподдержка: проверка обновлений только по кнопке; manifest в UTF-8; при сбоях сети — понятные сообщения (имеет смысл проверить офлайн и при медленном соединении).
- Техподдержка: текст релиза и кнопка скачивания APK показываются лишь если на сервере новее текущей сборки; убран переход в папку релизов на Google Drive (проверить сценарий «уже актуально» и «есть обновление»).

## 1.1.0+2 - 2026-04-22

- Added version history UI in Support.
- Added update-checking foundation via remote manifest JSON.
- Improved reading-plan day card layout and status badge behavior.
- Fixed several Chrome/menu/settings/safe-area UI issues.

## 1.0.0+1 - 2026-03-28

- Initial app release with Bible, Notebook, and Reading Plan.
