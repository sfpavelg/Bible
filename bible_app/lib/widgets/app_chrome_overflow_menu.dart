import 'dart:async';
import 'dart:math' as math;

import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/utils/app_exit.dart';
import 'package:bible_app/widgets/app_chrome_dialogs.dart';
import 'package:bible_app/widgets/chrome_frost_glass_panel.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/notebook_chrome_dialog_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Меню «⋯»: кнопка наследует цвета хрома ([iconColor] / [backgroundColor]),
/// выпадающий список следует светлой/тёмной теме приложения.
class AppChromeOverflowMenu extends StatefulWidget {
  const AppChromeOverflowMenu({
    super.key,
    this.iconColor = BibleLightPalette.iconActive,
    this.backgroundColor = BibleLightPalette.chromePillFill,
    this.tileWidth,
    this.shapeSide,
  });

  /// Иконка и фон **квадратной кнопки** «⋯» (как у ChromeIconButton).
  final Color iconColor;
  final Color backgroundColor;

  /// Ширина кнопки «⋯»; по умолчанию [AppProvider.chromeButtonSize].
  final double? tileWidth;

  /// Обводка кнопки; по умолчанию [ChromeOutline.side].
  final BorderSide? shapeSide;

  @override
  State<AppChromeOverflowMenu> createState() => _AppChromeOverflowMenuState();
}

class _AppChromeOverflowMenuState extends State<AppChromeOverflowMenu> {
  Future<void> _openMenu(BuildContext context) async {
    final app = context.read<AppProvider>();
    final safeTop = MediaQuery.paddingOf(context).top;
    final toolbarH = AppProvider.toolbarHeightForChrome(app.chromeButtonSize);
    // Контент начинается ниже закруглённой нижней кромки AppBar.
    // Привязываем меню к верхней кромке области текста, чтобы исключить наезд.
    final topAnchor = safeTop + toolbarH + 24;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final value = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 140),
      pageBuilder: (dialogContext, _, __) {
        Widget menuTile(String route, String label, IconData icon) {
          return InkWell(
            onTap: () => Navigator.pop(dialogContext, route),
            child: chromePopupMenuChoiceTile(
              context: dialogContext,
              label: label,
              icon: icon,
            ),
          );
        }

        final menuBody = Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              menuTile('settings', 'Настройки', Icons.settings_outlined),
              const SizedBox(height: 4),
              menuTile(
                'support',
                'Техподдержка',
                Icons.support_agent_outlined,
              ),
              const SizedBox(height: 4),
              menuTile('help', 'Инструкция', Icons.help_outline_rounded),
              const SizedBox(height: 4),
              menuTile('exit', 'Выход', Icons.logout_rounded),
            ],
          ),
        );

        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(dialogContext),
                child: ColoredBox(
                  color: isDark
                      ? const Color(0x8A000000)
                      : const Color(0x24000000),
                ),
              ),
            ),
            Positioned(
              top: topAnchor,
              right: 0,
              child: IntrinsicWidth(
                child: isDark
                    ? Material(
                        color: const Color(0xFF37474F),
                        elevation: 10,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: menuBody,
                      )
                    : chromeFrostGlassPanelShell(
                        borderRadius: 12,
                        child: menuBody,
                      ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted || value == null) return;
    if (value == 'settings') {
      showAppSettingsDialog(context);
    } else if (value == 'support') {
      showAppSupportDialog(context);
    } else if (value == 'help') {
      showAppHelpDialog(context);
    } else if (value == 'exit') {
      requestAppExit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final s = app.chromeButtonSize.clamp(
            AppProvider.chromeButtonSizeMin, AppProvider.chromeButtonSizeMax);
        final w = widget.tileWidth ?? s;
        final iconSz = (math.min(w, s) * 0.5).clamp(18.0, 30.0);
        final corner = (math.min(w, s) * 0.22).clamp(4.0, 12.0);
        return Material(
          color: widget.backgroundColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(corner),
            side: widget.shapeSide ?? ChromeOutline.side,
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: w,
            height: s,
            child: InkWell(
              onTap: () => unawaited(_openMenu(context)),
              child: Center(
                child: Icon(
                  Icons.more_vert,
                  color: widget.iconColor,
                  size: iconSz,
                ),
              ),
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
  final textIconGap = (fontSize * 2).clamp(18.0, 32.0);
  final hPad = (chrome * 0.30).clamp(10.0, 16.0);
  final vPad = (chrome * 0.18).clamp(7.0, 11.0);
  final minHeight = (chrome * 0.96).clamp(42.0, 62.0);
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final inner = isDark
      ? NotebookChromeUi.secondaryButtonBackground(context)
      : BibleLightPalette.settingsGlassCard;
  final fg = isDark
      ? NotebookChromeUi.secondaryButtonForeground(context)
      : BibleLightPalette.settingsGlassTextPrimary;
  final borderColor = isDark
      ? ChromeOutline.color
      : BibleLightPalette.settingsGlassBorderActive;
  final borderWidth = isDark ? ChromeOutline.width : 1.2;
  final iconColor =
      isDark ? fg : BibleLightPalette.settingsGlassPrimary;
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
            color: borderColor,
            width: borderWidth,
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
                      color: fg,
                    ),
                  ),
                ),
                SizedBox(width: textIconGap),
                Icon(icon, color: iconColor, size: iconSize),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
