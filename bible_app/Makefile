# Команды для запуска Flutter приложения
.PHONY: run
run:
	flutter run -d emulator-5554

.PHONY: run-web
run-web:
	flutter run -d chrome

.PHONY: run-dev
run-dev:
	flutter run -d emulator-5554 --debug

.PHONY: run-release
run-release:
	flutter run -d emulator-5554 --release

.PHONY: build-apk
build-apk:
	flutter build apk --release

.PHONY: build-appbundle
build-appbundle:
	flutter build appbundle --release