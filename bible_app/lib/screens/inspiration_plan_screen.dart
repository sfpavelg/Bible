import 'dart:async';

import 'package:bible_app/inspiration/holiday_catalog.dart';
import 'package:bible_app/inspiration/inspiration_engine.dart';
import 'package:bible_app/inspiration/inspiration_models.dart';
import 'package:bible_app/inspiration/inspiration_notifications.dart';
import 'package:bible_app/inspiration/inspiration_repository.dart';
import 'package:bible_app/models/bible_model.dart';
import 'package:bible_app/navigation/app_tab_switcher.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/app_bottom_notice.dart';
import 'package:bible_app/widgets/app_chrome_dialogs.dart';
import 'package:bible_app/widgets/app_chrome_picker_dialog.dart';
import 'package:bible_app/widgets/bible_reference_picker_dialogs.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _panelDialogBlockGap = 4.0;

TextStyle _panelDialogTitleStyle(BuildContext context, Color titleColor) {
  final fs = Provider.of<AppProvider>(context, listen: true).fontSize;
  return TextStyle(
    fontWeight: FontWeight.w600,
    fontSize: AppProvider.panelTitleFontSize(fs),
    color: titleColor,
    height: 1.1,
  );
}

TextStyle _panelDialogBodyStyle(BuildContext context, Color bodyColor) {
  final fs = Provider.of<AppProvider>(context, listen: true).fontSize;
  return TextStyle(
    color: bodyColor,
    fontSize: fs.clamp(12.0, 28.0),
    height: 1.1,
  );
}

TextStyle _panelDialogHintStyle(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final fs = Provider.of<AppProvider>(context, listen: true).fontSize;
  final hintColor = isDark
      ? BibleDarkPalette.secondaryText
      : BibleLightPalette.secondaryText;
  return TextStyle(
    color: hintColor,
    fontSize: AppProvider.panelHintFontSize(fs),
    height: 1.25,
    fontWeight: FontWeight.w500,
  );
}

TextStyle _panelDialogSmallStyle(
  BuildContext context,
  Color bodyColor, {
  double alpha = 0.7,
}) {
  final fs = Provider.of<AppProvider>(context, listen: true).fontSize;
  return TextStyle(
    color: bodyColor.withValues(alpha: alpha),
    fontSize: AppProvider.panelHintFontSize(fs),
    height: 1.1,
  );
}

double _panelDialogListRowExtent(BuildContext context) {
  final fs = Provider.of<AppProvider>(context, listen: true).fontSize;
  return (fs * 1.35).clamp(28.0, 44.0);
}

/// Панель настроек плана «Стих для вдохновения» (без кварталов).
class InspirationPlanScreen extends StatefulWidget {
  const InspirationPlanScreen({super.key});

  @override
  State<InspirationPlanScreen> createState() => _InspirationPlanScreenState();
}

