import 'package:flutter/material.dart';
import 'package:bible_app/screens/bible_screen.dart';
import 'package:bible_app/screens/notebook_screen.dart';
import 'package:bible_app/screens/journal_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
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

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
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
        backgroundColor: Colors.lightBlue[100], // Светло-голубой фон
        selectedItemColor: Colors.blue[800], // Цвет выбранной иконки
        unselectedItemColor: Colors.grey[600], // Цвет невыбранных иконок
      ),
    );
  }
}