import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Стиль действия в диалогах вкладки «Блокнот».
enum NotebookDialogActionStyle {
  /// Светлая плашка как у кнопок хрома (Отмена).
  cancel,

  /// Основное действие (Создать, Сохранить, Открыть почту).
  confirm,

  /// Уничтожающее действие (Удалить).
  danger,
}

/// Текстовая кнопка в диалоге блокнота: обводка [ChromeOutline], высота из [AppProvider.chromeButtonSize].
class NotebookChromeDialogButton extends StatelessWidget {
  const NotebookChromeDialogButton({
    super.key,
    required this.label,
    required this.onPressed,
    required this.style,
  });

  final String label;
  final VoidCallback? onPressed;
  final NotebookDialogActionStyle style;

  static const _secondaryBg = Color(0xFFE1F5FE);

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final fontSize = (chrome * 0.32).clamp(12.0, 17.0);
    final Color bg;
    final Color fg;
    switch (style) {
      case NotebookDialogActionStyle.cancel:
        bg = _secondaryBg;
        fg = Colors.black87;
      case NotebookDialogActionStyle.confirm:
        bg = Colors.blue;
        fg = Colors.white;
      case NotebookDialogActionStyle.danger:
        bg = Colors.red.shade700;
        fg = Colors.white;
    }
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: ChromeOutline.side,
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
      ),
    );
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
