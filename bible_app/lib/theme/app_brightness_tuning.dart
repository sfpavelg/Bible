import 'package:flutter/material.dart';

/// Нормализация яркости интерфейса: 0.5 — текущий вид по умолчанию.
abstract final class AppBrightnessTuning {
  static const double min = 0.0;
  static const double max = 1.0;
  static const double neutral = 0.5;

  static const double _surfaceDarkenMix = 0.32;
  static const double _surfaceLightenMix = 0.42;
  static const double _textDimMix = 0.72;
  static const double _textBrightMix = 0.55;

  static bool isNeutral(double value) => (value - neutral).abs() < 0.001;

  /// Светлая тема: фон и поверхности (t &lt; 0.5 — темнее, t &gt; 0.5 — светлее).
  static Color tuneSurface(Color base, double t) {
    if (isNeutral(t)) return base;
    final target = t < neutral
        ? Color.lerp(base, Colors.black, _surfaceDarkenMix)!
        : Color.lerp(base, Colors.white, _surfaceLightenMix)!;
    final amount = ((t - neutral).abs() / neutral).clamp(0.0, 1.0);
    final mixed = Color.lerp(base, target, amount)!;
    return mixed.withValues(alpha: base.a);
  }

  /// Тёмная тема: текст и читаемые подписи (t &lt; 0.5 — тусклее, t &gt; 0.5 — ярче).
  static Color tuneText(Color base, double t) {
    if (isNeutral(t)) return base;
    final dimTarget = Color.lerp(base, Colors.black, _textDimMix)!;
    final brightTarget = Color.lerp(base, Colors.white, _textBrightMix)!;
    final target = t < neutral ? dimTarget : brightTarget;
    final amount = ((t - neutral).abs() / neutral).clamp(0.0, 1.0);
    final mixed = Color.lerp(base, target, amount)!;
    return mixed.withValues(alpha: base.a);
  }

  static LinearGradient tuneGradient(
    LinearGradient gradient,
    double lightSurfaceBrightness,
  ) {
    if (isNeutral(lightSurfaceBrightness)) return gradient;
    return LinearGradient(
      begin: gradient.begin,
      end: gradient.end,
      colors: gradient.colors
          .map((c) => tuneSurface(c, lightSurfaceBrightness))
          .toList(growable: false),
      stops: gradient.stops,
      tileMode: gradient.tileMode,
      transform: gradient.transform,
    );
  }
}
