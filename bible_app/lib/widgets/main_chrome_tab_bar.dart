import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Горизонтальный зазор между кнопками хрома — как в шапке Библии (`s * 0.12`).
double _chromeToolbarGap(double chrome) => (chrome * 0.12).clamp(4.0, 10.0);

/// Иконка вкладки — тот же масштаб, что у [ChromeIconButton].
double _mainTabIconSize(double chrome) => (chrome * 0.5).clamp(18.0, 30.0);

/// Подпись под иконкой (в широкой плашке можно чуть крупнее).
double _mainTabLabelFont(double chrome) => (chrome * 0.30).clamp(10.0, 14.0);

/// Запас снизу, чтобы обводка не обрезалась у края экрана (половина stroke × 2).
double _mainTabBarBottomBorderReserve() =>
    BibleLightPalette.chromePillOutlineSide.width + 1;

/// Высота содержимого полосы вкладок (без [SafeArea] снизу).
double mainChromeTabBarInteriorHeight(double chrome) {
  final barVerticalInset = (chrome * 0.08).clamp(3.0, 7.0);
  final innerVertical = (chrome * 0.08).clamp(3.0, 7.0);
  final iconLabelGap = (chrome * 0.05).clamp(2.0, 5.0);
  final iconH = _mainTabIconSize(chrome);
  final labelFont = _mainTabLabelFont(chrome);
  final labelLine = labelFont * 1.1;
  return barVerticalInset * 2 +
      _mainTabBarBottomBorderReserve() +
      innerVertical +
      iconH +
      iconLabelGap +
      labelLine;
}

/// Расстояние от низа экрана до зоны над вкладками.
double mainChromeTabBarTotalHeight(BuildContext context) {
  final chrome =
      Provider.of<AppProvider>(context, listen: false).chromeButtonSize;
  return MediaQuery.viewPaddingOf(context).bottom +
      mainChromeTabBarInteriorHeight(chrome);
}

/// Нижняя навигация: те же обводки, что [ChromeIconButton] / [ChromeNavTextButton].
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

  @override
  Widget build(BuildContext context) {
    final chrome = context.watch<AppProvider>().chromeButtonSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final barBg = isDark ? BibleDarkPalette.screenBg : Colors.transparent;
    final buttonBg =
        isDark ? BibleDarkPalette.cardBg : BibleLightPalette.bottomIconBg;
    final fgSelected =
        isDark ? BibleDarkPalette.accentGold : BibleLightPalette.primary;
    final fgUnselected = isDark
        ? BibleDarkPalette.chromeTabInactiveFg
        : BibleLightPalette.iconInactive;

    final outlineSelected = isDark
        ? BibleDarkPalette.chromeButtonOutline
        : BibleLightPalette.chromePillOutlineSide;
    final outlineWidth = outlineSelected.width;
    final outlineUnselected = isDark
        ? BorderSide(
            color: BibleDarkPalette.chromeTabInactiveBorder,
            width: outlineWidth,
          )
        : BorderSide(
            color: BibleLightPalette.chromeTabInactiveBorder,
            width: outlineWidth,
          );

    final corner = (chrome * 0.22).clamp(4.0, 12.0);
    final iconSize = _mainTabIconSize(chrome);
    final labelSize = _mainTabLabelFont(chrome);
    final gap = _chromeToolbarGap(chrome);
    final barVerticalInset = (chrome * 0.08).clamp(3.0, 7.0);
    final bottomInset = barVerticalInset + _mainTabBarBottomBorderReserve();
    final tileVerticalPad = (chrome * 0.06).clamp(2.0, 6.0);
    final tileHorizontalPad = (chrome * 0.10).clamp(4.0, 9.0);
    final iconLabelGap = (chrome * 0.05).clamp(2.0, 5.0);

    final barContent = Material(
      color: barBg,
      elevation: 0,
      shadowColor: Colors.transparent,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            gap,
            barVerticalInset,
            gap,
            bottomInset,
          ),
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
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(corner),
                        side: currentIndex == i
                            ? outlineSelected
                            : outlineUnselected,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => onChanged(i),
                        customBorder: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(corner),
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: tileVerticalPad,
                            horizontal: tileHorizontalPad,
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
                              SizedBox(height: iconLabelGap),
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

    if (isDark) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(
            height: 1,
            thickness: 1,
            color: BibleDarkPalette.divider,
          ),
          barContent,
        ],
      );
    }

    return barContent;
  }
}
