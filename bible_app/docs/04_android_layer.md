# Слой 4: Android (`android`)

## Конфигурация Android-проекта

- `android/build.gradle` - общий Gradle-скрипт Android-модуля проекта.
- `android/settings.gradle` - состав Gradle-проектов/модулей Android.
- `android/gradle.properties` - параметры Gradle (JVM/Android build flags).
- `android/local.properties` - локальные пути SDK/Flutter (машинозависимый файл).
- `android/.gitignore` - правила игнорирования Android-артефактов.
- `android/bible_app_android.iml` - IDE-модуль Android.

## Gradle wrapper

- `android/gradlew` - Unix-скрипт запуска Gradle wrapper.
- `android/gradlew.bat` - Windows-скрипт запуска Gradle wrapper.
- `android/gradle/wrapper/gradle-wrapper.properties` - версия и источник Gradle wrapper.

## Модуль приложения `android/app`

- `android/app/build.gradle` - конфигурация Android app-модуля (applicationId, min/target sdk, зависимости, buildTypes).

## AndroidManifest (по вариантам сборки)

- `android/app/src/main/AndroidManifest.xml` - основной манифест приложения.
- `android/app/src/debug/AndroidManifest.xml` - манифест debug-варианта.
- `android/app/src/profile/AndroidManifest.xml` - манифест profile-варианта.

## Kotlin/Java код запуска

- `android/app/src/main/kotlin/com/example/bible_app/MainActivity.kt` - Android entrypoint активности Flutter.
- `android/app/src/main/java/io/flutter/plugins/GeneratedPluginRegistrant.java` - автогенерируемая регистрация Flutter-плагинов.

## Android-ресурсы

- `android/app/src/main/res/drawable/launch_background.xml` - фон launch-экрана (API < 21).
- `android/app/src/main/res/drawable-v21/launch_background.xml` - фон launch-экрана (API 21+).
- `android/app/src/main/res/values/styles.xml` - базовые Android-стили приложения.
- `android/app/src/main/res/values-night/styles.xml` - стили для ночной темы Android.

## Служебные артефакты

- `android/.gradle/buildOutputCleanup/cache.properties` - внутренние данные Gradle-кэша для cleanup.
