import 'dart:async';
import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';

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
                            rowBg = Colors.amber.shade100;
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

  void _showSearchDialog(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    final searchController = TextEditingController();
    bool includeOld = true;
    bool includeNew = true;
    List<Map<String, dynamic>> results = [];

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Поиск по Библии'),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: searchController,
                      decoration: const InputDecoration(
                        hintText: 'Введите текст',
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) {
                        final q = searchController.text.trim();
                        if (q.isEmpty) return;
                        results = appProvider.searchBible(
                          q,
                          includeOldTestament: includeOld,
                          includeNewTestament: includeNew,
                        );
                        setModalState(() {});
                      },
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: CheckboxListTile(
                            value: includeOld,
                            onChanged: (v) {
                              setModalState(() => includeOld = v ?? true);
                            },
                            title: const Text('ВЗ'),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                        Expanded(
                          child: CheckboxListTile(
                            value: includeNew,
                            onChanged: (v) {
                              setModalState(() => includeNew = v ?? true);
                            },
                            title: const Text('НЗ'),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                    if (results.isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final r = results[i];
                            final book = r['book'] as String;
                            final ch = r['chapter'] as int;
                            final v = r['verse'] as int;
                            final text = (r['text'] as String?) ?? '';
                            final preview = text.length > 80
                                ? '${text.substring(0, 80)}…'
                                : text;
                            return ListTile(
                              dense: true,
                              title: Text(
                                '$book $ch:$v',
                                style: const TextStyle(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(preview),
                              onTap: () async {
                                await appProvider.changeBookAndChapter(book, ch);
                                if (!mounted) return;
                                Navigator.pop(dialogContext);
                                final total =
                                    appProvider.getCurrentVerses().length;
                                _highlightVerseTemporarily(v);
                                unawaited(_scrollToVerse(v, total));
                              },
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Закрыть'),
                ),
                FilledButton(
                  onPressed: () {
                    final q = searchController.text.trim();
                    if (q.isEmpty) return;
                    results = appProvider.searchBible(
                      q,
                      includeOldTestament: includeOld,
                      includeNewTestament: includeNew,
                    );
                    setModalState(() {});
                  },
                  child: const Text('Найти'),
                ),
              ],
            );
          },
        );
      },
    );
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
