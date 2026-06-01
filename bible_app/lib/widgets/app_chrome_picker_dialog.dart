import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:bible_app/providers/app_provider.dart';

/// Одна строка в списке выбора (день, месяц, глава, стих, книга).
class AppChromePickerOption<T> {
  const AppChromePickerOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Оболочка модальных панелей: фиолетовая обводка (светлая) / золотая (тёмная).
Widget appChromePickerShell(
  BuildContext context, {
  required Widget child,
  double borderRadius = 14,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  if (isDark) {
    return Material(
      color: BibleDarkPalette.cardBg,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BibleDarkPalette.chromeButtonOutline,
      ),
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          boxShadow: BibleDarkPalette.verseCardShadow,
        ),
        child: child,
      ),
    );
  }
  return Material(
    color: BibleLightPalette.activeBg,
    elevation: 0,
    shadowColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(borderRadius),
      side: BibleLightPalette.chromePillOutlineSide,
    ),
    clipBehavior: Clip.antiAlias,
    child: DecoratedBox(
      decoration: const BoxDecoration(
        boxShadow: BibleLightPalette.verseCardShadow,
      ),
      child: child,
    ),
  );
}

/// Диалог с общей рамкой (прозрачный [Dialog] + [appChromePickerShell]).
Future<T?> showAppChromePanelDialog<T>({
  required BuildContext context,
  required Widget child,
  EdgeInsets? insetPadding,
}) {
  return showDialog<T>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: insetPadding ??
          const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: appChromePickerShell(ctx, child: child),
    ),
  );
}

Color appChromeDialogTitleColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? BibleDarkPalette.titleGold : BibleLightPalette.primary;
}

Color appChromeDialogBodyColor(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return isDark ? BibleDarkPalette.primaryText : BibleLightPalette.primaryText;
}

ButtonStyle _timePickerChromeButtonStyle({
  required bool isDark,
  required double chrome,
  double minWidthFactor = 1.8,
}) {
  final outline = isDark
      ? BibleDarkPalette.chromeButtonOutline
      : BibleLightPalette.chromePillOutlineSide;
  final fg = isDark ? BibleDarkPalette.accentGold : BibleLightPalette.primary;
  final fill = isDark ? BibleDarkPalette.screenBg : Colors.white;
  final labelFs = AppProvider.chromeLabelFontSize(chrome);
  return TextButton.styleFrom(
    foregroundColor: fg,
    backgroundColor: fill,
    side: outline,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    minimumSize: Size(chrome * minWidthFactor, chrome),
    padding: EdgeInsets.symmetric(
      horizontal: (chrome * 0.22).clamp(8.0, 16.0),
      vertical: (chrome * 0.16).clamp(4.0, 10.0),
    ),
    textStyle: TextStyle(fontSize: labelFs, fontWeight: FontWeight.w500),
  );
}

ButtonStyle _timePickerChromeIconButtonStyle({
  required bool isDark,
  required double chrome,
}) {
  final outline = isDark
      ? BibleDarkPalette.chromeButtonOutline
      : BibleLightPalette.chromePillOutlineSide;
  final fg = isDark ? BibleDarkPalette.accentGold : BibleLightPalette.primary;
  final fill = isDark ? BibleDarkPalette.screenBg : Colors.white;
  return IconButton.styleFrom(
    foregroundColor: fg,
    backgroundColor: fill,
    side: outline,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    minimumSize: Size(chrome, chrome),
    fixedSize: Size(chrome, chrome),
    padding: EdgeInsets.zero,
  );
}

