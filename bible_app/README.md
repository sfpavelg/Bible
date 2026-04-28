# 🧮 Flutter Bible
 в c:\Project\Bible создан Flutter‑проект Библия.

## 🚀 Быстрый старт

1.
```bash
# Проверь путь:
cd "c:\Project\Bible\bible_app"
```
2. 
```bash
# Посмотреть эмуляторы:
flutter emulators
```
3.
```bash
# Если нужен эмулятор, запустить:
flutter emulators --launch Pixel_XL_API_34
```
4.
```bash
# Проверить подключенные устройства, эмулятор (например:emulator-5554), или телефон:
flutter devices
```
5.
```bash
# Сборка и деплой APK:
# Готовый файл будет здесь: build/app/outputs/flutter-apk/app-release.apk
flutter build apk --release
```
6.
```bash
# Запуск приложения на эмулятор:
flutter run -d emulator-5554
# Но лучше переустановка:
flutter install -d emulator-5554
```
7.
```bash
# Запуск приложения на маленьком телефоне:
flutter install -d U10HFCPN228AD
# Запуск приложения на README:
flutter install -d 2e2c089
# Запустить во вкладке Chrome:
flutter run -d chrome
flutter run -d chrome --web-port 5000
```

## 📦 Сборка для Windows
```bash
# build\windows\x64\runner\Release\bible_app.exe
flutter build windows --release
```

## 📦 Пуш на ГитХаб
```bash
cd C:\Project\Bible
git push origin main
```


# Запуск на Android‑эмуляторе
Посмотреть эмуляторы: (`flutter emulators`)
Запустить эмулятор: (`flutter emulators --launch Pixel_XL_API_34`)
Проверить, что устройство появилось: (`flutter devices`)
У тебя оно определяется как emulator-5554 (sdk gphone64 x86 64)
Переместиться в директорию проекта: (`cd "c:\Project\Bible\bible_app"`)
Запуск приложения на эмулятор: (`flutter run -d emulator-5554`)

Запуск приложения на маленьком телефоне:(`flutter install -d U10HFCPN228AD`)
Запуск приложения на README:(`flutter install -d 2e2c089`)


Сборка и деплой APK (`flutter build apk --release`)



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

# Запустить во вкладке Chrome:
flutter run -d chrome
flutter run -d chrome --web-port 5000
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
`cd "c:\Project\Bible\bible_app"`
`flutter build apk --release`
- AAB (если будешь выкладывать в Google Play): flutter build appbundle --release Результат: build/app/outputs/bundle/release/app-release.aab
3) Установи на телефон

- Самый простой вариант (если устройство подключено по USB): flutter install -d <id> (где <id> смотри в flutter devices )
`flutter install -d U10HFCPN228AD`
`flutter install -d 2e2c089`
- Либо через adb: adb install -r build/app/outputs/flutter-apk/app-release.apk

диагностика устройства
cd c:\Project\Bible\bible_app
flutter run -d U10HFCPN228AD -v

### iOS

- Для автономной установки на iPhone нужен macOS + Xcode (на Windows собрать iOS нельзя).
Если скажешь, Android или iOS , и хочешь ли публикацию в магазин или только себе на устройство , я дам точные команды/настройки под твой сценарий (включая подпись релиза под Google Play).

## ⚠️ Обновления APK через Google Drive (manifest)

Папка в проекте для manifest-файлов:
`assets/version/release-manifests/`

- Текущий файл для загрузки на Drive:  
  `assets/version/release-manifests/latest.json`
- Архив по версии (необязательно, но удобно):  
  `assets/version/release-manifests/<version+build>/latest.json`  
  пример: `assets/version/release-manifests/1.1.0+2/latest.json`

⚠️ Порядок релиза:
1. Делаем коммит. В этот момент Ассистент-Помощник (АП)  прописывает в latest.json новые version_name и  version_code. 
version_name  меняется по принципу:
1.1.0 -> новая функциональность,
1.1.1 -> небольшой фикс,
2.0.0 -> крупное обновление/ломающие изменения.
А так же пишет описание    "changes":  Я проверяю.
2. Так же АП пишет новую версию в pubspec.yaml.
Я проверяю.
3. Я Собираю новый APK.
4. Загружаю APK и JSON на гугл-диск.
5. Предполагается, что при обновлении APK yна гугл диске, ⚠️ старый не удаляется, а перезаписывается с заменой на новый. Но в первый раз, его там нет.
6. Узнаём FILE_ID_APK. Для этого я захожу на гугл-диск и просматриваю url путь к файлу, используя кнопку "копировать ссылку". Далее в это ссылке нахожу FILE_ID_APK, колторый будет примерно тут: (в ссылке будет кусок: /file/d/FILE_ID_APK/view)
Беру FILE_ID_APK и вставляю в:
apk_url: https://drive.google.com/uc?export=download&id=FILE_ID_APK
в JSON.
7. Узнаю FILE_ID_JSON аналогично пункта 6. 
Нахожу поле _releaseManifestUrl в файле проекта:
lib/widgets/app_chrome_dialogs.dart
там будет строка типа:
https://drive.google.com/uc?export=download&id=FILE_ID_JSON
меняю последнее значение.
8. Важно: если вы каждый раз перезаписываете тот же latest.json и его ID не меняется, этот шаг больше повторять не нужно.
9. Проверка на устройстве.
В установленном приложении:
открыть Техподдержка,
нажать проверку/скачивание обновления,
установить новую APK,
увидеть обновлённую версию и историю изменений.
10. ⚠️⚠️⚠️Важно!
Так как получается некий цикл без выхода, в apk должен быть FILE_ID_JSON, 
а его там не будет пока не положишь JSON на гугл-диск. 
А JSON нет смысла класть пока нет FILE_ID_APK
То решение такое, делаешь все по списку выше, но понимаем, что первый apk выложенный на диск 
тиеет битый FILE_ID_JSON. 
Далее после зписи FILE_ID_JSON пересобираешь apk, н она диск его выкладываешь без УДАЛЕНИЯ старого, 
а заменой на новый. Тогда FILE_ID_JSON и FILE_ID_JSON меняться не будут, и прописывать постоянно не нужно.



