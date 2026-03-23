# Слой 7: Windows (`windows`)

## Корневые файлы Windows-слоя

- `windows/.gitignore` - исключения build-артефактов Windows.
- `windows/CMakeLists.txt` - верхнеуровневый CMake-файл сборки Windows-приложения.

## Папка `windows/flutter`

- `windows/flutter/CMakeLists.txt` - CMake-конфигурация Flutter-части на Windows.
- `windows/flutter/generated_plugin_registrant.cc` - автогенерируемая регистрация плагинов.
- `windows/flutter/generated_plugin_registrant.h` - заголовок регистрации плагинов.
- `windows/flutter/generated_plugins.cmake` - автогенерируемый список подключаемых плагинов.
- `windows/flutter/ephemeral/generated_config.cmake` - временная автогенерируемая конфигурация текущей сборки.

## Папка `windows/runner`

- `windows/runner/main.cpp` - точка входа desktop-приложения на Windows.
- `windows/runner/flutter_window.cpp` - интеграция окна приложения с Flutter engine.
- `windows/runner/flutter_window.h` - интерфейс `flutter_window.cpp`.
- `windows/runner/win32_window.cpp` - базовая реализация Win32-окна.
- `windows/runner/win32_window.h` - интерфейс Win32-окна.
- `windows/runner/utils.cpp` - вспомогательные функции раннера.
- `windows/runner/utils.h` - интерфейс утилит раннера.
- `windows/runner/resource.h` - идентификаторы ресурсов Windows.
- `windows/runner/Runner.rc` - ресурсный скрипт Windows-приложения.
- `windows/runner/runner.exe.manifest` - манифест desktop-приложения.
- `windows/runner/CMakeLists.txt` - CMake-конфигурация `runner`-таргета.
