import 'package:flutter/material.dart';

/// Единая чёрная обводка квадратных и круглых кнопок хрома (Библия, блокнот, план).
abstract final class ChromeOutline {
  static const Color color = Colors.black87;
  static const double width = 1.2;

  static const BorderSide side = BorderSide(color: color, width: width);
}
