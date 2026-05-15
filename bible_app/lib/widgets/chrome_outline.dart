import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:flutter/material.dart';

/// Единая чёрная обводка квадратных и круглых кнопок хрома (Библия, блокнот, план).
abstract final class ChromeOutline {
  static const Color color = Colors.black87;
  static const double width = 1.2;

  static const BorderSide side = BorderSide(color: color, width: width);

  /// Тёмная тема: золотая обводка в стиле вкладки «Библия».
  static BorderSide get darkSide => BibleDarkPalette.chromeButtonOutline;
}
