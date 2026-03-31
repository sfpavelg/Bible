import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Черновик поиска: сохраняется между открытиями, пока не нажали сброс в диалоге.
  String _searchDraft = '';
  List<Map<String, dynamic>> _searchResultRows = [];
  bool _searchIncludeVz = true;
  bool _searchIncludeNz = true;

  @override
  void dispose() {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          n == 1 ? 'Стих скопирован в буфер' : 'Скопировано стихов: $n',
        ),
      ),
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

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        foregroundColor: chromeTextColor,
        iconTheme: const IconThemeData(color: Colors.black),
        actionsIconTheme: const IconThemeData(color: Colors.black),
        elevation: 0,
        scrolledUnderElevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
        ),
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 400;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: buttonBg,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: chromeTextColor),
                    iconSize: isWide ? 18 : 16,
                    padding: const EdgeInsets.all(4),
                    onPressed: () async {
                      await appProvider.goPrev();
                    },
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: buttonBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 36),
                  child: TextButton(
                    onPressed: () => _showBookSelectionDialog(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 8 : 4,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      BibleService().getBookAbbreviation(appProvider.currentBook),
                      style: TextStyle(
                        color: chromeTextColor,
                        fontSize: isWide ? 14 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: BoxDecoration(
                    color: buttonBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  child: TextButton(
                    onPressed: () => _showChapterSelectionDialog(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(
                        horizontal: isWide ? 8 : 4,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      '${appProvider.currentChapter}',
                      style: TextStyle(
                        color: chromeTextColor,
                        fontSize: isWide ? 14 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Container(
                  decoration: const BoxDecoration(
                    color: buttonBg,
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: chromeTextColor),
                    iconSize: isWide ? 18 : 16,
                    padding: const EdgeInsets.all(4),
                    onPressed: () async {
                      await appProvider.goNext();
                    },
                  ),
                ),
              ],
            );
          },
        ),
        actions: [
          Container(
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: chromeTextColor),
              onPressed: () => _showSearchDialog(context),
            ),
          ),
          const AppChromeOverflowMenu(),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) async {
          if (details.primaryVelocity == null) return;
          if (details.primaryVelocity! > 0) {
            await appProvider.goPrev();
          } else if (details.primaryVelocity! < 0) {
            await appProvider.goNext();
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
                            rowBg = Colors.lightBlue.shade100;
                          }
                          final multiSelect =
                              _selectedVerses.isNotEmpty;
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
                                          if (_selectedVerses.contains(num)) {
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
                                      style: appProvider.bibleVerseTextStyle(
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
                              Container(
                                decoration: BoxDecoration(
                                  color: buttonBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.copy_all,
                                    color: chromeTextColor,
                                  ),
                                  tooltip: 'Копировать',
                                  onPressed: () => _copySelectedVerses(
                                    context,
                                    appProvider,
                                    verses,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Container(
                                decoration: BoxDecoration(
                                  color: buttonBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: chromeTextColor,
                                  ),
                                  tooltip: 'Отмена',
                                  onPressed: () => setState(
                                    () => _selectedVerses.clear(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
      ),
    );
  }

  Future<void> _showSearchDialog(BuildContext context) async {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
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
        final topOffset = MediaQuery.paddingOf(dialogContext).top + kToolbarHeight;
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
                history: history,
                historyKey: _kBibleSearchHistoryKey,
                onClosing: (q, results, vz, nz) {
                  _searchDraft = q;
                  _searchResultRows = results;
                  _searchIncludeVz = vz;
                  _searchIncludeNz = nz;
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
  final List<String> history;
  final String historyKey;
  final void Function(
    String query,
    List<Map<String, dynamic>> results,
    bool vz,
    bool nz,
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
  late List<String> _history;
  bool _hasRunSearch = false;

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
    );
    setState(() {
      _results = list;
      _hasRunSearch = true;
    });
    if (list.isNotEmpty) {
      unawaited(_persistHistoryIfMatch(q));
    }
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

    final matches = <({int start, int end})>[];
    final lowerText = text.toLowerCase();
    for (final segment in segments) {
      var from = 0;
      while (from < lowerText.length) {
        final index = lowerText.indexOf(segment, from);
        if (index == -1) break;
        matches.add((start: index, end: index + segment.length));
        from = index + segment.length;
      }
    }
    if (matches.isEmpty) {
      return [TextSpan(text: text, style: baseStyle)];
    }

    matches.sort((a, b) => a.start.compareTo(b.start));
    final merged = <({int start, int end})>[];
    for (final m in matches) {
      if (merged.isEmpty || m.start > merged.last.end) {
        merged.add(m);
      } else if (m.end > merged.last.end) {
        merged[merged.length - 1] = (start: merged.last.start, end: m.end);
      }
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
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12 * scale,
                                  vertical: 8 * scale,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(Icons.search, size: 18 * scale),
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
                                  width: 36 * scale,
                                  height: 36 * scale,
                                  child: Icon(
                                    Icons.close,
                                    color: _chromeTextColor,
                                    size: 20 * scale,
                                  ),
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
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          itemCount: _results.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _results[i];
                            final book = r['book'] as String;
                            final ch = r['chapter'] as int;
                            final v = r['verse'] as int;
                            final text = (r['text'] as String?) ?? '';
                            final preview = text.length > 100
                                ? '${text.substring(0, 100)}…'
                                : text;
                            return ListTile(
                              dense: false,
                              visualDensity: VisualDensity.standard,
                              contentPadding:
                                  const EdgeInsets.symmetric(horizontal: 6),
                              title: Text(
                                '$book $ch:$v',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: _chromeTextColor,
                                ),
                              ),
                              subtitle: RichText(
                                text: TextSpan(
                                  children: _buildHighlightedSpans(
                                    preview,
                                    DefaultTextStyle.of(context)
                                        .style
                                        .copyWith(
                                          color: Colors.grey.shade800,
                                        ),
                                  ),
                                ),
                              ),
                              onTap: () => widget.onPickResult(book, ch, v),
                            );
                          },
                        ),
                      ),
                    ),
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
