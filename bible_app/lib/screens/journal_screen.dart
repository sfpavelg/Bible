import 'dart:async';
import 'dart:convert';

import 'package:bible_app/journal/chronological_reading_plan_data.dart';
import 'package:bible_app/journal/parallel_reading_plan_data.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _JournalPlanKind { parallel, chronological }

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
    if (!c.hasClients || travel <= 0) return;
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
        if (c.hasClients && travel > 0) {
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
                    if (!c.hasClients || travel <= 0) return;
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
  static const _prefsScrollParallelQuarters =
      'journal_plan_scroll_parallel_quarters_v1';
  static const _prefsScrollChronoQuarters =
      'journal_plan_scroll_chrono_quarters_v1';
  static const _prefsPlanKind = 'journal_plan_kind_v1';

  _JournalPlanKind _plan = _JournalPlanKind.parallel;
  Set<int> _parallelDone = {};
  Set<int> _chronologicalDone = {};
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
        final m = _scrollController.position.maxScrollExtent;
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
    if (!c.hasClients) return;
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
    if (!mounted) return;
    setState(() {
      _parallelDone = parallel;
      _chronologicalDone = chrono;
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
  }

  Future<void> _persistChronological() async {
    final p = await SharedPreferences.getInstance();
    final sorted = _chronologicalDone.toList()..sort();
    await p.setString(_prefsKeyChronological, jsonEncode(sorted));
  }

  void _toggleParallelDay(int index) {
    setState(() {
      if (_parallelDone.contains(index)) {
        _parallelDone.remove(index);
      } else {
        _parallelDone.add(index);
      }
    });
    _persistParallel();
  }

  void _toggleChronologicalDay(int index) {
    setState(() {
      if (_chronologicalDone.contains(index)) {
        _chronologicalDone.remove(index);
      } else {
        _chronologicalDone.add(index);
      }
    });
    _persistChronological();
  }

  List<String> _linesForDay(int index) {
    if (_plan == _JournalPlanKind.parallel) {
      return kParallelReadingPlan365[index].lines;
    }
    return kChronologicalReadingPlan365[index].lines;
  }

  bool _dayDone(int index) {
    if (_plan == _JournalPlanKind.parallel) {
      return _parallelDone.contains(index);
    }
    return _chronologicalDone.contains(index);
  }

  void _toggleCurrentPlanDay(int index) {
    if (_plan == _JournalPlanKind.parallel) {
      _toggleParallelDay(index);
    } else {
      _toggleChronologicalDay(index);
    }
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
    final checkAccent = isDark ? const Color(0xFF81D4FA) : Colors.blue;
    final checkOnAccent = isDark ? const Color(0xFF263238) : Colors.white;

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
                      onTap: () => _toggleCurrentPlanDay(index),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 10, 12, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: done,
                                activeColor: checkAccent,
                                checkColor: checkOnAccent,
                                side: WidgetStateBorderSide.resolveWith(
                                  (states) {
                                    final c = isDark
                                        ? Colors.grey.shade400
                                        : Colors.grey.shade600;
                                    return BorderSide(color: c);
                                  },
                                ),
                                onChanged: (_) => _toggleCurrentPlanDay(index),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
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
                                  SizedBox(height: (lineGap + 2).clamp(4.0, 14.0)),
                                  ...lines.map(
                                    (line) => Padding(
                                      padding:
                                          EdgeInsets.only(bottom: lineGap),
                                      child: Text(
                                        line,
                                        style: app.bibleVerseTextStyle(
                                          color: bodyColor,
                                          fontWeight: FontWeight.normal,
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

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: (chromeSize + 10).clamp(kToolbarHeight, 78.0),
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
                  padding: const EdgeInsets.only(left: 4),
                  child: ChromeIconButton(
                    icon: Icons.arrow_back,
                    tooltip: 'К кварталам',
                    foregroundColor: chromeFg,
                    backgroundColor: buttonBg,
                    onPressed: _closeQuarterScreen,
                  ),
                ),
              )
            : null,
        leadingWidth: inQuarter
            ? (chromeSize + 10).clamp(48.0, 88.0)
            : null,
        title: Row(
          children: [
            if (inQuarter) ...[
              ChromeIconButton(
                icon: Icons.vertical_align_top,
                tooltip: 'В начало списка',
                foregroundColor: chromeFg,
                backgroundColor: buttonBg,
                onPressed: _jumpScrollToStart,
              ),
              const SizedBox(width: 8),
              ChromeIconButton(
                icon: Icons.vertical_align_bottom,
                tooltip: 'В конец списка',
                foregroundColor: chromeFg,
                backgroundColor: buttonBg,
                onPressed: _jumpScrollToEnd,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: inQuarter ? 8 : 0),
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
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _plan == _JournalPlanKind.parallel
                                  ? 'План чтения: параллельный'
                                  : 'План чтения: хронология',
                              maxLines: 1,
                              style: TextStyle(
                                color: chromeFg,
                                fontWeight: FontWeight.w800,
                                fontSize:
                                    (chromeSize * 0.26).clamp(10.0, 14.0),
                              ),
                            ),
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
          AppChromeOverflowMenu(
            iconColor: chromeFg,
            backgroundColor: buttonBg,
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
