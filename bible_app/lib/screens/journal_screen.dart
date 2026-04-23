import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:bible_app/journal/chronological_reading_plan_data.dart';
import 'package:bible_app/journal/parallel_reading_plan_data.dart';
import 'package:bible_app/journal/sequential_reading_plan.dart';
import 'package:bible_app/models/bible_model.dart';
import 'package:bible_app/navigation/app_tab_switcher.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _JournalPlanKind { parallel, chronological, sequential }

class _PlanChapterItem {
  const _PlanChapterItem({
    required this.key,
    required this.book,
    required this.chapter,
  });

  final String key;
  final String book;
  final int chapter;

  String get label => '$book $chapter';
}

/// Разбиение года на четыре квартала (сумма = 365).
const List<int> kJournalPlanQuarterDayCounts = [91, 91, 91, 92];

int journalQuarterStartDayIndex(int quarterIndex) {
  assert(quarterIndex >= 0 && quarterIndex < 4);
  var start = 0;
  for (var i = 0; i < quarterIndex; i++) {
    start += kJournalPlanQuarterDayCounts[i];
  }
  return start;
}

/// На вебе кратко после attach к [ScrollView] у позиции ещё нет метрик —
/// обращение к [ScrollPosition.maxScrollExtent] бросает (и даёт красный error frame в debug).
bool _scrollPositionHasMetrics(ScrollController c) =>
    c.hasClients && c.position.hasContentDimensions;

/// Вертикальная линия с квадратным бегунком: вверху список в начале, внизу — в конце.
class _PlanScrollRail extends StatefulWidget {
  const _PlanScrollRail({
    required this.controller,
    required this.thumbSize,
    required this.thumbColor,
    required this.trackHintColor,
    this.onScrollAdjusted,
  });

  final ScrollController controller;
  final double thumbSize;
  final Color thumbColor;
  final Color trackHintColor;

  /// После перетаскивания бегунка или тапа по дорожке — сохранить offset в prefs.
  final VoidCallback? onScrollAdjusted;

  @override
  State<_PlanScrollRail> createState() => _PlanScrollRailState();
}

