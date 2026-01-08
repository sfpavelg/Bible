# 🧮 Flutter Bible
 в c:\Project\Bible создан Flutter‑проект Библия.

## 🚀 Быстрый старт
# Запуск на Android‑эмуляторе
Посмотреть эмуляторы: `flutter emulators`
Запустить эмулятор: `flutter emulators --launch Pixel_XL_API_34`
Проверить, что устройство появилось: `flutter devices`
У тебя оно определяется как emulator-5554 (sdk gphone64 x86 64)
Переместиться в директорию проекта: `cd "c:\Project\Bible\bible_app"`

## 🎯 Быстрый запуск (используйте Makefile)

```bash
# Установить зависимости
flutter pub get

# Запустить приложение
make run          # На эмуляторе
make run-web      # В браузере

# Или альтернативные команды:
make run-dev      # Режим разработки на эмуляторе
make run-release  # Режим релиза на эмуляторе
```

Запуск приложения на эмулятор: `flutter run -d emulator-5554`
# Запуск в браузере
Переместиться в директорию проекта: `cd "c:\Project\Bible\bible_app"`
Для запуска приложения в браузере: `flutter run -d chrome`
# Запуск на реальном телефоне через кабель:
- Включи “Режим разработчика” + “Отладка по USB”, подключи кабелем
- [📱 Проверить, что устройство появилось] (`flutter devices`)
- [📱 Запустить приложение на устройство] (`flutter run -d U10HFCPN228AD`)

# ⚠️ Важно!!
Лицензии Android должны быть приняты: `flutter doctor --android-licenses` (у тебя уже “All SDK package licenses accepted.”)
Первый запуск на Android может долго собирать Gradle task 'assembleDebug' — это нормально, просто дождись окончания.

# Сборка проекта для автономного запуска на телефоне (APK)
- [📦 Сборка и деплой APK] (`flutter build apk --release`)
⚠️ Важно. Для установки “автономно” на Android без кабеля тебе нужен именно APK (файл AAB напрямую на телефон не ставится).
1) Собери APK
- [📦 В корне проекта:] (`flutter build apk --release`)
- Готовый файл будет здесь: build/app/outputs/flutter-apk/app-release.apk
2) Закинь APK в Google Drive
- [📤 Загрузить app-release.apk в свой Google Drive (любой папкой).]
3) Скачай и установи на телефоне
- [📥 Открой Drive на телефоне → найди app-release.apk → скачай.]
- [📥 Открой скачанный файл и установи.]
- Если система блокирует установку:
  - Android попросит разрешение “Устанавливать неизвестные приложения” для того, чем ты открываешь APK (обычно Files/Файлы , Drive или браузер) → включи.
  - Если мешает Play Protect, временно разреши установку (на свой риск, ставь только свои APK).
После установки приложение появится как обычное и будет запускаться автономно.

# Сборка проекта для заливки на Google Play (AAB)
- [📦 Сборка и деплой AAB] (`flutter build appbundle --release`)
Результат: build/app/outputs/bundle/release/app-release.aab
AAB это если будешь выкладывать в Google Play (тогда Google Play сам разберёт и установит зависимости) 

# 🔐 Настройка подписи приложения для Google Play

1. Создание ключа (keystore)
- Открой терминал (например PowerShell или Command Prompt)
- Перейди в папку с проектом: `cd c:\Project\TraeTest`
- Создание ключа:
```bash
keytool -genkey -v -keystore c:\Key\TraeTest\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Запомни пароли (store password и key password)
Сохрани файл upload-keystore.jks в надежное место

2. Создание файла android/key.properties
```properties
storePassword=твой_store_пароль
keyPassword=твой_key_пароль  
keyAlias=upload
storeFile=../upload-keystore.jks
```

3. Настройка android/app/build.gradle
- Добавь в начало файла:

```Gradle
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}

android {
    ...
}
```

- Найди блок buildTypes и замени его:

```Gradle
signingConfigs {
    release {
        keyAlias keystoreProperties['keyAlias']
        keyPassword keystoreProperties['keyPassword']
        storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
        storePassword keystoreProperties['storePassword']
    }
}

