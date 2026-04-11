import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/screens/bible_screen.dart';
import 'package:bible_app/screens/notebook_screen.dart';
import 'package:bible_app/screens/journal_screen.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _selectedIndex = 0;

  /// Вкладки монтируем лениво: не тянуть path_provider/ФС блокнота на старте (слабые API 23).
  final Set<int> _mountedTabs = {0};

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.menu_book),
      label: 'Библия',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.note),
      label: 'Блокнот',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.event_note),
      label: 'План',
    ),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadSelectedTab();
  }

  @override
  void dispose() {
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
  }

  Future<void> _loadSelectedTab() async {
    final prefs = await SharedPreferences.getInstance();
    final lastIndex = prefs.getInt('last_tab_index');
    if (lastIndex != null &&
        lastIndex >= 0 &&
        lastIndex < _navItems.length) {
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
    return Scaffold(
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
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor:
            isDark ? const Color(0xFF37474F) : Colors.lightBlue[100],
        selectedItemColor:
            isDark ? const Color(0xFF81D4FA) : Colors.blue[800],
        unselectedItemColor:
            isDark ? Colors.grey.shade500 : Colors.grey[600],
      ),
    );
  }
}