class _PlanScrollRailState extends State<_PlanScrollRail> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _PlanScrollRail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  Widget _scrollGripLine(double width) {
    return Container(
      width: width,
      height: 2.5,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(1.25),
      ),
    );
  }

  Widget _scrollGripLines(double ts) {
    final gap = (ts * 0.11).clamp(3.0, 6.0);
    final lineW = (ts * 0.55).clamp(14.0, 28.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _scrollGripLine(lineW),
        SizedBox(height: gap),
        _scrollGripLine(lineW),
        SizedBox(height: gap),
        _scrollGripLine(lineW),
      ],
    );
  }

  void _jumpToLocalY(double localY, double trackH, double ts, double travel) {
    final c = widget.controller;
    if (!_scrollPositionHasMetrics(c) || travel <= 0) return;
    final maxExt = c.position.maxScrollExtent;
    if (maxExt <= 0) {
      c.jumpTo(0);
      return;
    }
    final targetTop = (localY - ts / 2).clamp(0.0, travel);
    final pixels = (targetTop / travel) * maxExt;
    c.jumpTo(pixels.clamp(0.0, maxExt));
    widget.onScrollAdjusted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.thumbSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final travel = (h - ts).clamp(0.0, double.infinity);
        final c = widget.controller;
        double thumbTop = 0;
        if (_scrollPositionHasMetrics(c) && travel > 0) {
          final pos = c.position;
          final maxExt = pos.maxScrollExtent;
          if (maxExt > 0) {
            thumbTop = (pos.pixels / maxExt) * travel;
            thumbTop = thumbTop.clamp(0.0, travel);
          }
        }
        return SizedBox(
          width: ts,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) =>
                      _jumpToLocalY(d.localPosition.dy, h, ts, travel),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 4,
                    height: (h - 8).clamp(0.0, double.infinity),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.trackHintColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: thumbTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    if (!_scrollPositionHasMetrics(c) || travel <= 0) return;
                    final pos = c.position;
                    final maxExt = pos.maxScrollExtent;
                    if (maxExt <= 0) return;
                    final delta = details.delta.dy;
                    final next = pos.pixels + delta * maxExt / travel;
                    c.jumpTo(next.clamp(0.0, maxExt));
                    widget.onScrollAdjusted?.call();
                  },
                  onVerticalDragEnd: (_) => widget.onScrollAdjusted?.call(),
                  child: Material(
                    color: widget.thumbColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: ChromeOutline.side,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: ts,
                      height: ts,
                      child: Center(child: _scrollGripLines(ts)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class JournalScreen extends StatefulWidget {
  const JournalScreen({super.key});

  static const _appBarBgLight = Color(0xFFB3E5FC);
  static const _buttonBgLight = Color(0xFFE1F5FE);
  /// Как на экране Библии и нижней навигации.
  static const _appBarBgDark = Color(0xFF37474F);
  static const _buttonBgDark = Color(0xFF455A64);
  static const _chromeFgLight = Colors.black;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with WidgetsBindingObserver {
  static const _prefsKeyParallel = 'journal_parallel_done_days_v1';
  static const _prefsKeyChronological = 'journal_chronological_done_days_v1';
  static const _prefsKeyParallelItems = 'journal_parallel_done_items_v1';
  static const _prefsKeyChronologicalItems =
      'journal_chronological_done_items_v1';
  static const _prefsScrollParallelQuarters =
      'journal_plan_scroll_parallel_quarters_v1';
  static const _prefsScrollChronoQuarters =
      'journal_plan_scroll_chrono_quarters_v1';
  static const _prefsScrollSequentialQuarters =
      'journal_plan_scroll_sequential_quarters_v1';
  static const _prefsKeySequential = 'journal_sequential_done_days_v1';
  static const _prefsKeySequentialItems = 'journal_sequential_done_items_v1';
  static const _prefsPlanKind = 'journal_plan_kind_v1';

  _JournalPlanKind _plan = _JournalPlanKind.parallel;
  Set<int> _parallelDone = {};
  Set<int> _chronologicalDone = {};
  Set<int> _sequentialDone = {};
  Map<int, Set<String>> _parallelDoneItems = {};
  Map<int, Set<String>> _chronologicalDoneItems = {};
  Map<int, Set<String>> _sequentialDoneItems = {};
  final bool _loading = false;
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollSaveDebounce;
  late final Map<String, String> _bookLookup = _bookNameLookup();
  late final List<List<_PlanChapterItem>> _parallelChapterItemsByDay =
      _buildChapterItemsByDay(_JournalPlanKind.parallel);
  late final List<List<_PlanChapterItem>> _chronologicalChapterItemsByDay =
      _buildChapterItemsByDay(_JournalPlanKind.chronological);
  late final List<List<_PlanChapterItem>> _sequentialChapterItemsByDay =
      buildSequentialReadingPlanChaptersByDay()
          .map(
            (day) => day
                .map(
                  (r) => _PlanChapterItem(
                    key: '${r.book}|${r.chapter}',
                    book: r.book,
                    chapter: r.chapter,
                  ),
                )
                .toList(growable: false),
          )
          .toList(growable: false);

  /// Позиция прокрутки списка по каждому кварталу (0…3) для каждого типа плана.
  List<double> _scrollQuarterParallel = List<double>.filled(4, 0.0);
  List<double> _scrollQuarterChrono = List<double>.filled(4, 0.0);
  List<double> _scrollQuarterSequential = List<double>.filled(4, 0.0);

  /// null — экран с четырьмя кварталами; 0…3 — открыт соответствующий квартал.
  int? _openQuarter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    _scrollSaveDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    if (_scrollController.hasClients && _openQuarter != null) {
      _applyScrollOffsetToQuarterCache(_scrollController.offset);
      unawaited(_persistScrollQuarterListsToDisk());
    }
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollPersist() {
    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !_scrollController.hasClients || _openQuarter == null) {
        return;
      }
      _applyScrollOffsetToQuarterCache(_scrollController.offset);
      unawaited(_persistScrollQuarterListsToDisk());
    });
  }

  void _applyScrollOffsetToQuarterCache(double offset) {
    final q = _openQuarter;
    if (q == null) return;
    switch (_plan) {
      case _JournalPlanKind.parallel:
        _scrollQuarterParallel[q] = offset;
        break;
      case _JournalPlanKind.chronological:
        _scrollQuarterChrono[q] = offset;
        break;
      case _JournalPlanKind.sequential:
        _scrollQuarterSequential[q] = offset;
        break;
    }
  }

  void _updateScrollCacheOnly(double offset) {
    _applyScrollOffsetToQuarterCache(offset);
  }

  Future<void> _persistScrollQuarterListsToDisk() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      _prefsScrollParallelQuarters,
      jsonEncode(_scrollQuarterParallel),
    );
    await p.setString(
      _prefsScrollChronoQuarters,
      jsonEncode(_scrollQuarterChrono),
    );
    await p.setString(
      _prefsScrollSequentialQuarters,
      jsonEncode(_scrollQuarterSequential),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _persistScrollSnapshot();
      _persistPlanKind(_plan);
    }
  }

  /// Сохранить текущий offset без ожидания (переключение вкладок / фон).
  void _persistScrollSnapshot() {
    if (!_scrollController.hasClients || _openQuarter == null) return;
    _applyScrollOffsetToQuarterCache(_scrollController.offset);
    unawaited(_persistScrollQuarterListsToDisk());
  }

  List<double> _decodeQuarterScrollList(String? raw) {
    if (raw == null || raw.isEmpty) {
      return List<double>.filled(4, 0.0);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      final out = List<double>.filled(4, 0.0);
      for (var i = 0; i < 4 && i < list.length; i++) {
        final v = list[i];
        if (v is num) out[i] = v.toDouble();
      }
      return out;
    } catch (_) {
      return List<double>.filled(4, 0.0);
    }
  }

  /// Восстановить прокрутку списка дней квартала из кэша.
  void _restoreListScrollForOpenQuarter() {
    final q = _openQuarter;
    if (q == null) return;
    final target = switch (_plan) {
      _JournalPlanKind.parallel => _scrollQuarterParallel[q],
      _JournalPlanKind.chronological => _scrollQuarterChrono[q],
      _JournalPlanKind.sequential => _scrollQuarterSequential[q],
    };

    void tryJump(int attempt) {
      if (!mounted || attempt > 80) {
        if (mounted) setState(() {});
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (!_scrollController.hasClients) {
          tryJump(attempt + 1);
          return;
        }
        final pos = _scrollController.position;
        if (!pos.hasContentDimensions) {
          tryJump(attempt + 1);
          return;
        }
        final m = pos.maxScrollExtent;
        if (m <= 0) {
          tryJump(attempt + 1);
          return;
        }
        final clamped = target.clamp(0.0, m);
        _scrollController.jumpTo(clamped);
        _updateScrollCacheOnly(clamped);
        _scheduleScrollPersist();
        if (mounted) setState(() {});
      });
    }

    tryJump(0);
  }

  void _openQuarterScreen(int quarterIndex) {
    HapticFeedback.lightImpact();
    setState(() => _openQuarter = quarterIndex);
    _restoreListScrollForOpenQuarter();
  }

  void _closeQuarterScreen() {
    HapticFeedback.lightImpact();
    if (_scrollController.hasClients && _openQuarter != null) {
      _applyScrollOffsetToQuarterCache(_scrollController.offset);
      unawaited(_persistScrollQuarterListsToDisk());
    }
    setState(() => _openQuarter = null);
  }

  int _doneDaysInQuarter(int quarterIndex) {
    final start = journalQuarterStartDayIndex(quarterIndex);
    final len = kJournalPlanQuarterDayCounts[quarterIndex];
    final end = start + len;
    final done = switch (_plan) {
      _JournalPlanKind.parallel => _parallelDone,
      _JournalPlanKind.chronological => _chronologicalDone,
      _JournalPlanKind.sequential => _sequentialDone,
    };
    return done.where((i) => i >= start && i < end).length;
  }

  void _jumpScrollToStart() {
    HapticFeedback.lightImpact();
    final c = _scrollController;
    if (!c.hasClients) return;
    const target = 0.0;
    final dist = (c.offset - target).abs();
    if (dist < 1) {
      _updateScrollCacheOnly(target);
      _scheduleScrollPersist();
      return;
    }
    // Плавный «сдвиг по рельсу», а не мгновенный jump — видно движение, пока список догружает верстку.
    final ms = (200 + dist * 0.22).clamp(200.0, 1100.0).round();
    c
        .animateTo(
          target,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeInOutCubic,
        )
        .whenComplete(() {
          if (!mounted || !c.hasClients) return;
          _updateScrollCacheOnly(c.offset);
          _scheduleScrollPersist();
        });
  }

  void _jumpScrollToEnd() {
    HapticFeedback.lightImpact();
    final c = _scrollController;
    if (!_scrollPositionHasMetrics(c)) return;
    final m = c.position.maxScrollExtent;
    final dist = (m - c.offset).abs();
    if (dist < 1) {
      _updateScrollCacheOnly(m);
      _scheduleScrollPersist();
      return;
    }
    final ms = (200 + dist * 0.22).clamp(200.0, 1100.0).round();
    c
        .animateTo(
          m,
          duration: Duration(milliseconds: ms),
          curve: Curves.easeInOutCubic,
        )
        .whenComplete(() {
          if (!mounted || !c.hasClients) return;
          _updateScrollCacheOnly(c.offset);
          _scheduleScrollPersist();
        });
  }

  Set<int> _decodeIndexSet(String? raw, int maxLen) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => e as int)
          .where((i) => i >= 0 && i < maxLen)
          .toSet();
    } catch (_) {
      return {};
    }
  }

  static _JournalPlanKind _planKindFromPrefs(String? raw) {
    return switch (raw) {
      'chronological' => _JournalPlanKind.chronological,
      'sequential' => _JournalPlanKind.sequential,
      _ => _JournalPlanKind.parallel,
    };
  }

  static String _planKindToPrefs(_JournalPlanKind k) => switch (k) {
        _JournalPlanKind.parallel => 'parallel',
        _JournalPlanKind.chronological => 'chronological',
        _JournalPlanKind.sequential => 'sequential',
      };

  void _persistPlanKind(_JournalPlanKind k) {
    SharedPreferences.getInstance().then(
      (p) => p.setString(_prefsPlanKind, _planKindToPrefs(k)),
    );
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final parallel = _decodeIndexSet(
      p.getString(_prefsKeyParallel),
      kParallelReadingPlan365.length,
    );
    final chrono = _decodeIndexSet(
      p.getString(_prefsKeyChronological),
      kChronologicalReadingPlan365.length,
    );
    final sequential = _decodeIndexSet(
      p.getString(_prefsKeySequential),
      kSequentialReadingPlanDayCount,
    );
    final scrollP =
        _decodeQuarterScrollList(p.getString(_prefsScrollParallelQuarters));
    final scrollC =
        _decodeQuarterScrollList(p.getString(_prefsScrollChronoQuarters));
    final scrollS =
        _decodeQuarterScrollList(p.getString(_prefsScrollSequentialQuarters));
    final savedPlanKind = _planKindFromPrefs(p.getString(_prefsPlanKind));
    final parallelItems = _decodeDoneItems(
      p.getString(_prefsKeyParallelItems),
      kParallelReadingPlan365.length,
    );
    final chronoItems = _decodeDoneItems(
      p.getString(_prefsKeyChronologicalItems),
      kChronologicalReadingPlan365.length,
    );
    final sequentialItems = _decodeDoneItems(
      p.getString(_prefsKeySequentialItems),
      kSequentialReadingPlanDayCount,
    );
    final parallelDoneByItems = <int>{};
    for (final e in parallelItems.entries) {
      final day = e.key;
      if (day < 0 || day >= _parallelChapterItemsByDay.length) continue;
      final items = _parallelChapterItemsByDay[day];
      final done = e.value;
      if (items.isNotEmpty && items.every((it) => done.contains(it.key))) {
        parallelDoneByItems.add(day);
      }
    }
    final chronoDoneByItems = <int>{};
    for (final e in chronoItems.entries) {
      final day = e.key;
      if (day < 0 || day >= _chronologicalChapterItemsByDay.length) continue;
      final items = _chronologicalChapterItemsByDay[day];
      final done = e.value;
      if (items.isNotEmpty && items.every((it) => done.contains(it.key))) {
        chronoDoneByItems.add(day);
      }
    }
    final sequentialDoneByItems = <int>{};
    for (final e in sequentialItems.entries) {
      final day = e.key;
      if (day < 0 || day >= _sequentialChapterItemsByDay.length) continue;
      final items = _sequentialChapterItemsByDay[day];
      final done = e.value;
      if (items.isNotEmpty && items.every((it) => done.contains(it.key))) {
        sequentialDoneByItems.add(day);
      }
    }
    if (!mounted) return;
    setState(() {
      _parallelDone = {...parallel, ...parallelDoneByItems};
      _chronologicalDone = {...chrono, ...chronoDoneByItems};
      _sequentialDone = {...sequential, ...sequentialDoneByItems};
      _parallelDoneItems = parallelItems;
      _chronologicalDoneItems = chronoItems;
      _sequentialDoneItems = sequentialItems;
      _scrollQuarterParallel = scrollP;
      _scrollQuarterChrono = scrollC;
      _scrollQuarterSequential = scrollS;
      _plan = savedPlanKind;
    });
  }

  Future<void> _persistParallel() async {
    final p = await SharedPreferences.getInstance();
    final sorted = _parallelDone.toList()..sort();
    await p.setString(_prefsKeyParallel, jsonEncode(sorted));
    await p.setString(
      _prefsKeyParallelItems,
      jsonEncode(_encodeDoneItems(_parallelDoneItems)),
    );
  }

  Future<void> _persistChronological() async {
    final p = await SharedPreferences.getInstance();
    final sorted = _chronologicalDone.toList()..sort();
    await p.setString(_prefsKeyChronological, jsonEncode(sorted));
    await p.setString(
      _prefsKeyChronologicalItems,
      jsonEncode(_encodeDoneItems(_chronologicalDoneItems)),
    );
  }

  Future<void> _persistSequential() async {
    final p = await SharedPreferences.getInstance();
    final sorted = _sequentialDone.toList()..sort();
    await p.setString(_prefsKeySequential, jsonEncode(sorted));
    await p.setString(
      _prefsKeySequentialItems,
      jsonEncode(_encodeDoneItems(_sequentialDoneItems)),
    );
  }

  Map<String, List<String>> _encodeDoneItems(Map<int, Set<String>> src) {
    final out = <String, List<String>>{};
    final days = src.keys.toList()..sort();
    for (final d in days) {
      final entries = src[d];
      if (entries == null || entries.isEmpty) continue;
      final sorted = entries.toList()..sort();
      out['$d'] = sorted;
    }
    return out;
  }

  Map<int, Set<String>> _decodeDoneItems(String? raw, int maxLen) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <int, Set<String>>{};
      for (final e in decoded.entries) {
        final day = int.tryParse(e.key.toString());
        if (day == null || day < 0 || day >= maxLen) continue;
        final list = e.value;
        if (list is! List) continue;
        final values = list
            .map((v) => v.toString())
            .where((v) => v.isNotEmpty)
            .toSet();
        if (values.isNotEmpty) out[day] = values;
      }
      return out;
    } catch (_) {
      return {};
    }
  }

  List<String> _linesForDay(int index) {
    switch (_plan) {
      case _JournalPlanKind.parallel:
        return kParallelReadingPlan365[index].lines
            .map(_expandBookNamesForDisplay)
            .toList(growable: false);
      case _JournalPlanKind.chronological:
        return kChronologicalReadingPlan365[index].lines
            .map(_expandBookNamesForDisplay)
            .toList(growable: false);
      case _JournalPlanKind.sequential:
        return _formatChapterItemsAsDisplayLines(
          _sequentialChapterItemsByDay[index],
        );
    }
  }

  /// Строки дня для последовательного плана (полные названия книг из [BibleBook]).
  List<String> _formatChapterItemsAsDisplayLines(List<_PlanChapterItem> items) {
    if (items.isEmpty) return const [];
    final byBook = <String, List<int>>{};
    for (final i in items) {
      byBook.putIfAbsent(i.book, () => <int>[]).add(i.chapter);
    }
    return byBook.entries.map((e) {
      final chapters = (e.value.toSet().toList()..sort());
      final parts = <String>[];
      var start = chapters.first;
      var prev = chapters.first;
      for (var idx = 1; idx < chapters.length; idx++) {
        final curr = chapters[idx];
        if (curr == prev + 1) {
          prev = curr;
          continue;
        }
        parts.add(start == prev ? '$start' : '$start-$prev');
        start = curr;
        prev = curr;
      }
      parts.add(start == prev ? '$start' : '$start-$prev');
      return '${e.key} ${parts.join(', ')}';
    }).toList(growable: false);
  }

  String _normalizeReadingBlockForDisplay(String block) {
    var out = block.trim().replaceAll(RegExp(r'\.+$'), '');
    out = out.replaceAllMapped(
      RegExp(r'\d+(?:\s*,\s*\d+)+'),
      (m) {
        final raw = m.group(0);
        if (raw == null || raw.contains(':')) return raw ?? '';
        final nums = raw
            .split(RegExp(r'\s*,\s*'))
            .map(int.tryParse)
            .whereType<int>()
            .toList();
        if (nums.length < 2) return raw;
        for (var i = 1; i < nums.length; i++) {
          if (nums[i] != nums[i - 1] + 1) return raw;
        }
        return '${nums.first}-${nums.last}';
      },
    );
    return out;
  }

  List<String> _readingBlocksFromLines(List<String> lines) {
    final out = <String>[];
    for (final line in lines) {
      final parts = line
          .split(RegExp(r'[.;]'))
          .map((e) => _normalizeReadingBlockForDisplay(e))
          .where((e) => e.isNotEmpty);
      out.addAll(parts);
    }
    return out;
  }

  String _expandBookNamesForDisplay(String line) {
    final bookBeforeRef = RegExp(
      r'((?:[1-4]\s*)?[А-ЯЁа-яёA-Za-z]+(?:\.[А-ЯЁа-яёA-Za-z]+)*\.?)\s*(?=\d)',
    );
    return line.replaceAllMapped(bookBeforeRef, (m) {
      final rawBook = (m.group(1) ?? '').trim();
      if (rawBook.isEmpty) return m.group(0) ?? '';
      final full = _bookLookup[_normalizeBookToken(rawBook)];
      if (full == null) return m.group(0) ?? '';
      return '$full ';
    });
  }

  bool _dayDone(int index) {
    final items = _chapterItemsForDay(index);
    if (items.isEmpty) return false;
    final done = _doneItemsForCurrentPlan(index);
    for (final i in items) {
      if (!done.contains(i.key)) return false;
    }
    return true;
  }

  Set<String> _doneItemsForCurrentPlan(int dayIndex) {
    return switch (_plan) {
      _JournalPlanKind.parallel => _parallelDoneItems[dayIndex] ?? <String>{},
      _JournalPlanKind.chronological =>
        _chronologicalDoneItems[dayIndex] ?? <String>{},
      _JournalPlanKind.sequential =>
        _sequentialDoneItems[dayIndex] ?? <String>{},
    };
  }

  Future<void> _setChapterDone({
    required int dayIndex,
    required String itemKey,
    required bool done,
  }) async {
    setState(() {
      final map = switch (_plan) {
        _JournalPlanKind.parallel => _parallelDoneItems,
        _JournalPlanKind.chronological => _chronologicalDoneItems,
        _JournalPlanKind.sequential => _sequentialDoneItems,
      };
      final selected = (map[dayIndex] ?? <String>{}).toSet();
      if (done) {
        selected.add(itemKey);
      } else {
        selected.remove(itemKey);
      }
      if (selected.isEmpty) {
        map.remove(dayIndex);
      } else {
        map[dayIndex] = selected;
      }

      final dayIsDone = _dayDone(dayIndex);
      final doneSet = switch (_plan) {
        _JournalPlanKind.parallel => _parallelDone,
        _JournalPlanKind.chronological => _chronologicalDone,
        _JournalPlanKind.sequential => _sequentialDone,
      };
      if (dayIsDone) {
        doneSet.add(dayIndex);
      } else {
        doneSet.remove(dayIndex);
      }
    });

    switch (_plan) {
      case _JournalPlanKind.parallel:
        await _persistParallel();
        break;
      case _JournalPlanKind.chronological:
        await _persistChronological();
        break;
      case _JournalPlanKind.sequential:
        await _persistSequential();
        break;
    }
  }

  static String _normalizeBookToken(String s) =>
      s.toLowerCase().replaceAll(RegExp(r'[\s\.\-]'), '');

  Map<String, String> _bookNameLookup() {
    final out = <String, String>{};
    for (final b in BibleBook.books) {
      out[_normalizeBookToken(b.name)] = b.name;
      out[_normalizeBookToken(b.abbreviation)] = b.name;
      out[_normalizeBookToken('${b.abbreviation}.')] = b.name;
    }
    out['быт'] = 'Бытие';
    out['исх'] = 'Исход';
    out['лев'] = 'Левит';
    out['чис'] = 'Числа';
    out['втор'] = 'Второзаконие';
    out['пс'] = 'Псалтирь';
    out['иснав'] = 'Иисус Навин';
    out['пр'] = 'Притчи';
    out['притч'] = 'Притчи';
    out['еккл'] = 'Екклесиаст';
    out['ппесней'] = 'Песня Песней';
    out['ппесн'] = 'Песня Песней';
    out['есф'] = 'Есфирь';
    out['авдий'] = 'Авдий';
    out['наума'] = 'Наум';
    out['плиер'] = 'Плач Иеремии';
    out['плачиеремии'] = 'Плач Иеремии';
    out['иерем'] = 'Иеремия';
    out['иоиль'] = 'Иоиль';
    out['дан'] = 'Даниил';
    out['езд'] = 'Ездра';
    out['неем'] = 'Неемия';
    out['мтф'] = 'Матфея';
    out['лук'] = 'Луки';
    out['иоан'] = 'Иоанна';
    out['деян'] = 'Деяния';
    out['иакова'] = 'Иакова';
    out['гал'] = 'Галатам';
    out['рим'] = 'Римлянам';
    out['колос'] = 'Колоссянам';
    out['ефесянам'] = 'Ефесянам';
    out['филип'] = 'Филиппийцам';
    out['титу'] = 'Титу';
    out['евр'] = 'Евреям';
    out['иуды'] = 'Иуды';
    out['откр'] = 'Откровение';
    out['осия'] = 'Осия';
    out['амос'] = 'Амос';
    out['михея'] = 'Михей';
    out['софония'] = 'Софония';
    out['аввакум'] = 'Аввакум';
    out['аггей'] = 'Аггей';
    out['зах'] = 'Захария';
    out['1цар'] = '1 Царств';
    out['2цар'] = '2 Царств';
    out['3цар'] = '3 Царств';
    out['4цар'] = '4 Царств';
    out['1пар'] = '1 Паралипоменон';
    out['2пар'] = '2 Паралипоменон';
    out['1фес'] = '1 Фессалоникийцам';
    out['2фес'] = '2 Фессалоникийцам';
    out['1кор'] = '1 Коринфянам';
    out['2кор'] = '2 Коринфянам';
    out['1тим'] = '1 Тимофею';
    out['2тим'] = '2 Тимофею';
    out['1петр'] = '1 Петра';
    out['2петр'] = '2 Петра';
    out['1иоан'] = '1 Иоанна';
    out['2иоан'] = '2 Иоанна';
    out['3иоан'] = '3 Иоанна';
    return out;
  }

  List<List<_PlanChapterItem>> _buildChapterItemsByDay(_JournalPlanKind plan) {
    final total = plan == _JournalPlanKind.parallel
        ? kParallelReadingPlan365.length
        : kChronologicalReadingPlan365.length;
    return List<List<_PlanChapterItem>>.generate(
      total,
      (dayIndex) => _parseChapterItemsForDay(plan, dayIndex),
      growable: false,
    );
  }

  List<int> _parseChapterToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return const [];
    final colon = t.indexOf(':');
    if (colon > 0) {
      final chapter = int.tryParse(t.substring(0, colon).trim());
      return chapter == null ? const [] : [chapter];
    }
    final range = RegExp(r'^(\d+)\s*-\s*(\d+)$').firstMatch(t);
    if (range != null) {
      final a = int.tryParse(range.group(1)!);
      final b = int.tryParse(range.group(2)!);
      if (a == null || b == null) return const [];
      final from = math.min(a, b);
      final to = math.max(a, b);
      return [for (var i = from; i <= to; i++) i];
    }
    final single = int.tryParse(t);
    return single == null ? const [] : [single];
  }

  List<_PlanChapterItem> _parseChapterItemsForDay(
    _JournalPlanKind plan,
    int dayIndex,
  ) {
    final lines = plan == _JournalPlanKind.parallel
        ? kParallelReadingPlan365[dayIndex].lines
        : kChronologicalReadingPlan365[dayIndex].lines;
    final out = <_PlanChapterItem>[];
    final seen = <String>{};
    final pairPattern = RegExp(
      r'((?:[1-4]\s*)?[А-ЯЁа-яёA-Za-z]+(?:\.[А-ЯЁа-яёA-Za-z]+)*\.?(?:\s+[А-ЯЁа-яёA-Za-z]+(?:\.[А-ЯЁа-яёA-Za-z]+)*\.?)*)\s*([\d:,\-\s]+)',
    );
    for (final rawLine in lines) {
      final normalizedLine = rawLine.replaceAll(';', ' ');
      final matches = pairPattern.allMatches(normalizedLine);
      for (final m in matches) {
        final bookRaw = m.group(1)?.trim() ?? '';
        final refsRaw = m.group(2)?.trim() ?? '';
        if (bookRaw.isEmpty || refsRaw.isEmpty) continue;
        final book = _bookLookup[_normalizeBookToken(bookRaw)];
        if (book == null) continue;
        final parts = refsRaw
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty);
        for (final p in parts) {
          for (final chapter in _parseChapterToken(p)) {
            if (chapter <= 0) continue;
            final key = '$book|$chapter';
            if (!seen.add(key)) continue;
            out.add(_PlanChapterItem(key: key, book: book, chapter: chapter));
          }
        }
      }
    }
    return out;
  }

  List<_PlanChapterItem> _chapterItemsForDayByPlan(
    _JournalPlanKind plan,
    int dayIndex,
  ) {
    return switch (plan) {
      _JournalPlanKind.parallel => _parallelChapterItemsByDay[dayIndex],
      _JournalPlanKind.chronological =>
        _chronologicalChapterItemsByDay[dayIndex],
      _JournalPlanKind.sequential => _sequentialChapterItemsByDay[dayIndex],
    };
  }

  List<_PlanChapterItem> _chapterItemsForDay(int dayIndex) =>
      _chapterItemsForDayByPlan(_plan, dayIndex);

  Future<void> _openDayChapterChecklist(int dayIndex) async {
    final app = context.read<AppProvider>();
    final items = _chapterItemsForDay(dayIndex);
    if (items.isEmpty) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final isDark = Theme.of(dialogContext).brightness == Brightness.dark;
        final fg = isDark ? Colors.white : Colors.black87;
        final buttonBg =
            isDark ? JournalScreen._buttonBgDark : JournalScreen._buttonBgLight;
        final chrome = app.chromeButtonSize;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final doneNow = _doneItemsForCurrentPlan(dayIndex);
            return AlertDialog(
              insetPadding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'День ${dayIndex + 1}',
                    ),
                  ),
                  ChromeIconButton(
                    icon: Icons.close,
                    tooltip: 'Закрыть',
                    foregroundColor: fg,
                    backgroundColor: buttonBg,
                    width: chrome,
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              contentPadding: const EdgeInsets.fromLTRB(0, 4, 12, 10),
              content: SizedBox(
                width: 520,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView.separated(
                    shrinkWrap: true,
                    primary: false,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final item = items[i];
                      final checked = doneNow.contains(item.key);
                      return Material(
                        color: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(0, 4, 0, 4),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Checkbox(
                                  value: checked,
                                  onChanged: (v) async {
                                    await _setChapterDone(
                                      dayIndex: dayIndex,
                                      itemKey: item.key,
                                      done: v ?? false,
                                    );
                                    setModalState(() {});
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Material(
                                  color: isDark
                                      ? const Color(0xFF455A64)
                                      : const Color(0xFFE1F5FE),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: const BorderSide(
                                      color: Colors.black,
                                      width: ChromeOutline.width,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    onTap: () async {
                                      final dialogNavigator =
                                          Navigator.of(dialogContext);
                                      await app.changeBookAndChapter(
                                        item.book,
                                        item.chapter,
                                      );
                                      if (!mounted) return;
                                      dialogNavigator.pop();
                                      appTabSwitchRequest.value = 0;
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 10,
                                        horizontal: 10,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.label,
                                              style: app.bibleVerseTextStyle(
                                                color: fg,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                          Icon(
                                            Icons.open_in_new,
                                            size: (app.chromeButtonSize * 0.42)
                                                .clamp(14.0, 24.0),
                                            color: fg.withValues(alpha: 0.9),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  int get _planTotal => switch (_plan) {
    _JournalPlanKind.parallel => kParallelReadingPlan365.length,
    _JournalPlanKind.chronological => kChronologicalReadingPlan365.length,
    _JournalPlanKind.sequential => kSequentialReadingPlanDayCount,
  };

  int get _planDoneCount => switch (_plan) {
    _JournalPlanKind.parallel => _parallelDone.length,
    _JournalPlanKind.chronological => _chronologicalDone.length,
    _JournalPlanKind.sequential => _sequentialDone.length,
  };

  int _dayCountInOpenQuarter() {
    final q = _openQuarter;
    if (q == null) return 0;
    return kJournalPlanQuarterDayCounts[q];
  }

  void _selectPlanKind(_JournalPlanKind k) {
    if (k == _plan) return;
    if (_scrollController.hasClients && _openQuarter != null) {
      _applyScrollOffsetToQuarterCache(_scrollController.offset);
      unawaited(_persistScrollQuarterListsToDisk());
    }
    setState(() => _plan = k);
    _persistPlanKind(k);
    if (_openQuarter != null) {
      _restoreListScrollForOpenQuarter();
    }
  }

  Future<void> _openPlanKindPicker(double chromeHeight) async {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sheetBg = isDark ? const Color(0xFF263238) : Colors.white;
    final titleColor =
        isDark ? const Color(0xFF81D4FA) : Colors.blue.shade900;
    final unselectedBtn = isDark ? JournalScreen._buttonBgDark : JournalScreen._buttonBgLight;
    final chromeFg = isDark ? Colors.white : JournalScreen._chromeFgLight;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: sheetBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'План чтения',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _planRectButton(
                        label: 'Параллельный',
                        height: chromeHeight,
                        selected: _plan == _JournalPlanKind.parallel,
                        isDark: isDark,
                        unselectedBg: unselectedBtn,
                        chromeFg: chromeFg,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_plan != _JournalPlanKind.parallel) {
                            _selectPlanKind(_JournalPlanKind.parallel);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _planRectButton(
                        label: 'Хронология',
                        height: chromeHeight,
                        selected: _plan == _JournalPlanKind.chronological,
                        isDark: isDark,
                        unselectedBg: unselectedBtn,
                        chromeFg: chromeFg,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_plan != _JournalPlanKind.chronological) {
                            _selectPlanKind(_JournalPlanKind.chronological);
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _planRectButton(
                        label: 'Последовательный',
                        height: chromeHeight,
                        selected: _plan == _JournalPlanKind.sequential,
                        isDark: isDark,
                        unselectedBg: unselectedBtn,
                        chromeFg: chromeFg,
                        onTap: () {
                          Navigator.pop(ctx);
                          if (_plan != _JournalPlanKind.sequential) {
                            _selectPlanKind(_JournalPlanKind.sequential);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Экран с четырьмя кварталами: одна строка, текст масштабируется и
  /// выравнивается в кнопке по левому краю.
  Widget _planKindAppBarTitleOnHub(
    Color chromeFg,
    double chromeSize,
    double maxWidth,
  ) {
    final full = switch (_plan) {
      _JournalPlanKind.parallel => 'План чтения: параллельный',
      _JournalPlanKind.chronological => 'План чтения: хронология',
      _JournalPlanKind.sequential => 'План чтения: последовательный',
    };
    final titleStyle = TextStyle(
      color: chromeFg,
      fontWeight: FontWeight.w600,
      fontSize: (chromeSize * 0.42).clamp(14.0, 22.0),
      height: 1.0,
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        full,
        maxLines: 1,
        textAlign: TextAlign.left,
        softWrap: false,
        overflow: TextOverflow.visible,
        style: titleStyle,
      ),
    );
  }

  Widget _planKindAppBarTitleInQuarter(
    BuildContext context,
    Color chromeFg,
    double maxWidth,
  ) {
    final singleLine = switch (_plan) {
      _JournalPlanKind.parallel => 'План чтения: параллельный',
      _JournalPlanKind.chronological => 'План чтения: хронология',
      _JournalPlanKind.sequential => 'План чтения: последовательный',
    };
    final singleStyle = TextStyle(
      color: chromeFg,
      fontWeight: FontWeight.normal,
      fontSize: 25.6,
      height: 1.02,
    );
    final tp = TextPainter(
      text: TextSpan(text: singleLine, style: singleStyle),
      maxLines: 1,
      textDirection: Directionality.of(context),
    )..layout(maxWidth: double.infinity);
    if (tp.width <= maxWidth) {
      return Text(
        singleLine,
        maxLines: 1,
        textAlign: TextAlign.center,
        softWrap: false,
        style: singleStyle,
      );
    }
    final line2 = switch (_plan) {
      _JournalPlanKind.parallel => 'параллельный',
      _JournalPlanKind.chronological => 'хронология',
      _JournalPlanKind.sequential => 'последовательный',
    };
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'План чтения:',
          maxLines: 1,
          textAlign: TextAlign.center,
          softWrap: false,
          style: singleStyle,
        ),
        Text(
          line2,
          maxLines: 1,
          textAlign: TextAlign.center,
          softWrap: false,
          style: singleStyle,
        ),
      ],
    );
  }

  Widget _planRectButton({
    required String label,
    required double height,
    required bool selected,
    required bool isDark,
    required Color unselectedBg,
    required Color chromeFg,
    required VoidCallback onTap,
  }) {
    final bg = selected
        ? (isDark ? const Color(0xFF81D4FA) : Colors.blue)
        : unselectedBg;
    final fg = selected
        ? (isDark ? const Color(0xFF263238) : Colors.white)
        : chromeFg;
    final fontSize = (height * 0.30).clamp(11.0, 15.0);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: ChromeOutline.side,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuarterSelectionHub(
    AppProvider app, {
    required bool isDark,
    required Color cardTodoBg,
    required Color cardMutedFg,
    required Color titleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      child: Column(
        children: List.generate(4, (qi) {
          final done = _doneDaysInQuarter(qi);
          final total = kJournalPlanQuarterDayCounts[qi];
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Material(
                color: cardTodoBg,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: ChromeOutline.side,
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openQuarterScreen(qi),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${qi + 1} квартал',
                          textAlign: TextAlign.center,
                          style: app
                              .bibleVerseTextStyle(
                                color: titleColor,
                                fontWeight: FontWeight.w800,
                              )
                              .copyWith(
                                fontSize:
                                    app.fontSize * app.verseFontSizeScale * 1.12,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Прочитано $done из $total',
                          textAlign: TextAlign.center,
                          style: app.bibleVerseTextStyle(
                            color: cardMutedFg,
                            fontWeight: FontWeight.w600,
                          ).copyWith(
                            fontSize:
                                app.fontSize * app.verseFontSizeScale * 0.88,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildPlanListWithRail(
    AppProvider app,
    double chromeSize, {
    required bool isDark,
    required Color thumbColor,
    required Color trackHintColor,
  }) {
    final lineGap = (app.verseSpacing * 0.65).clamp(0.0, 12.0);
    final titleColor =
        isDark ? const Color(0xFF81D4FA) : Colors.blue.shade900;
    final bodyColor = isDark ? Colors.grey.shade200 : Colors.grey.shade900;
    final cardDoneBg = isDark
        ? Colors.amber.shade900.withValues(alpha: 0.42)
        : Colors.amber.shade50;
    final cardTodoBg = isDark ? const Color(0xFF37474F) : Colors.white;
    final railSize = (chromeSize * 0.68).clamp(26.0, 36.0);
    final railBg = isDark ? const Color(0xFF263238) : const Color(0xFFE1F5FE);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollUpdateNotification ||
                  n is ScrollEndNotification) {
                _scheduleScrollPersist();
              }
              return false;
            },
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context)
                  .copyWith(scrollbars: false),
              child: ListView.builder(
                controller: _scrollController,
                primary: false,
                padding: const EdgeInsets.fromLTRB(12, 8, 6, 12),
                itemCount: _dayCountInOpenQuarter(),
                itemBuilder: (context, localIndex) {
                  final q = _openQuarter!;
                  final index =
                      journalQuarterStartDayIndex(q) + localIndex;
                  final lines = _linesForDay(index);
                  final done = _dayDone(index);
                  final n = index + 1;
                  final chapterItems = _chapterItemsForDay(index);
                  final doneItems = _doneItemsForCurrentPlan(index);
                  final doneCount =
                      chapterItems.where((e) => doneItems.contains(e.key)).length;
                final readingBlocks = _readingBlocksFromLines(lines);
                final readingsStyle = app.bibleVerseTextStyle(
                  color: bodyColor,
                  fontWeight: done ? FontWeight.w600 : FontWeight.normal,
                );
                final doneLabelStyle = app.bibleVerseTextStyle(
                  color: titleColor,
                  fontWeight: FontWeight.w700,
                ).copyWith(
                  fontSize: (app.fontSize * app.verseFontSizeScale * 0.78)
                      .clamp(10.0, 20.0),
                  height: 1.0,
                );
                Widget doneBadge() => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF81D4FA).withValues(alpha: 0.2)
                            : Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: ChromeOutline.color,
                          width: ChromeOutline.width,
                        ),
                      ),
                      child: Text('Прочитано', style: doneLabelStyle),
                    );
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Material(
                      color: done ? cardDoneBg : cardTodoBg,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: ChromeOutline.side,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(10),
                        onTap: () => _openDayChapterChecklist(index),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'День $n',
                                            style: app
                                                .bibleVerseTextStyle(
                                                  color: titleColor,
                                                  fontWeight: FontWeight.w800,
                                                )
                                                .copyWith(
                                                  fontSize: app.fontSize *
                                                      app.verseFontSizeScale *
                                                      1.06,
                                                ),
                                          ),
                                        ),
                                      Text(
                                        chapterItems.isEmpty
                                            ? 'Нет глав для отметки'
                                            : 'Отмечено глав: $doneCount из ${chapterItems.length}',
                                        textAlign: TextAlign.right,
                                        style: app.bibleVerseTextStyle(
                                          color: bodyColor,
                                          fontWeight: FontWeight.w600,
                                        ).copyWith(
                                          fontSize: (app.fontSize *
                                                  app.verseFontSizeScale *
                                                  0.92)
                                              .clamp(11.0, 26.0),
                                        ),
                                      ),
                                      ],
                                    ),
                                    SizedBox(height: (lineGap + 2).clamp(4.0, 14.0)),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: LayoutBuilder(
                                          builder: (ctx, constraints) {
                                            if (readingBlocks.isEmpty) {
                                              return Text(
                                                'Нет чтений для дня',
                                                style: readingsStyle,
                                              );
                                            }
                                            final dir = Directionality.of(ctx);
                                            const minInterItemGap = 10.0;
                                            const badgeGap = 8.0;
                                            final displayBlocks = List<String>.from(
                                              readingBlocks,
                                            );
                                            var totalWidth = 0.0;
                                            for (final block in displayBlocks) {
                                              final tp = TextPainter(
                                                text: TextSpan(
                                                  text: block,
                                                  style: readingsStyle,
                                                ),
                                                maxLines: 1,
                                                textDirection: dir,
                                              )..layout(maxWidth: double.infinity);
                                              totalWidth += tp.width;
                                            }
                                            final baseGaps = displayBlocks.length <= 1
                                                ? 0.0
                                                : minInterItemGap *
                                                    (displayBlocks.length - 1);
                                            final canFitOneLine =
                                                totalWidth + baseGaps <=
                                                    constraints.maxWidth;
                                            final tpBadge = TextPainter(
                                              text: TextSpan(
                                                text: 'Прочитано',
                                                style: doneLabelStyle,
                                              ),
                                              maxLines: 1,
                                              textDirection: dir,
                                            )..layout(maxWidth: double.infinity);
                                            final badgeWidth = tpBadge.width + 16 + 2;
                                            final canFitWithBadge = done &&
                                                canFitOneLine &&
                                                (totalWidth +
                                                        baseGaps +
                                                        badgeGap +
                                                        badgeWidth) <=
                                                    constraints.maxWidth;

                                            Widget textLine(double maxWidth) {
                                              if (displayBlocks.length == 1) {
                                                return Text(
                                                  displayBlocks.first,
                                                  maxLines: 1,
                                                  softWrap: false,
                                                  style: readingsStyle,
                                                );
                                              }
                                              final gap = ((maxWidth - totalWidth) /
                                                      (displayBlocks.length - 1))
                                                  .clamp(minInterItemGap, 80.0);
                                              return Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  for (var i = 0;
                                                      i < displayBlocks.length;
                                                      i++) ...[
                                                    Text(
                                                      displayBlocks[i],
                                                      maxLines: 1,
                                                      softWrap: false,
                                                      style: readingsStyle,
                                                    ),
                                                    if (i < displayBlocks.length - 1)
                                                      SizedBox(width: gap),
                                                  ],
                                                ],
                                              );
                                            }

                                            Widget lineText(List<String> blocks) {
                                              return Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  for (var i = 0; i < blocks.length; i++) ...[
                                                    Text(blocks[i], style: readingsStyle),
                                                    if (i < blocks.length - 1)
                                                      const SizedBox(width: minInterItemGap),
                                                  ],
                                                ],
                                              );
                                            }

                                            if (canFitWithBadge) {
                                              final lineMaxWidth =
                                                  constraints.maxWidth -
                                                      badgeGap -
                                                      badgeWidth;
                                              return Row(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: textLine(lineMaxWidth),
                                                  ),
                                                  const SizedBox(width: badgeGap),
                                                  doneBadge(),
                                                ],
                                              );
                                            }
                                            if (canFitOneLine) {
                                              final line = textLine(constraints.maxWidth);
                                              if (!done) return line;
                                              return Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  line,
                                                  SizedBox(
                                                    height: (lineGap * 0.5)
                                                        .clamp(2.0, 8.0),
                                                  ),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: doneBadge(),
                                                  ),
                                                ],
                                              );
                                            }
                                            // Многострочный режим: раскладываем блоки по строкам вручную.
                                            final linesByWidth = <List<String>>[];
                                            var current = <String>[];
                                            var currentWidth = 0.0;
                                            for (var i = 0; i < displayBlocks.length; i++) {
                                              final block = displayBlocks[i];
                                              final tp = TextPainter(
                                                text: TextSpan(
                                                  text: block,
                                                  style: readingsStyle,
                                                ),
                                                maxLines: 1,
                                                textDirection: dir,
                                              )..layout(maxWidth: double.infinity);
                                              final w = tp.width;
                                              final extra = current.isEmpty
                                                  ? w
                                                  : (minInterItemGap + w);
                                              if (current.isNotEmpty &&
                                                  currentWidth + extra > constraints.maxWidth) {
                                                linesByWidth.add(current);
                                                current = <String>[block];
                                                currentWidth = w;
                                              } else {
                                                current.add(block);
                                                currentWidth += extra;
                                              }
                                            }
                                            if (current.isNotEmpty) {
                                              linesByWidth.add(current);
                                            }

                                            if (!done) {
                                              return Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  for (var i = 0; i < linesByWidth.length; i++) ...[
                                                    lineText(linesByWidth[i]),
                                                    if (i < linesByWidth.length - 1)
                                                      SizedBox(
                                                        height: (lineGap * 0.35).clamp(1.0, 6.0),
                                                      ),
                                                  ],
                                                ],
                                              );
                                            }

                                            final lastLine = linesByWidth.last;
                                            final tpLast = TextPainter(
                                              text: TextSpan(
                                                text: lastLine.join(' '),
                                                style: readingsStyle,
                                              ),
                                              maxLines: 1,
                                              textDirection: dir,
                                            )..layout(maxWidth: double.infinity);
                                            final lastLineTextWidth = tpLast.width;
                                            final canPutBadgeOnLastLine =
                                                lastLineTextWidth +
                                                        (lastLine.length > 1
                                                            ? (lastLine.length - 1) *
                                                                minInterItemGap
                                                            : 0) +
                                                        badgeGap +
                                                        badgeWidth <=
                                                    constraints.maxWidth;

                                            return Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                for (var i = 0;
                                                    i < linesByWidth.length - 1;
                                                    i++) ...[
                                                  lineText(linesByWidth[i]),
                                                  SizedBox(
                                                    height: (lineGap * 0.35).clamp(1.0, 6.0),
                                                  ),
                                                ],
                                                if (canPutBadgeOnLastLine)
                                                  Row(
                                                    children: [
                                                      lineText(lastLine),
                                                      const Spacer(),
                                                      doneBadge(),
                                                    ],
                                                  )
                                                else ...[
                                                  lineText(lastLine),
                                                  SizedBox(
                                                    height: (lineGap * 0.5).clamp(2.0, 8.0),
                                                  ),
                                                  Align(
                                                    alignment: Alignment.centerRight,
                                                    child: doneBadge(),
                                                  ),
                                                ],
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 6, 8),
          child: Container(
            width: railSize,
            color: railBg,
            child: _PlanScrollRail(
              controller: _scrollController,
              thumbSize: railSize,
              thumbColor: thumbColor,
              trackHintColor: trackHintColor,
              onScrollAdjusted: _scheduleScrollPersist,
            ),
          ),
        ),
      ],
    );
  }

  Widget _readProgressFooter(AppProvider app, {required bool isDark}) {
    final bg = isDark ? JournalScreen._buttonBgDark : JournalScreen._buttonBgLight;
    final fg = isDark ? const Color(0xFF81D4FA) : Colors.blue.shade900;
    final String line;
    final q = _openQuarter;
    if (q == null) {
      line = 'Прочитано: $_planDoneCount из $_planTotal';
    } else {
      final dq = _doneDaysInQuarter(q);
      final tq = kJournalPlanQuarterDayCounts[q];
      line = 'Прочитано: $dq из $tq';
    }
    return Material(
      color: bg,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Text(
          line,
          textAlign: TextAlign.center,
          style: app
              .bibleVerseTextStyle(color: fg, fontWeight: FontWeight.w700)
              .copyWith(
                fontSize: app.fontSize * app.verseFontSizeScale * 0.9,
              ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final chromeSize = app.chromeButtonSize;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg =
        isDark ? JournalScreen._appBarBgDark : JournalScreen._appBarBgLight;
    final buttonBg =
        isDark ? JournalScreen._buttonBgDark : JournalScreen._buttonBgLight;
    final chromeFg = isDark ? Colors.white : JournalScreen._chromeFgLight;
    final trackHint = isDark
        ? Colors.blueGrey.shade700.withValues(alpha: 0.9)
        : Colors.blue.shade100.withValues(alpha: 0.65);
    final hubTitleColor =
        isDark ? const Color(0xFF81D4FA) : Colors.blue.shade900;
    final hubMutedFg =
        isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final hubCardBg = isDark ? const Color(0xFF37474F) : Colors.white;

    final inQuarter = _openQuarter != null;
    final uiFs = app.fontSize.clamp(12.0, 28.0);
    final quarterLabelStyle = TextStyle(
      fontSize: (uiFs * 1.25).clamp(16.0, 32.0),
      fontWeight: FontWeight.w600,
      color: chromeFg,
    );

    /// В режиме квартала: иконки прямоугольные (ширина ограничена, высота [chromeSize]);
    /// вторая в ряду («в конец») не шире 42 px при большом [chromeSize]; промежутки уже.
    final quarterIconWFirst = math.min(chromeSize, 44.0);
    final quarterIconWSecond = math.min(chromeSize, 42.0);
    final quarterIconGap = (chromeSize * 0.07).clamp(2.0, 5.0);
    final quarterLeadingSlot =
        (quarterIconWFirst + 8).clamp(48.0, 56.0);
    final overflowRightInset =
        (chromeSize * 0.12).clamp(4.0, 10.0);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: AppProvider.toolbarHeightForChrome(chromeSize),
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        foregroundColor: chromeFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        automaticallyImplyLeading: false,
        leading: inQuarter
            ? Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child: ChromeIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'К кварталам',
                    foregroundColor: chromeFg,
                    backgroundColor: buttonBg,
                    width: quarterIconWFirst,
                    onPressed: _closeQuarterScreen,
                  ),
                ),
              )
            : null,
        leadingWidth: inQuarter ? quarterLeadingSlot : null,
        title: Row(
          children: [
            if (inQuarter) ...[
              ChromeIconButton(
                icon: Icons.vertical_align_top,
                tooltip: 'В начало списка',
                foregroundColor: chromeFg,
                backgroundColor: buttonBg,
                width: quarterIconWFirst,
                onPressed: _jumpScrollToStart,
              ),
              SizedBox(width: quarterIconGap),
              ChromeIconButton(
                icon: Icons.vertical_align_bottom,
                tooltip: 'В конец списка',
                foregroundColor: chromeFg,
                backgroundColor: buttonBg,
                width: quarterIconWSecond,
                onPressed: _jumpScrollToEnd,
              ),
              SizedBox(width: quarterIconGap),
              Expanded(
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${_openQuarter! + 1} квартал',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: quarterLabelStyle,
                    ),
                  ),
                ),
              ),
            ],
            if (!inQuarter)
              Padding(
                padding: const EdgeInsets.only(left: 0, right: 4),
                child: Material(
                  color: buttonBg,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: ChromeOutline.side,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: () => _openPlanKindPicker(chromeSize),
                    child: SizedBox(
                      height: chromeSize,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: (chromeSize * 0.26).clamp(10.0, 20.0),
                        ),
                        child: _planKindAppBarTitleOnHub(
                          chromeFg,
                          chromeSize,
                          double.infinity,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(right: overflowRightInset),
            child: AppChromeOverflowMenu(
              iconColor: chromeFg,
              backgroundColor: buttonBg,
              tileWidth: inQuarter
                  ? quarterIconWFirst
                  : math.min(chromeSize, 44.0),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: inQuarter
                      ? _buildPlanListWithRail(
                          app,
                          chromeSize,
                          isDark: isDark,
                          thumbColor: buttonBg,
                          trackHintColor: trackHint,
                        )
                      : _buildQuarterSelectionHub(
                          app,
                          isDark: isDark,
                          cardTodoBg: hubCardBg,
                          cardMutedFg: hubMutedFg,
                          titleColor: hubTitleColor,
                        ),
                ),
                _readProgressFooter(app, isDark: isDark),
              ],
            ),
    );
  }
}