buildTypes {
    release {
        signingConfig signingConfigs.release
    }
}
```

4. Перенос keystore файла
Положи upload-keystore.jks в корень проекта (рядом с папкой android)
Или укажи правильный путь в storeFile (например storeFile=../../keystore.jks)

5. Сборка релиза
```Bash
flutter build appbundle --release
```
Готовый файл: build/app/outputs/bundle/release/app-release.aab

⚠️ Важно!
Никогда не коммить key.properties и .jks файлы в git!
Добавь в .gitignore:
```PlainText
**/key.properties
**/*.jks
upload-keystore.jks
```
- Сохрани пароли и файл ключа в надежном месте - восстановить невозможно!
# После настройки можно публиковать .aab в Google Play Console.


## 📋 Содержание
- lib/main.dart — точка входа
- lib/src/app/app.dart — тема/MaterialApp
- lib/src/features/calculator/application/calculator_controller.dart — логика ввода/состояние
- lib/src/features/calculator/domain/calculator_engine.dart — вычисление выражений
- lib/src/features/calculator/presentation/calculator_page.dart — экран калькулятора
- lib/src/features/calculator/presentation/widgets/calc_button.dart — виджет кнопки

# Что умеет
- Операции: + , - , × , ÷ , десятичная точка
- ± меняет знак последнего числа, % применяет процент к последнему числу
- “живой” предпросмотр результата при вводе, = фиксирует результат

# Проверка

- flutter analyze — без ошибок
- flutter test — проходит (тесты на вычисление в test/widget_test.dart )


# Android (самый простой автономный запуск на телефоне)

1) Подготовь телефон

- Включи Режим разработчика → Отладка по USB
- Подключи кабелем
- Проверь, что Flutter видит устройство: flutter devices
2) Собери релиз

- APK (проще всего для установки вручную): flutter build apk --release Результат: build/app/outputs/flutter-apk/app-release.apk
- AAB (если будешь выкладывать в Google Play): flutter build appbundle --release Результат: build/app/outputs/bundle/release/app-release.aab
3) Установи на телефон

- Самый простой вариант (если устройство подключено по USB): flutter install -d <id> (где <id> смотри в flutter devices )
- Либо через adb: adb install -r build/app/outputs/flutter-apk/app-release.apk



# iOS

- Для автономной установки на iPhone нужен macOS + Xcode (на Windows собрать iOS нельзя).
Если скажешь, Android или iOS , и хочешь ли публикацию в магазин или только себе на устройство , я дам точные команды/настройки под твой сценарий (включая подпись релиза под Google Play).


# Как найти приложение на телефоне
- Открой меню всех приложений (обычно свайп вверх от нижнего края экрана или кнопка "Все приложения" в виде круга/квадрата из точек)
- Ищи приложение с названием "flutter_calculator" (или как в android/app/src/main/AndroidManifest.xml прописано android:label )
Если всё равно не находится

- Проверь в Настройки → Приложения → Все приложения — должно быть в списке
- Если нет — переустанови APK (иногда нужно дать время системе)
Чтобы добавить на рабочий стол

- Найди приложение в общем списке → зажми значок → перетащи на рабочий стол
Если проблема с именем/иконкой

- В android/app/src/main/AndroidManifest.xml можно поменять android:label (название) и android:icon (иконку)
- После изменений пересобери APK: flutter build apk --release

# Чтобы поменять иконку:

1) Готовые иконки (быстро)

- Скачай готовый набор иконок с сайтов:
  - Android Asset Studio
  - App Icon Generator
- Закинь скачанные файлы в папку android/app/src/main/res/ (замени существующие)
2) Создать свою иконку

- Нужен квадратный PNG (минимум 512×512)
- Конвертируй в Android иконки через те же онлайн-генераторы выше
- Или вручную создай нужные размеры:
  - mipmap-hdpi : 72×72
  - mipmap-mdpi : 48×48
  - mipmap-xhdpi : 96×96
  - mipmap-xxhdpi : 144×144
  - mipmap-xxxhdpi : 192×192
3) Замена в проекте

- Положи свои PNG файлы в соответствующие папки mipmap-* здесь: android/app/src/main/res/
- Убедись что имена файлов совпадают ( ic_launcher.png , ic_launcher_foreground.png etc.)
- Пересобери APK: flutter build apk --release
Быстрая проверка текущей иконки

- Посмотри что сейчас в папках android/app/src/main/res/mipmap-*/
- Обычно там должны быть ic_launcher.png разных размеров
Самый простой путь — использовать онлайн-генератор, он сразу создаст все нужные размеры и положит в zip-архиве.

###  Работа с GIT
## Последовательность команд в терминале для работы с GIT 
# Последовательность шагов должна быть следующая:
# 1. Проверка наличия установленной версии Git:
  - git --version
  # ожидание: 
    - git version 2.39.2.windows.1
# 2. Проверка конфигурации Git:
  - git config --list
  # ожидание: 
    - user.name=Pavel Sofein
    - user.email=sfpavelg@gmail.com
