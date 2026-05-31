import 'dart:ui' show ImageFilter;

import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:flutter/material.dart';

/// Frosted Glass Minimal — как панель «Настройки».
///
/// [backdropBlur]: живое размытие под панелью. Для длинных прокручиваемых
/// «Инструкция» / «Техподдержка» — false: тот же градиент и тени, без лагов.
Widget chromeFrostGlassPanelShell({
  required Widget child,
  double borderRadius = 12,
  bool backdropBlur = true,
}) {
  final frosted = DecoratedBox(
    decoration: BibleLightPalette.settingsFrostGlassPanelDecoration(
      radius: borderRadius,
    ),
    child: child,
  );
  return Material(
    color: Colors.transparent,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BibleLightPalette.chromePillOutlineSide,
    ),
    clipBehavior: Clip.antiAlias,
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: BibleLightPalette.settingsGlassPanelShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: backdropBlur
            ? BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: frosted,
              )
            : frosted,
      ),
    ),
  );
}
