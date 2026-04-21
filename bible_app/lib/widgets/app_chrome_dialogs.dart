import 'package:bible_app/journal/parallel_reading_plan_data.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/notebook_chrome_dialog_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Снимает один маршрут с навигатора не более одного раза (двойной клик не уводит
/// со стека экран под диалогом — чёрный экран).
class _PopRouteOnce extends StatefulWidget {
  const _PopRouteOnce({
    required this.navigatorContext,
    required this.builder,
  });

  final BuildContext navigatorContext;
  final Widget Function(BuildContext context, VoidCallback popOnce) builder;

  @override
  State<_PopRouteOnce> createState() => _PopRouteOnceState();
}

class _PopRouteOnceState extends State<_PopRouteOnce> {
  bool _used = false;

  void _popOnce() {
    if (_used) return;
    _used = true;
    final c = widget.navigatorContext;
    if (c.mounted && Navigator.of(c).canPop()) {
      Navigator.pop(c);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _popOnce);
  }
}

/// Деления на ползунках настроек — короткие вертикальные линии вместо круглых точек.
class _SettingsSliderVerticalTickMarkShape extends SliderTickMarkShape {
  const _SettingsSliderVerticalTickMarkShape();

  static const double _lineWidth = 1.2;

  @override
  Size getPreferredSize({
    required SliderThemeData sliderTheme,
    required bool isEnabled,
  }) {
    final th = sliderTheme.trackHeight ?? 4.0;
    final h = (th * 2.0).clamp(6.0, 10.0);
    return Size(_lineWidth, h);
  }

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required Animation<double> enableAnimation,
    required TextDirection textDirection,
    required Offset thumbCenter,
    required bool isEnabled,
  }) {
    assert(sliderTheme.disabledActiveTickMarkColor != null);
    assert(sliderTheme.disabledInactiveTickMarkColor != null);
    assert(sliderTheme.activeTickMarkColor != null);
    assert(sliderTheme.inactiveTickMarkColor != null);
    final double xOffset = center.dx - thumbCenter.dx;
    final (Color? begin, Color? end) = switch (textDirection) {
      TextDirection.ltr when xOffset > 0 => (
          sliderTheme.disabledInactiveTickMarkColor,
          sliderTheme.inactiveTickMarkColor,
        ),
      TextDirection.rtl when xOffset < 0 => (
          sliderTheme.disabledInactiveTickMarkColor,
          sliderTheme.inactiveTickMarkColor,
        ),
      TextDirection.ltr || TextDirection.rtl => (
          sliderTheme.disabledActiveTickMarkColor,
          sliderTheme.activeTickMarkColor,
        ),
    };
    final paint = Paint()
      ..color = ColorTween(begin: begin, end: end).evaluate(enableAnimation)!;
    final sz = getPreferredSize(isEnabled: isEnabled, sliderTheme: sliderTheme);
    context.canvas.drawRect(
      Rect.fromCenter(center: center, width: sz.width, height: sz.height),
      paint,
    );
  }
}

