import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  static const _appBarBg = Color(0xFFB3E5FC);
  static const _buttonBg = Color(0xFFE1F5FE);
  static const _chromeFg = Colors.black;

  @override
  Widget build(BuildContext context) {
    context.watch<AppProvider>().chromeButtonSize;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _appBarBg,
        surfaceTintColor: _appBarBg,
        foregroundColor: _chromeFg,
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            ChromeIconButton(
              icon: Icons.calendar_today,
              tooltip: 'Календарь',
              foregroundColor: _chromeFg,
              backgroundColor: _buttonBg,
              onPressed: () {
                // TODO: календарь прочтения
              },
            ),
          ],
        ),
        actions: const [
          AppChromeOverflowMenu(
            iconColor: _chromeFg,
            backgroundColor: _buttonBg,
          ),
        ],
      ),
      body: const Center(
        child: Text('Раздел Журнала - в разработке'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: добавить запись в журнал
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
