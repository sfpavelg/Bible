import 'dart:math' as math;

import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Обводка по умолчанию для кнопок хрома, если [outlineSide] не передан.
BorderSide _defaultChromeOutlineSide(
  BuildContext context, {
  required bool disabled,
}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  if (!disabled) {
    return dark ? ChromeOutline.darkSide : ChromeOutline.side;
  }
  return BorderSide(
    color: dark
        ? BibleDarkPalette.chromeMutedGold.withValues(alpha: 0.42)
        : ChromeOutline.color.withValues(alpha: 0.35),
    width: ChromeOutline.width,
  );
}

/// Кнопка хрома: высота из [AppProvider.chromeButtonSize], ширина по умолчанию равна высоте.
/// [width] задаёт общую ширину ячейки (например, в панели Библии все кнопки одной [width]).
class ChromeIconButton extends StatelessWidget {
  const ChromeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    required this.foregroundColor,
    required this.backgroundColor,
    this.circular = false,
    this.width,
    this.outlineSide,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color foregroundColor;
  final Color backgroundColor;

  /// Круг только если [width] не задана или совпадает с высотой; иначе — скруглённый прямоугольник.
  final bool circular;

  /// Если null — квадрат [chromeButtonSize] × [chromeButtonSize].
  final double? width;

  /// Если задано — обводка вместо стандартной [ChromeOutline] (например, светлая тема Библии).
  final BorderSide? outlineSide;

  @override
  Widget build(BuildContext context) {
    final height = context.watch<AppProvider>().chromeButtonSize;
    final w = width ?? height;
    final iconSize = (math.min(w, height) * 0.5).clamp(18.0, 30.0);
    final useCircle = circular && (w - height).abs() < 0.5;
    final corner = (math.min(w, height) * 0.22).clamp(4.0, 12.0);
    final disabled = onPressed == null;
    final outlineSideResolved = outlineSide != null
        ? BorderSide(
            color: outlineSide!.color.withValues(alpha: disabled ? 0.45 : 1.0),
            width: outlineSide!.width,
          )
        : _defaultChromeOutlineSide(context, disabled: disabled);
    final ShapeBorder shapeBorder = useCircle
        ? CircleBorder(side: outlineSideResolved)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(corner),
            side: outlineSideResolved,
          );
    final core = Material(
      color: backgroundColor,
      shape: shapeBorder,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shapeBorder,
        child: SizedBox(
          width: w,
          height: height,
          child: Icon(icon, color: foregroundColor, size: iconSize),
        ),
      ),
    );
    if (tooltip != null && tooltip!.isNotEmpty) {
      return Tooltip(
        message: tooltip!,
        waitDuration: const Duration(milliseconds: 400),
        child: core,
      );
    }
    return core;
  }
}

/// Текстовая кнопка навигации (книга / глава): размеры задаёт родитель (как у остальных ячеек панели).
class ChromeNavTextButton extends StatelessWidget {
  const ChromeNavTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    required this.backgroundColor,
    required this.width,
    required this.height,
    this.outlineSide,
  });

  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color backgroundColor;
  final double width;
  final double height;

  /// Если null — [ChromeOutline.side].
  final BorderSide? outlineSide;

  @override
  Widget build(BuildContext context) {
    final fontSize = (height * 0.34).clamp(11.0, 16.0);
    final corner = (math.min(width, height) * 0.22).clamp(4.0, 12.0);
    final radius = BorderRadius.circular(corner);
    final textStyle = TextStyle(
      color: foregroundColor,
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
    );
    return Material(
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: outlineSide ?? _defaultChromeOutlineSide(context, disabled: false),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: radius,
        child: SizedBox(
          width: width,
          height: height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: textStyle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
