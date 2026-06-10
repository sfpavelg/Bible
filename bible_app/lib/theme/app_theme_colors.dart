import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/app_brightness_tuning.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Подстройка палитры под ползунок «Яркость» (только внутри приложения).
abstract final class AppThemeColors {
  static bool _isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static AppProvider _app(BuildContext context) =>
      context.watch<AppProvider>();

  /// Светлая тема: фон/поверхность. В тёмной — без изменений.
  static Color lightSurface(BuildContext context, Color base) {
    if (_isDark(context)) return base;
    return AppBrightnessTuning.tuneSurface(
      base,
      _app(context).lightSurfaceBrightness,
    );
  }

  /// Тёмная тема: текст и читаемые подписи. В светлой — без изменений.
  static Color darkText(BuildContext context, Color base) {
    if (!_isDark(context)) return base;
    return AppBrightnessTuning.tuneText(
      base,
      _app(context).darkTextBrightness,
    );
  }

  static LinearGradient lightScreenGradient(BuildContext context) {
    final app = _app(context);
    if (_isDark(context) ||
        AppBrightnessTuning.isNeutral(app.lightSurfaceBrightness)) {
      return const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFEDEBFF),
          Color(0xFFDAD7FB),
        ],
      );
    }
    return AppBrightnessTuning.tuneGradient(
      const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFFEDEBFF),
          Color(0xFFDAD7FB),
        ],
      ),
      app.lightSurfaceBrightness,
    );
  }

  static LinearGradient lightVerseCardGradient(BuildContext context) {
    const base = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xCCFFFFFF),
        Color(0x00F4F2FF),
      ],
    );
    if (_isDark(context)) return base;
    final t = _app(context).lightSurfaceBrightness;
    if (AppBrightnessTuning.isNeutral(t)) return base;
    return AppBrightnessTuning.tuneGradient(base, t);
  }
}
