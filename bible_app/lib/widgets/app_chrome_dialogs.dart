import 'dart:math' as math;

import 'package:bible_app/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

void showAppSettingsDialog(BuildContext context) {
  final appProvider = Provider.of<AppProvider>(context, listen: false);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      ThemeMode selectedTheme = appProvider.themeMode;
      double fontSize = appProvider.fontSize;
      double lineHeight = appProvider.lineHeight;
      double verseSpacing = appProvider.verseSpacing;
      bool redLettersEnabled = appProvider.redLettersEnabled;
      bool keepScreenOn = appProvider.keepScreenOn;
      String fontPreset = appProvider.verseFontPreset;
      if (!AppProvider.verseFontLabels.containsKey(fontPreset)) {
        fontPreset = 'sans';
      }

      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          final themeGroup = selectedTheme == ThemeMode.system
              ? ThemeMode.light
              : selectedTheme;

          return Theme(
            data: ThemeData.light(useMaterial3: true).copyWith(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            child: Builder(
              builder: (panelThemeContext) {
                return Material(
                  color: Colors.lightBlue[50],
                  elevation: 10,
                  shadowColor: Colors.black45,
                  clipBehavior: Clip.antiAlias,
                  child: SafeArea(
                    left: false,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Настройки',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Material(
                                color: Colors.lightBlue.shade100,
                                borderRadius: BorderRadius.circular(8),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(8),
                                  onTap: () => Navigator.pop(modalContext),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.blue,
                                        width: 1.2,
                                      ),
                                    ),
                                    child: const Icon(Icons.close, size: 20),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Тема',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                RadioListTile<ThemeMode>(
                                  value: ThemeMode.light,
                                  groupValue: themeGroup,
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Светлая'),
                                  activeColor: Colors.blue,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setModalState(() => selectedTheme = value);
                                    appProvider.setThemeMode(value);
                                  },
                                ),
                                RadioListTile<ThemeMode>(
                                  value: ThemeMode.dark,
                                  groupValue: themeGroup,
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Тёмная'),
                                  activeColor: Colors.blue,
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setModalState(() => selectedTheme = value);
                                    appProvider.setThemeMode(value);
                                  },
                                ),
                                const SizedBox(height: 10),
                                const Text(
                                  'Шрифт текста',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: fontPreset,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.75),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    contentPadding:
                                        const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                  ),
                                  items: AppProvider.verseFontLabels.entries
                                      .map(
                                        (e) => DropdownMenuItem<String>(
                                          value: e.key,
                                          child: Text(
                                            e.value,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value == null) return;
                                    setModalState(() => fontPreset = value);
                                    appProvider.setVerseFontPreset(value);
                                  },
                                ),
                                const SizedBox(height: 12),
                                const Text(
                                  'Размер шрифта',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(panelThemeContext)
                                      .copyWith(
                                    activeTrackColor: Colors.blue,
                                    inactiveTrackColor: Colors.blue.shade100,
                                    thumbColor: Colors.blue,
                                    overlayColor: Colors.blue.withOpacity(0.12),
                                  ),
                                  child: Slider(
                                    value: fontSize.clamp(12.0, 28.0),
                                    min: 12.0,
                                    max: 28.0,
                                    divisions: 16,
                                    label: fontSize.toStringAsFixed(0),
                                    onChanged: (value) {
                                      setModalState(() => fontSize = value);
                                      appProvider.changeFontSize(value);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Межстрочный интервал',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(panelThemeContext)
                                      .copyWith(
                                    activeTrackColor: Colors.blue,
                                    inactiveTrackColor: Colors.blue.shade100,
                                    thumbColor: Colors.blue,
                                    overlayColor: Colors.blue.withOpacity(0.12),
                                  ),
                                  child: Slider(
                                    value: lineHeight.clamp(1.0, 2.2),
                                    min: 1.0,
                                    max: 2.2,
                                    divisions: 12,
                                    label: lineHeight.toStringAsFixed(2),
                                    onChanged: (value) {
                                      setModalState(() => lineHeight = value);
                                      appProvider.changeLineHeight(value);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'Интервал между стихами',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                SliderTheme(
                                  data: SliderTheme.of(panelThemeContext)
                                      .copyWith(
                                    activeTrackColor: Colors.blue,
                                    inactiveTrackColor: Colors.blue.shade100,
                                    thumbColor: Colors.blue,
                                    overlayColor: Colors.blue.withOpacity(0.12),
                                  ),
                                  child: Slider(
                                    value: verseSpacing.clamp(0.0, 28.0),
                                    min: 0.0,
                                    max: 28.0,
                                    divisions: 28,
                                    label: verseSpacing.toStringAsFixed(0),
                                    onChanged: (value) {
                                      setModalState(() => verseSpacing = value);
                                      appProvider.changeVerseSpacing(value);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Красные буквы'),
                                  value: redLettersEnabled,
                                  activeColor: Colors.blue,
                                  onChanged: (value) {
                                    setModalState(
                                      () => redLettersEnabled = value,
                                    );
                                    appProvider.setRedLettersEnabled(value);
                                  },
                                ),
                                SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text('Не выключать экран'),
                                  value: keepScreenOn,
                                  activeColor: Colors.blue,
                                  onChanged: (value) async {
                                    setModalState(() => keepScreenOn = value);
                                    await appProvider.setKeepScreenOn(value);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) {
      final size = MediaQuery.sizeOf(ctx);
      final w = size.width;
      final leftReveal =
          math.min(w * 0.42, math.max(64.0, w * 0.28));
      final panelWidth = size.width - leftReveal;
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return SizedBox(
        width: size.width,
        height: size.height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: leftReveal,
              child: FadeTransition(
                opacity: curved,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => Navigator.of(ctx).pop(),
                  child: ColoredBox(
                    color: Colors.black.withOpacity(0.28),
                  ),
                ),
              ),
            ),
            SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(1, 0),
                end: Offset.zero,
              ).animate(curved),
              child: SizedBox(
                width: panelWidth,
                height: size.height,
                child: child,
              ),
            ),
          ],
        ),
      );
    },
  );
}

