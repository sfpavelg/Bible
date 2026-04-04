import 'package:bible_app/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Квадратная кнопка хрома: размер из [AppProvider.chromeButtonSize].
class ChromeIconButton extends StatelessWidget {
  const ChromeIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    required this.foregroundColor,
    required this.backgroundColor,
    this.circular = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color foregroundColor;
  final Color backgroundColor;

  /// Круг как у стрелок «пред / след».
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final size = context.watch<AppProvider>().chromeButtonSize;
    final iconSize = (size * 0.5).clamp(18.0, 30.0);
    final radius = circular ? size / 2 : 8.0;
    final core = Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
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

/// Стрелка «пред / след» главы: та же высота, что у остальных кнопок; при узкой [width]
/// форма — эллипс (сжатие по горизонтали вместо масштабирования всей полосы).
class ChromeSliceNavButton extends StatelessWidget {
  const ChromeSliceNavButton({
    super.key,
    required this.width,
    required this.height,
    required this.icon,
    this.onPressed,
    this.tooltip,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final double width;
  final double height;
  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final iconSize = (height * 0.5).clamp(16.0, 30.0);
    final rx = width / 2;
    final ry = height / 2;
    final core = Material(
      color: backgroundColor,
      borderRadius: BorderRadius.all(Radius.elliptical(rx, ry)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.all(Radius.elliptical(rx, ry)),
        child: SizedBox(
          width: width,
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

/// Текстовая кнопка навигации (книга / глава): тот же квадрат [chromeButtonSize], что и иконки.
class ChromeNavTextButton extends StatelessWidget {
  const ChromeNavTextButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String label;
  final VoidCallback onPressed;
  final Color foregroundColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final size = context.watch<AppProvider>().chromeButtonSize;
    final fontSize = (size * 0.34).clamp(11.0, 16.0);
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
