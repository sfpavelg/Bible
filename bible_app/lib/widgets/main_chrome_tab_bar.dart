import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Горизонтальный зазор между кнопками хрома — как в шапке Библии (`s * 0.12`).
double _chromeToolbarGap(double chrome) =>
    (chrome * 0.12).clamp(4.0, 10.0);

/// Иконка вкладки — тот же масштаб, что у [ChromeIconButton].
double _mainTabIconSize(double chrome) =>
    (chrome * 0.5).clamp(18.0, 30.0);

/// Подпись под иконкой (в широкой плашке можно чуть крупнее).
double _mainTabLabelFont(double chrome) =>
    (chrome * 0.30).clamp(10.0, 14.0);

/// Высота содержимого полосы вкладок (без [SafeArea] снизу).
double mainChromeTabBarInteriorHeight(double chrome) {
  const outerVertical = 8.0;
  const innerVertical = 4.0;
  const iconLabelGap = 2.0;
  final iconH = _mainTabIconSize(chrome);
  final labelFont = _mainTabLabelFont(chrome);
  final labelLine = labelFont * 1.1;
  return outerVertical + innerVertical + iconH + iconLabelGap + labelLine;
}

/// Расстояние от низа экрана до зоны над вкладками.
double mainChromeTabBarTotalHeight(BuildContext context) {
  final chrome = Provider.of<AppProvider>(context, listen: false).chromeButtonSize;
  return MediaQuery.viewPaddingOf(context).bottom +
      mainChromeTabBarInteriorHeight(chrome);
}

/// Нижняя навигация: широкие прямоугольные плашки с обводкой [ChromeOutline].
class MainChromeTabBar extends StatelessWidget {
  const MainChromeTabBar({
    super.key,
    required this.currentIndex,
    required this.onChanged,
  });

  final int currentIndex;
  final ValueChanged<int> onChanged;

  static const _icons = [
    Icons.menu_book,
    Icons.note,
    Icons.event_note,
  ];
  static const _labels = ['Библия', 'Блокнот', 'План'];
  static const _tooltips = ['Библия', 'Блокнот', 'План'];

  static const Color _appBarBgLight = Color(0xFFB3E5FC);
  static const Color _buttonBgLight = Color(0xFFE1F5FE);
  static const Color _appBarBgDark = Color(0xFF37474F);
  static const Color _buttonBgDark = Color(0xFF455A64);

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? _appBarBgDark : _appBarBgLight;
    final buttonBg = isDark ? _buttonBgDark : _buttonBgLight;
    final fgSelected = isDark ? const Color(0xFF81D4FA) : Colors.blue.shade800;
    final fgUnselected =
        isDark ? Colors.grey.shade500 : Colors.grey.shade600;
    final corner = (chrome * 0.22).clamp(4.0, 12.0);
    final iconSize = _mainTabIconSize(chrome);
    final labelSize = _mainTabLabelFont(chrome);
    final gap = _chromeToolbarGap(chrome);

    return Material(
      color: barBg,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(gap, 4, gap, 4),
          child: Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(
                  child: Tooltip(
                    message: _tooltips[i],
                    waitDuration: const Duration(milliseconds: 400),
                    child: Material(
                      color: buttonBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(corner),
                        side: ChromeOutline.side,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onChanged(i),
                        customBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(corner),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 2,
                            horizontal: 4,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              SizedBox(
                                height: iconSize,
                                child: Center(
                                  child: Icon(
                                    _icons[i],
                                    size: iconSize,
                                    color: currentIndex == i
                                        ? fgSelected
                                        : fgUnselected,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _labels[i],
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: labelSize,
                                  fontWeight: FontWeight.w600,
                                  height: 1.05,
                                  color: currentIndex == i
                                      ? fgSelected
                                      : fgUnselected,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }
}
