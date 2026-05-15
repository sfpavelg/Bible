import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/models/bible_model.dart';
import 'package:bible_app/navigation/app_tab_switcher.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/widgets/app_bottom_notice.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_frost_glass_panel.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:bible_app/widgets/main_chrome_tab_bar.dart';
import 'package:shared_preferences/shared_preferences.dart';

void _showTransientOverlayMessage(
  BuildContext context,
  String message, {
  Duration duration = const Duration(seconds: 2),
}) {
  showAppBottomNotice(context, message, duration: duration);
}

// --- Цвета панелей «Поиск» и «Избранное» = шапка и тело основного экрана Библии ---

bool _bibleScreenIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

bool _scrollPositionHasMetrics(ScrollController c) =>
    c.hasClients && c.position.hasContentDimensions;

Color _bibleScreenAppBarBg(BuildContext context) => _bibleScreenIsDark(context)
    ? const Color(0xFF37474F)
    : BibleLightPalette.topBarBg;

Color _bibleScreenButtonBg(BuildContext context) => _bibleScreenIsDark(context)
    ? const Color(0xFF455A64)
    : BibleLightPalette.chromePillFill;

/// Непрозрачный фон плавающих кнопок поверх стихов и списков.
Color _bibleScreenOverlayButtonBg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? const Color(0xFF455A64)
        : BibleLightPalette.chromePillBg;

Color _bibleScreenChromeFg(BuildContext context) =>
    _bibleScreenIsDark(context) ? Colors.white : BibleLightPalette.primaryText;

Color _bibleScreenPanelHeadingFg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? _bibleScreenChromeFg(context)
        : BibleLightPalette.primaryDark;

Color _bibleScreenVerseAreaBg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? Colors.grey.shade900
        : BibleLightPalette.cardFillSecondary;

Color _bibleScreenVerseMutedFg(BuildContext context) =>
    _bibleScreenIsDark(context) ? Colors.grey.shade300 : BibleLightPalette.secondaryText;

Color _bibleScreenVerseHighlightBg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? BibleLightPalette.primaryDark.withValues(alpha: 0.42)
        : BibleLightPalette.verseHighlightBg;

Color _bibleScreenRowHighlight(BuildContext context) =>
    _bibleScreenVerseHighlightBg(context);

Color _bibleScreenSearchMatchHighlight(BuildContext context) =>
    _bibleScreenVerseHighlightBg(context);

double _bibleSearchControlPanelRadius(double panelRowHeight) =>
    panelRowHeight / 2;

