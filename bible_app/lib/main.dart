import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/bootstrap_splash.dart';
import 'package:bible_app/main_screen.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bible_app/inspiration/inspiration_notifications.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    await InspirationNotificationService.instance.initialize();
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
              scaffoldBackgroundColor: BibleDarkPalette.screenBg,
              colorScheme: ColorScheme.fromSeed(
                seedColor: BibleDarkPalette.accentGold,
                brightness: Brightness.dark,
              ).copyWith(
                surface: BibleDarkPalette.screenBg,
                surfaceContainerLowest: BibleDarkPalette.screenBg,
                surfaceContainerHigh: BibleDarkPalette.cardBg,
                surfaceContainerHighest: BibleDarkPalette.cardBg,
                primary: BibleDarkPalette.accentGold,
                onPrimary: const Color(0xFF1A1A1A),
                onSurface: BibleDarkPalette.primaryText,
                onSurfaceVariant: BibleDarkPalette.secondaryText,
                outline: BibleDarkPalette.divider,
                outlineVariant: BibleDarkPalette.divider,
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
