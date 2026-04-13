import 'dart:math' as math;

import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

  @override
  Widget build(BuildContext context) {
    final height = context.watch<AppProvider>().chromeButtonSize;
    final w = width ?? height;
    final iconSize = (math.min(w, height) * 0.5).clamp(18.0, 30.0);
    final useCircle = circular && (w - height).abs() < 0.5;
    final corner = (math.min(w, height) * 0.22).clamp(4.0, 12.0);
    final disabled = onPressed == null;
    final outlineSide = disabled
        ? BorderSide(
            color: ChromeOutline.color.withValues(alpha: 0.35),
            width: ChromeOutline.width,
          )
        : ChromeOutline.side;
    final ShapeBorder shapeBorder = useCircle
        ? CircleBorder(side: outlineSide)
        : RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(corner),
            side: outlineSide,
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
  });

  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color backgroundColor;
  final double width;
  final double height;

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
        side: ChromeOutline.side,
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