class _InspirationPlanScreenState extends State<InspirationPlanScreen> {
  InspirationRepository? _repository;
  final _engine = InspirationEngine();
  InspirationPlanSettings _settings = const InspirationPlanSettings();
  List<InspirationCustomDay> _customDays = [];
  List<InspirationDayEvent> _todayEvents = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = InspirationRepository(prefs);
    final settings = repo.loadSettings();
    final custom = repo.loadCustomDays();
    final deviceSeed = await repo.getOrCreateDeviceSeed();
    final today = await _engine.eventsForDate(
      DateTime.now(),
      settings,
      custom,
      deviceSeed: deviceSeed,
    );
    if (!mounted) return;
    setState(() {
      _repository = repo;
      _settings = settings;
      _customDays = custom;
      _todayEvents = today;
      _loading = false;
    });
    if (settings.remindersEnabled) {
      unawaited(
        InspirationNotificationService.instance.rescheduleIfNeeded(
          repository: repo,
          engine: _engine,
          settings: settings,
          customDays: custom,
        ),
      );
    }
  }

  Future<void> _persistAndRefresh({bool reschedule = false}) async {
    final repo = _repository;
    if (repo == null) return;
    await repo.saveSettings(_settings);
    await repo.saveCustomDays(_customDays);
    final deviceSeed = await repo.getOrCreateDeviceSeed();
    final today = await _engine.eventsForDate(
      DateTime.now(),
      _settings,
      _customDays,
      deviceSeed: deviceSeed,
    );
    if (!mounted) return;
    setState(() => _todayEvents = today);
    if (reschedule || _settings.remindersEnabled) {
      await InspirationNotificationService.instance.rescheduleIfNeeded(
        repository: repo,
        engine: _engine,
        settings: _settings,
        customDays: _customDays,
        force: reschedule,
      );
    }
  }

  Future<void> _onRemindersToggle(bool value) async {
    if (value) {
      final ok = await _showEnableRemindersDialog();
      if (!ok || !mounted) return;
      if (!kIsWeb) {
        final granted = await InspirationNotificationService.instance
            .requestNotificationPermission();
        if (!granted && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Разрешите уведомления в настройках системы, чтобы получать напоминания.',
              ),
            ),
          );
          return;
        }
      }
    } else {
      await InspirationNotificationService.instance.cancelAllScheduled();
    }
    setState(() {
      _settings = _settings.copyWith(
        remindersEnabled: value,
        clearLastRescheduleDate: value,
      );
    });
    await _persistAndRefresh(reschedule: value);
  }

  Future<bool> _showEnableRemindersDialog() async {
    final result = await showAppChromePanelDialog<bool>(
      context: context,
      child: Builder(
        builder: (ctx) {
          final titleColor = appChromeDialogTitleColor(ctx);
          final fg = appChromeDialogBodyColor(ctx);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Ежедневное напоминание',
                  style: _panelDialogTitleStyle(ctx, titleColor),
                ),
                const SizedBox(height: _panelDialogBlockGap),
                Text(
                  'В выбранное время придёт уведомление с полным текстом стиха '
                  '(например, «Ин 3:16» и текст ниже).\n\n'
                  'Данные хранятся только на этом устройстве.',
                  style: _panelDialogBodyStyle(ctx, fg).copyWith(height: 1.2),
                ),
                const SizedBox(height: _panelDialogBlockGap),
                Row(
                  children: [
                    Expanded(
                      child: AppChromeRectButton(
                        label: 'Не сейчас',
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppChromeRectButton(
                        label: 'Включить',
                        onPressed: () => Navigator.pop(ctx, true),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
    return result == true;
  }

  Future<void> _openInBible(InspirationVerseRef ref) async {
    if (!mounted) return;
    requestOpenBibleVerse(
      BibleVerseJumpRequest(
        book: ref.book,
        chapter: ref.chapter,
        verse: ref.verse,
      ),
    );
  }

  Future<void> _pickTime() async {
    final initial = TimeOfDay(
      hour: _settings.notifyTimeMinutes ~/ 60,
      minute: _settings.notifyTimeMinutes % 60,
    );
    final picked = await showAppChromeTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Время напоминания',
    );
    if (picked == null) return;
    setState(() {
      _settings = _settings.copyWith(
        notifyTimeMinutes: picked.hour * 60 + picked.minute,
        clearLastRescheduleDate: true,
      );
    });
    await _persistAndRefresh(reschedule: true);
  }

  Future<void> _showHolidayList() async {
    final year = DateTime.now().year;
    final catalog = HolidayCatalog.instance;
    final items = await catalog.holidaysInYear(
      year,
      orthodox: _settings.useOrthodoxCalendar,
      protestant: _settings.useProtestantCalendar,
    );
    if (!mounted) return;
    await showAppChromePanelDialog<void>(
      context: context,
      child: Builder(
        builder: (ctx) {
          final titleColor = appChromeDialogTitleColor(ctx);
          final bodyColor = appChromeDialogBodyColor(ctx);
          final titleStyle = _panelDialogTitleStyle(ctx, titleColor);
          final bodyStyle = _panelDialogBodyStyle(ctx, bodyColor);
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Праздники $year',
                  style: titleStyle,
                ),
                const SizedBox(height: _panelDialogBlockGap),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: items.isEmpty
                      ? Text(
                          'Включите православный или протестантский календарь.',
                          style: bodyStyle,
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: items.length,
                          itemBuilder: (_, i) {
                            final e = items[i];
                            final d = e.date;
                            final label =
                                '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}  ${e.holiday.name}';
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  label,
                                  style: bodyStyle.copyWith(height: 1.15),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: _panelDialogBlockGap),
                AppChromeRectButton(
                  label: 'Закрыть',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _showCustomDaysList() async {
    if (!mounted) return;
    await showAppChromePanelDialog<void>(
      context: context,
      child: StatefulBuilder(
        builder: (ctx, setDialogState) {
          final titleColor = appChromeDialogTitleColor(ctx);
          final bodyColor = appChromeDialogBodyColor(ctx);
          final titleStyle = _panelDialogTitleStyle(ctx, titleColor);
          final bodyStyle = _panelDialogBodyStyle(ctx, bodyColor);
          final smallStyle = _panelDialogSmallStyle(ctx, bodyColor);
          final smallMutedStyle =
              _panelDialogSmallStyle(ctx, bodyColor, alpha: 0.65);
          final days = List<InspirationCustomDay>.of(_customDays)
            ..sort((a, b) {
              final byMonth = a.month.compareTo(b.month);
              return byMonth != 0 ? byMonth : a.day.compareTo(b.day);
            });
          final showHolidayConflicts = _settings.useOrthodoxCalendar ||
              _settings.useProtestantCalendar;

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Особые дни',
                  style: titleStyle,
                ),
                const SizedBox(height: _panelDialogBlockGap),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 360),
                  child: days.isEmpty
                      ? Text(
                          'Пока нет особых дней.',
                          style: bodyStyle,
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: days.length,
                          itemBuilder: (_, i) {
                            final d = days[i];
                            final dateLabel =
                                '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}';
                            final verseLabel = d.useRandomVerse
                                ? 'случайный стих'
                                : (d.verseRefs.isEmpty
                                    ? null
                                    : () {
                                        final r = d.verseRefs.first;
                                        final abbr = BibleService()
                                            .getBookAbbreviation(r.book);
                                        return '$abbr ${r.chapter}:${r.verse}';
                                      }());
                            Widget row(List<InspirationHolidayDefinition> holidays) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 2),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$dateLabel  ${d.name}',
                                            style: bodyStyle,
                                          ),
                                          if (verseLabel != null)
                                            Text(
                                              verseLabel,
                                              style: smallStyle,
                                            ),
                                          if (holidays.isNotEmpty)
                                            Text(
                                              'совпадает с: ${holidays.map((h) => h.name).join(', ')}',
                                              style: smallMutedStyle,
                                            ),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.edit_outlined),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Изменить',
                                      onPressed: () async {
                                        await _editCustomDay(d);
                                        if (ctx.mounted) {
                                          setDialogState(() {});
                                        }
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      visualDensity: VisualDensity.compact,
                                      tooltip: 'Удалить',
                                      onPressed: () async {
                                        await _deleteCustomDay(d);
                                        if (ctx.mounted) {
                                          setDialogState(() {});
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              );
                            }

                            if (!showHolidayConflicts) {
                              return row(const []);
                            }
                            return FutureBuilder<
                                List<InspirationHolidayDefinition>>(
                              future: _engine.churchHolidaysOnMonthDay(
                                d.month,
                                d.day,
                                orthodox: _settings.useOrthodoxCalendar,
                                protestant: _settings.useProtestantCalendar,
                              ),
                              builder: (context, snap) =>
                                  row(snap.data ?? const []),
                            );
                          },
                        ),
                ),
                const SizedBox(height: _panelDialogBlockGap),
                AppChromeRectButton(
                  label: 'Закрыть',
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _editCustomDay([InspirationCustomDay? existing]) async {
    final result = await showDialog<InspirationCustomDay>(
      context: context,
      builder: (ctx) => _CustomDayEditorDialog(
        existing: existing,
        settings: _settings,
        engine: _engine,
      ),
    );
    if (result == null) return;
    setState(() {
      final idx = _customDays.indexWhere((d) => d.id == result.id);
      if (idx >= 0) {
        _customDays = List.of(_customDays)..[idx] = result;
      } else {
        _customDays = [..._customDays, result];
      }
      _settings = _settings.copyWith(clearLastRescheduleDate: true);
    });
    await _persistAndRefresh(reschedule: true);
  }

  Future<void> _deleteCustomDay(InspirationCustomDay day) async {
    setState(() {
      _customDays = _customDays.where((d) => d.id != day.id).toList();
      _settings = _settings.copyWith(clearLastRescheduleDate: true);
    });
    await _persistAndRefresh(reschedule: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg =
        isDark ? BibleDarkPalette.cardBg : BibleLightPalette.activeBg;
    final border = isDark
        ? BorderSide(color: BibleDarkPalette.cardBorderGold, width: 1)
        : BibleLightPalette.chromePillOutlineSide;
    final titleColor = isDark
        ? BibleDarkPalette.titleGold
        : BibleLightPalette.primary;
    final bodyColor = isDark
        ? BibleDarkPalette.primaryText
        : BibleLightPalette.primaryText;
    final app = context.watch<AppProvider>();
    final chrome = app.chromeButtonSize;
    final sectionTitleFs = AppProvider.panelTitleFontSize(app.fontSize);
    final labelFs = app.fontSize.clamp(12.0, 28.0);
    final labelStyle = TextStyle(
      color: bodyColor,
      fontSize: labelFs,
      height: 1.1,
    );
    final mutedLabelStyle = TextStyle(
      color: bodyColor.withValues(alpha: 0.75),
      fontSize: AppProvider.panelHintFontSize(labelFs),
      height: 1.1,
    );
    const blockGap = 4.0;

    Widget section(String title, List<Widget> children) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.fromBorderSide(border),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: sectionTitleFs,
                    color: titleColor,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: blockGap),
                ...children,
              ],
            ),
          ),
        ),
      );
    }

    final buttonLabelFs = AppProvider.chromeLabelFontSize(chrome);

    Widget outlineActionButton({
      required String label,
      required VoidCallback? onPressed,
    }) {
      final outline = isDark
          ? ChromeOutline.darkSide
          : BibleLightPalette.chromePillOutlineSide;
      final fg = isDark
          ? BibleDarkPalette.accentGold
          : BibleLightPalette.primary;
      return OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          disabledForegroundColor: fg.withValues(alpha: 0.38),
          side: outline,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          minimumSize: Size(double.infinity, chrome),
          padding: EdgeInsets.symmetric(
            horizontal: (chrome * 0.26).clamp(10.0, 20.0),
            vertical: (chrome * 0.20).clamp(6.0, 14.0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: buttonLabelFs,
            fontWeight: FontWeight.w600,
            height: 1.0,
          ),
        ),
      );
    }

    Widget compactSwitch({
      required String title,
      required bool value,
      required ValueChanged<bool> onChanged,
    }) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: Text(title, style: labelStyle)),
          Switch(
            value: value,
            onChanged: onChanged,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ],
      );
    }

    final time = TimeOfDay(
      hour: _settings.notifyTimeMinutes ~/ 60,
      minute: _settings.notifyTimeMinutes % 60,
    );

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        section('Ежедневное напоминание', [
          compactSwitch(
            title: 'Включить напоминания',
            value: _settings.remindersEnabled,
            onChanged: _onRemindersToggle,
          ),
          const SizedBox(height: blockGap),
          InkWell(
            onTap: _settings.remindersEnabled ? _pickTime : null,
            child: Opacity(
              opacity: _settings.remindersEnabled ? 1 : 0.5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Время', style: labelStyle),
                  Text(
                    time.format(context),
                    style: mutedLabelStyle,
                  ),
                ],
              ),
            ),
          ),
        ]),
        section('Сегодня', [
          if (_todayEvents.isEmpty)
            Text('Стих не найден', style: labelStyle)
          else
            ..._todayEvents.map((e) {
              final ref = _engine.formatReference(e.verseRef);
              final subtitle = e.kind == InspirationEventKind.dailyRandom
                  ? null
                  : e.displayName;
              return Padding(
                padding: const EdgeInsets.only(bottom: blockGap),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(ref, style: labelStyle),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: mutedLabelStyle.copyWith(
                          color: bodyColor.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                    const SizedBox(height: blockGap),
                    outlineActionButton(
                      label: 'Открыть в Библии',
                      onPressed: () => _openInBible(e.verseRef),
                    ),
                  ],
                ),
              );
            }),
        ]),
        section('Церковный календарь', [
          compactSwitch(
            title: 'Православные праздники',
            value: _settings.useOrthodoxCalendar,
            onChanged: (v) async {
              setState(() {
                _settings = _settings.copyWith(
                  useOrthodoxCalendar: v,
                  clearLastRescheduleDate: true,
                );
              });
              await _persistAndRefresh(reschedule: true);
            },
          ),
          const SizedBox(height: blockGap),
          compactSwitch(
            title: 'Протестантские праздники',
            value: _settings.useProtestantCalendar,
            onChanged: (v) async {
              setState(() {
                _settings = _settings.copyWith(
                  useProtestantCalendar: v,
                  clearLastRescheduleDate: true,
                );
              });
              await _persistAndRefresh(reschedule: true);
            },
          ),
          const SizedBox(height: blockGap),
          outlineActionButton(
            label: 'Посмотреть список праздников',
            onPressed: (_settings.useOrthodoxCalendar ||
                    _settings.useProtestantCalendar)
                ? _showHolidayList
                : null,
          ),
        ]),
        section('Мои особые дни', [
          outlineActionButton(
            label: 'Просмотреть список дней',
            onPressed: _showCustomDaysList,
          ),
          const SizedBox(height: blockGap),
          outlineActionButton(
            label: '+ Добавить особый день',
            onPressed: () => _editCustomDay(),
          ),
        ]),
        section('Как это работает', [
          Text(
            'В выбранное время приходит короткое напоминание со ссылкой на стих. '
            'В обычный день стих выбирается из всей Библии; в церковный праздник — '
            'из тематического списка этого праздника. Особые дни добавляете вы сами. '
            'Напоминания планируются на 14 дней вперёд и обновляются при открытии приложения.',
            style: mutedLabelStyle,
          ),
          const SizedBox(height: blockGap),
          outlineActionButton(
            label: 'Подробная инструкция',
            onPressed: () => showAppHelpDialog(
              context,
              initialSectionId: 'inspiration_verse',
            ),
          ),
        ]),
      ],
    );
  }
}

