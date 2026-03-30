// ignore_for_file: avoid_web_libraries_in_flutter

import 'dart:html' as html;

import 'package:flutter/services.dart';

/// Закрытие вкладки после действия пользователя.
///
/// Сначала подменяем документ пустым окном через [Window.open] в `_self` —
/// во многих браузерах (в т.ч. Chrome) после этого [Window.close] разрешён
/// для этой «открытой скриптом» страницы. Если вкладку всё равно не закроет
/// (политика браузера), остаётся [SystemNavigator.pop] (шаг назад по истории).
void requestAppExit() {
  try {
    html.window.open('', '_self');
    html.window.close();
  } catch (_) {}
  try {
    html.window.close();
  } catch (_) {}
  SystemNavigator.pop();
}