/// Системный выбор времени в цветах приложения с золотой/фиолетовой рамкой.
Future<TimeOfDay?> showAppChromeTimePicker({
  required BuildContext context,
  required TimeOfDay initialTime,
  String helpText = 'Время напоминания',
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final panelBg = isDark
      ? BibleDarkPalette.cardBg
      : BibleLightPalette.activeBg;
  final outline = isDark
      ? BibleDarkPalette.chromeButtonOutline
      : BibleLightPalette.chromePillOutlineSide;
  const borderRadius = 28.0;
  final entryIconColor =
      isDark ? BibleDarkPalette.accentGold : BibleLightPalette.primary;

  return showTimePicker(
    context: context,
    initialTime: initialTime,
    helpText: helpText,
    builder: (ctx, child) {
      if (child == null) return const SizedBox.shrink();
      final base = Theme.of(ctx);
      return Consumer<AppProvider>(
        builder: (context, app, _) {
          final chrome = app.chromeButtonSize;
          final actionStyle = _timePickerChromeButtonStyle(
            isDark: isDark,
            chrome: chrome,
          );
          final iconStyle = _timePickerChromeIconButtonStyle(
            isDark: isDark,
            chrome: chrome,
          );
          return Theme(
            data: base.copyWith(
              dialogTheme: DialogThemeData(
                backgroundColor: Colors.transparent,
                elevation: 0,
                shadowColor: Colors.transparent,
                surfaceTintColor: Colors.transparent,
                insetPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              ),
              timePickerTheme: TimePickerThemeData(
                backgroundColor: panelBg,
                elevation: 0,
                dialBackgroundColor: isDark
                    ? BibleDarkPalette.modalSectionCardBg
                    : BibleLightPalette.activeBg,
                hourMinuteTextColor: isDark
                    ? BibleDarkPalette.titleGold
                    : BibleLightPalette.primary,
                dayPeriodTextColor: isDark
                    ? BibleDarkPalette.primaryText
                    : BibleLightPalette.primaryText,
                entryModeIconColor: entryIconColor,
                helpTextStyle: TextStyle(
                  fontSize: AppProvider.panelTitleFontSize(app.fontSize),
                  color: isDark
                      ? BibleDarkPalette.titleGold
                      : BibleLightPalette.primary,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                  side: outline,
                ),
                cancelButtonStyle: actionStyle,
                confirmButtonStyle: actionStyle,
              ),
              iconButtonTheme: IconButtonThemeData(style: iconStyle),
            ),
            child: child,
          );
        },
      );
    },
  );
}

/// Компактный список в общем стиле (вместо стандартного [DropdownMenu]).
Future<T?> showAppChromeListPicker<T>({
  required BuildContext context,
  required String title,
  required List<AppChromePickerOption<T>> options,
  T? selected,
  double maxListHeight = 280,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final titleColor =
      isDark ? BibleDarkPalette.titleGold : BibleLightPalette.primary;
  final fg =
      isDark ? BibleDarkPalette.primaryText : BibleLightPalette.primaryText;
  final selectedBg = isDark
      ? BibleDarkPalette.modalSectionCardBg
      : BibleLightPalette.activeBg;

  return showAppChromePanelDialog<T>(
    context: context,
    insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
    child: Builder(
      builder: (ctx) {
        return Consumer<AppProvider>(
          builder: (context, app, _) {
            final uiFs = app.fontSize.clamp(12.0, 28.0);
            final titleFs = AppProvider.panelTitleFontSize(uiFs);
            final rowH = (uiFs * 1.35).clamp(28.0, 44.0);
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                    child: Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: titleFs,
                        height: 1.1,
                        color: titleColor,
                      ),
                    ),
                  ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: maxListHeight),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                      itemCount: options.length,
                      itemExtent: rowH,
                      itemBuilder: (_, i) {
                        final opt = options[i];
                        final isSelected =
                            selected != null && opt.value == selected;
                        return Material(
                          color: isSelected ? selectedBg : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.pop(ctx, opt.value),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                  opt.label,
                                  style: TextStyle(
                                    fontSize: uiFs,
                                    height: 1.15,
                                    color: fg,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    ),
  );
}

/// Поле «как Input», по нажатию открывает [showAppChromeListPicker].
class AppChromePickerField extends StatelessWidget {
  const AppChromePickerField({
    super.key,
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final labelFs = app.fontSize.clamp(12.0, 28.0);
    final fieldLabelFs = (labelFs * 0.86).clamp(10.5, 20.0);
    final chrome = app.chromeButtonSize;
    final padH = (chrome * 0.26).clamp(10.0, 20.0);
    final labelGap = (labelFs * 0.28).clamp(3.0, 8.0);
    final iconSize = (labelFs * 1.35).clamp(18.0, 32.0);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg =
        isDark ? BibleDarkPalette.primaryText : BibleLightPalette.primaryText;
    final labelColor = isDark
        ? BibleDarkPalette.secondaryText
        : BibleLightPalette.secondaryText;
    final fill = isDark ? BibleDarkPalette.screenBg : Colors.white;
    final border = isDark
        ? BibleDarkPalette.cardBorderGold
        : BibleLightPalette.chromePillOutlineSide.color;
    final borderWidth =
        isDark ? 1.0 : BibleLightPalette.chromePillOutlineSide.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: fieldLabelFs,
            height: 1.1,
            color: labelColor,
          ),
        ),
        SizedBox(height: labelGap),
        Material(
          color: fill,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: border, width: borderWidth),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox(
              height: chrome,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: padH),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        valueText,
                        style: TextStyle(
                          fontSize: labelFs,
                          height: 1.1,
                          color: fg,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.arrow_drop_down,
                      size: iconSize,
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Прямоугольная кнопка с обводкой (как поля «День» / «Месяц» и кнопки плана).
class AppChromeRectButton extends StatelessWidget {
  const AppChromeRectButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.borderRadius = 8,
  });

  final String label;
  final VoidCallback? onPressed;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final chrome = app.chromeButtonSize;
    final labelFs = AppProvider.chromeLabelFontSize(chrome);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fill = isDark ? BibleDarkPalette.screenBg : Colors.white;
    final border = isDark
        ? BibleDarkPalette.cardBorderGold
        : BibleLightPalette.chromePillOutlineSide.color;
    final borderWidth =
        isDark ? 1.0 : BibleLightPalette.chromePillOutlineSide.width;
    final labelColor =
        isDark ? BibleDarkPalette.accentGold : BibleLightPalette.primary;

    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        side: BorderSide(color: border, width: borderWidth),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(borderRadius),
        child: SizedBox(
          height: chrome,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (chrome * 0.26).clamp(10.0, 20.0),
              vertical: (chrome * 0.20).clamp(6.0, 14.0),
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: labelFs,
                  fontWeight: FontWeight.w600,
                  height: 1.0,
                  color: labelColor,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