Старая последовательность:
1. Обновить версию в `pubspec.yaml` (`x.y.z+build`).
2. Собрать APK.
3. Загрузить APK в папку Drive релизов.
4. Обновить `assets/version/release-manifests/latest.json`:
   - `version_name`
   - `version_code`
   - `apk_url` (прямая ссылка `https://drive.google.com/uc?export=download&id=FILE_ID_APK`)
   - `changes`
5. Скопировать `latest.json` в подпапку версии:
   `assets/version/release-manifests/<version+build>/latest.json`
6. Загрузить обновлённый `latest.json` в ту же папку Google Drive, где лежит APK.

Для автопроверки в приложении:
- в `lib/widgets/app_chrome_dialogs.dart` замените `FILE_ID_JSON` в `_releaseManifestUrl`
  на ID загруженного в Drive файла `latest.json`.

Ключевое про версии
В Flutter строка:

version: 1.1.0+2
означает:

version_name = 1.1.0 (то, что видит пользователь),
version_code = 2 (технический номер сборки, должен расти для каждого релиза).
Когда менять version_name
Меняйте, когда есть заметные изменения релиза:

1.1.0 -> новая функциональность,
1.1.1 -> небольшой фикс,
2.0.0 -> крупное обновление/ломающие изменения.
Что обязательно
Для каждого нового APK, который хотите “считать новее”, обязательно увеличивать version_code (+3, +4, ...).

Кто это делает: вы или я
Можно так, как вам удобнее:

Вариант A (рекомендую): вы просите “сделай коммит”, и я:
bump версии в pubspec.yaml,
обновляю assets/version/release-manifests/latest.json,
добавляю архивную копию в папку версии,
обновляю changelog.
Вариант B: вы меняете руками, я только проверяю/дополняю.
С учётом вашего процесса — Вариант A идеально подходит.

Про FILE_ID_APK (важно)
Вы правы: получить FILE_ID_APK можно только после загрузки APK на Google Drive.

Как взять:

Загрузили app-release.apk в Drive.
Открыли файл → “Копировать ссылку”.
В ссылке будет кусок: /file/d/FILE_ID_APK/view.
Берёте FILE_ID_APK и ставите в:
apk_url: https://drive.google.com/uc?export=download&id=FILE_ID_APK
Порядок релиза (финальный)
Просите меня: “сделай коммит релиза”.
Я обновляю версию + JSON + changelog и коммичу.
Вы собираете APK.
Вы загружаете APK в Drive.
Подставляете FILE_ID_APK в latest.json (или присылаете мне — я подставлю).
Загружаете latest.json в ту же папку Drive.
Если latest.json новый файл — один раз обновляем FILE_ID_JSON в _releaseManifestUrl.


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

"flutter upgrade"

коммиты и пуши
cd C:\Project\Bible
git status

Только bible_app:
git add bible_app
git commit -m "Краткий заголовок на русском или английском" -m "Что изменили и зачем (необязательно второй абзац)."

Весь репозиторий (если правки не только в bible_app):
git add -A
git commit -m "Краткий заголовок" -m "Пояснение."

Проверка последнего коммита:
git log -1 --oneline

`cd C:\Project\Bible`
`git push origin main`


### Сборка для Windows

cd "c:\Project\Bible\bible_app"
flutter build windows --release

Если сборка у вас на машине сейчас не прошла: нет подходящего Visual Studio (нужен компилятор C++ для Windows‑десктопа Flutter). Ниже — что сделать, чтобы получить .exe.

1. Установить инструменты
Установите Visual Studio Community (или Build Tools).
В установщике отметьте рабочую нагрузку «Разработка классических приложений на C++» (Desktop development with C++).

Да. Скачивай официальный установщик отсюда:
https://visualstudio.microsoft.com/ru/visual-cpp-build-tools/
Visual Studio Tools for C++
Что выбрать в установщике (Visual Studio Installer):

Workload: Desktop development with C++
И проверь, что в правой панели отмечены компоненты:

MSVC v143 - VS 2022 C++ x64/x86 build tools (или v142 для 2019)
Windows 10 SDK (или Windows 11 SDK)
C++ CMake tools for Windows

