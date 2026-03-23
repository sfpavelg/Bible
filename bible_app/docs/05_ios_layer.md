# Слой 5: iOS (`ios`)

## Корневые файлы iOS-слоя

- `ios/.gitignore` - исключения для iOS build-артефактов.

## Папка `ios/Flutter`

- `ios/Flutter/AppFrameworkInfo.plist` - метаданные Flutter framework для iOS.
- `ios/Flutter/Debug.xcconfig` - debug-конфигурация сборки Flutter/iOS.
- `ios/Flutter/Release.xcconfig` - release-конфигурация сборки Flutter/iOS.
- `ios/Flutter/Generated.xcconfig` - автогенерируемые флаги/пути Flutter для Xcode.
- `ios/Flutter/flutter_export_environment.sh` - экспорт переменных окружения Flutter build.

## Папка `ios/Runner`

- `ios/Runner/AppDelegate.swift` - точка входа iOS-приложения (UIKit + Flutter engine).
- `ios/Runner/Info.plist` - iOS metadata (bundle id, permissions, display settings).
- `ios/Runner/Runner-Bridging-Header.h` - bridging header для Swift/Obj-C.
- `ios/Runner/GeneratedPluginRegistrant.h` - заголовок автогенерируемой регистрации плагинов.
- `ios/Runner/GeneratedPluginRegistrant.m` - реализация автогенерируемой регистрации плагинов.
- `ios/Runner/Base.lproj/Main.storyboard` - основной storyboard интерфейса Runner.
- `ios/Runner/Base.lproj/LaunchScreen.storyboard` - launch screen storyboard.
- `ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json` - описание iOS-иконок приложения.
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/Contents.json` - описание launch-изображений.
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/README.md` - пояснение по launch image.

## Папка `ios/RunnerTests`

- `ios/RunnerTests/RunnerTests.swift` - шаблон тестов для iOS Runner.

## Xcode project/workspace

- `ios/Runner.xcodeproj/project.pbxproj` - основной проектный файл Xcode.
- `ios/Runner.xcodeproj/project.xcworkspace/contents.xcworkspacedata` - workspace-описание внутри `xcodeproj`.
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` - проверки IDE workspace.
- `ios/Runner.xcodeproj/project.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` - shared workspace settings.
- `ios/Runner.xcodeproj/xcshareddata/xcschemes/Runner.xcscheme` - схема сборки/запуска Runner.
- `ios/Runner.xcworkspace/contents.xcworkspacedata` - основной workspace для открытия проекта.
- `ios/Runner.xcworkspace/xcshareddata/IDEWorkspaceChecks.plist` - проверки IDE для workspace.
- `ios/Runner.xcworkspace/xcshareddata/WorkspaceSettings.xcsettings` - shared workspace settings.
