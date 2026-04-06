import 'dart:async';
import 'dart:convert';

import 'package:bible_app/journal/chronological_reading_plan_data.dart';
import 'package:bible_app/journal/parallel_reading_plan_data.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum _JournalPlanKind { parallel, chronological }

/// Вертикальная линия с квадратным бегунком: вверху список в начале, внизу — в конце.
class _PlanScrollRail extends StatefulWidget {
  const _PlanScrollRail({
    required this.controller,
    required this.thumbSize,
    this.onScrollAdjusted,
  });

  final ScrollController controller;
  final double thumbSize;

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
                      color: Colors.blue.shade100.withValues(alpha: 0.65),
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
                    color: JournalScreen._buttonBg,
                    borderRadius: BorderRadius.circular(8),
                    elevation: 0,
                    child: Container(
                      width: ts,
                      height: ts,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      alignment: Alignment.center,
                      child: _scrollGripLines(ts),
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

  static const _appBarBg = Color(0xFFB3E5FC);
  static const _buttonBg = Color(0xFFE1F5FE);
  static const _chromeFg = Colors.black;

  @override
  State<JournalScreen> createState() => _JournalScreenState();
}

class _JournalScreenState extends State<JournalScreen>
    with WidgetsBindingObserver {
  static const _prefsKeyParallel = 'journal_parallel_done_days_v1';
  static const _prefsKeyChronological = 'journal_chronological_done_days_v1';
  static const _prefsScrollParallel = 'journal_plan_scroll_parallel_v1';
  static const _prefsScrollChrono = 'journal_plan_scroll_chrono_v1';
  static const _prefsPlanKind = 'journal_plan_kind_v1';

  _JournalPlanKind _plan = _JournalPlanKind.parallel;
  Set<int> _parallelDone = {};
  Set<int> _chronologicalDone = {};
  bool _loading = true;
  final ScrollController _scrollController = ScrollController();
  Timer? _scrollSaveDebounce;

  /// Кэш позиции списка (из prefs при загрузке и при прокрутке) — восстановление без гонки async.
  double _scrollCacheParallel = 0;
  double _scrollCacheChrono = 0;

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
    _scrollController.dispose();
    super.dispose();
  }