После установки выполни:
```bash
flutter doctor -v
flutter build windows --release
```
$env:CMAKE_GENERATOR = "Visual Studio 17 2022"
flutter clean
flutter pub get
flutter build windows --release -v


Открой PowerShell от имени администратора и выполни:

winget install --id Microsoft.VisualStudio.2019.BuildTools -e
Дальше:

Откроется Visual Studio Installer
Выбери workload Desktop development with C++
Проверь компоненты:
MSVC v142
Windows 10 SDK
C++ CMake tools for Windows
Нажми Install
Потом в обычном PowerShell:

Причина найдена: все команды завершились с Exit Code: 5007.

Это означает, что команды с --passive/--quiet были запущены не в elevated-сессии с самого старта (инсталлер это прямо пишет).

Да, всё верно понял:

Почему ставим 2019: потому что твой текущий Flutter при сборке Windows вызывает CMake с генератором Visual Studio 16 2019.
Из-за Flutter ли это: да, из-за связки твоей текущей версии Flutter/инструментов проекта.
Какая версия сейчас: по твоему flutter doctor -v сейчас Flutter 3.35.7 (кастомный канал [user-branch]), и он ожидает именно toolchain уровня VS2019 для этой сборки.
Поэтому и нужна 19-я Build Tools с C++ компонентами.

Сделай так:

Закрой текущее окно PowerShell.
Открой PowerShell → Запуск от имени администратора.
Выполни одной командой:
& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.CMake.Project --add Microsoft.VisualStudio.Component.Windows10SDK.19041 --passive --norestart
Если 19041 не примется, повтори с 18362:

& "C:\Program Files (x86)\Microsoft Visual Studio\Installer\vs_installer.exe" modify --installPath "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools" --add Microsoft.VisualStudio.Workload.VCTools --add Microsoft.VisualStudio.Component.VC.Tools.x86.x64 --add Microsoft.VisualStudio.Component.VC.CMake.Project --add Microsoft.VisualStudio.Component.Windows10SDK.18362 --passive --norestart
Потом проверка:

flutter doctor -v
Если блок Visual Studio станет зеленым без X, сразу запускай сборку.


cd C:\Project\Bible\bible_app
flutter clean
Remove-Item -Recurse -Force .\build\windows\x64 -ErrorAction SilentlyContinue
flutter pub get
flutter build windows --release -v
Проверка, что пакет нашелся через winget:

winget search Microsoft.VisualStudio.2019.BuildTools


Если хочешь, после установки скидывай новый flutter doctor -v — проверю, всё ли закрыто.
В составе должны быть MSVC, Windows SDK, CMake (обычно ставятся вместе с этой нагрузкой).
Проверка:

cd c:\Project\Bible\bible_app
убедиться, что проблемс Visual Studio нет
flutter doctor -v
В блоке Windows должно быть без критичных ошибок про Visual Studio.

2. Собрать exe
cd c:\Project\Bible\bible_app
подтянуть зависимости проекта
flutter pub get
собрать Windows release
flutter build windows --release
3. Где лежит программа
Обычно так:

c:\Project\Bible\bible_app\build\windows\x64\runner\Release\

Там будет bible_app.exe (имя из pubspec.yaml) и рядом DLL и папки данных — для запуска на другом ПК копируйте всю папку Release, а не один только .exe.

Кратко: поставьте Visual Studio с C++ для десктопа, затем flutter build windows --release — готовый запуск — содержимое build\windows\x64\runner\Release\.

что нужно чтобы сделать сборку для линукс и для айфонов

Для вашего проекта (судя по flutter build windows) это Flutter, значит требования такие:

Linux build
Нужно:

Linux-хост (или Linux CI) — локально на Windows собрать Linux desktop нельзя нативно.
Установить Flutter SDK + включить desktop:
flutter config --enable-linux-desktop
Поставить toolchain:
clang, cmake, ninja-build, pkg-config, libgtk-3-dev
Проверить:
flutter doctor -v
Сборка:
flutter build linux --release
Результат обычно в build/linux/x64/release/bundle/
iPhone / iOS build
Нужно:

Только macOS (обязательно, из-за Xcode).
Установить:
Xcode (актуальный), Command Line Tools
CocoaPods (sudo gem install cocoapods или через Homebrew)
Flutter SDK
Принять лицензии и проверить:
sudo xcodebuild -license accept
flutter doctor -v
В проекте:
flutter build ios --release (без подписи для теста)
для реального устройства/App Store нужна подпись:
Apple Developer account
Bundle ID
Certificates + Provisioning Profiles
Настройка в ios/Runner.xcworkspace через Xcode
Для публикации:
Archive в Xcode → Upload to App Store Connect
Если у вас сейчас Windows-машина
Linux: собирайте в Linux CI (GitHub Actions/GitLab) или на отдельной Linux машине.
iOS: нужен Mac (локальный, rented Mac cloud, или CI с macOS runner).
Если хотите, могу сразу дать готовые workflow-файлы CI: отдельно для Linux артефакта и для iOS (build + export/Upload).
