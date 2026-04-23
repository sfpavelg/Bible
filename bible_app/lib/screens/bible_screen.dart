import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/models/bible_model.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:bible_app/widgets/main_chrome_tab_bar.dart';
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

  final bottomGap = mainChromeTabBarTotalHeight(context);

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

// --- Цвета панелей «Поиск» и «Избранное» = шапка и тело основного экрана Библии ---

bool _bibleScreenIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

bool _scrollPositionHasMetrics(ScrollController c) =>
    c.hasClients && c.position.hasContentDimensions;

Color _bibleScreenAppBarBg(BuildContext context) => _bibleScreenIsDark(context)
    ? const Color(0xFF37474F)
    : const Color(0xFFB3E5FC);

Color _bibleScreenButtonBg(BuildContext context) => _bibleScreenIsDark(context)
    ? const Color(0xFF455A64)
    : const Color(0xFFE1F5FE);

Color _bibleScreenChromeFg(BuildContext context) =>
    _bibleScreenIsDark(context) ? Colors.white : Colors.black;

Color _bibleScreenVerseAreaBg(BuildContext context) =>
    _bibleScreenIsDark(context) ? Colors.grey.shade900 : Colors.white;

Color _bibleScreenVerseMutedFg(BuildContext context) =>
    _bibleScreenIsDark(context) ? Colors.grey.shade300 : Colors.grey.shade800;