class _CustomDayEditorDialog extends StatefulWidget {
  const _CustomDayEditorDialog({
    this.existing,
    required this.settings,
    required this.engine,
  });

  final InspirationCustomDay? existing;
  final InspirationPlanSettings settings;
  final InspirationEngine engine;

  @override
  State<_CustomDayEditorDialog> createState() => _CustomDayEditorDialogState();
}

class _CustomDayEditorDialogState extends State<_CustomDayEditorDialog> {
  late final TextEditingController _nameController;
  late int _month;
  late int _day;
  InspirationVerseRef? _verseRef;
  bool _useRandomVerse = false;
  String? _validationHint;

  bool get _hasVerseChoice => _useRandomVerse || _verseRef != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _month = e?.month ?? DateTime.now().month;
    _day = e?.day ?? DateTime.now().day;
    _useRandomVerse = e?.useRandomVerse ?? false;
    _verseRef =
        (!_useRandomVerse && e != null && e.verseRefs.isNotEmpty)
            ? e.verseRefs.first
            : null;
    _nameController.addListener(_clearValidationHint);
  }

  void _clearValidationHint() {
    if (_validationHint != null) {
      setState(() => _validationHint = null);
    }
  }

  @override
  void dispose() {
    _nameController.removeListener(_clearValidationHint);
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addOrChangeVerse() async {
    final choice = await _pickVerseRef(context);
    if (choice == null) return;
    setState(() {
      if (choice.random) {
        _useRandomVerse = true;
        _verseRef = null;
      } else {
        _useRandomVerse = false;
        _verseRef = choice.ref;
      }
      _validationHint = null;
    });
  }

  void _clearVerseChoice() {
    setState(() {
      _useRandomVerse = false;
      _verseRef = null;
      _validationHint = null;
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty || !_hasVerseChoice) {
      const message = 'Укажите название и выберите стих или «Случайный»';
      setState(() => _validationHint = message);
      showAppBottomNotice(context, message);
      return;
    }
    final holidays = await widget.engine.churchHolidaysOnMonthDay(
      _month,
      _day,
      orthodox: widget.settings.useOrthodoxCalendar,
      protestant: widget.settings.useProtestantCalendar,
    );
    if (!mounted) return;
    if (holidays.isNotEmpty) {
      final proceed = await showAppChromePanelDialog<bool>(
        context: context,
        child: Builder(
          builder: (ctx) {
            final titleColor = appChromeDialogTitleColor(ctx);
            final fg = appChromeDialogBodyColor(ctx);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Совпадение с праздником',
                    style: _panelDialogTitleStyle(ctx, titleColor),
                  ),
                  const SizedBox(height: _panelDialogBlockGap),
                  Text(
                    'На ${_day.toString().padLeft(2, '0')}.${_month.toString().padLeft(2, '0')} уже есть: '
                    '${holidays.map((h) => h.name).join(', ')}.\n\n'
                    'В этот день придут отдельные напоминания по празднику и по этому дню.',
                    style: _panelDialogBodyStyle(ctx, fg).copyWith(height: 1.2),
                  ),
                  const SizedBox(height: _panelDialogBlockGap),
                  Row(
                    children: [
                      Expanded(
                        child: AppChromeRectButton(
                          label: 'Изменить дату',
                          onPressed: () => Navigator.pop(ctx, false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppChromeRectButton(
                          label: 'Сохранить',
                          onPressed: () => Navigator.pop(ctx, true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      );
      if (proceed != true) return;
    }
    final id = widget.existing?.id ??
        'custom_${DateTime.now().microsecondsSinceEpoch}';
    Navigator.pop(
      context,
      InspirationCustomDay(
        id: id,
        name: name,
        month: _month,
        day: _day,
        useRandomVerse: _useRandomVerse,
        verseRefs: _useRandomVerse || _verseRef == null ? const [] : [_verseRef!],
      ),
    );
  }

  Future<void> _pickDay() async {
    final v = await showCalendarDayPickerDialog(
      context: context,
      selectedDay: _day,
    );
    if (v != null) setState(() => _day = v);
  }

  Future<void> _pickMonth() async {
    final v = await showCalendarMonthPickerDialog(
      context: context,
      selectedMonth: _month,
    );
    if (v != null) setState(() => _month = v);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor =
        isDark ? BibleDarkPalette.titleGold : BibleLightPalette.primary;
    final fg =
        isDark ? BibleDarkPalette.primaryText : BibleLightPalette.primaryText;
    final labelFs = app.fontSize.clamp(12.0, 28.0);

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: appChromePickerShell(
        context,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.existing == null
                      ? 'Новый особый день'
                      : 'Редактирование',
                  style: _panelDialogTitleStyle(context, titleColor),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  style: TextStyle(fontSize: labelFs),
                  decoration: const InputDecoration(labelText: 'Название'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: AppChromePickerField(
                        label: 'День',
                        valueText: '$_day',
                        onTap: _pickDay,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppChromePickerField(
                        label: 'Месяц',
                        valueText: calendarMonthLabel(_month),
                        onTap: _pickMonth,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Стих для этого дня:',
                  style: TextStyle(color: fg, fontSize: labelFs),
                ),
                if (_hasVerseChoice)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _useRandomVerse
                          ? 'Случайный стих'
                          : () {
                              final r = _verseRef!;
                              final label =
                                  BibleService().getBookAbbreviation(r.book);
                              return '$label ${r.chapter}:${r.verse}';
                            }(),
                      style: TextStyle(fontSize: labelFs),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: _clearVerseChoice,
                    ),
                  ),
                if (!_hasVerseChoice) ...[
                  const SizedBox(height: 8),
                  AppChromeRectButton(
                    label: '+ Добавить стих',
                    onPressed: _addOrChangeVerse,
                  ),
                ],
                if (_validationHint != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _validationHint!,
                    style: _panelDialogHintStyle(context),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppChromeRectButton(
                        label: 'Отмена',
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AppChromeRectButton(
                        label: 'Сохранить',
                        onPressed: _save,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<InspirationCustomDayVerseChoice?> _pickVerseRef(BuildContext context) async {
  final bible = BibleService();
  var isRandom = false;
  String? book = BibleBook.books.first.name;
  var chapter = 1;
  var verse = 1;

  return showDialog<InspirationCustomDayVerseChoice>(
    context: context,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final isDark = Theme.of(ctx).brightness == Brightness.dark;
          final titleColor =
              isDark ? BibleDarkPalette.titleGold : BibleLightPalette.primary;
          if (!isRandom && book != null) {
            final selectedBook = book!;
            final verses = bible.getVerses(selectedBook, chapter);
            final maxV = verses.isEmpty ? 1 : verses.last.verse;
            if (verse > maxV) verse = maxV;
          }

          final bookLabel =
              isRandom ? 'Случайный' : BibleService().getBookAbbreviation(book!);

          Future<void> pickBook() async {
            final v = await showBibleBookPickerDialog(
              context: ctx,
              selectedBook: isRandom ? null : book,
              includeRandomOption: true,
              randomSelected: isRandom,
            );
            if (v == inspirationRandomBookPickerValue) {
              setLocal(() => isRandom = true);
            } else if (v != null) {
              setLocal(() {
                isRandom = false;
                book = v;
                chapter = 1;
                verse = 1;
              });
            }
          }

          Future<void> pickChapter() async {
            if (isRandom || book == null) return;
            final selectedBook = book!;
            final v = await showBibleChapterPickerDialog(
              context: ctx,
              book: selectedBook,
              selectedChapter: chapter,
            );
            if (v != null) {
              setLocal(() {
                chapter = v;
                verse = 1;
              });
            }
          }

          Future<void> pickVerse() async {
            if (isRandom || book == null) return;
            final selectedBook = book!;
            final v = await showBibleVersePickerDialog(
              context: ctx,
              book: selectedBook,
              chapter: chapter,
              selectedVerse: verse,
            );
            if (v != null) setLocal(() => verse = v);
          }

          return Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: appChromePickerShell(
              ctx,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Выберите стих',
                      style: _panelDialogTitleStyle(ctx, titleColor),
                    ),
                    const SizedBox(height: 12),
                    AppChromePickerField(
                      label: 'Книга',
                      valueText: bookLabel,
                      onTap: pickBook,
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: isRandom ? 0.45 : 1,
                      child: IgnorePointer(
                        ignoring: isRandom,
                        child: AppChromePickerField(
                          label: 'Глава',
                          valueText: isRandom ? '—' : '$chapter',
                          onTap: pickChapter,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Opacity(
                      opacity: isRandom ? 0.45 : 1,
                      child: IgnorePointer(
                        ignoring: isRandom,
                        child: AppChromePickerField(
                          label: 'Стих',
                          valueText: isRandom ? '—' : '$verse',
                          onTap: pickVerse,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: AppChromeRectButton(
                            label: 'Отмена',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: AppChromeRectButton(
                            label: 'Готово',
                            onPressed: () {
                              if (isRandom) {
                                Navigator.pop(
                                  ctx,
                                  const InspirationCustomDayVerseChoice.random(),
                                );
                              } else {
                                final selectedBook = book!;
                                Navigator.pop(
                                  ctx,
                                  InspirationCustomDayVerseChoice.specific(
                                    InspirationVerseRef(
                                      book: selectedBook,
                                      chapter: chapter,
                                      verse: verse,
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}