double _bibleSearchTextCharWidth(String char, TextStyle style) {
  final painter = TextPainter(
    text: TextSpan(text: char, style: style),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width;
}

Color _bibleSearchControlPanelTrackColor(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? const Color(0xFF37474F)
        : BibleLightPalette.disabledBg;

BorderSide _bibleChromeOutlineSide(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? ChromeOutline.side
        : BibleLightPalette.chromePillOutlineSide;

double _bibleBookChipMinWidth(String book, double fontSize, double padH) {
  final abbr = BibleService().getBookAbbreviation(book);
  final painter = TextPainter(
    text: TextSpan(
      text: abbr,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.width + padH * 2;
}

/// Раскладка как у [Wrap], но в каждой строке кнопки одной ширины на всю строку.
List<List<String>> _packBibleBookRows(
  List<String> books,
  double maxWidth,
  double spacing,
  double padH,
  double fontSize,
) {
  if (books.isEmpty || maxWidth <= 0) return const [];

  final rows = <List<String>>[];
  var row = <String>[];

  double rowMaxMinWidth() {
    if (row.isEmpty) return 0;
    return row
        .map((b) => _bibleBookChipMinWidth(b, fontSize, padH))
        .fold(0.0, math.max);
  }

  double equalCellWidth(int count) {
    if (count <= 0) return maxWidth;
    return (maxWidth - spacing * (count - 1)) / count;
  }

  for (final book in books) {
    final minW = _bibleBookChipMinWidth(book, fontSize, padH);
  loop:
    while (true) {
      final tryCount = row.length + 1;
      final cellW = equalCellWidth(tryCount);
      final maxMin = row.isEmpty ? minW : math.max(rowMaxMinWidth(), minW);
      if (row.isEmpty || cellW >= maxMin) {
        row.add(book);
        break loop;
      }
      rows.add(List<String>.from(row));
      row = [];
    }
  }
  if (row.isNotEmpty) rows.add(row);
  return rows;
}

double _bibleBookChipRowHeight(double fontSize, double padV) {
  final painter = TextPainter(
    text: TextSpan(
      text: '1Пар',
      style: TextStyle(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        height: 1.15,
      ),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  return painter.height + padV * 2 + 2.4;
}

double _bibleBookSelectionGridHeight({
  required List<String> books,
  required double maxWidth,
  required double horizontalGap,
  required double verticalGap,
  required double padH,
  required double padV,
  required double bookAbbrFs,
}) {
  final rows = _packBibleBookRows(
    books,
    maxWidth,
    horizontalGap,
    padH,
    bookAbbrFs,
  );
  if (rows.isEmpty) return 0;
  final rowH = _bibleBookChipRowHeight(bookAbbrFs, padV);
  return rows.length * rowH + math.max(0, rows.length - 1) * verticalGap;
}

/// Сетка кнопок книг: в полной строке кнопки одной ширины на всю строку;
/// в неполном последнем ряду — тот же размер, без растягивания на всю ширину.
class _BibleBookSelectionChipGrid extends StatelessWidget {
  const _BibleBookSelectionChipGrid({
    required this.books,
    required this.currentBook,
    required this.isDark,
    required this.horizontalGap,
    required this.verticalGap,
    required this.padH,
    required this.padV,
    required this.bookAbbrFs,
    required this.onBookTap,
  });

  final List<String> books;
  final String currentBook;
  final bool isDark;
  final double horizontalGap;
  final double verticalGap;
  final double padH;
  final double padV;
  final double bookAbbrFs;
  final ValueChanged<String> onBookTap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        final rows = _packBibleBookRows(
          books,
          maxW,
          horizontalGap,
          padH,
          bookAbbrFs,
        );
        final maxRowLen = rows.isEmpty
            ? 0
            : rows.map((r) => r.length).reduce(math.max);
        final chipWidth = maxRowLen > 0
            ? (maxW - horizontalGap * (maxRowLen - 1)) / maxRowLen
            : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var r = 0; r < rows.length; r++) ...[
              if (r > 0) SizedBox(height: verticalGap),
              Builder(
                builder: (context) {
                  final row = rows[r];
                  final isPartialLastRow =
                      r == rows.length - 1 && row.length < maxRowLen;
                  if (isPartialLastRow) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var c = 0; c < row.length; c++) ...[
                          if (c > 0) SizedBox(width: horizontalGap),
                          SizedBox(
                            width: chipWidth,
                            child: _chip(row[c]),
                          ),
                        ],
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < row.length; c++) ...[
                        if (c > 0) SizedBox(width: horizontalGap),
                        Expanded(child: _chip(row[c])),
                      ],
                    ],
                  );
                },
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _chip(String book) {
    final isCurrentBook = book == currentBook;
    return TextButton(
      onPressed: () => onBookTap(book),
      style: TextButton.styleFrom(
        backgroundColor: isCurrentBook
            ? (isDark ? Colors.blue : BibleLightPalette.primary)
            : (isDark ? Colors.lightBlue[50] : BibleLightPalette.activeBg),
        foregroundColor: isCurrentBook
            ? Colors.white
            : (isDark ? Colors.black : BibleLightPalette.primaryText),
        side: isDark
            ? BorderSide.none
            : BorderSide(
                color: isCurrentBook
                    ? BibleLightPalette.primaryDark
                    : BibleLightPalette.chromePillOutlineColor,
                width: 1.2,
              ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(
        BibleService().getBookAbbreviation(book),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrentBook
              ? Colors.white
              : (isDark ? Colors.black : BibleLightPalette.primaryText),
          fontSize: bookAbbrFs,
          fontWeight: isCurrentBook ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Текст панели «Избранное»: тот же шрифт, размер и интервал, что у стихов в настройках.
TextStyle _favoritesPanelTextStyle(
  AppProvider app, {
  required Color color,
  required FontWeight fontWeight,
  double? fontSize,
}) {
  return TextStyle(
    fontFamily: app.verseFontFamily,
    fontFamilyFallback: app.verseFontFallback,
    fontSize: (fontSize ?? app.fontSize) * app.verseFontSizeScale,
    height: app.lineHeight,
    color: color,
    fontWeight: fontWeight,
  );
}

String _bibleVisibleText(AppProvider app, String text) {
  final noMarkup = BibleService.stripInlineMarkupTags(text);
  if (app.showSeptuagintText) return noMarkup;
  return BibleService.stripSeptuagintBracketedText(noMarkup);
}

const String _bibleNoteMarker = '\uE000';
final RegExp _bibleInlineNoteTag = RegExp(r'<note>(.*?)</note>', dotAll: true);

class _BibleVerseDisplayPayload {
  const _BibleVerseDisplayPayload({
    required this.textWithMarkers,
    required this.notes,
  });

  final String textWithMarkers;
  final List<String> notes;
}

_BibleVerseDisplayPayload _bibleVerseDisplayPayloadFromRaw(
  String raw,
) {
  final src = BibleService.decodeInlineTagEntities(raw);
  final notes = <String>[];
  final buf = StringBuffer();
  var from = 0;
  for (final m in _bibleInlineNoteTag.allMatches(src)) {
    if (m.start > from) buf.write(src.substring(from, m.start));
    final body = (m.group(1) ?? '').trim();
    if (body.isNotEmpty) {
      notes.add(body);
      buf.write(_bibleNoteMarker);
    }
    from = m.end;
  }
  if (from < src.length) buf.write(src.substring(from));
  var out = buf.toString();
  out = out.replaceAll(RegExp(r'</?[^>]+>'), '');
  out = out.replaceAll(RegExp(r'\s{2,}'), ' ');
  out = out.replaceAllMapped(
    RegExp(r'\s+([,.;:!?])'),
    (m) => m.group(1) ?? '',
  );
  return _BibleVerseDisplayPayload(
    textWithMarkers: out.trim(),
    notes: notes,
  );
}

Future<void> _replaceClipboardText(String text) async {
  await Clipboard.setData(ClipboardData(text: text));
}

/// Тело записи «Избранное»: жирная ссылка (книга, глава, стих) и текст в кавычках; по строке на стих.
Widget _favoritesEntryBody(
  _BookmarkTab tab, {
  required Color fg,
  required TextStyle baseStyle,
}) {
  if (tab.verses.isEmpty) {
    return Text(tab.plainText, style: baseStyle);
  }
  final refStyle = baseStyle.copyWith(
    fontWeight: FontWeight.bold,
    color: fg,
  );
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (var i = 0; i < tab.verses.length; i++) ...[
        if (i != 0) const SizedBox(height: 6),
        Text.rich(
          TextSpan(
            style: baseStyle,
            children: [
              TextSpan(text: tab.verses[i].reference, style: refStyle),
              const TextSpan(text: ' '),
              TextSpan(text: '"${tab.verses[i].body}"'),
            ],
          ),
        ),
      ],
    ],
  );
}

class _BookmarkVerseLine {
  const _BookmarkVerseLine({required this.reference, required this.body});

  final String reference;
  final String body;

  _BookmarkVerseLine copy() =>
      _BookmarkVerseLine(reference: reference, body: body);
}

class _BibleSelectedRangeBlock {
  const _BibleSelectedRangeBlock({
    required this.reference,
    required this.body,
  });

  final String reference;
  final String body;
}

class _BookmarkTab {
  _BookmarkTab._({
    required this.verses,
    required this.createdAt,
    String? legacyPlain,
  }) : _legacyPlain = legacyPlain;

  /// Новая запись: по одному блоку на стих, ссылка и текст разделены для вёрстки.
  factory _BookmarkTab.structured({
    required List<_BookmarkVerseLine> verses,
    required DateTime createdAt,
  }) {
    return _BookmarkTab._(verses: verses, createdAt: createdAt);
  }

  /// Старые сохранённые записи (один сплошной текст).
  factory _BookmarkTab.legacy({
    required String text,
    required DateTime createdAt,
  }) {
    return _BookmarkTab._(
      verses: const [],
      createdAt: createdAt,
      legacyPlain: text,
    );
  }

  final List<_BookmarkVerseLine> verses;
  final DateTime createdAt;
  final String? _legacyPlain;

  bool get _isStructured => verses.isNotEmpty;

  /// Плоский текст для буфера и совместимости с полем `text` в JSON.
  String get plainText {
    if (_isStructured) {
      return verses.map((v) => '${v.reference} "${v.body}"').join('\n');
    }
    return _legacyPlain ?? '';
  }

  Map<String, dynamic> toJson() {
    final at = createdAt.toIso8601String();
    if (_isStructured) {
      return {
        'at': at,
        'v': verses
            .map((e) => <String, dynamic>{'r': e.reference, 't': e.body})
            .toList(growable: false),
        'text': plainText,
      };
    }
    return {
      'at': at,
      'text': _legacyPlain ?? '',
    };
  }

  static _BookmarkTab fromJson(Map<String, dynamic> j) {
    final at = DateTime.tryParse(j['at'] as String? ?? '') ?? DateTime.now();
    final rawV = j['v'];
    if (rawV is List<dynamic> && rawV.isNotEmpty) {
      final parsed = <_BookmarkVerseLine>[];
      for (final row in rawV) {
        if (row is! Map) continue;
        final m = Map<String, dynamic>.from(row);
        final r = m['r'] as String? ?? '';
        final t = m['t'] as String? ?? '';
        parsed.add(_BookmarkVerseLine(reference: r, body: t));
      }
      if (parsed.isNotEmpty) {
        return _BookmarkTab.structured(verses: parsed, createdAt: at);
      }
    }
    return _BookmarkTab.legacy(
      text: j['text'] as String? ?? '',
      createdAt: at,
    );
  }

  _BookmarkTab copy() {
    if (_isStructured) {
      return _BookmarkTab.structured(
        verses: verses.map((e) => e.copy()).toList(growable: false),
        createdAt: createdAt,
      );
    }
    return _BookmarkTab.legacy(
      text: _legacyPlain ?? '',
      createdAt: createdAt,
    );
  }
}

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  /// Светлая шапка — прозрачная, градиент экрана из [MainScreen].
  static const Color _appBarBgLight = Colors.transparent;
  static const Color _buttonBgLight = BibleLightPalette.chromePillFill;

  /// Согласован с нижней навигацией в тёмной теме.
  static const Color _appBarBgDark = Color(0xFF37474F);
  static const Color _buttonBgDark = Color(0xFF455A64);

  final ScrollController _scrollController = ScrollController();

  Future<void> _showVerseNoteDialog(String noteText) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        title: Text(
          'Примечание',
          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                color: _bibleScreenPanelHeadingFg(ctx),
                fontWeight: FontWeight.w700,
              ),
        ),
        content: Builder(
          builder: (contentContext) {
            final app = contentContext.watch<AppProvider>();
            final fg = _bibleScreenChromeFg(contentContext);
            final bg = _bibleScreenAppBarBg(contentContext);
            final textStyle = app.bibleVerseTextStyle(
              color: fg,
              fontWeight: FontWeight.normal,
            );
            final maxH = MediaQuery.sizeOf(contentContext).height * 0.72;
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 560,
                maxHeight: maxH.clamp(180.0, 900.0),
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Scrollbar(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: DefaultTextStyle(
                      style: textStyle,
                      child: Text(noteText),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  List<InlineSpan> _buildVerseInlineSpans(
    AppProvider app,
    String textWithMarkers,
    List<String> notes, {
    required Color textColor,
  }) {
    final baseStyle = app.bibleVerseTextStyle(
      color: textColor,
      fontWeight: FontWeight.normal,
    );
    final starStyle = baseStyle.copyWith(
      color: Colors.blue,
      fontWeight: FontWeight.w700,
      height: 1.0,
    );
    final noteBtnHeight = app.fontSize.clamp(12.0, 28.0);
    final noteBtnWidth = (app.fontSize * 2).clamp(24.0, 56.0);
    final noteBtnRadius = (noteBtnHeight * 0.22).clamp(4.0, 8.0);
    final spans = <InlineSpan>[];
    final b = StringBuffer();
    var noteIdx = 0;
    void flushBuffer() {
      if (b.isEmpty) return;
      spans.add(TextSpan(text: b.toString(), style: baseStyle));
      b.clear();
    }

    for (var i = 0; i < textWithMarkers.length; i++) {
      final ch = textWithMarkers[i];
      if (ch == _bibleNoteMarker) {
        flushBuffer();
        final noteText = noteIdx < notes.length ? notes[noteIdx] : '';
        noteIdx++;
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Material(
                color: _bibleScreenButtonBg(context),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(noteBtnRadius),
                  side: _bibleChromeOutlineSide(context),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: noteText.isEmpty
                      ? null
                      : () => unawaited(_showVerseNoteDialog(noteText)),
                  child: SizedBox(
                    width: noteBtnWidth,
                    height: noteBtnHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: Text(
                          '*',
                          style: starStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      } else {
        b.write(ch);
      }
    }
    flushBuffer();
    return spans;
  }

  /// Ключи строк главы по номеру стиха — для [Scrollable.ensureVisible] при переходе из поиска.
  final Map<int, GlobalKey> _verseRowKeys = {};
  int? _highlightVerse;
  Timer? _highlightTimer;

  /// Первый стих — долгим нажатием; дальше — обычным касанием.
  final LinkedHashSet<int> _selectedVerses = LinkedHashSet<int>();
  String _navRef = '';

  /// Сброс [GlobalKey] строк при смене главы или параметров вёрстки списка стихов.
  String _verseListLayoutRef = '';

  static const String _kBibleSearchHistoryKey = 'bible_search_matched_history';
  static const String _kBibleBookmarksKey = 'bible_bookmarks_tabs';

  List<_BookmarkTab> _bookmarks = [];

  /// Увеличивается при каждом открытии панели «Избранное», чтобы игнорировать
  /// поздний [dispose] предыдущего диалога (он перезаписывал список старыми данными).
  int _favoritesPanelSerial = 0;


  /// Черновик поиска: сохраняется между открытиями, пока не нажали сброс в диалоге.
  String _searchDraft = '';
  List<Map<String, dynamic>> _searchResultRows = [];
  bool _searchIncludeVz = true;
  bool _searchIncludeNz = true;
  bool _searchWholeWords = false;
  /// Сохраняется между открытиями диалога поиска (список результатов).
  double _searchResultsScrollOffset = 0;

  VoidCallback? _bibleVerseJumpListener;

  @override
  void initState() {
    super.initState();
    unawaited(_loadBookmarks());
    _bibleVerseJumpListener = () {
      final r = bibleVerseJumpRequest.value;
      if (r == null) return;
      bibleVerseJumpRequest.value = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(_consumeBibleVerseJumpFromPlan(r));
      });
    };
    bibleVerseJumpRequest.addListener(_bibleVerseJumpListener!);
  }

  /// План «Вера» и др.: после смены главы из журнала — подсветка первого стиха, как из поиска.
  Future<void> _consumeBibleVerseJumpFromPlan(BibleVerseJumpRequest r) async {
    final app = Provider.of<AppProvider>(context, listen: false);
    for (var i = 0; i < 80; i++) {
      if (!mounted) return;
      if (app.currentBook == r.book && app.currentChapter == r.chapter) {
        _highlightVerseTemporarily(r.verse);
        await _scrollToVerse(r.verse);
        return;
      }
      await WidgetsBinding.instance.endOfFrame;
      await Future<void>.delayed(const Duration(milliseconds: 8));
    }
  }

  Future<void> _loadBookmarks() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kBibleBookmarksKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<dynamic>) return;
      final list = decoded
          .map(
              (e) => _BookmarkTab.fromJson(Map<String, dynamic>.from(e as Map)))
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
    if (!_isBibleInteractionActive) return;
    final lines = _selectedBookmarkVerses(appProvider, verses);
    if (lines != null) {
      setState(() {
        _bookmarks.add(
          _BookmarkTab.structured(
            verses: lines,
            createdAt: DateTime.now(),
          ),
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

  List<_BookmarkVerseLine>? _selectedBookmarkVerses(
    AppProvider appProvider,
    List<Map<String, dynamic>> verses,
  ) {
    if (_selectedVerses.isEmpty) return null;
    final blocks = _buildSelectedRangeBlocks(appProvider, verses);
    if (blocks.isEmpty) return null;
    return blocks
        .map(
          (b) => _BookmarkVerseLine(
            reference: b.reference,
            body: b.body,
          ),
        )
        .toList(growable: false);
  }

  List<_BibleSelectedRangeBlock> _buildSelectedRangeBlocks(
    AppProvider appProvider,
    List<Map<String, dynamic>> verses,
  ) {
    final ordered = _selectedVerses.toList()..sort();
    if (ordered.isEmpty) return const [];
    final ranges = <({int start, int end})>[];
    var start = ordered.first;
    var prev = ordered.first;
    for (var i = 1; i < ordered.length; i++) {
      final cur = ordered[i];
      if (cur == prev + 1) {
        prev = cur;
        continue;
      }
      ranges.add((start: start, end: prev));
      start = cur;
      prev = cur;
    }
    ranges.add((start: start, end: prev));

    final out = <_BibleSelectedRangeBlock>[];
    for (final r in ranges) {
      final ref = r.start == r.end
          ? '${appProvider.currentBook} ${appProvider.currentChapter}:${r.start}'
          : '${appProvider.currentBook} ${appProvider.currentChapter}:${r.start}-${r.end}';
      final lines = <String>[];
      for (var n = r.start; n <= r.end; n++) {
        final text = _verseText(verses, n);
        if (text == null) continue;
        lines.add('$n. $text');
      }
      if (lines.isEmpty) continue;
      out.add(
        _BibleSelectedRangeBlock(
          reference: ref,
          body: lines.join('\n'),
        ),
      );
    }
    return out;
  }

  void _addSelectedVersesToBookmarks(
    BuildContext context,
    AppProvider appProvider,
    List<Map<String, dynamic>> verses,
  ) {
    if (!_isBibleInteractionActive) return;
    final lines = _selectedBookmarkVerses(appProvider, verses);
    if (lines == null) return;
    setState(() {
      _bookmarks.add(
        _BookmarkTab.structured(
          verses: lines,
          createdAt: DateTime.now(),
        ),
      );
      _selectedVerses.clear();
    });
    unawaited(_persistBookmarks());
    if (!context.mounted) return;
    _showBottomBanner('Добавлено в избранное');
  }

  void _showBottomBanner(String message) {
    if (!mounted) return;
    showAppBottomNotice(context, message);
  }

  @override
  void dispose() {
    final lj = _bibleVerseJumpListener;
    if (lj != null) {
      bibleVerseJumpRequest.removeListener(lj);
    }
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  /// Пока поверх приложения открыт диалог, маршрут вкладки не «текущий» — не даём
  /// жестам и копипасту на экране Библии срабатывать под оверлеем.
  bool get _isBibleInteractionActive {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  void _highlightVerseTemporarily(int verse) {
    _highlightTimer?.cancel();
    setState(() => _highlightVerse = verse);
    _highlightTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _highlightVerse = null);
    });
  }

  Future<void> _scrollToVerse(int verseNum) async {
    if (!mounted) return;
    final app = Provider.of<AppProvider>(context, listen: false);
    var verses = <Map<String, dynamic>>[];
    var index = -1;

    // Дождаться списка после смены главы; rough jump — иначе у строки вне экрана
    // у GlobalKey ещё нет context (ListView.builder не построил элемент).
    for (var wait = 0; wait < 16; wait++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      verses = app.getCurrentVerses();
      if (verses.isEmpty) {
        await Future<void>.delayed(const Duration(milliseconds: 24));
        continue;
      }
      index = -1;
      for (var i = 0; i < verses.length; i++) {
        final vn = verses[i]['verse'];
        final n = vn is int ? vn : (vn as num).toInt();
        if (n == verseNum) {
          index = i;
          break;
        }
      }
      if (index >= 0 && _scrollController.hasClients) break;
      await Future<void>.delayed(const Duration(milliseconds: 24));
    }

    if (index >= 0 &&
        verses.isNotEmpty &&
        _scrollController.hasClients &&
        verses.length > 1) {
      final pos = _scrollController.position;
      final max = pos.maxScrollExtent;
      final t = index / (verses.length - 1);
      pos.jumpTo((max * t).clamp(0.0, max));
      await WidgetsBinding.instance.endOfFrame;
    }

    if (!mounted) return;
    for (var attempt = 0; attempt < 12; attempt++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) return;
      final ctx = _verseRowKeys[verseNum]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOut,
        );
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  String? _verseText(List<Map<String, dynamic>> verses, int verseNum) {
    for (final v in verses) {
      if (v['verse'] == verseNum) {
        final raw = v['text'] as String?;
        if (raw == null) return null;
        final app = Provider.of<AppProvider>(context, listen: false);
        return _bibleVisibleText(app, raw);
      }
    }
    return null;
  }

  void _copySelectedVerses(
    BuildContext context,
    AppProvider appProvider,
    List<Map<String, dynamic>> verses,
  ) {
    if (!_isBibleInteractionActive) return;
    if (_selectedVerses.isEmpty) return;
    final blocks = _buildSelectedRangeBlocks(appProvider, verses);
    final parts = <String>[];
    for (final b in blocks) {
      parts.add('(${b.reference})\n"${b.body}"');
    }
    if (parts.isEmpty) return;
    unawaited(_replaceClipboardText(parts.join('\n')));
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
    final verseLayoutRef =
        '${navRef}_${appProvider.verseFontPreset}_${appProvider.fontSize}_${appProvider.lineHeight}_${appProvider.verseSpacing}';
    if (_verseListLayoutRef != verseLayoutRef) {
      _verseListLayoutRef = verseLayoutRef;
      _verseRowKeys.clear();
    }
    if (_navRef != navRef) {
      _navRef = navRef;
      _selectedVerses.clear();
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appBarBg = isDark ? _appBarBgDark : _appBarBgLight;
    final buttonBg = isDark ? _buttonBgDark : _buttonBgLight;
    final chromeTextColor =
        isDark ? Colors.white : BibleLightPalette.primaryText;
    final verseBg = isDark ? Colors.grey.shade900 : Colors.transparent;
    final verseTextColor =
        isDark ? Colors.white : BibleLightPalette.primaryText;
    final iconFg = isDark ? chromeTextColor : BibleLightPalette.iconActive;
    final iconFgDisabled = isDark
        ? chromeTextColor.withValues(alpha: 0.35)
        : BibleLightPalette.disabledText;
    final lightChromeOutline =
        isDark ? null : BibleLightPalette.chromePillOutlineSide;

    final toolbarH =
        AppProvider.toolbarHeightForChrome(appProvider.chromeButtonSize);

    final scaffold = Scaffold(
      backgroundColor: isDark ? null : Colors.transparent,
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: isDark ? appBarBg : Colors.transparent,
        foregroundColor: chromeTextColor,
        iconTheme: IconThemeData(color: iconFg),
        actionsIconTheme: IconThemeData(color: iconFg),
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
            final g = (s * 0.12).clamp(4.0, 10.0);
            final maxW = constraints.maxWidth;

            Widget prevBtn(double w) {
              final can = appProvider.canGoPrevBible;
              return ChromeIconButton(
                icon: Icons.arrow_back,
                width: w,
                tooltip: can ? 'Предыдущая глава' : 'Нет предыдущей главы',
                foregroundColor: can ? iconFg : iconFgDisabled,
                backgroundColor: buttonBg,
                circular: false,
                outlineSide: lightChromeOutline,
                onPressed: can
                    ? () async {
                        await appProvider.goPrev();
                      }
                    : null,
              );
            }

            Widget nextBtn(double w) {
              final can = appProvider.canGoNextBible;
              return ChromeIconButton(
                icon: Icons.arrow_forward,
                width: w,
                tooltip: can ? 'Следующая глава' : 'Нет следующей главы',
                foregroundColor: can ? iconFg : iconFgDisabled,
                backgroundColor: buttonBg,
                circular: false,
                outlineSide: lightChromeOutline,
                onPressed: can
                    ? () async {
                        await appProvider.goNext();
                      }
                    : null,
              );
            }

            Widget bookBtn(double w) => ChromeNavTextButton(
                  width: w,
                  height: s,
                  label: BibleService()
                      .getBookAbbreviation(appProvider.currentBook),
                  foregroundColor:
                      isDark ? chromeTextColor : BibleLightPalette.iconActive,
                  backgroundColor: buttonBg,
                  outlineSide: lightChromeOutline,
                  onPressed: () => _showBookSelectionDialog(context),
                );

            Widget chapterBtn(double w) => ChromeNavTextButton(
                  width: w,
                  height: s,
                  label: '${appProvider.currentChapter}',
                  foregroundColor:
                      isDark ? chromeTextColor : BibleLightPalette.iconActive,
                  backgroundColor: buttonBg,
                  outlineSide: lightChromeOutline,
                  onPressed: () => _showChapterSelectionDialog(context),
                );

            Widget favBtn(double w) => ChromeIconButton(
                  icon: Icons.bookmarks_outlined,
                  width: w,
                  tooltip: 'Избранное',
                  foregroundColor: iconFg,
                  backgroundColor: buttonBg,
                  outlineSide: lightChromeOutline,
                  onPressed: () => _openBookmarksFromToolbar(
                    context,
                    appProvider,
                    verses,
                  ),
                );

            Widget searchBtn(double w) => ChromeIconButton(
                  icon: Icons.search,
                  width: w,
                  tooltip: 'Поиск',
                  foregroundColor: iconFg,
                  backgroundColor: buttonBg,
                  outlineSide: lightChromeOutline,
                  onPressed: () => _showSearchDialog(context),
                );

            Widget menuBtn(double w) => AppChromeOverflowMenu(
                  iconColor: iconFg,
                  backgroundColor: buttonBg,
                  tileWidth: w,
                  shapeSide: lightChromeOutline,
                );

            /// Полная ширина кнопок [s] с отступами [2*g] и шестью зазорами [g] между кнопками.
            final fitsWide = maxW.isFinite && maxW + 0.5 >= 7 * s + 8 * g;

            if (fitsWide) {
              final row = SizedBox(
                width: maxW,
                height: s,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: g),
                  child: Row(
                    children: [
                      prevBtn(s),
                      SizedBox(width: g),
                      bookBtn(s),
                      SizedBox(width: g),
                      chapterBtn(s),
                      SizedBox(width: g),
                      nextBtn(s),
                      const Spacer(),
                      SizedBox(width: g),
                      searchBtn(s),
                      SizedBox(width: g),
                      favBtn(s),
                      SizedBox(width: g),
                      menuBtn(s),
                    ],
                  ),
                ),
              );
              return Center(child: row);
            }

            final innerW = maxW.isFinite ? maxW - 2 * g : double.infinity;
            var cellW = maxW.isFinite ? (maxW - 8 * g) / 7 : s;
            if (!cellW.isFinite || cellW < 1) cellW = 1;
            if (cellW > s) cellW = s;
            final contentW = 7 * cellW + 6 * g;
            final needsScale = maxW.isFinite && contentW > innerW + 0.5;

            Widget splitRow(double w) => Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        prevBtn(w),
                        SizedBox(width: g),
                        bookBtn(w),
                        SizedBox(width: g),
                        chapterBtn(w),
                        SizedBox(width: g),
                        nextBtn(w),
                      ],
                    ),
                    SizedBox(width: g),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        searchBtn(w),
                        SizedBox(width: g),
                        favBtn(w),
                        SizedBox(width: g),
                        menuBtn(w),
                      ],
                    ),
                  ],
                );

            final narrowPadded = Padding(
              padding: EdgeInsets.symmetric(horizontal: g),
              child: splitRow(cellW),
            );

            if (needsScale) {
              return Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: SizedBox(
                    width: contentW + 2 * g,
                    height: s,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: g),
                      child: splitRow(cellW),
                    ),
                  ),
                ),
              );
            }

            return Center(
              child: SizedBox(
                width: maxW,
                height: s,
                child: narrowPadded,
              ),
            );
          },
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: isDark
                ? IgnorePointer(
                    ignoring: !_isBibleInteractionActive,
                    child: GestureDetector(
                      onHorizontalDragEnd: (details) async {
                        if (!_isBibleInteractionActive) return;
                        if (details.primaryVelocity == null) return;
                        if (details.primaryVelocity! > 0) {
                          if (appProvider.canGoPrevBible) {
                            await appProvider.goPrev();
                          }
                        } else if (details.primaryVelocity! < 0) {
                          if (appProvider.canGoNextBible) {
                            await appProvider.goNext();
                          }
                        }
                      },
                      child: _bibleVerseBody(
                        appProvider: appProvider,
                        verses: verses,
                        verseBg: verseBg,
                        verseTextColor: verseTextColor,
                        isDark: isDark,
                        chromeTextColor: chromeTextColor,
                        buttonBg: buttonBg,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        gradient: BibleLightPalette.verseCardGradient,
                        border: Border.all(
                          color: BibleLightPalette.border,
                          width: 1,
                        ),
                        boxShadow: BibleLightPalette.verseCardShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: IgnorePointer(
                          ignoring: !_isBibleInteractionActive,
                          child: GestureDetector(
                            onHorizontalDragEnd: (details) async {
                              if (!_isBibleInteractionActive) return;
                              if (details.primaryVelocity == null) return;
                              if (details.primaryVelocity! > 0) {
                                if (appProvider.canGoPrevBible) {
                                  await appProvider.goPrev();
                                }
                              } else if (details.primaryVelocity! < 0) {
                                if (appProvider.canGoNextBible) {
                                  await appProvider.goNext();
                                }
                              }
                            },
                            child: _bibleVerseBody(
                              appProvider: appProvider,
                              verses: verses,
                              verseBg: verseBg,
                              verseTextColor: verseTextColor,
                              isDark: isDark,
                              chromeTextColor: chromeTextColor,
                              buttonBg: buttonBg,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );

    return scaffold;
  }

  Widget _bibleVerseBody({
    required AppProvider appProvider,
    required List<Map<String, dynamic>> verses,
    required Color verseBg,
    required Color verseTextColor,
    required bool isDark,
    required Color chromeTextColor,
    required Color buttonBg,
  }) {
    final overlayIconFg =
        isDark ? chromeTextColor : BibleLightPalette.iconActive;
    final overlayChromeOutline =
        isDark ? null : BibleLightPalette.chromePillOutlineSide;
    final overlayButtonBg = _bibleScreenOverlayButtonBg(context);

    return appProvider.isLoading
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
                      final payload = _bibleVerseDisplayPayloadFromRaw(
                        (verse['text'] ?? '').toString(),
                      );
                      final verseTextWithMarkers =
                          '$num. ${payload.textWithMarkers}';
                      Color textColor = verseTextColor;
                      final highlighted = _highlightVerse == num;
                      final selected = _selectedVerses.contains(num);
                      Color rowBg = verseBg;
                      if (highlighted || selected) {
                        rowBg = _bibleScreenVerseHighlightBg(context);
                      }
                      final multiSelect = _selectedVerses.isNotEmpty;
                      final gap = index < verses.length - 1
                          ? appProvider.verseSpacing
                          : 0.0;
                      final showDivider =
                          !isDark && index < verses.length - 1;
                      return KeyedSubtree(
                        key: _verseRowKeys.putIfAbsent(
                          num,
                          GlobalKey.new,
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(bottom: gap),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: rowBg,
                              border: showDivider
                                  ? const Border(
                                      bottom: BorderSide(
                                        color: BibleLightPalette.verseDivider,
                                        width: 1,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Material(
                              color: Colors.transparent,
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
                                    child: Text.rich(
                                      TextSpan(
                                        children: _buildVerseInlineSpans(
                                          appProvider,
                                          verseTextWithMarkers,
                                          payload.notes,
                                          textColor: textColor,
                                        ),
                                      ),
                                    ),
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
                            foregroundColor: overlayIconFg,
                            backgroundColor: overlayButtonBg,
                            outlineSide: overlayChromeOutline,
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
                            foregroundColor: overlayIconFg,
                            backgroundColor: overlayButtonBg,
                            outlineSide: overlayChromeOutline,
                            onPressed: () => _addSelectedVersesToBookmarks(
                              context,
                              appProvider,
                              verses,
                            ),
                          ),
                          const SizedBox(width: 4),
                          ChromeIconButton(
                            icon: Icons.highlight_off_outlined,
                            tooltip: 'Отмена',
                            foregroundColor: overlayIconFg,
                            backgroundColor: overlayButtonBg,
                            outlineSide: overlayChromeOutline,
                            onPressed: () =>
                                setState(() => _selectedVerses.clear()),
                          ),
                        ],
                      ),
                    ),
                ],
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
        final chrome = appProvider.chromeButtonSize;
        final topReserved = AppProvider.toolbarHeightForChrome(chrome) + 8;
        final bottomReserved = mainChromeTabBarTotalHeight(dialogContext) + 8;
        return SizedBox.expand(
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(0, topReserved, 0, bottomReserved),
              child: Align(
                alignment: Alignment.topRight,
                child: Material(
                  color: _bibleScreenAppBarBg(dialogContext),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: _bibleChromeOutlineSide(dialogContext),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _BibleSearchDialog(
                    appProvider: appProvider,
                    initialQuery: _searchDraft,
                    initialResults: _searchResultRows
                        .map((e) => Map<String, dynamic>.from(e))
                        .toList(),
                    initialScrollOffset: _searchResultsScrollOffset,
                    initialVz: _searchIncludeVz,
                    initialNz: _searchIncludeNz,
                    initialWholeWords: _searchWholeWords,
                    history: history,
                    historyKey: _kBibleSearchHistoryKey,
                    onClosing: (q, results, vz, nz, wholeWords, scrollOffset) {
                      _searchDraft = q;
                      _searchResultRows = results;
                      _searchIncludeVz = vz;
                      _searchIncludeNz = nz;
                      _searchWholeWords = wholeWords;
                      _searchResultsScrollOffset = scrollOffset;
                    },
                    onPickResult: (book, chapter, verse) async {
                      Navigator.pop(dialogContext);
                      await appProvider.changeBookAndChapter(book, chapter);
                      if (!mounted) return;
                      _highlightVerseTemporarily(verse);
                      unawaited(_scrollToVerse(verse));
                    },
                  ),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
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
        AppProvider.toolbarHeightForChrome(appProvider.chromeButtonSize);
    final panelSerial = ++_favoritesPanelSerial;

    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Bookmarks',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (dialogContext, _, __) {
        final topOffset = MediaQuery.paddingOf(dialogContext).top + toolbarH;
        final isDark =
            Theme.of(dialogContext).brightness == Brightness.dark;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: GestureDetector(
                onTap: () => Navigator.of(dialogContext).pop(),
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: isDark
                      ? const Color(0x8A000000)
                      : const Color(0x24000000),
                ),
              ),
            ),
            SafeArea(
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
            ),
          ],
        );
      },
      transitionBuilder: (_, animation, __, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOut);
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
      builder: (dialogContext) {
        return Consumer<AppProvider>(
          builder: (ctx, app, _) {
            final uiFs = app.fontSize;
            final titleFs = (uiFs * 1.0).clamp(15.0, 28.0);
            final chapterNumFs = (uiFs * 0.875).clamp(12.0, 24.0);
            final chapterCell =
                (uiFs * 2.5).clamp(34.0, 56.0); // ~40 при шрифте 16
            final wrapGap = (uiFs * 0.25).clamp(3.0, 10.0);
            final mq = MediaQuery.of(dialogContext);
            final h = mq.size.height;
            final w = mq.size.width;
            final maxDialogH =
                (h - mq.viewPadding.vertical - 12).clamp(120.0, h);
            final dialogMaxW = (w - 16).clamp(280.0, 440.0);
            const padH = 16.0;
            const padTop = 16.0;
            const padBottom = 14.0;
            const gapAfterTitle = 10.0;
            final contentW = dialogMaxW - padH * 2;
            final cols = math.max(
              1,
              ((contentW + wrapGap) / (chapterCell + wrapGap)).floor(),
            );
            final rowCount = (chapterCount + cols - 1) ~/ cols;
            final gridHeight = rowCount * chapterCell +
                math.max(0, rowCount - 1) * wrapGap;
            final titleText =
                'Выберите главу (${BibleBook.liturgicalDisplayName(selectedBook)})';
            final titleStyle = TextStyle(
              fontSize: titleFs,
              fontWeight: FontWeight.w600,
              color: _bibleScreenPanelHeadingFg(dialogContext),
              height: 1.2,
            );
            final titlePainter = TextPainter(
              text: TextSpan(text: titleText, style: titleStyle),
              textDirection: TextDirection.ltr,
              maxLines: 4,
            )..layout(maxWidth: contentW);
            final headerH = padTop + titlePainter.height + gapAfterTitle;
            final bodyMaxH = (maxDialogH - headerH - padBottom).clamp(48.0, maxDialogH);
            final needsScroll = gridHeight > bodyMaxH;
            final bodyH = needsScroll ? bodyMaxH : gridHeight;
            final chapterButtons = List.generate(chapterCount, (index) {
                              final chapterNumber = index + 1;
                              final isCurrent = selectedBook == app.currentBook &&
                                  chapterNumber == app.currentChapter;
                              final isLight = !_bibleScreenIsDark(dialogContext);
                              return SizedBox(
                                width: chapterCell,
                                height: chapterCell,
                                child: ElevatedButton(
                                  onPressed: () {
                                    app.changeBookAndChapter(
                                      selectedBook,
                                      chapterNumber,
                                    );
                                    Navigator.pop(dialogContext);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    shape: const CircleBorder(),
                                    elevation: 0,
                                    backgroundColor: isCurrent
                                        ? (isLight
                                            ? BibleLightPalette.primary
                                            : Colors.blue)
                                        : (isLight
                                            ? BibleLightPalette.activeBg
                                            : Colors.lightBlue[50]),
                                    foregroundColor: isCurrent
                                        ? Colors.white
                                        : (isLight
                                            ? BibleLightPalette.primaryText
                                            : Colors.black),
                                    side: isLight
                                        ? BorderSide(
                                            color: isCurrent
                                                ? BibleLightPalette.primaryDark
                                                : BibleLightPalette
                                                    .chromePillOutlineColor,
                                            width: 1.2,
                                          )
                                        : BorderSide.none,
                                  ),
                                  child: Text(
                                    '$chapterNumber',
                                    style: TextStyle(
                                      fontSize: chapterNumFs,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              );
            });
            final chapterGrid = Wrap(
              spacing: wrapGap,
              runSpacing: wrapGap,
              alignment: WrapAlignment.center,
              children: chapterButtons,
            );
            return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.symmetric(
            horizontal: (uiFs * 0.5).clamp(6.0, 14.0),
            vertical: (uiFs * 0.375).clamp(4.0, 12.0),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: DecoratedBox(
              decoration: _bibleScreenIsDark(dialogContext)
                  ? const BoxDecoration(
                      color: Color(0xFF37474F),
                      borderRadius: BorderRadius.all(Radius.circular(22)),
                    )
                  : BibleLightPalette.lightPanelShellDecoration(radius: 22),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: dialogMaxW,
                  maxHeight: maxDialogH,
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    padH,
                    padTop,
                    padH,
                    padBottom,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        titleText,
                        style: titleStyle,
                      ),
                      const SizedBox(height: gapAfterTitle),
                      SizedBox(
                        height: bodyH,
                        child: needsScroll
                            ? SingleChildScrollView(child: chapterGrid)
                            : chapterGrid,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
          },
        );
      },
    );
  }

  void _showBookSelectionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return Consumer<AppProvider>(
          builder: (ctx, app, _) {
            final uiFs = app.fontSize;
            final titleFs = (uiFs * 1.0).clamp(15.0, 28.0);
            final sectionFs = (uiFs * 1.0).clamp(14.0, 26.0);
            final bookAbbrFs = (uiFs * 0.75).clamp(11.0, 22.0);
            final gapSm = (uiFs * 0.5).clamp(6.0, 14.0);
            final gapMd = (uiFs * 0.75).clamp(8.0, 18.0);
            final wrapH = (uiFs * 0.5).clamp(6.0, 12.0);
            final wrapV = (uiFs * 0.25).clamp(3.0, 10.0);
            final padH = (uiFs * 0.5).clamp(6.0, 16.0);
            final padV = (uiFs * 0.25).clamp(3.0, 10.0);
            final oldTestamentBooks = app.getBooks('old');
            final newTestamentBooks = app.getBooks('new');
            final mq = MediaQuery.of(dialogContext);
            final h = mq.size.height;
            final w = mq.size.width;
            final maxH =
                (h - mq.viewPadding.vertical - 12).clamp(360.0, 2000.0);
            final dialogMaxW = (w - 16).clamp(280.0, 560.0);
            const padDialogH = 18.0;
            const padTop = 18.0;
            const padBottom = 16.0;
            final contentW = dialogMaxW - padDialogH * 2;
            final headingFg = _bibleScreenPanelHeadingFg(dialogContext);
            final isLight = !_bibleScreenIsDark(dialogContext);
            void onBookChosen(String book) {
              Navigator.pop(dialogContext);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  _showChapterSelectionDialog(context, forBook: book);
                }
              });
            }
            final titleStyle = TextStyle(
              fontSize: titleFs,
              fontWeight: FontWeight.w600,
              color: headingFg,
              height: 1.2,
            );
            final sectionStyle = TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: sectionFs,
              color: headingFg,
              height: 1.2,
            );
            final titlePainter = TextPainter(
              text: TextSpan(text: 'Выберите книгу', style: titleStyle),
              textDirection: TextDirection.ltr,
              maxLines: 2,
            )..layout(maxWidth: contentW);
            final oldSectionPainter = TextPainter(
              text: TextSpan(text: 'Ветхий Завет:', style: sectionStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout(maxWidth: contentW);
            final newSectionPainter = TextPainter(
              text: TextSpan(text: 'Новый Завет:', style: sectionStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
            )..layout(maxWidth: contentW);
            final oldGridH = _bibleBookSelectionGridHeight(
              books: oldTestamentBooks,
              maxWidth: contentW,
              horizontalGap: wrapH,
              verticalGap: wrapV,
              padH: padH,
              padV: padV,
              bookAbbrFs: bookAbbrFs,
            );
            final newGridH = _bibleBookSelectionGridHeight(
              books: newTestamentBooks,
              maxWidth: contentW,
              horizontalGap: wrapH,
              verticalGap: wrapV,
              padH: padH,
              padV: padV,
              bookAbbrFs: bookAbbrFs,
            );
            final scrollContentH = titlePainter.height +
                gapSm +
                oldSectionPainter.height +
                gapSm +
                oldGridH +
                gapMd +
                newSectionPainter.height +
                gapSm +
                newGridH;
            final headerH = padTop + titlePainter.height + gapSm;
            final bodyMaxH =
                (maxH - headerH - padBottom).clamp(80.0, maxH);
            final needsScroll = scrollContentH > bodyMaxH;
            final bodyH = needsScroll ? bodyMaxH : scrollContentH;
            final bookList = Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Ветхий Завет:', style: sectionStyle),
                SizedBox(height: gapSm),
                _BibleBookSelectionChipGrid(
                  books: oldTestamentBooks,
                  currentBook: app.currentBook,
                  isDark: !isLight,
                  horizontalGap: wrapH,
                  verticalGap: wrapV,
                  padH: padH,
                  padV: padV,
                  bookAbbrFs: bookAbbrFs,
                  onBookTap: onBookChosen,
                ),
                SizedBox(height: gapMd),
                Text('Новый Завет:', style: sectionStyle),
                SizedBox(height: gapSm),
                _BibleBookSelectionChipGrid(
                  books: newTestamentBooks,
                  currentBook: app.currentBook,
                  isDark: !isLight,
                  horizontalGap: wrapH,
                  verticalGap: wrapV,
                  padH: padH,
                  padV: padV,
                  bookAbbrFs: bookAbbrFs,
                  onBookTap: onBookChosen,
                ),
              ],
            );

            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: EdgeInsets.symmetric(
                horizontal: (uiFs * 0.5).clamp(6.0, 14.0),
                vertical: (uiFs * 0.375).clamp(4.0, 12.0),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: DecoratedBox(
                  decoration: _bibleScreenIsDark(dialogContext)
                      ? const BoxDecoration(
                          color: Color(0xFF37474F),
                          borderRadius: BorderRadius.all(Radius.circular(22)),
                        )
                      : BibleLightPalette.lightPanelShellDecoration(radius: 22),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: dialogMaxW,
                      maxHeight: maxH,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        padDialogH,
                        padTop,
                        padDialogH,
                        padBottom,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text('Выберите книгу', style: titleStyle),
                          SizedBox(height: gapSm),
                          SizedBox(
                            height: bodyH,
                            child: needsScroll
                                ? SingleChildScrollView(child: bookList)
                                : bookList,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _BibleRailScrollHandle extends StatefulWidget {
  const _BibleRailScrollHandle({
    required this.controller,
    required this.thumbColor,
    required this.trackHintColor,
    required this.thumbSize,
    this.onScrollAdjusted,
  });

  final ScrollController controller;
  final Color thumbColor;
  final Color trackHintColor;
  final double thumbSize;
  final VoidCallback? onScrollAdjusted;

  @override
  State<_BibleRailScrollHandle> createState() => _BibleRailScrollHandleState();
}

class _BibleRailScrollHandleState extends State<_BibleRailScrollHandle> {
  Widget _scrollGripLine(double width) {
    return Container(
      width: width,
      height: 2.5,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(1.25),
      ),
    );
  }

  Widget _scrollGripLines(double ts) {
    final gap = (ts * 0.11).clamp(3.0, 6.0);
    final lineW = (ts * 0.55).clamp(14.0, 28.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _scrollGripLine(lineW),
        SizedBox(height: gap),
        _scrollGripLine(lineW),
        SizedBox(height: gap),
        _scrollGripLine(lineW),
      ],
    );
  }

  void _jumpToLocalY(double localY, double trackH, double ts, double travel) {
    final c = widget.controller;
    if (!_scrollPositionHasMetrics(c) || travel <= 0) return;
    final maxExt = c.position.maxScrollExtent;
    if (maxExt <= 0) {
      c.jumpTo(0);
      return;
    }
    final targetTop = (localY - ts / 2).clamp(0.0, travel);
    final pixels = (targetTop / travel) * maxExt;
    c.jumpTo(pixels.clamp(0.0, maxExt));
    widget.onScrollAdjusted?.call();
  }

  @override
  Widget build(BuildContext context) {
    final ts = widget.thumbSize;
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        final travel = (h - ts).clamp(0.0, double.infinity);
        final c = widget.controller;
        double thumbTop = 0;
        if (_scrollPositionHasMetrics(c) && travel > 0) {
          final pos = c.position;
          final maxExt = pos.maxScrollExtent;
          if (maxExt > 0) {
            thumbTop = (pos.pixels / maxExt) * travel;
            thumbTop = thumbTop.clamp(0.0, travel);
          }
        }
        return SizedBox(
          width: ts,
          height: h,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTapDown: (d) =>
                      _jumpToLocalY(d.localPosition.dy, h, ts, travel),
                ),
              ),
              Center(
                child: IgnorePointer(
                  child: Container(
                    width: 4,
                    height: (h - 8).clamp(0.0, double.infinity),
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: widget.trackHintColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                top: thumbTop,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragUpdate: (details) {
                    if (!_scrollPositionHasMetrics(c) || travel <= 0) return;
                    final pos = c.position;
                    final maxExt = pos.maxScrollExtent;
                    if (maxExt <= 0) return;
                    final delta = details.delta.dy;
                    final next = pos.pixels + delta * maxExt / travel;
                    c.jumpTo(next.clamp(0.0, maxExt));
                    widget.onScrollAdjusted?.call();
                  },
                  onVerticalDragEnd: (_) => widget.onScrollAdjusted?.call(),
                  child: Material(
                    color: widget.thumbColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: Theme.of(context).brightness == Brightness.dark
                          ? ChromeOutline.side
                          : BibleLightPalette.chromePillOutlineSide,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: ts,
                      height: ts,
                      child: Center(child: _scrollGripLines(ts)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _BibleSearchQueryPanelShell extends StatelessWidget {
  const _BibleSearchQueryPanelShell({
    required this.uiFs,
    required this.panelRowHeight,
    required this.child,
  });

  final double uiFs;
  final double panelRowHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = _bibleScreenIsDark(context);
    final panelRadius = _bibleSearchControlPanelRadius(panelRowHeight);
    final segTrack = _bibleSearchControlPanelTrackColor(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: segTrack,
        borderRadius: BorderRadius.circular(panelRadius),
        border: Border.all(
          color: isDark
              ? ChromeOutline.color
              : BibleLightPalette.chromePillOutlineColor,
          width: ChromeOutline.width,
        ),
      ),
      child: SizedBox(
        height: panelRowHeight,
        child: Align(
          alignment: Alignment.center,
          child: child,
        ),
      ),
    );
  }
}

class _BibleSearchDialog extends StatefulWidget {
  const _BibleSearchDialog({
    required this.appProvider,
    required this.initialQuery,
    required this.initialResults,
    required this.initialScrollOffset,
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
  final double initialScrollOffset;
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
    double resultsScrollOffset,
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
  final ScrollController _resultsScrollController = ScrollController();
  late double _trackedResultsScrollOffset;
  Timer? _searchDebounce;

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
    _trackedResultsScrollOffset =
        widget.initialScrollOffset < 0 ? 0.0 : widget.initialScrollOffset;
    _resultsScrollController.addListener(_onResultsScroll);
    if (_trackedResultsScrollOffset > 0 && _results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyRestoredScrollOffset();
      });
    }
  }

  void _applyRestoredScrollOffset() {
    final c = _resultsScrollController;
    if (!c.hasClients) return;
    final max = c.position.maxScrollExtent;
    final target = _trackedResultsScrollOffset.clamp(0.0, max);
    c.jumpTo(target);
    _trackedResultsScrollOffset = target;
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    widget.onClosing(
      _queryCtrl.text,
      _results.map((e) => Map<String, dynamic>.from(e)).toList(),
      _vz,
      _nz,
      _wholeWords,
      _trackedResultsScrollOffset,
    );
    _queryCtrl.dispose();
    _focusNode.dispose();
    _resultsScrollController
      ..removeListener(_onResultsScroll)
      ..dispose();
    super.dispose();
  }

  void _onResultsScroll() {
    final c = _resultsScrollController;
    if (c.hasClients) {
      _trackedResultsScrollOffset = c.offset;
    }
    if (mounted) setState(() {});
  }

  void _maybeRefreshSearch() {
    if (!mounted) return;
    if (_queryCtrl.text.trim().isEmpty) return;
    _runSearch(unfocus: false);
  }

  void _scheduleDebouncedSearch() {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      _runSearch(unfocus: false);
    });
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
    _maybeRefreshSearch();
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
    _maybeRefreshSearch();
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

  void _runSearch({bool unfocus = true}) {
    if (unfocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _hasRunSearch = false;
        _selectedResultIndices.clear();
      });
      _trackedResultsScrollOffset = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final c = _resultsScrollController;
        if (c.hasClients) {
          c.jumpTo(0);
        }
      });
      return;
    }
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
    _trackedResultsScrollOffset = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final c = _resultsScrollController;
      if (c.hasClients) {
        c.jumpTo(0);
      }
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
      final text = _bibleVisibleText(
        widget.appProvider,
        (r['text'] as String?) ?? '',
      );
      parts.add('($book $ch:$v)\n"$text"');
    }
    if (parts.isEmpty) return;
    await _replaceClipboardText(parts.join('\n'));
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

  /// Диапазон [start, end) в полном тексте стиха для превью в списке поиска.
  ({int start, int end}) _searchPreviewRange(String fullText) {
    const padBefore = 52;
    const padAfter = 88;
    const maxWindow = 560;
    const fallbackLen = 150;

    if (fullText.isEmpty) return (start: 0, end: 0);

    final segments = _querySegments();
    if (segments.isEmpty) {
      final end = fullText.length < fallbackLen ? fullText.length : fallbackLen;
      return (start: 0, end: end);
    }

    final merged = bibleMergedQueryMatches(
      fullText,
      segments,
      wholeWordsOnly: _wholeWords,
    );
    if (merged.isEmpty) {
      final end = fullText.length < fallbackLen ? fullText.length : fallbackLen;
      return (start: 0, end: end);
    }

    var start = merged.first.start - padBefore;
    var end = merged.last.end + padAfter;
    for (final m in merged) {
      final a = m.start - padBefore;
      final b = m.end + padAfter;
      if (a < start) start = a;
      if (b > end) end = b;
    }
    if (start < 0) start = 0;
    if (end > fullText.length) end = fullText.length;
    if (end <= start) {
      final endSafe =
          fullText.length < fallbackLen ? fullText.length : fallbackLen;
      return (start: 0, end: endSafe);
    }

    if (end - start > maxWindow) {
      final m = merged.first;
      start = m.start - padBefore;
      end = m.end + padAfter;
      if (start < 0) start = 0;
      if (end > fullText.length) end = fullText.length;
      if (end - start > maxWindow) {
        end = start + maxWindow;
        if (end > fullText.length) {
          end = fullText.length;
          start = end > maxWindow ? end - maxWindow : 0;
          if (start < 0) start = 0;
        }
      }
    }
    return (start: start, end: end);
  }

  List<({int start, int end})> _mergeMatchIntervals(
    List<({int start, int end})> raw,
  ) {
    if (raw.isEmpty) return raw;
    final sorted = [...raw]..sort((a, b) => a.start.compareTo(b.start));
    final out = <({int start, int end})>[];
    var cur = sorted.first;
    for (var i = 1; i < sorted.length; i++) {
      final n = sorted[i];
      if (n.start > cur.end) {
        out.add(cur);
        cur = n;
      } else {
        final ne = n.end > cur.end ? n.end : cur.end;
        cur = (start: cur.start, end: ne);
      }
    }
    out.add(cur);
    return out;
  }

  /// Полный текст стиха в выдаче поиска с подсветкой совпадений (без усечения).
  List<InlineSpan> _buildSearchPreviewSpans(
    BuildContext context,
    String fullText,
    TextStyle baseStyle,
  ) {
    if (fullText.isEmpty) {
      return [TextSpan(text: '', style: baseStyle)];
    }

    final segments = _querySegments();
    final hiBg = _bibleScreenSearchMatchHighlight(context);
    final hiStyle = baseStyle.copyWith(
      backgroundColor: hiBg,
      fontWeight: FontWeight.w700,
    );

    final mergedFull = segments.isEmpty
        ? <({int start, int end})>[]
        : bibleMergedQueryMatches(
            fullText,
            segments,
            wholeWordsOnly: _wholeWords,
          );

    final mergedRel = _mergeMatchIntervals(mergedFull);

    final spans = <InlineSpan>[];
    var cursor = 0;
    for (final m in mergedRel) {
      if (m.start > cursor) {
        spans.add(
          TextSpan(text: fullText.substring(cursor, m.start), style: baseStyle),
        );
      }
      spans.add(
        TextSpan(text: fullText.substring(m.start, m.end), style: hiStyle),
      );
      cursor = m.end;
    }
    if (cursor < fullText.length) {
      spans.add(TextSpan(text: fullText.substring(cursor), style: baseStyle));
    }
    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final padBg = _bibleScreenButtonBg(context);
    final fg = _bibleScreenChromeFg(context);
    final headingFg = _bibleScreenPanelHeadingFg(context);
    final verseBg = _bibleScreenVerseAreaBg(context);
    final verseMuted = _bibleScreenVerseMutedFg(context);
    final rowHi = _bibleScreenRowHighlight(context);
    final hintColor = _bibleScreenIsDark(context)
        ? Colors.grey.shade500
        : BibleLightPalette.disabledText;
    final divColor = _bibleScreenIsDark(context)
        ? Colors.white.withValues(alpha: 0.12)
        : BibleLightPalette.cardDivider;
    final iconToolFg =
        _bibleScreenIsDark(context) ? fg : BibleLightPalette.iconActive;
    final searchChromeOutline =
        _bibleScreenIsDark(context) ? null : BibleLightPalette.chromePillOutlineSide;
    final mqW = MediaQuery.sizeOf(context).width;
    final contentW = (mqW - 24).clamp(280.0, double.infinity);
    final app = widget.appProvider;
    final uiFs = app.fontSize.clamp(12.0, 28.0);
    final panelScale = (contentW / 420).clamp(0.76, 1.0);
    final panelRowHeight = (uiFs * 1.75 * panelScale).clamp(36.0, 48.0);
    final searchPanelLabelFs = (uiFs * 0.92 * panelScale).clamp(11.0, 22.0);
    final queryStyle = app.bibleVerseTextStyle(
      color: fg,
      fontWeight: FontWeight.normal,
    ).copyWith(
      fontSize: searchPanelLabelFs,
      height: 1.15,
    );
    final hintStyle = queryStyle.copyWith(
      color: hintColor,
      fontWeight: FontWeight.w400,
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final textScale = panelScale;
              final isDark = _bibleScreenIsDark(context);
              final segTrack = _bibleSearchControlPanelTrackColor(context);
              final panelRadius = _bibleSearchControlPanelRadius(panelRowHeight);
              final segActive = isDark
                  ? const Color(0xFF81D4FA)
                  : BibleLightPalette.primary;
              final segActiveFg = isDark ? Colors.black87 : Colors.white;
              final segInactiveFg =
                  isDark ? Colors.white70 : BibleLightPalette.secondaryText;
              final rowLabelStyle = TextStyle(
                fontSize: searchPanelLabelFs,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.15,
              );
              final wholeWordLabelStyle = rowLabelStyle.copyWith(
                color: isDark ? fg : BibleLightPalette.primaryDark,
              );
              final segmentInset =
                  (panelRowHeight * 0.085).clamp(3.0, 4.5);
              final wholeWordLabelPadL =
                  (panelRowHeight * 0.24).clamp(8.0, 14.0) +
                  _bibleSearchTextCharWidth('Ц', wholeWordLabelStyle);
              final innerSegmentRadius =
                  (panelRowHeight - 2 * segmentInset) / 2;
              final switchScale =
                  (panelRowHeight / 48.0).clamp(0.72, 1.0);
              final panelGap = (uiFs * 0.5 * textScale).clamp(6.0, 12.0);
              final switchOutline = isDark
                  ? Colors.grey.shade600
                  : BibleLightPalette.chromePillOutlineColor;
              final panelBorder = Border.all(
                color: isDark
                    ? ChromeOutline.color
                    : BibleLightPalette.chromePillOutlineColor,
                width: ChromeOutline.width,
              );
              final panelDecoration = BoxDecoration(
                color: segTrack,
                borderRadius: BorderRadius.circular(panelRadius),
                border: panelBorder,
              );

              Widget searchControlPanel({required Widget child}) {
                return DecoratedBox(
                  decoration: panelDecoration,
                  child: SizedBox(
                    height: panelRowHeight,
                    child: Align(
                      alignment: Alignment.center,
                      child: child,
                    ),
                  ),
                );
              }

              Widget testamentSegment({
                required String label,
                required bool selected,
                required VoidCallback onTap,
              }) {
                final highlightShape =
                    BorderRadius.circular(innerSegmentRadius);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: highlightShape,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      curve: Curves.easeOutCubic,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: selected ? segActive : Colors.transparent,
                        borderRadius: highlightShape,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: rowLabelStyle.copyWith(
                          color: selected ? segActiveFg : segInactiveFg,
                        ),
                      ),
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchControlPanel(
                    child: Padding(
                      padding: EdgeInsets.all(segmentInset),
                      child: Row(
                        children: [
                          Expanded(
                            child: testamentSegment(
                              label: 'Ветхий завет',
                              selected: _vz,
                              onTap: () => _setVz(!_vz),
                            ),
                          ),
                          SizedBox(width: segmentInset),
                          Expanded(
                            child: testamentSegment(
                              label: 'Новый завет',
                              selected: _nz,
                              onTap: () => _setNz(!_nz),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: panelGap),
                  searchControlPanel(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        wholeWordLabelPadL,
                        segmentInset,
                        segmentInset,
                        segmentInset,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text(
                              'Целое слово',
                              style: wholeWordLabelStyle,
                            ),
                          ),
                          SizedBox(
                            height: panelRowHeight - 2 * segmentInset,
                            child: Align(
                              alignment: Alignment.center,
                              child: Transform.scale(
                                scale: switchScale,
                                alignment: Alignment.center,
                                child: SwitchTheme(
                                  data: SwitchThemeData(
                                    thumbColor:
                                        WidgetStateProperty.resolveWith((s) {
                                      if (s.contains(WidgetState.selected)) {
                                        return Colors.white;
                                      }
                                      return segActive;
                                    }),
                                    trackColor:
                                        WidgetStateProperty.resolveWith((s) {
                                      if (s.contains(WidgetState.selected)) {
                                        return BibleLightPalette.primary;
                                      }
                                      return isDark
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300;
                                    }),
                                    trackOutlineColor:
                                        WidgetStateProperty.resolveWith((s) {
                                      if (s.contains(WidgetState.selected)) {
                                        return Colors.transparent;
                                      }
                                      return switchOutline;
                                    }),
                                    trackOutlineWidth:
                                        const WidgetStatePropertyAll(1.2),
                                  ),
                                  child: Switch.adaptive(
                                    value: _wholeWords,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    onChanged: (v) {
                                      setState(() => _wholeWords = v);
                                      _maybeRefreshSearch();
                                    },
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          SizedBox(height: (uiFs * 0.5).clamp(6.0, 12.0)),
          _BibleSearchQueryPanelShell(
            uiFs: uiFs,
            panelRowHeight: panelRowHeight,
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
                _runSearch(unfocus: false);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                final isDark = _bibleScreenIsDark(context);
                final fieldFill = isDark
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.transparent;
                final fs = queryStyle.fontSize ?? 16.0;
                final strutH = fs * (queryStyle.height ?? 1.35);
                final iconSize = (fs * 0.95).clamp(18.0, 28.0);
                final iconSlotW = (iconSize + 16).clamp(40.0, 52.0);
                final iconSlotH = panelRowHeight;
                final vertPad =
                    ((iconSlotH - strutH) / 2).clamp(0.0, 6.0);
                return ListenableBuilder(
                  listenable: controller,
                  builder: (ctx, _) {
                    final trimmed = controller.text.trim();
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      style: queryStyle,
                      cursorColor: fg,
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: fieldFill,
                        hintText: 'Набери текст',
                        hintStyle: hintStyle,
                        isDense: fs < 22,
                        contentPadding: EdgeInsets.fromLTRB(
                          2,
                          vertPad,
                          2,
                          vertPad,
                        ),
                        prefixIcon: SizedBox(
                          width: iconSlotW,
                          height: iconSlotH,
                          child: Center(
                            child: Icon(
                              Icons.search,
                              color: fg.withValues(alpha: 0.45),
                              size: iconSize,
                            ),
                          ),
                        ),
                        prefixIconConstraints: BoxConstraints(
                          minWidth: iconSlotW,
                          maxWidth: iconSlotW,
                          minHeight: iconSlotH,
                          maxHeight: iconSlotH,
                        ),
                        suffixIcon: trimmed.isEmpty
                            ? null
                            : SizedBox(
                                width: iconSlotW,
                                height: iconSlotH,
                                child: IconButton(
                                  tooltip: 'Очистить',
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: iconSlotW,
                                    maxWidth: iconSlotW,
                                    minHeight: iconSlotH,
                                    maxHeight: iconSlotH,
                                  ),
                                  style: IconButton.styleFrom(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  icon: Icon(
                                    Icons.highlight_off_outlined,
                                    color: iconToolFg,
                                    size: (fs * 0.95).clamp(20.0, 30.0),
                                  ),
                                  onPressed: () {
                                    controller.clear();
                                    _scheduleDebouncedSearch();
                                  },
                                ),
                              ),
                        suffixIconConstraints: BoxConstraints(
                          minWidth: iconSlotW,
                          maxWidth: iconSlotW,
                          minHeight: iconSlotH,
                          maxHeight: iconSlotH,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                      ),
                      onChanged: (_) => _scheduleDebouncedSearch(),
                      onSubmitted: (_) => _runSearch(),
                    );
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    color: verseBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: _bibleChromeOutlineSide(context),
                    ),
                    clipBehavior: Clip.antiAlias,
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
                                style: widget.appProvider.bibleVerseTextStyle(
                                  color: fg,
                                  fontWeight: FontWeight.normal,
                                ),
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
          const SizedBox(height: 8),
          Expanded(
            child: !_hasRunSearch
                ? const SizedBox.shrink()
                : _results.isEmpty
                    ? const SizedBox.shrink()
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: verseBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _bibleScreenIsDark(context)
                                    ? ChromeOutline.color
                                    : BibleLightPalette.chromePillOutlineColor,
                                width: ChromeOutline.width,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: ScrollConfiguration(
                                    behavior: ScrollConfiguration.of(context)
                                        .copyWith(scrollbars: false),
                                    child: ListView.separated(
                                      controller: _resultsScrollController,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      itemCount: _results.length,
                                      separatorBuilder: (_, __) =>
                                          Divider(height: 1, color: divColor),
                                      itemBuilder: (context, i) {
                                      final r = _results[i];
                                      final book = r['book'] as String;
                                      final ch = r['chapter'] as int;
                                      final v = r['verse'] as int;
                                      final text = _bibleVisibleText(
                                        widget.appProvider,
                                        (r['text'] as String?) ?? '',
                                      );
                                      final multi =
                                          _selectedResultIndices.isNotEmpty;
                                      final picked =
                                          _selectedResultIndices.contains(i);
                                      final previewBase = widget.appProvider
                                          .bibleVerseTextStyle(
                                        color: verseMuted,
                                        fontWeight: FontWeight.normal,
                                      );
                                      return Material(
                                        color: picked
                                            ? rowHi
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
                                                      _selectedResultIndices
                                                          .add(i);
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
                                                  style: widget.appProvider
                                                      .bibleVerseTextStyle(
                                                    color: fg,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text.rich(
                                                  TextSpan(
                                                    children:
                                                        _buildSearchPreviewSpans(
                                                      context,
                                                      text,
                                                      previewBase,
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
                                const SizedBox(width: 4),
                                _BibleRailScrollHandle(
                                  controller: _resultsScrollController,
                                  thumbColor: padBg,
                                  trackHintColor: _bibleScreenIsDark(context)
                                      ? Colors.blueGrey.shade700
                                          .withValues(alpha: 0.9)
                                      : BibleLightPalette.activeBg,
                                  thumbSize: (widget.appProvider.chromeButtonSize *
                                          0.68)
                                      .clamp(26.0, 36.0),
                                  onScrollAdjusted: () {
                                    if (mounted) setState(() {});
                                  },
                                ),
                                const SizedBox(width: 4),
                              ],
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
                                    foregroundColor: iconToolFg,
                                    backgroundColor:
                                        _bibleScreenOverlayButtonBg(context),
                                    outlineSide: searchChromeOutline,
                                    onPressed: () {
                                      unawaited(
                                        _copySelectedSearchResults(context),
                                      );
                                    },
                                  ),
                                  const SizedBox(width: 4),
                                  ChromeIconButton(
                                    icon: Icons.highlight_off_outlined,
                                    tooltip: 'Отмена',
                                    foregroundColor: iconToolFg,
                                    backgroundColor:
                                        _bibleScreenOverlayButtonBg(context),
                                    outlineSide: searchChromeOutline,
                                    onPressed: () => setState(
                                      () => _selectedResultIndices.clear(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
          ),
          if (_hasRunSearch)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Найдено совпадений: ${_results.length}',
                style: TextStyle(
                  color: headingFg,
                  fontWeight: FontWeight.w600,
                  fontSize: (widget.appProvider.chromeButtonSize * 0.36)
                      .clamp(12.0, 22.0),
                ),
                textAlign: TextAlign.center,
              ),
            ),
        ],
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
      parts.add('${_headerLine(i + 1, e.createdAt)}\n${e.plainText}');
    }
    await _replaceClipboardText(parts.join('\n\n'));
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
    final app = context.watch<AppProvider>();
    final hasSelection = _selectedEntryIndices.isNotEmpty;
    final panelBg = _bibleScreenAppBarBg(context);
    final fg = _bibleScreenChromeFg(context);
    final headingFg = _bibleScreenPanelHeadingFg(context);
    final listBg = _bibleScreenIsDark(context)
        ? _bibleScreenVerseAreaBg(context)
        : BibleLightPalette.settingsGlassCard;
    /// Бледно‑фиолетовая подложка под текст «Пока нет записей…».
    final favEmptyHintBg = _bibleScreenIsDark(context)
        ? _bibleScreenVerseAreaBg(context)
        : BibleLightPalette.activeBg;
    final verseMuted = _bibleScreenVerseMutedFg(context);
    final favIconFg =
        _bibleScreenIsDark(context) ? fg : BibleLightPalette.iconActive;
    final favOutline =
        _bibleScreenIsDark(context) ? null : BibleLightPalette.chromePillOutlineSide;

    final panelBody = Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LayoutBuilder(
                  builder: (context, constraints) {
                    final scale = (constraints.maxWidth / 420).clamp(0.76, 1.0);
                    final textScale = scale;
                    final titleStyle = _favoritesPanelTextStyle(
                      app,
                      color: headingFg,
                      fontWeight: FontWeight.w800,
                      fontSize:
                          (app.fontSize * 1.12 * textScale).clamp(14.0, 30.0),
                    );
                    return Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Избранное',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: titleStyle,
                          ),
                        ),
                        if (hasSelection)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ChromeIconButton(
                                  icon: Icons.select_all,
                                  tooltip: _entries.length > 1 &&
                                          _selectedEntryIndices.length ==
                                              _entries.length &&
                                          _entries.isNotEmpty
                                      ? 'Снять выделение'
                                      : 'Выделить всё',
                                  foregroundColor: favIconFg,
                                  backgroundColor:
                                      _bibleScreenOverlayButtonBg(context),
                                  outlineSide: favOutline,
                                  onPressed: _toggleSelectAll,
                                ),
                                const SizedBox(width: 4),
                                ChromeIconButton(
                                  icon: Icons.copy_all,
                                  tooltip: 'Копировать',
                                  foregroundColor: favIconFg,
                                  backgroundColor:
                                      _bibleScreenOverlayButtonBg(context),
                                  outlineSide: favOutline,
                                  onPressed: () => unawaited(_copySelected()),
                                ),
                                const SizedBox(width: 4),
                                ChromeIconButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Удалить',
                                  foregroundColor: favIconFg,
                                  backgroundColor:
                                      _bibleScreenOverlayButtonBg(context),
                                  outlineSide: favOutline,
                                  onPressed: _deleteSelected,
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
                      color: favEmptyHintBg,
                      borderRadius: BorderRadius.circular(10),
                      border: _bibleScreenIsDark(context)
                          ? null
                          : Border.all(
                              color: BibleLightPalette.settingsGlassBorderActive,
                              width: 1,
                            ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 22,
                    ),
                    child: Text(
                      'Пока нет записей. Выделите стихи на экране Библии и нажмите «В избранное».',
                      textAlign: TextAlign.center,
                      style: _favoritesPanelTextStyle(
                        app,
                        color: fg,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  )
                else
                  Container(
                    decoration: BoxDecoration(
                      color: listBg,
                      borderRadius: BorderRadius.circular(10),
                      border: _bibleScreenIsDark(context)
                          ? null
                          : Border.all(
                              color: BibleLightPalette.settingsGlassBorderActive,
                              width: 1,
                            ),
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
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: _bibleScreenIsDark(context)
                                ? Colors.white.withValues(alpha: 0.12)
                                : BibleLightPalette.cardDivider,
                          ),
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final n = i + 1;
                            final picked = _selectedEntryIndices.contains(i);
                            final multi = _selectedEntryIndices.isNotEmpty;
                            final bodyStyle = _favoritesPanelTextStyle(
                              app,
                              color: verseMuted,
                              fontWeight: FontWeight.normal,
                            );
                            final headerLineStyle = _favoritesPanelTextStyle(
                              app,
                              color: verseMuted,
                              fontWeight: FontWeight.w600,
                              fontSize: (app.fontSize * 0.95).clamp(
                                12.0,
                                26.0,
                              ),
                            );
                            Color rowTint = Colors.transparent;
                            if (picked) {
                              rowTint = _bibleScreenRowHighlight(context);
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
                                        style: headerLineStyle,
                                      ),
                                      const SizedBox(height: 4),
                                      _favoritesEntryBody(
                                        e,
                                        fg: fg,
                                        baseStyle: bodyStyle,
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
                      style: _favoritesPanelTextStyle(
                        app,
                        color: fg,
                        fontWeight: FontWeight.w600,
                        fontSize: (app.fontSize * 0.9).clamp(12.0, 22.0),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: _bibleScreenIsDark(context)
            ? Container(
                decoration: BoxDecoration(
                  color: panelBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: panelBody,
              )
            : chromeFrostGlassPanelShell(
                borderRadius: 14,
                child: panelBody,
              ),
      ),
    );
  }
}