Color _bibleScreenRowHighlight(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? Colors.blueGrey.shade700
        : Colors.amber.shade100;

Color _bibleScreenSearchMatchHighlight(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? Colors.amber.shade700.withValues(alpha: 0.45)
        : Colors.amber.shade300;

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
  static const Color _appBarBgLight = Color(0xFFB3E5FC);
  static const Color _buttonBgLight = Color(0xFFE1F5FE);

  /// Согласован с нижней навигацией в тёмной теме.
  static const Color _appBarBgDark = Color(0xFF37474F);
  static const Color _buttonBgDark = Color(0xFF455A64);

  final ScrollController _scrollController = ScrollController();

  Widget _bibleChromeCloseButton(BuildContext context, VoidCallback onPressed) {
    final app = context.watch<AppProvider>();
    final chrome = app.chromeButtonSize;
    final bg = _bibleScreenButtonBg(context);
    final fg = _bibleScreenChromeFg(context);
    final iconSize = (chrome * 0.5).clamp(18.0, 30.0);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: ChromeOutline.side,
    );
    return Material(
      color: bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: SizedBox(
          width: chrome,
          height: chrome,
          child: Icon(Icons.close, color: fg, size: iconSize),
        ),
      ),
    );
  }

  Future<void> _showVerseNoteDialog(String noteText) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        titlePadding: const EdgeInsets.fromLTRB(20, 14, 12, 10),
        contentPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                'Примечание',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      color: _bibleScreenChromeFg(ctx),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            _bibleChromeCloseButton(ctx, () => Navigator.pop(ctx)),
          ],
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
                  side: ChromeOutline.side,
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
    final chromeTextColor = isDark ? Colors.white : Colors.black;
    final verseBg = isDark ? Colors.grey.shade900 : Colors.white;
    final verseTextColor = isDark ? Colors.white : Colors.black;

    final toolbarH =
        AppProvider.toolbarHeightForChrome(appProvider.chromeButtonSize);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: appBarBg,
        surfaceTintColor: appBarBg,
        foregroundColor: chromeTextColor,
        iconTheme: IconThemeData(color: chromeTextColor),
        actionsIconTheme: IconThemeData(color: chromeTextColor),
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
                foregroundColor: can
                    ? chromeTextColor
                    : chromeTextColor.withValues(alpha: 0.35),
                backgroundColor: buttonBg,
                circular: false,
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
                foregroundColor: can
                    ? chromeTextColor
                    : chromeTextColor.withValues(alpha: 0.35),
                backgroundColor: buttonBg,
                circular: false,
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
                  foregroundColor: chromeTextColor,
                  backgroundColor: buttonBg,
                  onPressed: () => _showBookSelectionDialog(context),
                );

            Widget chapterBtn(double w) => ChromeNavTextButton(
                  width: w,
                  height: s,
                  label: '${appProvider.currentChapter}',
                  foregroundColor: chromeTextColor,
                  backgroundColor: buttonBg,
                  onPressed: () => _showChapterSelectionDialog(context),
                );

            Widget favBtn(double w) => ChromeIconButton(
                  icon: Icons.bookmarks_outlined,
                  width: w,
                  tooltip: 'Избранное',
                  foregroundColor: chromeTextColor,
                  backgroundColor: buttonBg,
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
                  foregroundColor: chromeTextColor,
                  backgroundColor: buttonBg,
                  onPressed: () => _showSearchDialog(context),
                );

            Widget menuBtn(double w) => AppChromeOverflowMenu(
                  iconColor: chromeTextColor,
                  backgroundColor: buttonBg,
                  tileWidth: w,
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
            child: IgnorePointer(
              ignoring: !_isBibleInteractionActive,
              child: GestureDetector(
                onHorizontalDragEnd: (details) async {
                  if (!_isBibleInteractionActive) return;
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
                                  final payload =
                                      _bibleVerseDisplayPayloadFromRaw(
                                    (verse['text'] ?? '').toString(),
                                  );
                                  final verseTextWithMarkers =
                                      '$num. ${payload.textWithMarkers}';
                                  Color textColor = verseTextColor;
                                  final highlighted = _highlightVerse == num;
                                  final selected =
                                      _selectedVerses.contains(num);
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
                                  final multiSelect =
                                      _selectedVerses.isNotEmpty;
                                  final gap = index < verses.length - 1
                                      ? appProvider.verseSpacing
                                      : 0.0;
                                  return KeyedSubtree(
                                    key: _verseRowKeys.putIfAbsent(
                                      num,
                                      GlobalKey.new,
                                    ),
                                    child: Padding(
                                      padding: EdgeInsets.only(bottom: gap),
                                      child: Material(
                                        color: rowBg,
                                        child: InkWell(
                                          onTap: multiSelect
                                              ? () {
                                                  setState(() {
                                                    if (_selectedVerses
                                                        .contains(num)) {
                                                      _selectedVerses
                                                          .remove(num);
                                                    } else {
                                                      _selectedVerses.add(num);
                                                    }
                                                  });
                                                }
                                              : null,
                                          onLongPress: () {
                                            setState(() {
                                              if (_selectedVerses
                                                  .contains(num)) {
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
                                                  children:
                                                      _buildVerseInlineSpans(
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
                    side: ChromeOutline.side,
                  ),
                  clipBehavior: Clip.antiAlias,
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
            // Высота диалога — по экрану устройства (без искусственного потолка).
            final maxDialogH =
                (h - mq.viewPadding.vertical - 12).clamp(120.0, h);
            final titleAndChrome = (uiFs * 5.5).clamp(72.0, 120.0);
            final contentMaxH =
                (maxDialogH - titleAndChrome).clamp(60.0, maxDialogH);
            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: (uiFs * 0.5).clamp(6.0, 14.0),
                vertical: (uiFs * 0.375).clamp(4.0, 12.0),
              ),
              constraints: BoxConstraints(
                maxWidth: (w - 16).clamp(280.0, 440.0),
                maxHeight: maxDialogH,
              ),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Выберите главу (${BibleBook.liturgicalDisplayName(selectedBook)})',
                      style: TextStyle(
                        fontSize: titleFs,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _BibleDialogCloseButton(
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: (w - 48).clamp(260.0, 400.0),
                  maxHeight: contentMaxH,
                ),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: wrapGap,
                    runSpacing: wrapGap,
                    alignment: WrapAlignment.center,
                    children: List.generate(chapterCount, (index) {
                      final chapterNumber = index + 1;
                      final isCurrent = selectedBook == app.currentBook &&
                          chapterNumber == app.currentChapter;
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
                            backgroundColor:
                                isCurrent ? Colors.blue : Colors.lightBlue[50],
                            foregroundColor:
                                isCurrent ? Colors.white : Colors.black,
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
                    }),
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
            // Почти вся высота экрана: иначе 66 кнопок в Wrap не помещаются и включается скролл.
            final maxH =
                (h - mq.viewPadding.vertical - 12).clamp(360.0, 2000.0);
            return AlertDialog(
              insetPadding: EdgeInsets.symmetric(
                horizontal: (uiFs * 0.5).clamp(6.0, 14.0),
                vertical: (uiFs * 0.375).clamp(4.0, 12.0),
              ),
              constraints: BoxConstraints(
                maxWidth: (w - 16).clamp(280.0, 560.0),
                maxHeight: maxH,
              ),
              title: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      'Выберите книгу',
                      style: TextStyle(
                        fontSize: titleFs,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _BibleDialogCloseButton(
                    onPressed: () => Navigator.pop(dialogContext),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Ветхий Завет:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: sectionFs,
                      ),
                    ),
                    SizedBox(height: gapSm),
                    Wrap(
                      spacing: wrapH,
                      runSpacing: wrapV,
                      children: oldTestamentBooks.map((book) {
                        final isCurrentBook = book == app.currentBook;
                        return TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                _showChapterSelectionDialog(context,
                                    forBook: book);
                              }
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: isCurrentBook
                                ? Colors.blue
                                : Colors.lightBlue[50],
                            padding: EdgeInsets.symmetric(
                              horizontal: padH,
                              vertical: padV,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            BibleService().getBookAbbreviation(book),
                            style: TextStyle(
                              color:
                                  isCurrentBook ? Colors.white : Colors.black,
                              fontSize: bookAbbrFs,
                              fontWeight: isCurrentBook
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    SizedBox(height: gapMd),
                    Text(
                      'Новый Завет:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: sectionFs,
                      ),
                    ),
                    SizedBox(height: gapSm),
                    Wrap(
                      spacing: wrapH,
                      runSpacing: wrapV,
                      children: newTestamentBooks.map((book) {
                        final isCurrentBook = book == app.currentBook;
                        return TextButton(
                          onPressed: () {
                            Navigator.pop(dialogContext);
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (context.mounted) {
                                _showChapterSelectionDialog(context,
                                    forBook: book);
                              }
                            });
                          },
                          style: TextButton.styleFrom(
                            backgroundColor: isCurrentBook
                                ? Colors.blue
                                : Colors.lightBlue[50],
                            padding: EdgeInsets.symmetric(
                              horizontal: padH,
                              vertical: padV,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: Text(
                            BibleService().getBookAbbreviation(book),
                            style: TextStyle(
                              color:
                                  isCurrentBook ? Colors.white : Colors.black,
                              fontSize: bookAbbrFs,
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
      },
    );
  }
}

/// Кнопка закрытия диалога выбора книги/главы (как в панели поиска).
class _BibleDialogCloseButton extends StatelessWidget {
  const _BibleDialogCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  static const _bg = Color(0xFFE1F5FE);
  static const _fg = Colors.black;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final chrome = app.chromeButtonSize;
    final fs = app.fontSize;
    // Растёт и с «размером кнопок», и с шрифтом — как остальной диалог.
    final dim = ((chrome + fs * 2.0) / 2).clamp(40.0, 58.0);
    final ic = (dim * 0.5).clamp(18.0, 30.0);
    final corner = (dim * 0.2).clamp(6.0, 12.0);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(corner),
      side: ChromeOutline.side,
    );
    return Material(
      color: _bg,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        customBorder: shape,
        child: SizedBox(
          width: dim,
          height: dim,
          child: Icon(Icons.close, color: _fg, size: ic),
        ),
      ),
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
                      side: ChromeOutline.side,
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
  final ScrollController _resultsScrollController = ScrollController();

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
    _resultsScrollController.addListener(_onResultsScroll);
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
    _resultsScrollController
      ..removeListener(_onResultsScroll)
      ..dispose();
    super.dispose();
  }

  void _onResultsScroll() {
    if (mounted) setState(() {});
  }

  void _jumpResultsToStart() {
    HapticFeedback.lightImpact();
    final c = _resultsScrollController;
    if (!c.hasClients) return;
    const target = 0.0;
    final dist = (c.offset - target).abs();
    if (dist < 1) return;
    final ms = (200 + dist * 0.22).clamp(200.0, 1100.0).round();
    c.animateTo(
      target,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeInOutCubic,
    );
  }

  void _jumpResultsToEnd() {
    HapticFeedback.lightImpact();
    final c = _resultsScrollController;
    if (!_scrollPositionHasMetrics(c)) return;
    final m = c.position.maxScrollExtent;
    final dist = (m - c.offset).abs();
    if (dist < 1) return;
    final ms = (200 + dist * 0.22).clamp(200.0, 1100.0).round();
    c.animateTo(
      m,
      duration: Duration(milliseconds: ms),
      curve: Curves.easeInOutCubic,
    );
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
    final verseBg = _bibleScreenVerseAreaBg(context);
    final verseMuted = _bibleScreenVerseMutedFg(context);
    final rowHi = _bibleScreenRowHighlight(context);
    final hintColor = _bibleScreenIsDark(context)
        ? Colors.grey.shade500
        : const Color(0xFFBDBDBD);
    final divColor = _bibleScreenIsDark(context)
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final mqW = MediaQuery.sizeOf(context).width;
    final contentW = (mqW - 24).clamp(280.0, double.infinity);
    final app = widget.appProvider;
    final queryStyle = app.bibleVerseTextStyle(
      color: fg,
      fontWeight: FontWeight.normal,
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
              final scale = (constraints.maxWidth / 420).clamp(0.76, 1.0);
              final textScale = scale;
              final checkboxScale =
                  (0.9 + (scale - 0.76) * 0.25).clamp(0.86, 1.0);
              final chrome = widget.appProvider.chromeButtonSize;
              final closeIc = (chrome * 0.5).clamp(18.0, 30.0);
              final chromeLabel = (chrome * 0.36).clamp(12.0, 22.0);
              final railBtnWFirst = chrome.clamp(32.0, 44.0);
              final railBtnWSecond = chrome.clamp(32.0, 42.0);
              final railBtnGap = (chrome * 0.07).clamp(2.0, 5.0);
              final rowShape = RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: ChromeOutline.side,
              );
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Material(
                        color: padBg,
                        shape: rowShape,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _runSearch,
                          customBorder: rowShape,
                          child: SizedBox(
                            height: chrome,
                            child: Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12 * scale,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search,
                                    color: fg,
                                    size: (chrome * 0.45).clamp(16.0, 24.0),
                                  ),
                                  SizedBox(width: (chrome * 0.16).clamp(4.0, 8.0)),
                                  Text(
                                    'Найти',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: chromeLabel * textScale,
                                      color: fg,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: railBtnGap),
                      ChromeIconButton(
                        icon: Icons.vertical_align_top,
                        tooltip: 'В начало списка',
                        foregroundColor: fg,
                        backgroundColor: padBg,
                        width: railBtnWFirst,
                        onPressed:
                            _results.isEmpty ? null : _jumpResultsToStart,
                      ),
                      SizedBox(width: railBtnGap),
                      ChromeIconButton(
                        icon: Icons.vertical_align_bottom,
                        tooltip: 'В конец списка',
                        foregroundColor: fg,
                        backgroundColor: padBg,
                        width: railBtnWSecond,
                        onPressed: _results.isEmpty ? null : _jumpResultsToEnd,
                      ),
                      const Spacer(),
                      Transform.scale(
                        scale: checkboxScale,
                        child: Checkbox(
                          value: _vz,
                          onChanged: _setVz,
                          visualDensity: VisualDensity.compact,
                          activeColor: padBg,
                          checkColor: fg,
                          side: ChromeOutline.side,
                        ),
                      ),
                      Text(
                        'ВЗ',
                        style: TextStyle(
                          fontSize: chromeLabel * textScale,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      SizedBox(width: 8 * scale),
                      Transform.scale(
                        scale: checkboxScale,
                        child: Checkbox(
                          value: _nz,
                          onChanged: _setNz,
                          visualDensity: VisualDensity.compact,
                          activeColor: padBg,
                          checkColor: fg,
                          side: ChromeOutline.side,
                        ),
                      ),
                      Text(
                        'НЗ',
                        style: TextStyle(
                          fontSize: chromeLabel * textScale,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      const Spacer(),
                      Material(
                        color: padBg,
                        shape: rowShape,
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => Navigator.pop(context),
                          customBorder: rowShape,
                          child: SizedBox(
                            width: chrome,
                            height: chrome,
                            child: Icon(
                              Icons.close,
                              color: fg,
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
                          activeColor: padBg,
                          checkColor: fg,
                          side: ChromeOutline.side,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Целое слово',
                          style: TextStyle(
                            fontSize: chromeLabel * 0.92 * textScale,
                            fontWeight: FontWeight.w600,
                            color: fg,
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
              color: padBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: ChromeOutline.color,
                width: ChromeOutline.width,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
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
                  style: queryStyle,
                  cursorColor: fg,
                  decoration: InputDecoration(
                    hintText: 'Набери текст',
                    hintStyle: hintStyle,
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      vertical: (app.fontSize * 0.45).clamp(8.0, 16.0),
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
                    color: verseBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: ChromeOutline.side,
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
                    ? Center(
                        child: Text(
                          'Совпадений не найдено',
                          style: app.bibleVerseTextStyle(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: verseBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: ChromeOutline.color,
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
                                      : Colors.blue.shade100
                                          .withValues(alpha: 0.65),
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
                                    foregroundColor: fg,
                                    backgroundColor: padBg,
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
                                    foregroundColor: fg,
                                    backgroundColor: padBg,
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
                  color: fg,
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
    final buttonBg = _bibleScreenButtonBg(context);
    final fg = _bibleScreenChromeFg(context);
    final listBg = _bibleScreenVerseAreaBg(context);
    final verseMuted = _bibleScreenVerseMutedFg(context);

    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 740),
        child: Container(
          decoration: BoxDecoration(
            color: panelBg,
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
                    final scale = (constraints.maxWidth / 420).clamp(0.76, 1.0);
                    final textScale = scale;
                    final titleStyle = _favoritesPanelTextStyle(
                      app,
                      color: fg,
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
                                  foregroundColor: fg,
                                  backgroundColor: buttonBg,
                                  onPressed: _toggleSelectAll,
                                ),
                                const SizedBox(width: 4),
                                ChromeIconButton(
                                  icon: Icons.copy_all,
                                  tooltip: 'Копировать',
                                  foregroundColor: fg,
                                  backgroundColor: buttonBg,
                                  onPressed: () => unawaited(_copySelected()),
                                ),
                                const SizedBox(width: 4),
                                ChromeIconButton(
                                  icon: Icons.delete_outline,
                                  tooltip: 'Удалить',
                                  foregroundColor: fg,
                                  backgroundColor: buttonBg,
                                  onPressed: _deleteSelected,
                                ),
                                const SizedBox(width: 4),
                              ],
                              ChromeIconButton(
                                icon: Icons.close,
                                tooltip: 'Закрыть',
                                foregroundColor: fg,
                                backgroundColor: buttonBg,
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
                      color: buttonBg,
                      borderRadius: BorderRadius.circular(10),
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
                                : Colors.black.withValues(alpha: 0.08),
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
                              color: fg,
                              fontWeight: FontWeight.w700,
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
          ),
        ),
      ),
    );
  }
}
