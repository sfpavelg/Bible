import 'dart:ui' show ImageFilter;

import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:flutter/material.dart';

/// Frosted Glass Minimal — как панель «Настройки».
Widget chromeFrostGlassPanelShell({
  required Widget child,
  double borderRadius = 12,
}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(borderRadius),
      boxShadow: BibleLightPalette.settingsGlassPanelShadow,
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BibleLightPalette.settingsFrostGlassPanelDecoration(
            radius: borderRadius,
          ),
          child: child,
        ),
      ),
    ),
  );
}