void showAppSupportDialog(BuildContext context) {
  const supportPayload =
      'Автор проекта: Софеин Павел Геннадьевич\n'
      'Контактная почта: sfpavelg@gmail.com\n'
      'Версия проекта: ver_28_03_2026';

  showDialog<void>(
    context: context,
    builder: (routeContext) {
      return Theme(
        data: ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        child: Builder(
          builder: (_) {
            return AlertDialog(
              backgroundColor: Colors.lightBlue[50],
              titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              title: Row(
                children: [
                  const Expanded(child: Text('Техподдержка')),
                  Material(
                    color: Colors.lightBlue.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(routeContext),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue, width: 1.2),
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              content: const SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Автор проекта:'),
                    SizedBox(height: 4),
                    Text(
                      'Софеин Павел Геннадьевич',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),
                    Text('Контактная почта:'),
                    SizedBox(height: 4),
                    Text(
                      'sfpavelg@gmail.com',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    SizedBox(height: 12),
                    Text('Версия проекта:'),
                    SizedBox(height: 4),
                    Text(
                      'ver_28_03_2026',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              actions: [
                Material(
                  color: Colors.lightBlue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () async {
                      await Clipboard.setData(
                        const ClipboardData(text: supportPayload),
                      );
                      if (!routeContext.mounted) return;
                      ScaffoldMessenger.of(routeContext).showSnackBar(
                        const SnackBar(
                          content: Text('Данные техподдержки скопированы'),
                        ),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue, width: 1.2),
                      ),
                      child: const Icon(Icons.copy_all, size: 20),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}

void showAppHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (routeContext) {
      return Theme(
        data: ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        child: Builder(
          builder: (_) {
            return AlertDialog(
              backgroundColor: Colors.lightBlue[50],
              titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              title: Row(
                children: [
                  const Expanded(child: Text('Помощь')),
                  Material(
                    color: Colors.lightBlue.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(routeContext),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue, width: 1.2),
                        ),
                        child: const Icon(Icons.close, size: 20),
                      ),
                    ),
                  ),
                ],
              ),
              content: const SizedBox(
                width: 360,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Как пользоваться поиском:'),
                    SizedBox(height: 6),
                    Text('• Введите одно или несколько слов и нажмите "Найти".'),
                    Text('• Флажками ВЗ и НЗ ограничьте область поиска.'),
                    Text('• Нажмите на результат, чтобы перейти к стиху.'),
                    SizedBox(height: 12),
                    Text('Навигация по Библии:'),
                    SizedBox(height: 6),
                    Text('• Кнопки сверху переключают книгу и главу.'),
                    Text('• Свайп влево/вправо листает главы.'),
                    Text('• Долгое нажатие на стих включает выбор и копирование.'),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
