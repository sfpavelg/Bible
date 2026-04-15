import 'dart:math' as math;

import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/utils/app_exit.dart';
import 'package:bible_app/widgets/app_chrome_dialogs.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/notebook_chrome_dialog_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Меню «⋯»: кнопка наследует цвета хрома ([iconColor] / [backgroundColor]),
/// выпадающий список следует светлой/тёмной теме приложения.
class AppChromeOverflowMenu extends StatelessWidget {
  const AppChromeOverflowMenu({
    super.key,
    this.iconColor = Colors.black,
    this.backgroundColor = const Color(0xFFE1F5FE),
    this.tileWidth,
  });

  /// Иконка и фон **квадратной кнопки** «⋯» (как у ChromeIconButton).
  final Color iconColor;
  final Color backgroundColor;

  /// Ширина кнопки «⋯»; по умолчанию [AppProvider.chromeButtonSize].
  final double? tileWidth;

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final s = app.chromeButtonSize.clamp(
            AppProvider.chromeButtonSizeMin, AppProvider.chromeButtonSizeMax);
        final w = tileWidth ?? s;
        final iconSz = (math.min(w, s) * 0.5).clamp(18.0, 30.0);
        final corner = (math.min(w, s) * 0.22).clamp(4.0, 12.0);
        final scheme = Theme.of(context).colorScheme;
        return Material(
          color: backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(corner),
            side: ChromeOutline.side,
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: w,
            height: s,
            child: PopupMenuButton<String>(
              padding: EdgeInsets.zero,
              icon: Icon(
                Icons.more_vert,
                color: iconColor,
                size: iconSz,
              ),
              tooltip: 'Меню',
              position: PopupMenuPosition.under,
              offset: const Offset(0, 8),
              color: scheme.surfaceContainerHigh,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              onSelected: (value) {
                if (value == 'settings') {
                  showAppSettingsDialog(context);
                } else if (value == 'support') {
                  showAppSupportDialog(context);
                } else if (value == 'help') {
                  showAppHelpDialog(context);
                } else if (value == 'exit') {
                  requestAppExit();
                }
              },
              itemBuilder: (menuContext) => [
                PopupMenuItem<String>(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 3),
                  value: 'settings',
                  child: chromePopupMenuChoiceTile(
                    context: menuContext,
                    label: 'Настройки',
                    icon: Icons.settings_outlined,
                  ),
                ),
                PopupMenuItem<String>(
                  padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                  value: 'support',
                  child: chromePopupMenuChoiceTile(
                    context: menuContext,
                    label: 'Техподдержка',
                    icon: Icons.support_agent_outlined,
                  ),
                ),
                PopupMenuItem<String>(
                  padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                  value: 'help',
                  child: chromePopupMenuChoiceTile(
                    context: menuContext,
                    label: 'Помощь',
                    icon: Icons.help_outline_rounded,
                  ),
                ),
                PopupMenuItem<String>(
                  padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
                  value: 'exit',
                  child: chromePopupMenuChoiceTile(
                    context: menuContext,
                    label: 'Выход',
                    icon: Icons.logout_rounded,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Плашка пункта всплывающего меню — стиль кнопок хрома (как в Библии / блокноте).
Widget chromePopupMenuChoiceTile({
  required BuildContext context,
  required String label,
  required IconData icon,
}) {
  final chrome = context.watch<AppProvider>().chromeButtonSize;
  final iconSize = (chrome * 0.48).clamp(18.0, 30.0);
  final fontSize = (chrome * 0.34).clamp(12.0, 16.0);
  final hPad = (chrome * 0.30).clamp(10.0, 16.0);
  final vPad = (chrome * 0.18).clamp(7.0, 11.0);
  final minHeight = (chrome * 0.96).clamp(42.0, 62.0);
  final inner = NotebookChromeUi.secondaryButtonBackground(context);
  final fg = NotebookChromeUi.secondaryButtonForeground(context);
  return Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: inner,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ChromeOutline.color,
            width: ChromeOutline.width,
          ),
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: fontSize,
                      color: fg.withValues(alpha: 0.92),
                    ),
                  ),
                ),
                Icon(icon, color: fg, size: iconSize),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
