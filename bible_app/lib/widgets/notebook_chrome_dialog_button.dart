import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Фон и цвет текста/иконки «вторичных» кнопок хрома — как в разделе «Библия».
abstract final class NotebookChromeUi {
  static const Color _buttonBgDark = Color(0xFF455A64);

  static Color secondaryButtonBackground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? _buttonBgDark
          : BibleLightPalette.chromePillFill;

  static Color secondaryButtonForeground(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : BibleLightPalette.primaryText;
}

/// Стиль действия в диалогах вкладки «Блокнот».
enum NotebookDialogActionStyle {
  /// Светлая плашка как у кнопок хрома (Отмена).
  cancel,

  /// Основное действие (Создать, Сохранить).
  confirm,

  /// Уничтожающее действие (Удалить).
  danger,
}

/// Крестик закрытия в заголовке диалогов (настройки, помощь, техподдержка).
class NotebookChromeDialogCloseButton extends StatelessWidget {
  const NotebookChromeDialogCloseButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final ic = (chrome * 0.5).clamp(18.0, 30.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outlineSide =
        isDark ? ChromeOutline.side : BibleLightPalette.chromePillOutlineSide;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: outlineSide,
    );
    final bg = NotebookChromeUi.secondaryButtonBackground(context);
    final fg = NotebookChromeUi.secondaryButtonForeground(context);
    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: SizedBox(
          width: chrome,
          height: chrome,
          child: Icon(Icons.close, color: fg, size: ic),
        ),
      ),
    );
  }
}

/// Квадратная кнопка в заголовке диалога блокнота:
/// та же высота/ширина [AppProvider.chromeButtonSize], обводка и фон хрома.
/// [onPressed] == null — неактивна (серый значок, без нажатия), как «вверх» в корне Библии.
class NotebookChromeDialogToolbarIconButton extends StatelessWidget {
  const NotebookChromeDialogToolbarIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final ic = (chrome * 0.5).clamp(18.0, 30.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outlineSide =
        isDark ? ChromeOutline.side : BibleLightPalette.chromePillOutlineSide;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: outlineSide,
    );
    final bg = NotebookChromeUi.secondaryButtonBackground(context);
    final baseFg = NotebookChromeUi.secondaryButtonForeground(context);
    final fg = onPressed == null
        ? baseFg.withValues(alpha: Theme.of(context).brightness == Brightness.dark ? 0.32 : 0.38)
        : baseFg;
    final core = Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: SizedBox(
          width: chrome,
          height: chrome,
          child: Icon(icon, color: fg, size: ic),
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

/// Текстовая кнопка в диалоге блокнота: обводка [ChromeOutline], высота из [AppProvider.chromeButtonSize].
class NotebookChromeDialogButton extends StatelessWidget {
  const NotebookChromeDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.style,
    this.expandWidth = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final NotebookDialogActionStyle style;

  /// Если false — ширина по содержимому (одна строка, без переноса слова).
  final bool expandWidth;

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final fontSize = (chrome * 0.32).clamp(12.0, 17.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final outlineSide =
        isDark ? ChromeOutline.side : BibleLightPalette.chromePillOutlineSide;
    final Color bg;
    final Color fg;
    switch (style) {
      case NotebookDialogActionStyle.cancel:
        bg = NotebookChromeUi.secondaryButtonBackground(context);
        fg = NotebookChromeUi.secondaryButtonForeground(context);
      case NotebookDialogActionStyle.confirm:
        bg = isDark ? Colors.blue : BibleLightPalette.primary;
        fg = Colors.white;
      case NotebookDialogActionStyle.danger:
        bg = Colors.red.shade700;
        fg = Colors.white;
    }
    final core = Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: outlineSide,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: chrome * 2.2,
            minHeight: chrome,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (chrome * 0.45).clamp(12.0, 20.0),
              vertical: (chrome * 0.12).clamp(4.0, 8.0),
            ),
            child: Center(
              child: Text(
                label,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: fg,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (expandWidth) {
      return SizedBox(width: double.infinity, child: core);
    }
    return core;
  }
}

/// Ряд из двух кнопок диалога блокнота с промежутком от размера кнопок.
class NotebookChromeDialogActions extends StatelessWidget {
  const NotebookChromeDialogActions({
    super.key,
    required this.startLabel,
    required this.onStart,
    required this.startStyle,
    required this.endLabel,
    required this.onEnd,
    required this.endStyle,
  });

  final String startLabel;
  final VoidCallback? onStart;
  final NotebookDialogActionStyle startStyle;
  final String endLabel;
  final VoidCallback? onEnd;
  final NotebookDialogActionStyle endStyle;

  @override
  Widget build(BuildContext context) {
    final gap = (context.watch<AppProvider>().chromeButtonSize * 0.2)
        .clamp(6.0, 12.0);
    return SizedBox(
      width: double.infinity,
      child: Row(
        children: [
          Expanded(
            child: NotebookChromeDialogButton(
              label: startLabel,
              onPressed: onStart,
              style: startStyle,
            ),
          ),
          SizedBox(width: gap),
          Expanded(
            child: NotebookChromeDialogButton(
              label: endLabel,
              onPressed: onEnd,
              style: endStyle,
            ),
          ),
        ],
      ),
    );
  }
}
