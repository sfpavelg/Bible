import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/utils/app_exit.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  final ScrollController _scrollController = ScrollController();
  int? _highlightVerse;
  Timer? _highlightTimer;

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

  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final verses = appProvider.getCurrentVerses();
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
          Container(
            decoration: BoxDecoration(
              color: buttonBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: chromeTextColor),
              onSelected: (value) {
                if (value == 'settings') {
                  _showSettingsDialog(context);
                } else if (value == 'support') {
                  _showSupportDialog(context);
                } else if (value == 'exit') {
                  requestAppExit();
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'settings', child: Text('Настройки')),
                PopupMenuItem(value: 'support', child: Text('Техподдержка')),
                PopupMenuDivider(),
                PopupMenuItem(value: 'exit', child: Text('Выход')),
              ],
            ),
          ),
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
                : ListView.builder(
                    key: ValueKey(
                      '${appProvider.currentBook}_${appProvider.currentChapter}',
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
                      return Material(
                        color: highlighted
                            ? Colors.amber.shade100
                            : verseBg,
                        child: ListTile(
                          title: Text(
                            verseText,
                            style: TextStyle(
                              fontSize: appProvider.fontSize,
                              height: appProvider.lineHeight,
                              color: textColor,
                              fontWeight:
                                  isSpeech ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                        ),
                      );
                    },
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

  void _showSettingsDialog(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (dialogRouteContext) {
        ThemeMode selectedTheme = appProvider.themeMode;
        double fontSize = appProvider.fontSize;
        double lineHeight = appProvider.lineHeight;
        bool redLettersEnabled = appProvider.redLettersEnabled;
        final screenSize = MediaQuery.of(dialogRouteContext).size;
        final dialogWidth = (screenSize.width * 0.92).clamp(320.0, 520.0);
        final dialogMaxHeight = screenSize.height * 0.82;

        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            final themeGroup = selectedTheme == ThemeMode.system
                ? ThemeMode.light
                : selectedTheme;
            return Theme(
              data: ThemeData.light(useMaterial3: true).copyWith(
                colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
              ),
              child: Builder(
                builder: (dialogThemeContext) {
                  return AlertDialog(
                    backgroundColor: Colors.lightBlue[50],
                    titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                    title: Row(
                      children: [
                        const Expanded(child: Text('Настройки')),
                        Material(
                          color: Colors.lightBlue.shade100,
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => Navigator.pop(modalContext),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue, width: 1.2),
                              ),
                              child: const Icon(Icons.close, size: 20),
                            ),
                          ),
                        ),
                      ],
                    ),
                    content: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: dialogWidth,
                        maxHeight: dialogMaxHeight,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Тема',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            RadioListTile<ThemeMode>(
                              value: ThemeMode.light,
                              groupValue: themeGroup,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Светлая'),
                              activeColor: Colors.blue,
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() => selectedTheme = value);
                                appProvider.setThemeMode(value);
                              },
                            ),
                            RadioListTile<ThemeMode>(
                              value: ThemeMode.dark,
                              groupValue: themeGroup,
                              dense: true,
                              visualDensity: VisualDensity.compact,
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Тёмная'),
                              activeColor: Colors.blue,
                              onChanged: (value) {
                                if (value == null) return;
                                setModalState(() => selectedTheme = value);
                                appProvider.setThemeMode(value);
                              },
                            ),
                            const SizedBox(height: 10),
                            const Text(
                              'Размер шрифта',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(dialogThemeContext).copyWith(
                                activeTrackColor: Colors.blue,
                                inactiveTrackColor: Colors.blue.shade100,
                                thumbColor: Colors.blue,
                                overlayColor: Colors.blue.withOpacity(0.12),
                              ),
                              child: Slider(
                                value: fontSize.clamp(12.0, 28.0),
                                min: 12.0,
                                max: 28.0,
                                divisions: 16,
                                label: fontSize.toStringAsFixed(0),
                                onChanged: (value) {
                                  setModalState(() => fontSize = value);
                                  appProvider.changeFontSize(value);
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Межстрочный интервал',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            SliderTheme(
                              data: SliderTheme.of(dialogThemeContext).copyWith(
                                activeTrackColor: Colors.blue,
                                inactiveTrackColor: Colors.blue.shade100,
                                thumbColor: Colors.blue,
                                overlayColor: Colors.blue.withOpacity(0.12),
                              ),
                              child: Slider(
                                value: lineHeight.clamp(1.0, 2.2),
                                min: 1.0,
                                max: 2.2,
                                divisions: 12,
                                label: lineHeight.toStringAsFixed(2),
                                onChanged: (value) {
                                  setModalState(() => lineHeight = value);
                                  appProvider.changeLineHeight(value);
                                },
                              ),
                            ),
                            const SizedBox(height: 8),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Красные буквы'),
                              value: redLettersEnabled,
                              activeColor: Colors.blue,
                              onChanged: (value) {
                                setModalState(() => redLettersEnabled = value);
                                appProvider.setRedLettersEnabled(value);
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  void _showSupportDialog(BuildContext context) {
    const supportPayload =
        'Автор проекта: Софеин Павел Геннадьевич\n'
        'Контактная почта: sfpavelg@gmail.com\n'
        'Версия проекта: ver_28_03_2026';

    showDialog(
      context: context,
      builder: (routeContext) {
        return Theme(
          data: ThemeData.light(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
          ),
          child: Builder(
            builder: (_) {
              return AlertDialog(
                backgroundColor: Colors.lightBlue[50],
                titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
                title: Row(
                  children: [
                    const Expanded(child: Text('Техподдержка')),
                    Material(
                      color: Colors.lightBlue.shade100,
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => Navigator.pop(routeContext),
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blue, width: 1.2),
                          ),
                          child: const Icon(Icons.close, size: 20),
                        ),
                      ),
                    ),
                  ],
                ),
                content: const SizedBox(
                  width: 360,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Автор проекта:'),
                      SizedBox(height: 4),
                      Text(
                        'Софеин Павел Геннадьевич',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 12),
                      Text('Контактная почта:'),
                      SizedBox(height: 4),
                      Text(
                        'sfpavelg@gmail.com',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(height: 12),
                      Text('Версия проекта:'),
                      SizedBox(height: 4),
                      Text(
                        'ver_28_03_2026',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                actions: [
                  Material(
                    color: Colors.lightBlue.shade100,
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: supportPayload),
                        );
                        if (!routeContext.mounted) return;
                        ScaffoldMessenger.of(routeContext).showSnackBar(
                          const SnackBar(
                            content: Text('Данные техподдержки скопированы'),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.blue, width: 1.2),
                        ),
                        child: const Icon(Icons.copy_all, size: 20),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
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
