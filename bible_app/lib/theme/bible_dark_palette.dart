import 'package:flutter/material.dart';

/// Тёмная тема «золото / бронза» — главный экран Библии и согласованный хром.
abstract final class BibleDarkPalette {
  static const Color screenBg = Color(0xFF1A1A1A);
  static const Color cardBg = Color(0xFF242424);

  static const Color accentGold = Color(0xFFD4AF37);
  static const Color accentGoldLight = Color(0xFFF4D03F);
  static const Color accentGoldDark = Color(0xFFB8941F);

  static const Color titleGold = Color(0xFFE5C15C);
  static const Color primaryText = Color(0xFFB8B8B8);
  static const Color secondaryText = Color(0xFF888888);

  /// Рамка крупной карточки (область стихов и т.п.)
  static const Color cardBorderGold = Color(0xFFC9A962);

  static const Color divider = Color(0xFF3A3A3A);

  static const Color iconActive = Color(0xFFD4AF37);
  static const Color iconInactive = Color(0xFF666666);

  /// Приглушённое золото для хрома на тёмном фоне (неактивные вкладки, иконки с золотой обводкой).
  static const Color chromeMutedGold = Color(0xFFB09A56);

  /// Нижняя панель вкладок без выбора — тусклее [chromeMutedGold], чтобы активная вкладка контрастировала.
  static const Color chromeTabInactiveFg = Color(0xFF756846);

  /// Обводка неактивной нижней вкладки (не яркая [cardBorderGold]).
  static const Color chromeTabInactiveBorder = Color(0xFF564D34);

  static const List<BoxShadow> verseCardShadow = [
    BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
      color: Color(0x80000000),
    ),
  ];

  static BorderSide get chromeButtonOutline =>
      const BorderSide(color: accentGold, width: 1.2);

  static BorderSide get cardOutline =>
      const BorderSide(color: cardBorderGold, width: 1);
}
