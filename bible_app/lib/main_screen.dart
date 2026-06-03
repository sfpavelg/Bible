import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/screens/bible_screen.dart';
import 'package:bible_app/screens/notebook_screen.dart';
import 'package:bible_app/screens/journal_screen.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/navigation/app_tab_switcher.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/main_chrome_tab_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_app/inspiration/inspiration_engine.dart';
import 'package:bible_app/inspiration/inspiration_notifications.dart';
import 'package:bible_app/inspiration/inspiration_repository.dart';
import 'package:flutter/foundation.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  /// Вкладки монтируем лениво: не тянуть path_provider/ФС блокнота на старте (слабые API 23).
  final Set<int> _mountedTabs = {0};
  bool _restoredLastTab = false;

  void _syncBibleTabActive() {
    bibleTabIsActive.value = _selectedIndex == 0;
  }

  void _deliverPendingBibleJump() {
    if (_selectedIndex != 0) return;
    if (bibleVerseJumpRequest.value != null) {
      renotifyBibleVerseJumpRequest();
    }
  }

  void _onExternalTabSwitch() {
    final target = appTabSwitchRequest.value;
    if (target == null) return;
    if (!mounted) return;
    if (target >= 0 && target < 3) {
      _onItemTapped(target);
    }
    appTabSwitchRequest.value = null;
  }

  void _onBibleJumpRequest() {
    final r = bibleVerseJumpRequest.value;
    if (r == null || !mounted) return;
    if (_selectedIndex != 0) {
      _onItemTapped(0);
    } else {
      _deliverPendingBibleJump();
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    appTabSwitchRequest.addListener(_onExternalTabSwitch);
    bibleVerseJumpRequest.addListener(_onBibleJumpRequest);
    _syncBibleTabActive();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_onStartupNavigation());
    });
  }

  Future<void> _onStartupNavigation() async {
    if (!kIsWeb) {
      await InspirationNotificationService.instance
          .applyLaunchNotificationNavigation();
    }
    if (!mounted) return;
    if (bibleVerseJumpRequest.value != null) {
      _onItemTapped(0);
      return;
    }
    await _loadSelectedTab();
  }

  @override
  void dispose() {
    appTabSwitchRequest.removeListener(_onExternalTabSwitch);
    bibleVerseJumpRequest.removeListener(_onBibleJumpRequest);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      appProvider.persistLastPosition();
    }
    if (state == AppLifecycleState.resumed && !kIsWeb) {
      unawaited(_rescheduleInspirationNotifications());
    }
  }

  Future<void> _rescheduleInspirationNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    final repo = InspirationRepository(prefs);
    final settings = repo.loadSettings();
    if (!settings.remindersEnabled) return;
    await InspirationNotificationService.instance.rescheduleIfNeeded(
      repository: repo,
      engine: InspirationEngine(),
      settings: settings,
      customDays: repo.loadCustomDays(),
    );
  }

  Future<void> _loadSelectedTab() async {
    if (_restoredLastTab) return;
    _restoredLastTab = true;
    final prefs = await SharedPreferences.getInstance();
    final lastIndex = prefs.getInt('last_tab_index');
    if (lastIndex != null && lastIndex >= 0 && lastIndex < 3) {
      if (!mounted) return;
      setState(() {
        _selectedIndex = lastIndex;
        _mountedTabs.add(lastIndex);
      });
    }
  }

  void _onItemTapped(int index) {
    // Скрыть клавиатуру при смене вкладки: поле блокнота остаётся в дереве (Offstage)
    // и иначе удерживает фокус. Набор текста — только там, где пользователь тапнул поле
    // (блокнот, поиск в Библии).
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _selectedIndex = index;
      _mountedTabs.add(index);
    });
    _syncBibleTabActive();
    if (index == 0 && bibleVerseJumpRequest.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _deliverPendingBibleJump();
      });
    }
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('last_tab_index', _selectedIndex);
    });
  }

  Widget _tabBody(int index) {
    switch (index) {
      case 0:
        return const BibleScreen();
      case 1:
        return const NotebookScreen();
      case 2:
        return const JournalScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabOrder = _mountedTabs.toList()..sort();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Верх не инсетим: AppBar вкладок рисуется под статус-бар (primary),
    // фон шапки идёт до края; системные иконки — поверх прозрачной панели.
    final scaffold = Scaffold(
      backgroundColor: isDark ? null : Colors.transparent,
      body: Stack(
        fit: StackFit.expand,
        children: [
          for (final i in tabOrder)
            Offstage(
              offstage: _selectedIndex != i,
              child: _tabBody(i),
            ),
        ],
      ),
      bottomNavigationBar: MainChromeTabBar(
        currentIndex: _selectedIndex,
        onChanged: _onItemTapped,
      ),
    );

    final shell = SafeArea(top: false, child: scaffold);

    if (isDark) return shell;

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: BibleLightPalette.screenGradient,
      ),
      child: shell,
    );
  }
}
