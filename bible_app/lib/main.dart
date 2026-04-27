import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/bootstrap_splash.dart';
import 'package:bible_app/main_screen.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  }
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
            title: 'Bible',
            debugShowCheckedModeBanner: false,
            locale: const Locale('ru', 'RU'),
            supportedLocales: const [
              Locale('ru', 'RU'),
              Locale('en', 'US'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              useMaterial3: true,
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.dark,
                  statusBarBrightness: Brightness.light,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarIconBrightness: Brightness.dark,
                ),
              ),
            ),
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.blue,
                brightness: Brightness.dark,
              ).copyWith(
                // Чуть светлее «чистого» чёрного, чтобы экран не выглядел плоским.
                surface: const Color(0xFF2E323A),
                surfaceContainerLowest: const Color(0xFF262A32),
              ),
              appBarTheme: const AppBarTheme(
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarColor: Colors.transparent,
                  statusBarIconBrightness: Brightness.light,
                  statusBarBrightness: Brightness.dark,
                  systemNavigationBarColor: Colors.transparent,
                  systemNavigationBarDividerColor: Colors.transparent,
                  systemNavigationBarIconBrightness: Brightness.light,
                ),
              ),
            ),
            themeMode: appProvider.themeMode,
            builder: (context, child) {
              final brightness = Theme.of(context).brightness;
              final lightIcons = brightness == Brightness.dark;
              final overlay = SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarDividerColor: Colors.transparent,
                statusBarIconBrightness:
                    lightIcons ? Brightness.light : Brightness.dark,
                statusBarBrightness:
                    lightIcons ? Brightness.dark : Brightness.light,
                systemNavigationBarIconBrightness:
                    lightIcons ? Brightness.light : Brightness.dark,
              );
              return AnnotatedRegion<SystemUiOverlayStyle>(
                value: overlay,
                child: child ?? const SizedBox.shrink(),
              );
            },
            home: appProvider.isLoading
                ? const BootstrapSplash()
                : const MainScreen(),
          );
        },
      ),
    );
  }
}