void showAppSettingsDialog(BuildContext context) {
  final appProvider = Provider.of<AppProvider>(context, listen: false);

  showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      ThemeMode selectedTheme = appProvider.themeMode;
      double fontSize = appProvider.fontSize;
      double lineHeight = appProvider.lineHeight;
      double verseSpacing = appProvider.verseSpacing;
      bool showSeptuagintText = appProvider.showSeptuagintText;
      bool keepScreenOn = appProvider.keepScreenOn;
      String fontPreset = appProvider.verseFontPreset;
      if (!AppProvider.verseFontLabels.containsKey(fontPreset)) {
        fontPreset = 'sans';
      }
      double chromeBtnSize = appProvider.chromeButtonSize;

      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Consumer<AppProvider>(
            builder: (consumerContext, _, __) {
              // Держим локальное значение в синхроне с провайдером, чтобы якорь и
              // геометрия панели пересчитывались сразу при изменении размера кнопок.
              chromeBtnSize = appProvider.chromeButtonSize;
              final theme = Theme.of(consumerContext);
              final scheme = theme.colorScheme;
              final isDark = theme.brightness == Brightness.dark;
              final settingsBg =
                  isDark ? const Color(0xFF37474F) : const Color(0xFFE1F5FE);

              final uiFs = fontSize.clamp(12.0, 28.0);
              final kSettingsTitleStyle = TextStyle(
                fontSize: (uiFs * 1.25).clamp(16.0, 32.0),
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              );
              final kSettingsHeadingStyle = TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: (uiFs * 0.9).clamp(12.0, 26.0),
                color: scheme.onSurface,
              );
              final kSettingsBodyStyle = TextStyle(
                fontSize: uiFs,
                color: scheme.onSurface,
              );
              final kSettingsSegmentTextStyle = TextStyle(
                fontSize: (uiFs * 0.92).clamp(12.0, 24.0),
              );
              const kSegIcon = 18.0;

              SliderThemeData sliderDecor(SliderThemeData base) =>
                  base.copyWith(
                    activeTrackColor: scheme.primary,
                    inactiveTrackColor: isDark
                        ? scheme.surfaceContainerHighest
                        : Colors.blue.shade100,
                    thumbColor: scheme.primary,
                    overlayColor: scheme.primary.withValues(alpha: 0.12),
                    tickMarkShape: const _SettingsSliderVerticalTickMarkShape(),
                    activeTickMarkColor:
                        isDark ? scheme.primary : Colors.blue.shade900,
                    inactiveTickMarkColor: isDark
                        ? scheme.onSurface.withValues(alpha: 0.38)
                        : Colors.blue.shade600,
                    disabledActiveTickMarkColor: Colors.grey.shade600,
                    disabledInactiveTickMarkColor: Colors.grey.shade500,
                  );

              final panelWidth = ((MediaQuery.sizeOf(consumerContext).width - 12) * (2 / 3))
                  .clamp(300.0, 362.5);
              final topAnchor = MediaQuery.paddingOf(consumerContext).top +
                  AppProvider.toolbarHeightForChrome(chromeBtnSize);
              final maxBodyHeight = (MediaQuery.sizeOf(consumerContext).height -
                      topAnchor -
                      24)
                  .clamp(220.0, 640.0);

              return Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => Navigator.pop(modalContext),
                    ),
                  ),
                  Positioned(
                    top: topAnchor,
                    right: 0,
                    child: SizedBox(
                      width: panelWidth,
                      child: Material(
                        color: settingsBg,
                        elevation: 10,
                        borderRadius: BorderRadius.circular(12),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Настройки',
                                      style: kSettingsTitleStyle,
                                    ),
                                  ),
                                  _PopRouteOnce(
                                    navigatorContext: modalContext,
                                    builder: (c, popOnce) =>
                                        NotebookChromeDialogCloseButton(
                                      onPressed: popOnce,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              ConstrainedBox(
                                constraints: BoxConstraints(maxHeight: maxBodyHeight),
                                child: SingleChildScrollView(
                                  padding: const EdgeInsets.fromLTRB(2, 2, 2, 2),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                              Text(
                                'Размер шрифта',
                                style: kSettingsHeadingStyle,
                              ),
                              const SizedBox(height: 4),
                              SliderTheme(
                                data: sliderDecor(
                                    SliderTheme.of(consumerContext)),
                                child: Slider(
                                  padding: EdgeInsets.zero,
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
                              const SizedBox(height: 5),
                              Text(
                                'Межстрочный интервал',
                                style: kSettingsHeadingStyle,
                              ),
                              SliderTheme(
                                data: sliderDecor(
                                    SliderTheme.of(consumerContext)),
                                child: Slider(
                                  padding: EdgeInsets.zero,
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
                              const SizedBox(height: 5),
                              Text(
                                'Интервал между стихами',
                                style: kSettingsHeadingStyle,
                              ),
                              SliderTheme(
                                data: sliderDecor(
                                    SliderTheme.of(consumerContext)),
                                child: Slider(
                                  padding: EdgeInsets.zero,
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
                              Text(
                                'Шрифт текста',
                                style: kSettingsHeadingStyle,
                              ),
                              const SizedBox(height: 4),
                              SizedBox(
                                height: chromeBtnSize,
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  isDense: true,
                                  itemHeight: chromeBtnSize,
                                  value: fontPreset,
                                  style: kSettingsBodyStyle,
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.75),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: ChromeOutline.side,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: ChromeOutline.side,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: ChromeOutline.side.copyWith(
                                        width: ChromeOutline.width + 0.3,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 0,
                                    ),
                                  ),
                                  items: AppProvider.verseFontLabels.entries
                                      .map(
                                        (e) => DropdownMenuItem<String>(
                                          value: e.key,
                                          child: Text(
                                            e.value,
                                            overflow: TextOverflow.ellipsis,
                                            style: kSettingsBodyStyle,
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
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Размер кнопок',
                                style: kSettingsHeadingStyle,
                              ),
                              SliderTheme(
                                data: sliderDecor(
                                    SliderTheme.of(consumerContext)),
                                child: Slider(
                                  padding: EdgeInsets.zero,
                                  value: chromeBtnSize.clamp(
                                    AppProvider.chromeButtonSizeMin,
                                    AppProvider.chromeButtonSizeMax,
                                  ),
                                  min: AppProvider.chromeButtonSizeMin,
                                  max: AppProvider.chromeButtonSizeMax,
                                  divisions: 24,
                                  label: chromeBtnSize.round().toString(),
                                  onChanged: (value) {
                                    setModalState(() => chromeBtnSize = value);
                                    appProvider.changeChromeButtonSize(value);
                                  },
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Тема',
                                style: kSettingsHeadingStyle,
                              ),
                              const SizedBox(height: 4),
                              SegmentedButton<ThemeMode>(
                                segments: <ButtonSegment<ThemeMode>>[
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.light,
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Светлая',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: kSettingsSegmentTextStyle,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.light_mode_outlined,
                                      size: kSegIcon,
                                    ),
                                  ),
                                  ButtonSegment<ThemeMode>(
                                    value: ThemeMode.dark,
                                    label: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Тёмная',
                                        maxLines: 1,
                                        softWrap: false,
                                        style: kSettingsSegmentTextStyle,
                                      ),
                                    ),
                                    icon: const Icon(
                                      Icons.dark_mode_outlined,
                                      size: kSegIcon,
                                    ),
                                  ),
                                ],
                                style: SegmentedButton.styleFrom(
                                  textStyle: kSettingsSegmentTextStyle,
                                ).copyWith(
                                  backgroundColor:
                                      WidgetStateProperty.resolveWith<Color?>(
                                    (states) {
                                      if (states
                                          .contains(WidgetState.selected)) {
                                        return scheme.surfaceContainerHighest
                                            .withValues(alpha: 0.75);
                                      }
                                      return null;
                                    },
                                  ),
                                  side: const WidgetStatePropertyAll(
                                    ChromeOutline.side,
                                  ),
                                ),
                                selected: <ThemeMode>{selectedTheme},
                                onSelectionChanged: (Set<ThemeMode> next) {
                                  if (next.isEmpty) return;
                                  final m = next.first;
                                  setModalState(() => selectedTheme = m);
                                  appProvider.setThemeMode(m);
                                },
                              ),
                              const SizedBox(height: 4),
                              SwitchListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Септуагинта [ ]',
                                  style: kSettingsBodyStyle,
                                ),
                                value: showSeptuagintText,
                                activeThumbColor: scheme.primary,
                                onChanged: (value) {
                                  setModalState(
                                    () => showSeptuagintText = value,
                                  );
                                  appProvider.setShowSeptuagintText(value);
                                },
                              ),
                              SwitchListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Не выключать экран',
                                  style: kSettingsBodyStyle,
                                ),
                                value: keepScreenOn,
                                activeThumbColor: scheme.primary,
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
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
    },
    transitionBuilder: (ctx, animation, secondaryAnimation, child) => FadeTransition(
      opacity: CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
      child: child,
    ),
  );
}

void showAppSupportDialog(BuildContext context) {
  const supportPayload = 'Автор проекта: Софеин Павел Геннадьевич\n'
      'Контактная почта: sfpavelg@gmail.com\n'
      'Версия проекта: ver_28_03_2026';

  showDialog<void>(
    context: context,
    builder: (routeContext) {
      final theme = Theme.of(routeContext);
      final scheme = theme.colorScheme;
      final app = routeContext.watch<AppProvider>();
      final body = theme.textTheme.bodyMedium!.copyWith(
        color: scheme.onSurface,
        fontSize: app.fontSize,
        height: app.lineHeight,
      );
      final chrome = app.chromeButtonSize;
      final copyIcon = (chrome * 0.5).clamp(18.0, 30.0);
      return AlertDialog(
        backgroundColor: scheme.surface,
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Техподдержка',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: scheme.onSurface),
              ),
            ),
            _PopRouteOnce(
              navigatorContext: routeContext,
              builder: (c, popOnce) =>
                  NotebookChromeDialogCloseButton(onPressed: popOnce),
            ),
          ],
        ),
        content: DefaultTextStyle(
          style: body,
          child: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Автор проекта:'),
                const SizedBox(height: 4),
                Text(
                  'Софеин Павел Геннадьевич',
                  style: body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text('Контактная почта:'),
                const SizedBox(height: 4),
                Text(
                  'sfpavelg@gmail.com',
                  style: body.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                const Text('Версия проекта:'),
                const SizedBox(height: 4),
                Text(
                  'ver_28_03_2026',
                  style: body.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        actions: [
          Material(
            color: NotebookChromeUi.secondaryButtonBackground(routeContext),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: ChromeOutline.side,
            ),
            clipBehavior: Clip.antiAlias,
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
              child: SizedBox(
                width: chrome,
                height: chrome,
                child: Icon(
                  Icons.copy_all,
                  size: copyIcon,
                  color:
                      NotebookChromeUi.secondaryButtonForeground(routeContext),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Заголовки разделов в окне «Помощь» (оглавление).
const TextStyle _helpDialogTocStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontStyle: FontStyle.italic,
);

void showAppHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (routeContext) {
      final theme = Theme.of(routeContext);
      final scheme = theme.colorScheme;
      final app = routeContext.watch<AppProvider>();
      final fs = app.fontSize;
      final lh = app.lineHeight;
      final tocStyle = _helpDialogTocStyle.copyWith(
        color: scheme.onSurface,
        fontSize: (fs * 0.95).clamp(12.0, 26.0),
        height: lh,
      );
      final bodyStyle = theme.textTheme.bodyMedium!.copyWith(
        color: scheme.onSurface,
        fontSize: fs,
        height: lh,
      );
      final n = kParallelReadingPlan365.length;
      final helpMaxH = MediaQuery.sizeOf(routeContext).height * 0.65;
      return AlertDialog(
        backgroundColor: scheme.surface,
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
        title: Row(
          children: [
            Expanded(
              child: Text(
                'Помощь',
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: scheme.onSurface),
              ),
            ),
            _PopRouteOnce(
              navigatorContext: routeContext,
              builder: (c, popOnce) =>
                  NotebookChromeDialogCloseButton(onPressed: popOnce),
            ),
          ],
        ),
        content: DefaultTextStyle(
          style: bodyStyle,
          child: SizedBox(
            width: 360,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: helpMaxH),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Библия:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Навигация',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Книгу и главу выбирают кнопки в верхней полосе.',
                    ),
                    Text(
                      '• Листать главу за главой можно жестом влево или вправо.',
                    ),
                    Text(
                      '• Долгое касание стиха включает выделение; коротким касанием отмечают ещё стихи.',
                    ),
                    Text(
                      '• «Избранное» в шапке сохраняет выбранные стихи и открывает их перечень.',
                    ),
                    Text(
                      '• В окнах выбора книги или главы закрыть подсказку можно кнопкой в углу заголовка.',
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Поиск',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Введите одно слово или несколько и нажмите «Найти».',
                    ),
                    Text(
                      '• Флажки «ВЗ» и «НЗ» ограничивают поиск Ветхим или Новым Заветом.',
                    ),
                    Text(
                      '• При включённом «Целом слове» находятся только отдельные слова целиком; '
                      'если выключить, подойдёт и вхождение внутри слова '
                      '(например, по «рад» откроется и «радость»).',
                    ),
                    Text(
                      '• По строке из списка результатов открывается соответствующий стих.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Блокнот:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Список файлов и папок:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• Стрелка «Назад» слева в папке возвращает к внешнему списку.',
                    ),
                    Text(
                      '• «Новая папка» создаёт каталог там, где вы сейчас просматриваете список.',
                    ),
                    Text(
                      '• «Новый документ» — новая текстовая заметка; после создания откроется редактор.',
                    ),
                    Text(
                      '• Три точки справа в шапке открывают общее меню приложения '
                      '(настройки, помощь, выход и другое).',
                    ),
                    Text(
                      '• В настройках можно сменить тему, шрифт и интервалы в Библии, красные буквы, '
                      'величину кнопок панели и включить «Не выключать экран».',
                    ),
                    Text(
                      '• Короткое касание открывает файл или папку.',
                    ),
                    Text(
                      '• Долгое касание файла или папки открывает меню справа: для файла — '
                      'поделиться, сохранить копию, переименовать или удалить; '
                      'для папки — переименовать или удалить.',
                    ),
                    Text(
                      '• Перемещение файла: долгим касанием откройте меню файла, выберите '
                      '«Переместить в…», затем перейдите в нужную папку в дереве и нажмите '
                      '«Переместить сюда». Исходная папка отмечена серым цветом.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Редактор документа:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '• «Закрыть» (стрелка) — сохранить изменения и вернуться к списку.',
                    ),
                    Text(
                      '• После паузы в наборе текст автоматически записывается на диск; '
                      'кнопка «Сохранить» в шапке сохраняет немедленно.',
                    ),
                    Text(
                      '• «Шаг назад» и «Шаг вперёд» отменяют или возвращают последние правки в тексте.',
                    ),
                    Text(
                      '• В списке при входе в папку внизу показана строка «Папка:» — путь от корня блокнота; '
                      'по сегментам пути можно нажимать и быстро переходить в выбранную папку '
                      '(с возвратом на нужный уровень).',
                    ),
                    Text(
                      '• В редакторе строка «Документ:» внизу напоминает полный путь к заметке, '
                      'со всеми вложенными папками.',
                    ),
                    Text(
                      '• Вертикальные три точки в шапке редактора ведут в то же общее меню приложения.',
                    ),
                    Text(
                      '• Текст набирается во всю ширину экрана; стихи из вкладки «Библия» можно '
                      'скопировать и вставить сюда.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'План чтения:',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '• Сначала показаны четыре квартала года; внутри каждого — подряд все дни '
                      'этой четверти. Номера дней сквозные, на весь год (1…$n). '
                      'На экране кварталов в шапке — выбор плана и меню; внутри квартала — прокрутка списка '
                      'и переход к началу или концу перечня.',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Параллельный план',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ветхий Завет, Псалтирь и Новый Завет читаются рядом, по заранее выстроенному '
                      'порядку глав на каждый день. Нумерация дней идёт подряд (1…$n), без привязки к датам '
                      'календаря. Отметки «прочитано» хранятся на вашем устройстве.',
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Хронологический план',
                      style: tocStyle,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Здесь порядок глав приближён к ходу событий и к сопутствующим текстам. '
                      'Дни снова идут подряд (1…$n), вне календарных дат. '
                      'Отметки «прочитано» не смешиваются с параллельным планом.',
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
