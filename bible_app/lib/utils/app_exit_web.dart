// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:async';

import 'dart:html' as html;

import 'package:flutter/services.dart';

void _tryClose(html.WindowBase w) {
  try {
    w.close();
  } catch (_) {}
}

/// Выход из приложения в браузере.
///
/// Закрыть вкладку скриптом разрешено только если её открыл тот же скрипт
/// (`window.open`). Обычная вкладка (адресная строка, закладка, ссылка из
/// другого сайта) в Chrome **не закрывается** — это ограничение браузера, не
/// Flutter. Делаем всё возможное; иначе снимаем приложение с `about:blank`.
void requestAppExit() {
  final w = html.window;

  // Иногда переводит окно в контекст, где close() менее строго блокируется.
  try {
    w.open('', '_self');
  } catch (_) {}

  _tryClose(w);
  try {
    w.top?.close();
  } catch (_) {}

  scheduleMicrotask(() {
    if (w.closed == true) return;

    _tryClose(w);

    if (w.closed == true) return;

    try {
      SystemNavigator.pop();
    } catch (_) {}

    if (w.closed == true) return;

    try {
      w.location.replace('about:blank');
    } catch (_) {}

    scheduleMicrotask(() => _tryClose(w));
  });
}