# 3. Проверка состояния Git (состояние репозитория, но если небыло инициализации, то выдаст ошибку о том, что репозиторий не инициализирован, в этом случае выполните пункт №4):
  - git status
  # ожидание: 
    - On branch main
    - nothing to commit, working tree clean
# 4. Инициализация репозитория (в репозитории проекта будет создан файл .git, который содержит всю информацию о состоянии репозитория): 
  - git init
  # ожидание: 
    - Initialized empty Git repository in C:/Project/Bible/bible_app/.git/
# 5. Добавление файлов в индекс для последующего коммита (. точка означает выбор всех файлов, или укажите конкретные файлы): 
  - git add .
  # ожидание: 
    - 10 files changed, 10 insertions(+)
    - create mode 100644 android/app/src/main/AndroidManifest.xml
    - create mode 100644 android/app/src/main/assets/flutter_assets/AssetManifest.json
    - create mode 100644 android/app/src/main/assets/flutter_assets/FontManifest.json
    - create mode 100644 android/app/src/main/assets/flutter_assets/LICENSE
    - create mode 100644 android/app/src/main/assets/flutter_assets/fonts/NotoSans-Regular.ttf
    - create mode 100644 android/app/src/main/assets/flutter_assets/fonts/NotoSans-Regular.ttf
    - create mode 100644 android/app/src/main/assets/flutter_assets/fonts/NotoSans-Regular.ttf
    - create mode 100644 android/app/src/main/assets/flutter_assets/fonts/NotoSans-Regular.ttf
# 6. Создание коммита с названием "Initial commit" (создание начального коммита, который будет содержать все добавленные в индекс файлы): 
  - git commit -m "Initial commit"
  # ожидание: 
    - [main (root-commit) 8b90451] Initial commit
    - 10 files changed, 10 insertions(+)
    - create mode 100644 android/app/src/main/AndroidManifest.xml
    - create mode 100644 android/app/src/main/assets/flutter_assets/AssetManifest.json
    - create mode 100644 android/app/src/main/assets/flutter_assets/FontManifest.json
    - create mode 100644 android/app/src/main/assets/flutter_assets/LICENSE
    - create mode 100644 android/app/src/main/assets/flutter_assets/fonts/NotoSans-Regular.ttf
    - create mode 100644 android/app/src/main/assets/flutter_assets/fonts/NotoSans-Regular.ttf
    - create mode 100644 android/app/src/main/assets/flutter_assets/fonts/NotoSans-Regular.ttf
# 7. Добавление удаленного репозитория, например на GitHub, для последующей отправки изменений (если он ещё не был добавлен ранее):
  - git remote add origin https://github.com/sfpavelg/Bible.git
  # ожидание: 
    - fatal: remote origin already exists.
# 8. Проверка удаленного репозитория:
  - git remote -v
  # ожидание: 
    - origin  https://github.com/sfpavelg/Bible.git (fetch)
    - origin  https://github.com/sfpavelg/Bible.git (push)
# 9. Отправка изменений на удаленный репозиторий (если он отправляется в перваый раз): 
  - git push -u origin main
  # ожидание: 
    - Enumerating objects: 10, done.
    - Counting objects: 100% (10/10), done.
    - Delta compression using up to 8 threads
    - Compressing objects: 100% (10/10), done.
    - Writing objects: 100% (10/10), 1.02 KiB | 1.02 MiB/s, done.
    - Total 10 (delta 0), reused 0 (delta 0), pack-reused 0
    - To https://github.com/sfpavelg/Bible.git
    -  * [new branch]      main -> main
    - branch 'main' set up to track 'origin/main'.
# 10. Последующая отправка изменений на удаленный репозиторий (если он уже был отправлен ранее): 
  - git push
  # ожидание: 
    - Everything up-to-date
# 11. Дополнитеольные команды для проверки. 
# Проверка состояния Git после отправки изменений на удаленный репозиторий:
  - git status
  # ожидание: 
    - On branch main
    - nothing to commit, working tree clean
  # Это значит все коммиты запушены в удалённый репозиторий.
# Так же можног выполнить команду проверки локальных коммитов (верхние 5 коммитов):
  - git log --oneline -5
  # ожидаю: 
   - 8b90451 (HEAD -> main) ver02
   - d47ebc8 ver01
  # есть два коммита: ver01 и ver02
# Так же можног выполнить команду проверки коммитов на удаленном репозитории(--all - из всех веток,   -10 - отобрать верхние 10 коммитов):
  - git log --oneline --graph --all -10
  # ожидаю: 
   - 8b90451 (HEAD -> main) ver02
   - d47ebc8 ver01
  # есть два коммита: ver01 и ver02


