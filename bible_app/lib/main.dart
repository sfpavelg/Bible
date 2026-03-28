import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/main_screen.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final initialBook = prefs.getString('last_book') ?? 'Бытие';
  final initialChapter = prefs.getInt('last_chapter') ?? 1;

  runApp(MyApp(
    initialBook: initialBook,
    initialChapter: initialChapter,
    prefs: prefs,
  ));
}

class MyApp extends StatelessWidget {
  final String initialBook;
  final int initialChapter;
  final SharedPreferences? prefs;

  const MyApp({
    super.key,
    this.initialBook = 'Бытие',
    this.initialChapter = 1,
    this.prefs,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider(
        initialBook: initialBook,
        initialChapter: initialChapter,
        prefs: prefs,
      )..initializeApp(),
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            title: 'Библия',
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
            ),
            darkTheme: ThemeData.dark(),
            themeMode: appProvider.themeMode,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}
