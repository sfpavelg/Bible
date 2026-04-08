import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/utils/app_exit.dart';
import 'package:bible_app/widgets/app_chrome_dialogs.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Плашки пунктов — тот же оттенок, что у кнопок книги/главы на экране Библии.
const _kMenuTileBg = Color(0xFFE1F5FE);

/// Меню «⋯»: кнопка наследует цвета хрома ([iconColor] / [backgroundColor]),
/// сам выпадающий список всегда светлый — [menuItemIconColor] по умолчанию тёмный.
class AppChromeOverflowMenu extends StatelessWidget {
  const AppChromeOverflowMenu({
    super.key,
    this.iconColor = Colors.black,
    this.backgroundColor = _kMenuTileBg,
    this.menuItemIconColor = const Color(0xDD000000),
  });

  /// Иконка и фон **квадратной кнопки** «⋯» (как у ChromeIconButton).
  final Color iconColor;
  final Color backgroundColor;

  /// Текст и иконки **внутри** выпадающего меню (не зависят от тёмной темы).
  final Color menuItemIconColor;

  @override
  Widget build(BuildContext context) {
    // Только светлая тема для «⋯» и выпадающего списка — как панель «Настройки»,
    // без наследования тёмной темы приложения.
    return Consumer<AppProvider>(
      builder: (context, app, _) {
        final s = app.chromeButtonSize
            .clamp(AppProvider.chromeButtonSizeMin, AppProvider.chromeButtonSizeMax);
        final iconSz = (s * 0.5).clamp(18.0, 30.0);
        return Theme(
          data: ThemeData.light(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            iconTheme: IconThemeData(color: menuItemIconColor),
            popupMenuTheme: PopupMenuThemeData(
              surfaceTintColor: Colors.transparent,
              textStyle: const TextStyle(
                color: Color(0xDD000000),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          child: Material(
            color: backgroundColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: ChromeOutline.side,
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: s,
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
                color: Colors.white,
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
                itemBuilder: (context) => [
                  PopupMenuItem<String>(
                    padding: const EdgeInsets.fromLTRB(8, 8, 8, 3),
                    value: 'settings',
                    child: chromePopupMenuChoiceTile(
                      label: 'Настройки',
                      icon: Icons.settings_outlined,
                      iconColor: menuItemIconColor,
                    ),
                  ),
                  PopupMenuItem<String>(
                    padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                    value: 'support',
                    child: chromePopupMenuChoiceTile(
                      label: 'Техподдержка',
                      icon: Icons.support_agent_outlined,
                      iconColor: menuItemIconColor,
                    ),
                  ),
                  PopupMenuItem<String>(
                    padding: const EdgeInsets.fromLTRB(8, 3, 8, 3),
                    value: 'help',
                    child: chromePopupMenuChoiceTile(
                      label: 'Помощь',
                      icon: Icons.help_outline_rounded,
                      iconColor: menuItemIconColor,
                    ),
                  ),
                  PopupMenuItem<String>(
                    padding: const EdgeInsets.fromLTRB(8, 3, 8, 8),
                    value: 'exit',
                    child: chromePopupMenuChoiceTile(
                      label: 'Выход',
                      icon: Icons.logout_rounded,
                      iconColor: menuItemIconColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Плашка пункта всплывающего меню: тот же вид, что у [AppChromeOverflowMenu].
Widget chromePopupMenuChoiceTile({
  required String label,
  required IconData icon,
  required Color iconColor,
}) {
  return Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(10),
    child: Padding(
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          color: _kMenuTileBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: ChromeOutline.color,
            width: ChromeOutline.width,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: iconColor.withValues(alpha: 0.92),
                ),
              ),
            ),
            Icon(icon, color: iconColor, size: 22),
          ],
        ),
      ),
    ),
  );
}
