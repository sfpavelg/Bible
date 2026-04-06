import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сообщение над нижней навигацией приложения (диалоги поиска / избранного).
/// Не перекрывает кнопки «Библия», «Блокнот», «План».
void _showTransientOverlayMessage(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(content: Text(message)),
    );
    return;
  }

  final bottomGap =
      MediaQuery.viewPaddingOf(context).bottom + kBottomNavigationBarHeight;

  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => Positioned(
      left: 0,
      right: 0,
      bottom: bottomGap,
      child: Material(
        elevation: 0,
        color: const Color(0xE6323232),
        child: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            border: Border(
              top: BorderSide(color: Color(0x44FFFFFF), width: 1),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            message,
            style: const TextStyle(color: Colors.white, fontSize: 15),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    ),
  );
  overlay.insert(entry);
  Future<void>.delayed(duration, () {
    entry.remove();
  });
}

class _BookmarkTab {
  _BookmarkTab({required this.text, required this.createdAt});

  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toJson() => {
        'text': text,
        'at': createdAt.toIso8601String(),
      };

  static _BookmarkTab fromJson(Map<String, dynamic> j) {
    return _BookmarkTab(
      text: j['text'] as String? ?? '',
      createdAt: DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now(),
    );
  }

  _BookmarkTab copy() =>
      _BookmarkTab(text: text, createdAt: createdAt);
}

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _highlightVerse;
  Timer? _highlightTimer;
  /// Первый стих — долгим нажатием; дальше — обычным касанием. Порядок = порядок копирования.
  final LinkedHashSet<int> _selectedVerses = LinkedHashSet<int>();
  String _navRef = '';

  static const String _kBibleSearchHistoryKey = 'bible_search_matched_history';
  static const String _kBibleBookmarksKey = 'bible_bookmarks_tabs';

  List<_BookmarkTab> _bookmarks = [];

  /// Увеличивается при каждом открытии панели «Избранное», чтобы игнорировать
  /// поздний [dispose] предыдущего диалога (он перезаписывал список старыми данными).
  int _favoritesPanelSerial = 0;

  String? _bottomBannerText;
  Timer? _bottomBannerTimer;

  /// Черновик поиска: сохраняется между открытиями, пока не нажали сброс в диалоге.
  String _searchDraft = '';
  List<Map<String, dynamic>> _searchResultRows = [];
  bool _searchIncludeVz = true;
  bool _searchIncludeNz = true;
  bool _searchWholeWords = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBookmarks());
  }

  Future<void> _loadBookmarks() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kBibleBookmarksKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return;
      final list = decoded
          .map((e) => _BookmarkTab.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      if (mounted) setState(() => _bookmarks = list);
    } catch (_) {}
  }

  Future<void> _persistBookmarks() async {
    final p = await SharedPreferences.getInstance();
    final raw = jsonEncode(_bookmarks.map((e) => e.toJson()).toList());
    await p.setString(_kBibleBookmarksKey, raw);
  }

  Future<void> _openBookmarksFromToolbar(
    BuildContext context,
    AppProvider appProvider,
    List<Map<String, dynamic>> verses,
  ) async {
    final plain = _selectedVersesPlainText(appProvider, verses);
    if (plain != null) {
      setState(() {
        _bookmarks.add(
          _BookmarkTab(text: plain, createdAt: DateTime.now()),
        );
        _selectedVerses.clear();
      });
      unawaited(_persistBookmarks());
      if (context.mounted) {
        _showBottomBanner('Добавлено в избранное');
      }
    }
    await _showBookmarksPanel(context);
  }

  String? _selectedVersesPlainText(
    AppProvider appProvider,
    List<Map<String, dynamic>> verses,
  ) {
    if (_selectedVerses.isEmpty) return null;
    final parts = <String>[];
    for (final n in _selectedVerses) {
      final text = _verseText(verses, n);
      if (text == null) continue;
      parts.add(
        '${appProvider.currentBook} ${appProvider.currentChapter}:$n $text',
      );
    }
    if (parts.isEmpty) return null;
    return parts.join('\n');
  }

  void _addSelectedVersesToBookmarks(
    BuildContext context,
    AppProvider appProvider,
    List<Map<String, dynamic>> verses,
  ) {
    final plain = _selectedVersesPlainText(appProvider, verses);
    if (plain == null) return;
    setState(() {
      _bookmarks.add(
        _BookmarkTab(text: plain, createdAt: DateTime.now()),
      );
      _selectedVerses.clear();
    });
    unawaited(_persistBookmarks());
    if (!context.mounted) return;
    _showBottomBanner('Добавлено в избранное');
  }

  void _showBottomBanner(String message) {
    _bottomBannerTimer?.cancel();
    if (!mounted) return;
    setState(() => _bottomBannerText = message);
    _bottomBannerTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _bottomBannerText = null);
    });
  }

  @override
  void dispose() {
    _bottomBannerTimer?.cancel();
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _highlightVerseTemporarily(int verse) {
    _highlightTimer?.cancel();
    setState(() => _highlightVerse = verse);
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightVerse = null);
    });
  }

  Future<void> _scrollToVerse(int verseNum, int totalVerses) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!_scrollController.hasClients || !mounted) return;
    final max = _scrollController.position.maxScrollExtent;
    final t = totalVerses <= 1 ? 0.0 : (verseNum - 1) / (totalVerses - 1);
    await _scrollController.animateTo(
      max * t,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  String? _verseText(List<Map<String, dynamic>> verses, int verseNum) {
    for (final v in verses) {
      if (v['verse'] == verseNum) {
        return v['text'] as String?;
      }
    }
    return null;
  }

  void _copySelectedVerses(
    BuildContext context,
    AppProvider appProvider,
    List<Map<String, dynamic>> verses,
  ) {
    if (_selectedVerses.isEmpty) return;
    final parts = <String>[];
    for (final n in _selectedVerses) {
      final text = _verseText(verses, n);
      if (text == null) continue;
      parts.add(
        '${appProvider.currentBook} ${appProvider.currentChapter}:$n $text',
      );
    }
    if (parts.isEmpty) return;
    unawaited(Clipboard.setData(ClipboardData(text: parts.join('\n'))));
    if (!context.mounted) return;
    final n = parts.length;
    _showBottomBanner(
      n == 1 ? 'Стих скопирован в буфер' : 'Скопировано стихов: $n',
    );
    setState(() => _selectedVerses.clear());
  }

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final verses = appProvider.getCurrentVerses();
    final navRef = '${appProvider.currentBook}_${appProvider.currentChapter}';
    if (_navRef != navRef) {
      _navRef = navRef;
      _selectedVerses.clear();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const appBarBg = Color(0xFFB3E5FC);
    const buttonBg = Color(0xFFE1F5FE);
    const chromeTextColor = Colors.black;
    final verseBg = isDark ? Colors.grey.shade900 : Colors.white;
    final verseTextColor = isDark ? Colors.white : Colors.black;

    final toolbarH =
        (appProvider.chromeButtonSize + 10).clamp(kToolbarHeight, 78.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        foregroundColor: chromeTextColor,
        iconTheme: const IconThemeData(color: Colors.black),
        actionsIconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: toolbarH,
        automaticallyImplyLeading: false,
        titleSpacing: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final s = appProvider.chromeButtonSize;
            const g = 4.0;
            final trailingW = 3 * s + 8;
            final fullW = constraints.maxWidth;
            double sliceW = s;
            if (fullW.isFinite) {
              final availLeft = fullW - trailingW;
              final gaps = 3 * g;
              final forTwoSlices = availLeft - 2 * s - gaps;
              sliceW = (forTwoSlices / 2).clamp(s * 0.5, s);
            }

            return Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (appProvider.canGoPrevBible)
                          ChromeSliceNavButton(
                            width: sliceW,
                            height: s,
                            icon: Icons.arrow_back,
                            tooltip: 'Предыдущая глава',
                            foregroundColor: chromeTextColor,
                            backgroundColor: buttonBg,
                            onPressed: () async {
                              await appProvider.goPrev();
                            },
                          )
                        else
                          SizedBox(width: sliceW, height: s),
                        SizedBox(width: g),
                        ChromeNavTextButton(
                          label: BibleService()
                              .getBookAbbreviation(appProvider.currentBook),
                          foregroundColor: chromeTextColor,
                          backgroundColor: buttonBg,
                          onPressed: () =>
                              _showBookSelectionDialog(context),
                        ),
                        SizedBox(width: g),
                        ChromeNavTextButton(
                          label: '${appProvider.currentChapter}',
                          foregroundColor: chromeTextColor,
                          backgroundColor: buttonBg,
                          onPressed: () =>
                              _showChapterSelectionDialog(context),
                        ),
                        SizedBox(width: g),
                        if (appProvider.canGoNextBible)
                          ChromeSliceNavButton(
                            width: sliceW,
                            height: s,
                            icon: Icons.arrow_forward,
                            tooltip: 'Следующая глава',
                            foregroundColor: chromeTextColor,
                            backgroundColor: buttonBg,
                            onPressed: () async {
                              await appProvider.goNext();
                            },
                          )
                        else
                          SizedBox(width: sliceW, height: s),
                      ],
                    ),
                  ),
                ),
                ChromeIconButton(
                  icon: Icons.bookmarks_outlined,
                  tooltip: 'Избранное',
                  foregroundColor: chromeTextColor,
                  backgroundColor: buttonBg,
                  onPressed: () => _openBookmarksFromToolbar(
                    context,
                    appProvider,
                    verses,
                  ),
                ),
                const SizedBox(width: 4),
                ChromeIconButton(
                  icon: Icons.search,
                  tooltip: 'Поиск',
                  foregroundColor: chromeTextColor,
                  backgroundColor: buttonBg,
                  onPressed: () => _showSearchDialog(context),
                ),
                const SizedBox(width: 4),
                const AppChromeOverflowMenu(),
              ],
            );
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: GestureDetector(
              onHorizontalDragEnd: (details) async {
                if (details.primaryVelocity == null) return;
                if (details.primaryVelocity! > 0) {
                  if (appProvider.canGoPrevBible) await appProvider.goPrev();
                } else if (details.primaryVelocity! < 0) {
                  if (appProvider.canGoNextBible) await appProvider.goNext();
                }
              },
              child: appProvider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : verses.isEmpty
                      ? const Center(child: Text('Глава не найдена'))
                      : Stack(
                          clipBehavior: Clip.none,
                          children: [
                            ListView.builder(
                              key: ValueKey(
                                '${appProvider.currentBook}_${appProvider.currentChapter}_${appProvider.verseFontPreset}',
                              ),
                              controller: _scrollController,
                              itemCount: verses.length,
                              itemBuilder: (context, index) {
                                final verse = verses[index];
                                final num = verse['verse'] as int;
                                final verseText = '$num. ${verse['text']}';
                                final isSpeech = verse['type'] == 'speech';
                                Color textColor = verseTextColor;
                                if (isSpeech && appProvider.redLettersEnabled) {
                                  textColor = Colors.red;
                                }
                                final highlighted = _highlightVerse == num;
                                final selected = _selectedVerses.contains(num);
                                Color rowBg = verseBg;
                                if (highlighted) {
                                  rowBg = isDark
                                      ? Colors.blueGrey.shade700
                                      : Colors.amber.shade100;
                                } else if (selected) {
                                  rowBg = isDark
                                      ? Colors.blueGrey.shade700
                                      : Colors.amber.shade100;
                                }
                                final multiSelect = _selectedVerses.isNotEmpty;
                                final gap = index < verses.length - 1
                                    ? appProvider.verseSpacing
                                    : 0.0;
                                return Padding(
                                  padding: EdgeInsets.only(bottom: gap),
                                  child: Material(
                                    color: rowBg,
                                    child: InkWell(
                                      onTap: multiSelect
                                          ? () {
                                              setState(() {
                                                if (_selectedVerses
                                                    .contains(num)) {
                                                  _selectedVerses.remove(num);
                                                } else {
                                                  _selectedVerses.add(num);
                                                }
                                              });
                                            }
                                          : null,
                                      onLongPress: () {
                                        setState(() {
                                          if (_selectedVerses.contains(num)) {
                                            _selectedVerses.remove(num);
                                          } else {
                                            _selectedVerses.add(num);
                                          }
                                        });
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 2,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Text(
                                            verseText,
                                            style: appProvider
                                                .bibleVerseTextStyle(
                                              color: textColor,
                                              fontWeight: isSpeech
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                            if (_selectedVerses.isNotEmpty)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    ChromeIconButton(
                                      icon: Icons.copy_all,
                                      tooltip: 'Копировать',
                                      foregroundColor: chromeTextColor,
                                      backgroundColor: buttonBg,
                                      onPressed: () => _copySelectedVerses(
                                        context,
                                        appProvider,
                                        verses,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ChromeIconButton(
                                      icon: Icons.bookmark_add_outlined,
                                      tooltip: 'В избранное',
                                      foregroundColor: chromeTextColor,
                                      backgroundColor: buttonBg,
                                      onPressed: () =>
                                          _addSelectedVersesToBookmarks(
                                        context,
                                        appProvider,
                                        verses,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    ChromeIconButton(
                                      icon: Icons.close,
                                      tooltip: 'Отмена',
                                      foregroundColor: chromeTextColor,
                                      backgroundColor: buttonBg,
                                      onPressed: () => setState(
                                        () => _selectedVerses.clear(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
            ),
          ),
          if (_bottomBannerText != null)
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xE6323232),
                border: Border(
                  top: BorderSide(color: Color(0x44FFFFFF), width: 1),
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Text(
                _bottomBannerText!,
                style: const TextStyle(color: Colors.white, fontSize: 15),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final toolbarH =
        (appProvider.chromeButtonSize + 10).clamp(kToolbarHeight, 78.0);
    final prefs = await SharedPreferences.getInstance();
    final history = prefs.getStringList(_kBibleSearchHistoryKey) ?? [];
    if (!mounted || !context.mounted) return;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Search',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) {
        final topOffset = MediaQuery.paddingOf(dialogContext).top + toolbarH;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, topOffset + 2, 8, 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: _BibleSearchDialog(
                appProvider: appProvider,
                initialQuery: _searchDraft,
                initialResults: _searchResultRows
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList(),
                initialVz: _searchIncludeVz,
                initialNz: _searchIncludeNz,
                initialWholeWords: _searchWholeWords,
                history: history,
                historyKey: _kBibleSearchHistoryKey,
                onClosing: (q, results, vz, nz, wholeWords) {
                  _searchDraft = q;
                  _searchResultRows = results;
                  _searchIncludeVz = vz;
                  _searchIncludeNz = nz;
                  _searchWholeWords = wholeWords;
                },
                onPickResult: (book, chapter, verse) async {
                  Navigator.pop(dialogContext);
                  await appProvider.changeBookAndChapter(book, chapter);
                  if (!mounted) return;
                  final total = appProvider.getCurrentVerses().length;
                  _highlightVerseTemporarily(verse);
                  unawaited(_scrollToVerse(verse, total));
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  Future<void> _showBookmarksPanel(BuildContext context) async {
    if (!mounted || !context.mounted) return;
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final toolbarH =
        (appProvider.chromeButtonSize + 10).clamp(kToolbarHeight, 78.0);
    final panelSerial = ++_favoritesPanelSerial;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bookmarks',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) {
        final topOffset = MediaQuery.paddingOf(dialogContext).top + toolbarH;
        return SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(8, topOffset + 2, 8, 8),
            child: Align(
              alignment: Alignment.topCenter,
              child: _BibleBookmarksPanel(
                key: ValueKey(panelSerial),
                panelSerial: panelSerial,
                initialEntries:
                    _bookmarks.map((e) => e.copy()).toList(growable: false),
                onClosing: (entries, serial) {
                  if (!mounted || serial != _favoritesPanelSerial) return;
                  setState(
                    () => _bookmarks =
                        entries.map((e) => e.copy()).toList(growable: true),
                  );
                  unawaited(_persistBookmarks());
                },
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, -0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
    if (mounted) setState(() {});
  }

  void _showChapterSelectionDialog(BuildContext context, {String? forBook}) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final selectedBook = forBook ?? appProvider.currentBook;
    final chapterCount = BibleService().getChapterCount(selectedBook);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Выберите главу ($selectedBook)'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 300),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: List.generate(chapterCount, (index) {
                  final chapterNumber = index + 1;
                  final isCurrent = selectedBook == appProvider.currentBook &&
                      chapterNumber == appProvider.currentChapter;
                  return SizedBox(
                    width: 40,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        appProvider.changeBookAndChapter(
                          selectedBook,
                          chapterNumber,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        backgroundColor:
                            isCurrent ? Colors.blue : Colors.lightBlue[50],
                        foregroundColor:
                            isCurrent ? Colors.white : Colors.black,
                      ),
                      child: Text(
                        '$chapterNumber',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showBookSelectionDialog(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final oldTestamentBooks = appProvider.getBooks('old');
    final newTestamentBooks = appProvider.getBooks('new');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Выберите книгу'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Ветхий Завет:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: oldTestamentBooks.map((book) {
                    final isCurrentBook = book == appProvider.currentBook;
                    return TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            _showChapterSelectionDialog(context, forBook: book);
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: isCurrentBook
                            ? Colors.blue
                            : Colors.lightBlue[50],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        BibleService().getBookAbbreviation(book),
                        style: TextStyle(
                          color: isCurrentBook ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: isCurrentBook
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Новый Завет:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: newTestamentBooks.map((book) {
                    final isCurrentBook = book == appProvider.currentBook;
                    return TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (context.mounted) {
                            _showChapterSelectionDialog(context, forBook: book);
                          }
                        });
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: isCurrentBook
                            ? Colors.blue
                            : Colors.lightBlue[50],
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        BibleService().getBookAbbreviation(book),
                        style: TextStyle(
                          color: isCurrentBook ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: isCurrentBook
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BibleSearchDialog extends StatefulWidget {
  const _BibleSearchDialog({
    required this.appProvider,
    required this.initialQuery,
    required this.initialResults,
    required this.initialVz,
    required this.initialNz,
    required this.initialWholeWords,
    required this.history,
    required this.historyKey,
    required this.onClosing,
    required this.onPickResult,
  });

  final AppProvider appProvider;
  final String initialQuery;
  final List<Map<String, dynamic>> initialResults;
  final bool initialVz;
  final bool initialNz;
  final bool initialWholeWords;
  final List<String> history;
  final String historyKey;
  final void Function(
    String query,
    List<Map<String, dynamic>> results,
    bool vz,
    bool nz,
    bool wholeWords,
  ) onClosing;
  final Future<void> Function(String book, int chapter, int verse) onPickResult;

  @override
  State<_BibleSearchDialog> createState() => _BibleSearchDialogState();
}

class _BibleSearchDialogState extends State<_BibleSearchDialog> {
  late final TextEditingController _queryCtrl;
  late final FocusNode _focusNode;
  late List<Map<String, dynamic>> _results;
  late bool _vz;
  late bool _nz;
  late bool _wholeWords;
  late List<String> _history;
  bool _hasRunSearch = false;
  final LinkedHashSet<int> _selectedResultIndices = LinkedHashSet<int>();

  static const _hintStyle = TextStyle(
    color: Color(0xFFBDBDBD),
    fontWeight: FontWeight.w400,
  );
  static const _appBarBg = Color(0xFFB3E5FC);
  static const _buttonBg = Color(0xFFE1F5FE);
  static const _chromeTextColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _queryCtrl = TextEditingController(text: widget.initialQuery);
    _focusNode = FocusNode();
    _results =
        widget.initialResults.map((e) => Map<String, dynamic>.from(e)).toList();
    _vz = widget.initialVz;
    _nz = widget.initialNz;
    _wholeWords = widget.initialWholeWords;
    _history = List<String>.from(widget.history);
    _hasRunSearch = widget.initialQuery.trim().isNotEmpty ||
        widget.initialResults.isNotEmpty;
  }

  @override
  void dispose() {
    widget.onClosing(
      _queryCtrl.text,
      _results.map((e) => Map<String, dynamic>.from(e)).toList(),
      _vz,
      _nz,
      _wholeWords,
    );
    _queryCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setVz(bool? v) {
    var vz = v ?? false;
    var nz = _nz;
    if (!vz && !nz) {
      nz = true;
    }
    setState(() {
      _vz = vz;
      _nz = nz;
    });
  }

  void _setNz(bool? v) {
    var nz = v ?? false;
    var vz = _vz;
    if (!vz && !nz) {
      vz = true;
    }
    setState(() {
      _vz = vz;
      _nz = nz;
    });
  }

  Future<void> _persistHistoryIfMatch(String q) async {
    if (q.isEmpty || _results.isEmpty) return;
    _history.remove(q);
    _history.insert(0, q);
    if (_history.length > 40) {
      _history.removeRange(40, _history.length);
    }
    final p = await SharedPreferences.getInstance();
    await p.setStringList(widget.historyKey, List<String>.from(_history));
    if (mounted) setState(() {});
  }

  void _runSearch() {
    FocusManager.instance.primaryFocus?.unfocus();
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) return;
    final list = widget.appProvider.searchBible(
      q,
      includeOldTestament: _vz,
      includeNewTestament: _nz,
      wholeWordsOnly: _wholeWords,
    );
    setState(() {
      _results = list;
      _hasRunSearch = true;
      _selectedResultIndices.clear();
    });
    if (list.isNotEmpty) {
      unawaited(_persistHistoryIfMatch(q));
    }
  }

  Future<void> _copySelectedSearchResults(BuildContext context) async {
    if (_selectedResultIndices.isEmpty) return;
    final parts = <String>[];
    for (final i in _selectedResultIndices) {
      if (i < 0 || i >= _results.length) continue;
      final r = _results[i];
      final book = r['book'] as String;
      final ch = r['chapter'] as int;
      final v = r['verse'] as int;
      final text = (r['text'] as String?) ?? '';
      parts.add('$book $ch:$v $text');
    }
    if (parts.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: parts.join('\n')));
    if (!context.mounted) return;
    final n = parts.length;
    _showTransientOverlayMessage(
      context,
      n == 1 ? 'Стих скопирован в буфер' : 'Скопировано стихов: $n',
    );
    setState(() => _selectedResultIndices.clear());
  }

  List<String> _querySegments() {
    return _queryCtrl.text
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .toSet()
        .toList();
  }

  List<TextSpan> _buildHighlightedSpans(String text, TextStyle baseStyle) {
    final segments = _querySegments();
    if (text.isEmpty || segments.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final merged = bibleMergedQueryMatches(
      text,
      segments,
      wholeWordsOnly: _wholeWords,
    );
    if (merged.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    final spans = <TextSpan>[];
    var cursor = 0;
    for (final m in merged) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start), style: baseStyle));
      }
      spans.add(
        TextSpan(
          text: text.substring(m.start, m.end),
          style: baseStyle.copyWith(
            backgroundColor: Colors.amber.shade300,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width.clamp(320, double.infinity);
    final contentW = (w * 0.92).clamp(280.0, 640.0);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: Container(
          decoration: BoxDecoration(
            color: _appBarBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        (constraints.maxWidth / 420).clamp(0.76, 1.0);
                    final textScale = scale;
                    final checkboxScale =
                        (0.9 + (scale - 0.76) * 0.25).clamp(0.86, 1.0);
                    final chrome = widget.appProvider.chromeButtonSize;
                    final closeIc = (chrome * 0.5).clamp(18.0, 30.0);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            TextButton.icon(
                              onPressed: _runSearch,
                              style: TextButton.styleFrom(
                                backgroundColor: _buttonBg,
                                foregroundColor: _chromeTextColor,
                                minimumSize: Size(0, chrome),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12 * scale,
                                  vertical: 4,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(
                                Icons.search,
                                size: (chrome * 0.45).clamp(16.0, 24.0),
                              ),
                              label: Text(
                                'Найти',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14 * textScale,
                                ),
                              ),
                            ),
                            const Spacer(),
                            Transform.scale(
                              scale: checkboxScale,
                              child: Checkbox(
                                value: _vz,
                                onChanged: _setVz,
                                visualDensity: VisualDensity.compact,
                                activeColor: _buttonBg,
                                checkColor: _chromeTextColor,
                                side: const BorderSide(
                                  color: _chromeTextColor,
                                ),
                              ),
                            ),
                            Text(
                              'ВЗ',
                              style: TextStyle(fontSize: 14 * textScale),
                            ),
                            SizedBox(width: 8 * scale),
                            Transform.scale(
                              scale: checkboxScale,
                              child: Checkbox(
                                value: _nz,
                                onChanged: _setNz,
                                visualDensity: VisualDensity.compact,
                                activeColor: _buttonBg,
                                checkColor: _chromeTextColor,
                                side: const BorderSide(
                                  color: _chromeTextColor,
                                ),
                              ),
                            ),
                            Text(
                              'НЗ',
                              style: TextStyle(fontSize: 14 * textScale),
                            ),
                            const Spacer(),
                            Material(
                              color: _buttonBg,
                              borderRadius: BorderRadius.circular(8),
                              clipBehavior: Clip.antiAlias,
                              child: InkWell(
                                onTap: () => Navigator.pop(context),
                                child: SizedBox(
                                  width: chrome,
                                  height: chrome,
                                  child: Icon(
                                    Icons.close,
                                    color: _chromeTextColor,
                                    size: closeIc,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 4 * scale),
                        Row(
                          children: [
                            Transform.scale(
                              scale: checkboxScale,
                              child: Checkbox(
                                value: _wholeWords,
                                onChanged: (v) {
                                  setState(() => _wholeWords = v ?? false);
                                },
                                visualDensity: VisualDensity.compact,
                                activeColor: _buttonBg,
                                checkColor: _chromeTextColor,
                                side: const BorderSide(
                                  color: _chromeTextColor,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'Целое слово (не часть слова)',
                                style: TextStyle(
                                  fontSize: 13 * textScale,
                                  color: _chromeTextColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: _buttonBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                  child: RawAutocomplete<String>(
                    textEditingController: _queryCtrl,
                    focusNode: _focusNode,
                    optionsBuilder: (TextEditingValue tev) {
                      final normalized = tev.text.toLowerCase().trim();
                      if (normalized.isEmpty) {
                        return const Iterable<String>.empty();
                      }
                      final segments = normalized
                          .split(RegExp(r'\s+'))
                          .where((s) => s.isNotEmpty)
                          .toList();
                      return _history.where((h) {
                        final candidate = h.toLowerCase();
                        for (final segment in segments) {
                          if (!candidate.contains(segment)) return false;
                        }
                        return true;
                      });
                    },
                    onSelected: (s) {
                      _queryCtrl.text = s;
                      _queryCtrl.selection =
                          TextSelection.collapsed(offset: s.length);
                    },
                    fieldViewBuilder:
                        (context, controller, focusNode, onFieldSubmitted) {
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        style: const TextStyle(
                          color: _chromeTextColor,
                        ),
                        cursorColor: _chromeTextColor,
                        decoration: InputDecoration(
                          hintText: 'Набери текст',
                          hintStyle: _hintStyle,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 10,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                        onSubmitted: (_) => _runSearch(),
                      );
                    },
                    optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 6,
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: 220,
                              maxWidth: contentW,
                            ),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (context, index) {
                                final o = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(o),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 12,
                                    ),
                                    child: Text(
                                      o,
                                      style: TextStyle(color: _chromeTextColor),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (_hasRunSearch && _results.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 320),
                          child: Scrollbar(
                            child: ListView.separated(
                              shrinkWrap: true,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 2),
                              itemCount: _results.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final r = _results[i];
                                final book = r['book'] as String;
                                final ch = r['chapter'] as int;
                                final v = r['verse'] as int;
                                final text = (r['text'] as String?) ?? '';
                                final preview = text.length > 100
                                    ? '${text.substring(0, 100)}…'
                                    : text;
                                final multi =
                                    _selectedResultIndices.isNotEmpty;
                                final picked =
                                    _selectedResultIndices.contains(i);
                                return Material(
                                  color: picked
                                      ? Colors.amber.shade100
                                      : Colors.transparent,
                                  child: InkWell(
                                    onTap: multi
                                        ? () {
                                            setState(() {
                                              if (_selectedResultIndices
                                                  .contains(i)) {
                                                _selectedResultIndices
                                                    .remove(i);
                                              } else {
                                                _selectedResultIndices.add(i);
                                              }
                                            });
                                          }
                                        : () => widget.onPickResult(
                                              book,
                                              ch,
                                              v,
                                            ),
                                    onLongPress: () {
                                      setState(() {
                                        if (_selectedResultIndices
                                            .contains(i)) {
                                          _selectedResultIndices.remove(i);
                                        } else {
                                          _selectedResultIndices.add(i);
                                        }
                                      });
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 10,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '$book $ch:$v',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: _chromeTextColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          RichText(
                                            text: TextSpan(
                                              children: _buildHighlightedSpans(
                                                preview,
                                                DefaultTextStyle.of(context)
                                                    .style
                                                    .copyWith(
                                                      color: Colors
                                                          .grey.shade800,
                                                    ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                      if (_selectedResultIndices.isNotEmpty)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ChromeIconButton(
                                icon: Icons.copy_all,
                                tooltip: 'Копировать',
                                foregroundColor: _chromeTextColor,
                                backgroundColor: _buttonBg,
                                onPressed: () {
                                  unawaited(
                                    _copySelectedSearchResults(context),
                                  );
                                },
                              ),
                              const SizedBox(width: 4),
                              ChromeIconButton(
                                icon: Icons.close,
                                tooltip: 'Отмена',
                                foregroundColor: _chromeTextColor,
                                backgroundColor: _buttonBg,
                                onPressed: () => setState(
                                  () => _selectedResultIndices.clear(),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
                if (_hasRunSearch)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Найдено совпадений: ${_results.length}',
                      style: const TextStyle(
                        color: _chromeTextColor,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BibleBookmarksPanel extends StatefulWidget {
  const _BibleBookmarksPanel({
    super.key,
    required this.panelSerial,
    required this.initialEntries,
    required this.onClosing,
  });

  final int panelSerial;
  final List<_BookmarkTab> initialEntries;
  final void Function(List<_BookmarkTab> entries, int panelSerial) onClosing;

  @override
  State<_BibleBookmarksPanel> createState() => _BibleBookmarksPanelState();
}

class _BibleBookmarksPanelState extends State<_BibleBookmarksPanel> {
  late List<_BookmarkTab> _entries;
  final LinkedHashSet<int> _selectedEntryIndices = LinkedHashSet<int>();

  static const _appBarBg = Color(0xFFB3E5FC);
  static const _buttonBg = Color(0xFFE1F5FE);
  static const _chromeTextColor = Colors.black;

  @override
  void initState() {
    super.initState();
    _entries = widget.initialEntries.map((e) => e.copy()).toList();
  }

  @override
  void dispose() {
    widget.onClosing(
      _entries.map((e) => e.copy()).toList(growable: false),
      widget.panelSerial,
    );
    super.dispose();
  }

  String _headerLine(int ordinal, DateTime at) {
    String two(int x) => x.toString().padLeft(2, '0');
    final stamp =
        '${two(at.day)}.${two(at.month)}.${at.year} ${two(at.hour)}:${two(at.minute)}';
    return '$ordinal · $stamp';
  }

  void _toggleSelectAll() {
    setState(() {
      if (_entries.isEmpty) return;
      // Одна запись: кнопка только дополняет выделение, не снимает его.
      if (_entries.length == 1) {
        _selectedEntryIndices.add(0);
        return;
      }
      if (_selectedEntryIndices.length == _entries.length) {
        _selectedEntryIndices.clear();
      } else {
        _selectedEntryIndices.clear();
        for (var i = 0; i < _entries.length; i++) {
          _selectedEntryIndices.add(i);
        }
      }
    });
  }

  Future<void> _copySelected() async {
    if (_selectedEntryIndices.isEmpty) return;
    final ordered = _selectedEntryIndices.toList()..sort();
    final parts = <String>[];
    for (final i in ordered) {
      final e = _entries[i];
      parts.add('${_headerLine(i + 1, e.createdAt)}\n${e.text}');
    }
    await Clipboard.setData(ClipboardData(text: parts.join('\n\n')));
    if (!mounted) return;
    _showTransientOverlayMessage(
      context,
      parts.length == 1
          ? 'Запись скопирована'
          : 'Скопировано записей: ${parts.length}',
    );
  }

  void _deleteSelected() {
    if (_selectedEntryIndices.isEmpty) return;
    final sorted = _selectedEntryIndices.toList()
      ..sort((a, b) => b.compareTo(a));
    setState(() {
      for (final i in sorted) {
        _entries.removeAt(i);
      }
      _selectedEntryIndices.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width.clamp(320, double.infinity);
    final statScale = (w / 420).clamp(0.76, 1.0);
    final hasSelection = _selectedEntryIndices.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: Container(
          decoration: BoxDecoration(
            color: _appBarBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scale =
                        (constraints.maxWidth / 420).clamp(0.76, 1.0);
                    final textScale = scale;
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Избранное',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15 * textScale,
                              color: _chromeTextColor,
                            ),
                          ),
                        ),
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasSelection) ...[
                                ChromeIconButton(
                                  icon: Icons.select_all,
                                  tooltip: _entries.length > 1 &&
                                          _selectedEntryIndices.length ==
                                              _entries.length &&
                                          _entries.isNotEmpty
                                      ? 'Снять выделение'
                                      : 'Выделить всё',
                                  foregroundColor: _chromeTextColor,
                                  backgroundColor: _buttonBg,
                                  onPressed: _toggleSelectAll,
                                ),
                                const SizedBox(width: 4),
                                ChromeIconButton(
                                  icon: Icons.copy_all,
                                  tooltip: 'Копировать',
                                  foregroundColor: _chromeTextColor,
                                  backgroundColor: _buttonBg,
                                  onPressed: () => unawaited(_copySelected()),
                                ),
                                const SizedBox(width: 4),
                                ChromeIconButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Удалить',
                                  foregroundColor: _chromeTextColor,
                                  backgroundColor: _buttonBg,
                                  onPressed: _deleteSelected,
                                ),
                                const SizedBox(width: 4),
                              ],
                              ChromeIconButton(
                                icon: Icons.close,
                                tooltip: 'Закрыть',
                                foregroundColor: _chromeTextColor,
                                backgroundColor: _buttonBg,
                                onPressed: () => Navigator.pop(context),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (_entries.isEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: _buttonBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 22,
                    ),
                    child: const Text(
                      'Пока нет записей. Выделите стихи на экране Библии и нажмите «В избранное».',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _chromeTextColor, height: 1.35),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 360),
                      child: Scrollbar(
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                          itemCount: _entries.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final n = i + 1;
                            final picked = _selectedEntryIndices.contains(i);
                            final multi = _selectedEntryIndices.isNotEmpty;
                            final isDark = Theme.of(context).brightness ==
                                Brightness.dark;
                            final subStyle = DefaultTextStyle.of(context)
                                .style
                                .copyWith(
                                  color: Colors.grey.shade800,
                                  height: 1.35,
                                  fontSize: 15,
                                );
                            Color rowTint = Colors.transparent;
                            if (picked) {
                              rowTint = isDark
                                  ? Colors.blueGrey.shade700
                                  : Colors.amber.shade100;
                            }
                            return Material(
                              color: rowTint,
                              child: InkWell(
                                onTap: multi
                                    ? () {
                                        setState(() {
                                          if (_selectedEntryIndices
                                              .contains(i)) {
                                            _selectedEntryIndices.remove(i);
                                          } else {
                                            _selectedEntryIndices.add(i);
                                          }
                                        });
                                      }
                                    : null,
                                onLongPress: () {
                                  setState(() {
                                    if (_selectedEntryIndices.contains(i)) {
                                      _selectedEntryIndices.remove(i);
                                    } else {
                                      _selectedEntryIndices.add(i);
                                    }
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 8,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        _headerLine(n, e.createdAt),
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          color: _chromeTextColor,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        e.text,
                                        style: subStyle,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                if (_entries.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      hasSelection
                          ? 'Всего записей: ${_entries.length} · Выбрано: ${_selectedEntryIndices.length}'
                          : 'Всего записей: ${_entries.length}',
                      style: TextStyle(
                        color: _chromeTextColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 12 * statScale,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
