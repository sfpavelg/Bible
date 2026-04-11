import 'dart:math' as math;

import 'package:bible_app/journal/parallel_reading_plan_data.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

/// Фон и иконки квадратных кнопок в шапках диалогов — как «книга / глава» на Библии.
const Color _kChromePanelButtonBg = Color(0xFFE1F5FE);
const Color _kChromePanelButtonFg = Colors.black;

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
      double chromeBtnSize = appProvider.chromeButtonSize;

      return StatefulBuilder(
        builder: (modalContext, setModalState) {
          return Theme(
            data: ThemeData.light(useMaterial3: true).copyWith(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
            ),
            child: Builder(
              builder: (panelThemeContext) {
                const kSettingsTitleStyle =
                    TextStyle(fontSize: 20, fontWeight: FontWeight.w600);
                const kSettingsHeadingStyle =
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 14);
                const kSettingsBodyStyle = TextStyle(fontSize: 15);
                const kCloseBtn = 40.0;
                const kCloseIcon = 20.0;
                const kSegIcon = 18.0;

                SliderThemeData sliderDecor(SliderThemeData base) =>
                    base.copyWith(
                  activeTrackColor: Colors.blue,
                  inactiveTrackColor: Colors.blue.shade100,
                  thumbColor: Colors.blue,
                  overlayColor: Colors.blue.withOpacity(0.12),
                );

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
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
                          child: Row(
                            children: [
                              const Expanded(
                                child: Text(
                                  'Настройки',
                                  style: kSettingsTitleStyle,
                                ),
                              ),
                              _PopRouteOnce(
                                navigatorContext: modalContext,
                                builder: (c, popOnce) => Material(
                                  color: _kChromePanelButtonBg,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: ChromeOutline.side,
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: popOnce,
                                    child: const SizedBox(
                                      width: kCloseBtn,
                                      height: kCloseBtn,
                                      child: Icon(
                                        Icons.close,
                                        size: kCloseIcon,
                                        color: _kChromePanelButtonFg,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Divider(height: 1),
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(10, 6, 10, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Text(
                                  'Размер шрифта',
                                  style: kSettingsHeadingStyle,
                                ),
                                const SizedBox(height: 4),
                                SliderTheme(
                                  data: sliderDecor(
                                      SliderTheme.of(panelThemeContext)),
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
                                const Text(
                                  'Межстрочный интервал',
                                  style: kSettingsHeadingStyle,
                                ),
                                SliderTheme(
                                  data: sliderDecor(
                                      SliderTheme.of(panelThemeContext)),
                                  child: Slider(
                                    padding: EdgeInsets.zero,
                                    value: lineHeight.clamp(1.0, 2.2),
                                    min: 1.0,
                                    max: 2.2,
                                    divisions: 12,
                                    label: lineHeight.toStringAsFixed(2),
                                    onChanged: (value) {
                                      setModalState(
                                          () => lineHeight = value);
                                      appProvider.changeLineHeight(value);
                                    },
                                  ),
                                ),
                                const SizedBox(height: 5),
                                const Text(
                                  'Интервал между стихами',
                                  style: kSettingsHeadingStyle,
                                ),
                                SliderTheme(
                                  data: sliderDecor(
                                      SliderTheme.of(panelThemeContext)),
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
                                const Text(
                                  'Шрифт текста',
                                  style: kSettingsHeadingStyle,
                                ),
                                const SizedBox(height: 4),
                                DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  value: fontPreset,
                                  style: kSettingsBodyStyle.copyWith(
                                    color: Colors.black87,
                                  ),
                                  decoration: InputDecoration(
                                    filled: true,
                                    fillColor: Colors.white.withOpacity(0.75),
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
                                const SizedBox(height: 8),
                                const Text(
                                  'Размер кнопок',
                                  style: kSettingsHeadingStyle,
                                ),
                                SliderTheme(
                                  data: sliderDecor(
                                      SliderTheme.of(panelThemeContext)),
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
                                const Text(
                                  'Тема',
                                  style: kSettingsHeadingStyle,
                                ),
                                const SizedBox(height: 4),
                                SegmentedButton<ThemeMode>(
                                  segments: <ButtonSegment<ThemeMode>>[
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.light,
                                      label: const Text(
                                        'Светлая',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      icon: const Icon(
                                        Icons.light_mode_outlined,
                                        size: kSegIcon,
                                      ),
                                    ),
                                    ButtonSegment<ThemeMode>(
                                      value: ThemeMode.dark,
                                      label: const Text(
                                        'Тёмная',
                                        style: TextStyle(fontSize: 14),
                                      ),
                                      icon: const Icon(
                                        Icons.dark_mode_outlined,
                                        size: kSegIcon,
                                      ),
                                    ),
                                  ],
                                  style: SegmentedButton.styleFrom(
                                    textStyle: const TextStyle(fontSize: 14),
                                  ).copyWith(
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
                                  title: const Text(
                                    'Красные буквы',
                                    style: kSettingsBodyStyle,
                                  ),
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
                                  dense: true,
                                  visualDensity: VisualDensity.compact,
                                  contentPadding: EdgeInsets.zero,
                                  title: const Text(
                                    'Не выключать экран',
                                    style: kSettingsBodyStyle,
                                  ),
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
                child: _PopRouteOnce(
                  navigatorContext: ctx,
                  builder: (c, popOnce) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: popOnce,
                    child: ColoredBox(
                      color: Colors.black.withOpacity(0.28),
                    ),
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
                  _PopRouteOnce(
                    navigatorContext: routeContext,
                    builder: (c, popOnce) => Material(
                      color: _kChromePanelButtonBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: ChromeOutline.side,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: popOnce,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: _kChromePanelButtonFg,
                          ),
                        ),
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
                  color: _kChromePanelButtonBg,
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
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(
                        Icons.copy_all,
                        size: 20,
                        color: _kChromePanelButtonFg,
                      ),
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

/// Заголовки разделов в окне «Помощь» (оглавление).
const TextStyle _helpDialogTocStyle = TextStyle(
  fontWeight: FontWeight.bold,
  fontStyle: FontStyle.italic,
);

void showAppHelpDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (routeContext) {
      return Theme(
        data: ThemeData.light(useMaterial3: true).copyWith(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        ),
        child: Builder(
          builder: (dialogContext) {
            final n = kParallelReadingPlan365.length;
            final helpMaxH =
                MediaQuery.sizeOf(dialogContext).height * 0.65;
            return AlertDialog(
              backgroundColor: Colors.lightBlue[50],
              titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              title: Row(
                children: [
                  const Expanded(child: Text('Помощь')),
                  _PopRouteOnce(
                    navigatorContext: routeContext,
                    builder: (c, popOnce) => Material(
                      color: _kChromePanelButtonBg,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: ChromeOutline.side,
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: popOnce,
                        child: const Padding(
                          padding: EdgeInsets.all(8),
                          child: Icon(
                            Icons.close,
                            size: 20,
                            color: _kChromePanelButtonFg,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 360,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: helpMaxH),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Как пользоваться поиском:',
                          style: _helpDialogTocStyle,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• Введите одно или несколько слов и нажмите "Найти".',
                        ),
                        const Text(
                          '• Флажками ВЗ и НЗ ограничьте область поиска.',
                        ),
                        const Text(
                          '• «Целое слово»: ищутся только отдельные слова целиком. '
                          'Если опция выключена, совпадением считается и вхождение '
                          'внутри другого слова (например, по запросу «рад» '
                          'найдётся и «радость»).',
                        ),
                        const Text(
                          '• Нажмите на результат, чтобы перейти к стиху.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Навигация по Библии:',
                          style: _helpDialogTocStyle,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          '• Кнопки сверху переключают книгу и главу.',
                        ),
                        const Text('• Свайп влево/вправо листает главы.'),
                        const Text(
                          '• Долгое нажатие на стих включает выбор; коротким нажатием отметьте другие стихи.',
                        ),
                        const Text(
                          '• Кнопка «Избранное» в шапке добавляет выбранные стихи в избранное и открывает список.',
                        ),
                        const Text(
                          '• В диалогах выбора книги и главы в заголовке есть кнопка закрытия (крестик).',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Блокнот:',
                          style: _helpDialogTocStyle,
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Список файлов и папок:',
                          style: _helpDialogTocStyle,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• «Назад» слева (в папке) — выйти на уровень вверх.',
                        ),
                        const Text(
                          '• «Новая папка» — создать каталог в текущем месте.',
                        ),
                        const Text(
                          '• «Новый документ» — текстовый файл .txt; после создания откроется редактор.',
                        ),
                        const Text(
                          '• «Обновить список» — перечитать список с диска.',
                        ),
                        const Text(
                          '• Кнопка с тремя точками справа — общее меню приложения '
                          '(настройки, помощь, выход и т.д.).',
                        ),
                        const Text(
                          '• В настройках: тема, шрифт и интервалы в Библии, красные буквы, '
                          'размер кнопок панели, опция «Не выключать экран».',
                        ),
                        const Text(
                          '• Короткое нажатие по файлу или папке — открыть.',
                        ),
                        const Text(
                          '• Долгое нажатие по файлу или папке — меню справа: для файла — '
                          'поделиться, сохранить копию в файл, переименовать, удалить; '
                          'для папки — переименовать, удалить.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Редактор документа:',
                          style: _helpDialogTocStyle,
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '• «Закрыть» (стрелка) — сохранить изменения и вернуться к списку.',
                        ),
                        const Text(
                          '• После паузы в наборе текст автоматически записывается на диск; '
                          'кнопка «Сохранить» в шапке сохраняет немедленно.',
                        ),
                        const Text(
                          '• «Шаг назад» и «Шаг вперёд» — отмена и возврат последних правок в тексте '
                          '(на компьютере часто то же действует Ctrl+Z / Ctrl+Y).',
                        ),
                        const Text(
                          '• В списке, когда вы внутри папки, внизу строка «Папка:» — цепочка вложенных '
                          'папок от корня блокнота (можно выделить и скопировать).',
                        ),
                        const Text(
                          '• В редакторе внизу строка «Документ:» — полный путь к файлу от корня блокнота '
                          'с вложенностью папок.',
                        ),
                        const Text(
                          '• Вертикальные три точки в шапке — общее меню приложения '
                          '(настройки, помощь, выход и т.д.).',
                        ),
                        const Text(
                          '• Поле на весь экран — обычный многострочный текст; можно переключиться '
                          'на вкладку «Библия», скопировать стихи и вставить в документ.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'План чтения:',
                          style: _helpDialogTocStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• Сначала четыре блока кварталов (1–4); внутри квартала — список дней этого '
                          'сегмента, как раньше был весь год. Номера дней по-прежнему сквозные по году (1…$n). '
                          'В шапке на экране кварталов — только выбор плана и меню; внутри квартала — прокрутка и '
                          'кнопки «в начало / в конец» списка.',
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Параллельный план',
                          style: _helpDialogTocStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Чтение Ветхого Завета, Псалтири и Нового Завета параллельно, '
                          'по заранее заданным порядку глав на каждый день. '
                          'Дни пронумерованы по порядку (1…$n), без привязки к календарным датам. '
                          'Отметки «прочитано» сохраняются на устройстве.',
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Хронологический план',
                          style: _helpDialogTocStyle,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Чтение Библии в порядке, близком к хронологии событий и '
                          'связанным с ними текстам. '
                          'Дни пронумерованы по порядку (1…$n), без привязки к календарю. '
                          'Отметки «прочитано» хранятся отдельно от параллельного плана.',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      );
    },
  );
}