  void _scheduleScrollPersist() {
    _scrollSaveDebounce?.cancel();
    _scrollSaveDebounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted || !_scrollController.hasClients) return;
      _cacheAndPersistScrollForPlan(_plan, _scrollController.offset);
    });
  }

  void _updateScrollCacheOnly(double offset) {
    if (_plan == _JournalPlanKind.parallel) {
      _scrollCacheParallel = offset;
    } else {
      _scrollCacheChrono = offset;
    }
  }

  void _cacheAndPersistScrollForPlan(_JournalPlanKind plan, double offset) {
    if (plan == _JournalPlanKind.parallel) {
      _scrollCacheParallel = offset;
      SharedPreferences.getInstance()
          .then((p) => p.setDouble(_prefsScrollParallel, offset));
    } else {
      _scrollCacheChrono = offset;
      SharedPreferences.getInstance()
          .then((p) => p.setDouble(_prefsScrollChrono, offset));
    }
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
    if (!_scrollController.hasClients) return;
    _cacheAndPersistScrollForPlan(_plan, _scrollController.offset);
  }

  /// Восстановить прокрутку из кэша после того, как ListView получит ненулевой maxScrollExtent.
  void _restoreScrollForCurrentPlan() {
    final target = _plan == _JournalPlanKind.parallel
        ? _scrollCacheParallel
        : _scrollCacheChrono;

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
    final savedParallel = p.getDouble(_prefsScrollParallel) ?? 0.0;
    final savedChrono = p.getDouble(_prefsScrollChrono) ?? 0.0;
    final savedPlanKind = _planKindFromPrefs(p.getString(_prefsPlanKind));
    if (!mounted) return;
    setState(() {
      _parallelDone = parallel;
      _chronologicalDone = chrono;
      _scrollCacheParallel = savedParallel;
      _scrollCacheChrono = savedChrono;
      _plan = savedPlanKind;
      _loading = false;
    });
    _restoreScrollForCurrentPlan();
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

  void _selectPlanKind(_JournalPlanKind k) {
    if (k == _plan) return;
    if (_scrollController.hasClients) {
      _cacheAndPersistScrollForPlan(_plan, _scrollController.offset);
    }
    setState(() => _plan = k);
    _persistPlanKind(k);
    _restoreScrollForCurrentPlan();
  }

  Future<void> _openPlanKindPicker(double chromeHeight) async {
    HapticFeedback.lightImpact();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
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
                    color: Colors.blue.shade900,
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black87, width: 1.5),
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
    required VoidCallback onTap,
  }) {
    final bg = selected ? Colors.blue : JournalScreen._buttonBg;
    final fg = selected ? Colors.white : JournalScreen._chromeFg;
    final fontSize = (height * 0.30).clamp(11.0, 15.0);
    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: Colors.black87, width: 1.2),
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

  Widget _buildPlanListWithRail(double chromeSize) {
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
              itemCount: _planTotal,
              itemBuilder: (context, index) {
                final lines = _linesForDay(index);
                final done = _dayDone(index);
                final n = index + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Material(
                    color: done ? Colors.amber.shade50 : Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: BorderSide(
                        color: Colors.blue.shade100,
                        width: 1,
                      ),
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
                                activeColor: Colors.blue,
                                onChanged: (_) => _toggleCurrentPlanDay(index),
                              ),
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'День $n',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 15,
                                      color: Colors.blue.shade900,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  ...lines.map(
                                    (line) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 4),
                                      child: Text(
                                        line,
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          height: 1.35,
                                          color: Colors.grey.shade900,
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
            onScrollAdjusted: _scheduleScrollPersist,
          ),
        ),
      ],
    );
  }

  Widget _readProgressFooter() {
    return Material(
      color: JournalScreen._buttonBg,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
        child: Text(
          'Прочитано: $_planDoneCount из $_planTotal',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.blue.shade900,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chromeSize = context.watch<AppProvider>().chromeButtonSize;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: JournalScreen._appBarBg,
        surfaceTintColor: JournalScreen._appBarBg,
        foregroundColor: JournalScreen._chromeFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ChromeIconButton(
              icon: Icons.vertical_align_top,
              tooltip: 'В начало списка',
              foregroundColor: JournalScreen._chromeFg,
              backgroundColor: JournalScreen._buttonBg,
              onPressed: _jumpScrollToStart,
            ),
            const SizedBox(width: 8),
            ChromeIconButton(
              icon: Icons.vertical_align_bottom,
              tooltip: 'В конец списка',
              foregroundColor: JournalScreen._chromeFg,
              backgroundColor: JournalScreen._buttonBg,
              onPressed: _jumpScrollToEnd,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Material(
                  color: JournalScreen._buttonBg,
                  borderRadius: BorderRadius.circular(8),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openPlanKindPicker(chromeSize),
                    child: SizedBox(
                      height: chromeSize,
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'План Чтения',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: JournalScreen._chromeFg,
                                    fontWeight: FontWeight.w800,
                                    fontSize: (chromeSize * 0.24)
                                        .clamp(10.0, 13.0),
                                  ),
                                ),
                                Text(
                                  _plan == _JournalPlanKind.parallel
                                      ? 'Параллельный'
                                      : 'Хронология',
                                  maxLines: 1,
                                  style: TextStyle(
                                    color: JournalScreen._chromeFg
                                        .withValues(alpha: 0.88),
                                    fontWeight: FontWeight.w600,
                                    fontSize: (chromeSize * 0.20)
                                        .clamp(8.5, 11.0),
                                  ),
                                ),
                              ],
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
        actions: const [
          AppChromeOverflowMenu(
            iconColor: JournalScreen._chromeFg,
            backgroundColor: JournalScreen._buttonBg,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildPlanListWithRail(chromeSize)),
                _readProgressFooter(),
              ],
            ),
    );
  }
}
