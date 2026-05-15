/// Палитра светлой темы экрана Библии и нижнего «хрома» (вкладки).
/// Тёмная тема по-прежнему задаётся локально в виджетах.
import 'package:flutter/material.dart';

abstract final class BibleLightPalette {
  // Акцент
  static const Color primary = Color(0xFF7B6DFF);
  static const Color primaryLight = Color(0xFFA89BFF);
  static const Color primaryDark = Color(0xFF5F4DEE);

  // Текст
  static const Color primaryText = Color(0xFF1A1C2E);
  static const Color secondaryText = Color(0xFF6F7391);
  static const Color disabledText = Color(0xFFB7BACD);

  // Иконки
  static const Color iconActive = Color(0xFF7B6DFF);
  static const Color iconInactive = Color(0xFFA0A3BA);
  static const Color iconLight = Color(0xFF7B6DFF);

  // Поверхности кнопок / состояния
  static const Color activeBg = Color(0xFFF0EDFF);
  static const Color hoverBg = Color(0xFFE8E4FF);
  static const Color pressedBg = Color(0xFFDDD9FF);
  static const Color border = Color(0xFFE3E1F6);
  static const Color borderActive = Color(0xFFCFCBFA);
  static const Color tabIndicator = Color(0xFF7B6DFF);

  static const Color bottomIconBg = Color(0xFFF5F3FF);
  static const Color bottomIconActiveBg = Color(0xFFEDEBFF);

  // Фоны экрана и карточек
  static const Color screenBg = Color(0xFFF7F5FF);
  static const Color topBarBg = Color(0xFFF1EFFD);

  /// #FFFFFF при 80 % непрозрачности.
  static const Color cardFillPrimary = Color(0xCCFFFFFF);

  /// #FFFFFF при 70 % непрозрачности.
  static const Color cardFillSecondary = Color(0xB3FFFFFF);

  // Градиенты
  static const Color screenGradientStart = Color(0xFFEDEBFF);
  static const Color screenGradientEnd = Color(0xFFDAD7FB);

  static const Color cardGradientTop = Color(0xCCFFFFFF);
  static const Color cardGradientBottom = Color(0x00F4F2FF);

