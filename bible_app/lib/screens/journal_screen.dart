import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:bible_app/journal/chronological_reading_plan_data.dart';
import 'package:bible_app/journal/parallel_reading_plan_data.dart';
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

enum _JournalPlanKind { parallel, chronological }

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
  static const _prefsPlanKind = 'journal_plan_kind_v1';

  _JournalPlanKind _plan = _JournalPlanKind.parallel;
  Set<int> _parallelDone = {};
  Set<int> _chronologicalDone = {};
  Map<int, Set<String>> _parallelDoneItems = {};
  Map<int, Set<String>> _chronologicalDoneItems = {};
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollSaveDebounce;

  /// Позиция прокрутки списка по каждому кварталу (0…3) для параллельного и хронологического плана.
  List<double> _scrollQuarterParallel = List<double>.filled(4, 0.0);
  List<double> _scrollQuarterChrono = List<double>.filled(4, 0.0);

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
    if (_plan == _JournalPlanKind.parallel) {
      _scrollQuarterParallel[q] = offset;
    } else {
      _scrollQuarterChrono[q] = offset;
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
    final target = _plan == _JournalPlanKind.parallel
        ? _scrollQuarterParallel[q]
        : _scrollQuarterChrono[q];

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
    final done = _plan == _JournalPlanKind.parallel
        ? _parallelDone
        : _chronologicalDone;
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
    if (raw == 'chronological') {
      return _JournalPlanKind.chronological;
    }
    return _JournalPlanKind.parallel;
  }

  static String _planKindToPrefs(_JournalPlanKind k) =>
      k == _JournalPlanKind.parallel ? 'parallel' : 'chronological';

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
    final scrollP =
        _decodeQuarterScrollList(p.getString(_prefsScrollParallelQuarters));
    final scrollC =
        _decodeQuarterScrollList(p.getString(_prefsScrollChronoQuarters));
    final savedPlanKind = _planKindFromPrefs(p.getString(_prefsPlanKind));
    final parallelItems = _decodeDoneItems(
      p.getString(_prefsKeyParallelItems),
    );
    final chronoItems = _decodeDoneItems(
      p.getString(_prefsKeyChronologicalItems),
    );
    final parallelDoneByItems = <int>{};
    for (var i = 0; i < kParallelReadingPlan365.length; i++) {
      final items = _chapterItemsForDayByPlan(_JournalPlanKind.parallel, i);
      final done = parallelItems[i] ?? <String>{};
      if (items.isNotEmpty && items.every((e) => done.contains(e.key))) {
        parallelDoneByItems.add(i);
      }
    }
    final chronoDoneByItems = <int>{};
    for (var i = 0; i < kChronologicalReadingPlan365.length; i++) {
      final items = _chapterItemsForDayByPlan(_JournalPlanKind.chronological, i);
      final done = chronoItems[i] ?? <String>{};
      if (items.isNotEmpty && items.every((e) => done.contains(e.key))) {
        chronoDoneByItems.add(i);
      }
    }
    if (!mounted) return;
    setState(() {
      _parallelDone = {...parallel, ...parallelDoneByItems};
      _chronologicalDone = {...chrono, ...chronoDoneByItems};
      _parallelDoneItems = parallelItems;
      _chronologicalDoneItems = chronoItems;
      _scrollQuarterParallel = scrollP;
      _scrollQuarterChrono = scrollC;
      _plan = savedPlanKind;
      _loading = false;
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

  Map<int, Set<String>> _decodeDoneItems(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      final out = <int, Set<String>>{};
      for (final e in decoded.entries) {
        final day = int.tryParse(e.key.toString());
        if (day == null || day < 0 || day >= _planTotal) continue;
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
    if (_plan == _JournalPlanKind.parallel) {
      return kParallelReadingPlan365[index].lines;
    }
    return kChronologicalReadingPlan365[index].lines;
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
    if (_plan == _JournalPlanKind.parallel) {
      return _parallelDoneItems[dayIndex] ?? <String>{};
    }
    return _chronologicalDoneItems[dayIndex] ?? <String>{};
  }

  Future<void> _setChapterDone({
    required int dayIndex,
    required String itemKey,
    required bool done,
  }) async {
    setState(() {
      final map = _plan == _JournalPlanKind.parallel
          ? _parallelDoneItems
          : _chronologicalDoneItems;
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
      if (_plan == _JournalPlanKind.parallel) {
        if (dayIsDone) {
          _parallelDone.add(dayIndex);
        } else {
          _parallelDone.remove(dayIndex);
        }
      } else {
        if (dayIsDone) {
          _chronologicalDone.add(dayIndex);
        } else {
          _chronologicalDone.remove(dayIndex);
        }
      }
    });

    if (_plan == _JournalPlanKind.parallel) {
      await _persistParallel();
    } else {
      await _persistChronological();
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
    return out;
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

  List<_PlanChapterItem> _chapterItemsForDayByPlan(
    _JournalPlanKind plan,
    int dayIndex,
  ) {
    final lookup = _bookNameLookup();
    final lines = plan == _JournalPlanKind.parallel
        ? kParallelReadingPlan365[dayIndex].lines
        : kChronologicalReadingPlan365[dayIndex].lines;
    final out = <_PlanChapterItem>[];
    final seen = <String>{};
    for (final rawLine in lines) {
      final chunks = rawLine
          .replaceAll(';', '.')
          .split('.')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty);
      for (final chunk in chunks) {
        final m = RegExp(r'^(.+?)(\d.*)$').firstMatch(chunk);
        if (m == null) continue;
        final bookRaw = m.group(1)!.trim();
        final refsRaw = m.group(2)!.trim();
        final book = lookup[_normalizeBookToken(bookRaw)];
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
        final rowBg = isDark ? const Color(0xFF37474F) : Colors.white;
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
              contentPadding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
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
                        color: rowBg,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: ChromeOutline.side,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
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
                              Expanded(
                                child: Material(
                                  color: isDark
                                      ? const Color(0xFF455A64)
                                      : const Color(0xFFE1F5FE),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: ChromeOutline.side,
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

  int get _planTotal => _plan == _JournalPlanKind.parallel
      ? kParallelReadingPlan365.length
      : kChronologicalReadingPlan365.length;

  int get _planDoneCount => _plan == _JournalPlanKind.parallel
      ? _parallelDone.length
      : _chronologicalDone.length;

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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
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
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: ChromeOutline.color,
                      width: ChromeOutline.width,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
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

  /// Экран с четырьмя кварталами: одна строка, шрифт по возможности на всю кнопку.
  Widget _planKindAppBarTitleOnHub(Color chromeFg, double chromeSize) {
    final full = _plan == _JournalPlanKind.parallel
        ? 'План чтения: параллельный'
        : 'План чтения: хронология';
    return Text(
      full,
      maxLines: 1,
      textAlign: TextAlign.center,
      softWrap: false,
      overflow: TextOverflow.fade,
      style: TextStyle(
        color: chromeFg,
        fontWeight: FontWeight.normal,
        fontSize: (chromeSize * 0.864).clamp(14.4, 44.8),
        height: 1.0,
      ),
    );
  }

  Widget _planKindAppBarTitleInQuarter(
    BuildContext context,
    Color chromeFg,
    double maxWidth,
  ) {
    final singleLine = _plan == _JournalPlanKind.parallel
        ? 'План чтения: параллельный'
        : 'План чтения: хронология';
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
    final line2 =
        _plan == _JournalPlanKind.parallel ? 'параллельный' : 'хронология';
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
                              .copyWith(fontSize: app.fontSize * 1.12),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Прочитано $done из $total',
                          textAlign: TextAlign.center,
                          style: app.bibleVerseTextStyle(
                            color: cardMutedFg,
                            fontWeight: FontWeight.w600,
                          ).copyWith(fontSize: app.fontSize * 0.88),
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
                                    crossAxisAlignment: CrossAxisAlignment.start,
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
                                                fontSize: app.fontSize * 1.06,
                                              ),
                                        ),
                                      ),
                                      if (done)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? const Color(0xFF81D4FA)
                                                    .withValues(alpha: 0.2)
                                                : Colors.blue.shade50,
                                            borderRadius:
                                                BorderRadius.circular(999),
                                            border: Border.all(
                                              color: ChromeOutline.color,
                                              width: ChromeOutline.width,
                                            ),
                                          ),
                                          child: Text(
                                            'Прочитано',
                                            style: app.bibleVerseTextStyle(
                                              color: titleColor,
                                              fontWeight: FontWeight.w700,
                                            ).copyWith(
                                              fontSize:
                                                  (app.fontSize * 0.78).clamp(
                                                10.0,
                                                20.0,
                                              ),
                                              height: 1.0,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  SizedBox(height: (lineGap + 2).clamp(4.0, 14.0)),
                                  Text(
                                    chapterItems.isEmpty
                                        ? 'Нет глав для отметки'
                                        : 'Отмечено глав: $doneCount из ${chapterItems.length}',
                                    style: app.bibleVerseTextStyle(
                                      color: bodyColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: (lineGap + 1).clamp(2.0, 8.0)),
                                  ...lines.map(
                                    (line) => Padding(
                                      padding:
                                          EdgeInsets.only(bottom: lineGap),
                                      child: Text(
                                        line,
                                        style: app.bibleVerseTextStyle(
                                          color: bodyColor,
                                          fontWeight:
                                              done ? FontWeight.w600 : FontWeight.normal,
                                        ),
                                      ),
                                    ),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(0, 8, 6, 8),
          child: _PlanScrollRail(
            controller: _scrollController,
            thumbSize: chromeSize,
            thumbColor: thumbColor,
            trackHintColor: trackHintColor,
            onScrollAdjusted: _scheduleScrollPersist,
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
              .copyWith(fontSize: app.fontSize * 0.9),
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
            ],
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  left: inQuarter ? 2 : 0,
                  right: inQuarter ? 4 : 0,
                ),
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
                      child: Center(
                        child: Padding(
                          padding: inQuarter
                              ? EdgeInsets.all(
                                  (chromeSize * 0.22).clamp(8.0, 16.0),
                                )
                              : EdgeInsets.symmetric(
                                  horizontal:
                                      (chromeSize * 0.26).clamp(10.0, 20.0),
                                ),
                          child: FittedBox(
                            fit: BoxFit.contain,
                            alignment: Alignment.center,
                            child: inQuarter
                                ? LayoutBuilder(
                                    builder: (ctx, constraints) =>
                                        _planKindAppBarTitleInQuarter(
                                      ctx,
                                      chromeFg,
                                      constraints.maxWidth,
                                    ),
                                  )
                                : _planKindAppBarTitleOnHub(chromeFg, chromeSize),
                          ),
                        ),
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
