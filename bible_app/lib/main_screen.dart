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

  static const List<Widget> _screens = [
    BibleScreen(),
    NotebookScreen(),
    JournalScreen(),
  ];

  static const List<BottomNavigationBarItem> _navItems = [
    BottomNavigationBarItem(
      icon: Icon(Icons.book),
      label: 'Библия',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.note),
      label: 'Блокнот',
    ),
    BottomNavigationBarItem(
      icon: Icon(Icons.calendar_month),
      label: 'Журнал',
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
    if (lastIndex != null && lastIndex >= 0 && lastIndex < _screens.length) {
      if (!mounted) return;
      setState(() {
        _selectedIndex = lastIndex;
      });
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('last_tab_index', _selectedIndex);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: _navItems,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.lightBlue[100],
        selectedItemColor: Colors.blue[800],
        unselectedItemColor: Colors.grey[600],
      ),
    );
  }
}
