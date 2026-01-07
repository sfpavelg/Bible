import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/main_screen.dart';
import 'package:bible_app/providers/app_provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppProvider()..initializeApp(),
      child: Consumer<AppProvider>(
        builder: (context, appProvider, child) {
          return MaterialApp(
            title: 'Библия',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
              textTheme: TextTheme(
                bodyLarge: TextStyle(fontSize: appProvider.fontSize),
                bodyMedium: TextStyle(fontSize: appProvider.fontSize),
              ),
            ),
            darkTheme: ThemeData.dark().copyWith(
              textTheme: TextTheme(
                bodyLarge: TextStyle(fontSize: appProvider.fontSize),
                bodyMedium: TextStyle(fontSize: appProvider.fontSize),
              ),
            ),
            themeMode: appProvider.themeMode,
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}