  static const LinearGradient screenGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [screenGradientStart, screenGradientEnd],
  );

  static const LinearGradient verseCardGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [cardGradientTop, cardGradientBottom],
  );

  /// Оболочка всплывающих панелей и модальных окон в светлой теме.
  static BoxDecoration lightPanelShellDecoration({double radius = 14}) =>
      BoxDecoration(
        gradient: verseCardGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: verseCardShadow,
        border: Border.all(color: border, width: 1),
      );

  /// Нижний край без «дырки» — оба цвета непрозрачные (окно настроек).
  static const LinearGradient settingsPanelGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFF3F0FC)],
  );

  static BoxDecoration lightSettingsPanelDecoration({double radius = 14}) =>
      BoxDecoration(
        gradient: settingsPanelGradient,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: verseCardShadow,
        border: Border.all(color: border, width: 1),
      );

  /// Техподдержка / инструкция: сплошной фон, без просвета к тексту Библии.
  static const Color modalPanelSolid = Color(0xFFF7F5FF);

  static BoxDecoration lightModalOpaquePanelDecoration({double radius = 14}) =>
      BoxDecoration(
        color: modalPanelSolid,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: verseCardShadow,
        border: Border.all(color: border, width: 1),
      );

  // Разделители
  static const Color verseDivider = Color(0xFFEDEBFA);
  static const Color cardDivider = Color(0xFFECE9FA);

  // Выделение / отключено
  static const Color selectedBg = Color(0xFFF0EDFF);
  /// Подсветка выбранного стиха, перехода из поиска и совпадений в превью.
  static const Color verseHighlightBg = Color(0xFFBFB3F5);
  static const Color disabledBg = Color(0xFFF3F2F9);

  /// Плашки в шапке Библии — тот же тон, что «фон иконки внизу».
  static const Color chromePillBg = bottomIconBg;

  /// «Стекло» на градиенте: белый ~70 %.
  static const Color chromePillFill = Color(0xB3FFFFFF);

  /// Окаймовка кнопок на градиенте — тёмно-фиолетовый контур (читаемость на лаванде).
  static const Color chromePillOutlineColor = primaryDark;

  static const BorderSide chromePillOutlineSide =
      BorderSide(color: chromePillOutlineColor, width: 1.2);

  /// Активная вкладка внизу — чуть светлее основного контура.
  static const BorderSide chromePillOutlineActiveSide =
      BorderSide(color: primary, width: 1.25);

  /// Обводка элементов на сплошном светлом фоне (панели, поля).
  static const BorderSide chromeBorderSide =
      BorderSide(color: border, width: 1.2);

  /// Активная обводка на сплошном фоне.
  static const BorderSide chromeBorderActiveSide =
      BorderSide(color: borderActive, width: 1.2);

  /// Тень карточки: 0 8px 24px rgba(123, 109, 255, 0.08)
  static const List<BoxShadow> verseCardShadow = [
    BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 24,
      spreadRadius: 0,
      color: Color(0x147B6DFF),
    ),
  ];

  /// Тень нижней панели: 0 -4px 16px rgba(123, 109, 255, 0.06)
  static const List<BoxShadow> bottomBarShadow = [
    BoxShadow(
      offset: Offset(0, -4),
      blurRadius: 16,
      spreadRadius: 0,
      color: Color(0x0F7B6DFF),
    ),
  ];

  /// Свечение: 0 0 24px rgba(123, 109, 255, 0.25)
  static const List<BoxShadow> glow = [
    BoxShadow(
      offset: Offset.zero,
      blurRadius: 24,
      spreadRadius: 0,
      color: Color(0x407B6DFF),
    ),
  ];

  // --- Frosted Glass Minimal (панель «Настройки», светлая тема) ---

  /// ~45 % лаванды — blur должен просвечивать.
  static const Color settingsGlassPanelBg = Color(0x73F4F1FF);
  static const Color settingsGlassOverlay = Color(0x40FFFFFF);
  static const Color settingsGlassCard = Color(0xC4FFFFFF);
  static const Color settingsGlassGlow = Color(0x55B9A7FF);
  static const Color settingsGlassPrimary = Color(0xFF7B6DFF);
  static const Color settingsGlassHover = Color(0xFF9589FF);
  static const Color settingsGlassActiveGlow = Color(0xFFB5ACFF);
  static const Color settingsGlassTextPrimary = Color(0xFF23213A);
  static const Color settingsGlassTextSecondary = Color(0xFF6E6A91);
  static const Color settingsGlassTextDisabled = Color(0xFFB6B2D1);
  static const Color settingsGlassBorder = Color(0xB3FFFFFF);
  static const Color settingsGlassBorderActive = Color(0xFFA89BFF);

  static const LinearGradient settingsFrostGlassPanelGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xA8FFFFFF),
      Color(0x73F4F1FF),
    ],
  );

  static const List<BoxShadow> settingsGlassPanelShadow = [
    BoxShadow(
      offset: Offset(0, 16),
      blurRadius: 40,
      spreadRadius: -4,
      color: Color(0x45B9A7FF),
    ),
    BoxShadow(
      offset: Offset(0, 8),
      blurRadius: 28,
      spreadRadius: 0,
      color: Color(0x307B6DFF),
    ),
  ];

  static BoxDecoration settingsFrostGlassPanelDecoration({double radius = 12}) =>
      BoxDecoration(
        gradient: settingsFrostGlassPanelGradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: settingsGlassBorder, width: 1.2),
      );

  /// Фиолетовое свечение подписей в glass-настройках.
  static const List<Shadow> settingsGlassTextShadows = [
    Shadow(
      color: Color(0x997B6DFF),
      offset: Offset(0, 1),
      blurRadius: 2,
    ),
    Shadow(
      color: Color(0x66B5ACFF),
      offset: Offset(0, 0),
      blurRadius: 4,
    ),
  ];

  static BoxDecoration settingsGlassCardDecoration({double radius = 14}) =>
      BoxDecoration(
        color: settingsGlassCard,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: settingsGlassBorder, width: 1.1),
        boxShadow: const [
          BoxShadow(
            offset: Offset(0, 4),
            blurRadius: 16,
            spreadRadius: 0,
            color: Color(0x28B9A7FF),
          ),
          BoxShadow(
            offset: Offset(0, 1),
            blurRadius: 0,
            spreadRadius: 0,
            color: Color(0x33FFFFFF),
          ),
        ],
      );
}
