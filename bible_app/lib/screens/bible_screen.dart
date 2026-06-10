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
import 'package:bible_app/theme/app_theme_colors.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/widgets/app_bottom_notice.dart';
import 'package:bible_app/widgets/app_chrome_overflow_menu.dart';
import 'package:bible_app/widgets/bible_reference_picker_dialogs.dart';
import 'package:bible_app/widgets/chrome_frost_glass_panel.dart';
import 'package:bible_app/widgets/chrome_outline.dart';
import 'package:bible_app/widgets/chrome_toolbar_button.dart';
import 'package:bible_app/widgets/main_chrome_tab_bar.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';
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
    ? BibleDarkPalette.screenBg
    : AppThemeColors.lightSurface(context, BibleLightPalette.topBarBg);

Color _bibleScreenButtonBg(BuildContext context) => _bibleScreenIsDark(context)
    ? BibleDarkPalette.cardBg
    : AppThemeColors.lightSurface(context, BibleLightPalette.chromePillFill);

/// Непрозрачный фон плавающих кнопок поверх стихов и списков.
Color _bibleScreenOverlayButtonBg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? BibleDarkPalette.cardBg
        : AppThemeColors.lightSurface(context, BibleLightPalette.chromePillBg);

Color _bibleScreenChromeFg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? AppThemeColors.darkText(context, BibleDarkPalette.primaryText)
        : BibleLightPalette.primaryText;

Color _bibleScreenChromeTitleFg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? AppThemeColors.darkText(context, BibleDarkPalette.titleGold)
        : BibleLightPalette.primaryText;

Color _bibleScreenPanelHeadingFg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? AppThemeColors.darkText(context, BibleDarkPalette.titleGold)
        : BibleLightPalette.primaryDark;

Color _bibleScreenVerseAreaBg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? BibleDarkPalette.cardBg
        : AppThemeColors.lightSurface(
            context,
            BibleLightPalette.cardFillSecondary,
          );

Color _bibleScreenVerseHighlightBg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? BibleDarkPalette.accentGold.withValues(alpha: 0.28)
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
        ? BibleDarkPalette.cardBg
        : AppThemeColors.lightSurface(context, BibleLightPalette.disabledBg);

/// Непрозрачный фон выпадающего списка и области результатов поиска (без cardFillSecondary 70 %).
Color _bibleSearchSolidSurfaceBg(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? BibleDarkPalette.cardBg
        : AppThemeColors.lightSurface(context, BibleLightPalette.topBarBg);

const int _kBibleSearchResultsCap = BibleService.searchResultsCap;

/// Усечённое окно превью стиха в списке поиска — не рисуем весь текст целиком.
({int start, int end}) _bibleSearchPreviewWindowRange(
  String fullText,
  List<String> segments, {
  required bool wholeWordsOnly,
}) {
  const padBefore = 52;
  const padAfter = 88;
  const maxWindow = 280;
  const fallbackLen = 120;

  if (fullText.isEmpty) return (start: 0, end: 0);

  if (segments.isEmpty) {
    final end = fullText.length < fallbackLen ? fullText.length : fallbackLen;
    return (start: 0, end: end);
  }

  final merged = bibleMergedQueryMatches(
    fullText,
    segments,
    wholeWordsOnly: wholeWordsOnly,
  );
  if (merged.isEmpty) {
    final end = fullText.length < fallbackLen ? fullText.length : fallbackLen;
    return (start: 0, end: end);
  }

  var start = merged.first.start - padBefore;
  var end = merged.last.end + padAfter;
  if (start < 0) start = 0;
  if (end > fullText.length) end = fullText.length;
  if (end - start > maxWindow) {
    final m = merged.first;
    start = m.start - padBefore;
    end = m.end + padAfter;
    if (start < 0) start = 0;
    if (end > fullText.length) end = fullText.length;
    if (end - start > maxWindow) {
      end = start + maxWindow;
      if (end > fullText.length) end = fullText.length;
    }
  }
  if (end <= start) {
    final endSafe =
        fullText.length < fallbackLen ? fullText.length : fallbackLen;
    return (start: 0, end: endSafe);
  }
  return (start: start, end: end);
}

List<InlineSpan> _bibleSearchPreviewSpans({
  required String fullText,
  required TextStyle baseStyle,
  required TextStyle hiStyle,
  required List<String> segments,
  required bool wholeWordsOnly,
}) {
  if (fullText.isEmpty) {
    return [TextSpan(text: '', style: baseStyle)];
  }

  final window = _bibleSearchPreviewWindowRange(
    fullText,
    segments,
    wholeWordsOnly: wholeWordsOnly,
  );
  final sliceStart = window.start;
  final sliceEnd = window.end;
  final slice = fullText.substring(sliceStart, sliceEnd);

  final merged = bibleMergedQueryMatches(
    slice,
    segments,
    wholeWordsOnly: wholeWordsOnly,
  );

  final spans = <InlineSpan>[];
  if (sliceStart > 0) {
    spans.add(TextSpan(text: '… ', style: baseStyle));
  }

  var cursor = 0;
  for (final m in merged) {
    if (m.start > cursor) {
      spans.add(
        TextSpan(text: slice.substring(cursor, m.start), style: baseStyle),
      );
    }
    spans.add(
      TextSpan(text: slice.substring(m.start, m.end), style: hiStyle),
    );
    cursor = m.end;
  }
  if (cursor < slice.length) {
    spans.add(TextSpan(text: slice.substring(cursor), style: baseStyle));
  }
  if (sliceEnd < fullText.length) {
    spans.add(TextSpan(text: ' …', style: baseStyle));
  }
  return spans;
}

BorderSide _bibleChromeOutlineSide(BuildContext context) =>
    _bibleScreenIsDark(context)
        ? BibleDarkPalette.chromeButtonOutline
        : BibleLightPalette.chromePillOutlineSide;

/// [Dialog] не учитывает [Scaffold.bottomNavigationBar] — резервируем вручную.
double _bibleModalBottomChromeReserve(BuildContext context) =>
    mainChromeTabBarTotalHeight(context) + 10.0;

double _bibleModalTopChromeReserve(double chromeButtonSize) =>
    AppProvider.toolbarHeightForChrome(chromeButtonSize) + 8.0;

double _bibleModalMaxDialogHeight(
  BuildContext context, {
  required double screenHeight,
  required double verticalViewPadding,
  required double chromeButtonSize,
  double extraMargin = 12.0,
  double minHeight = 200.0,
}) {
  return (screenHeight -
          verticalViewPadding -
          _bibleModalBottomChromeReserve(context) -
          _bibleModalTopChromeReserve(chromeButtonSize) -
          extraMargin)
      .clamp(minHeight, screenHeight);
}

/// Оболочка «Выберите книгу» / «Выберите главу» — как меню «⋯», без прозрачного
/// [lightPanelShellDecoration] (низ градиента verseCard был полностью прозрачным).
Widget _biblePickerDialogShell({
  required BuildContext context,
  required double borderRadius,
  required Widget child,
}) {
  if (_bibleScreenIsDark(context)) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BibleDarkPalette.cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: BibleDarkPalette.cardBorderGold,
          width: 1,
        ),
        boxShadow: BibleDarkPalette.verseCardShadow,
      ),
      child: child,
    );
  }
  return chromeFrostGlassPanelShell(
    borderRadius: borderRadius,
    child: child,
  );
}

double _bibleBookChipMinWidth(
  String book,
  double fontSize,
  double padH,
  TextScaler textScaler,
) {
  final abbr = BibleService().getBookAbbreviation(book);
  final painter = TextPainter(
    text: TextSpan(
      text: abbr,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    textScaler: textScaler,
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
  TextScaler textScaler,
) {
  if (books.isEmpty || maxWidth <= 0) return const [];

  final rows = <List<String>>[];
  var row = <String>[];

  double rowMaxMinWidth() {
    if (row.isEmpty) return 0;
    return row
        .map((b) => _bibleBookChipMinWidth(b, fontSize, padH, textScaler))
        .fold(0.0, math.max);
  }

  double equalCellWidth(int count) {
    if (count <= 0) return maxWidth;
    return (maxWidth - spacing * (count - 1)) / count;
  }

  for (final book in books) {
    final minW = _bibleBookChipMinWidth(book, fontSize, padH, textScaler);
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

double _bibleBookChipRowHeight(
  double fontSize,
  double padV,
  TextScaler textScaler,
) {
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
    textScaler: textScaler,
  )..layout();
  /// Небольшой запас под обводку [TextButton]/Material при крупном шрифте.
  final slop =
      math.max(1.25, math.min(8.5, fontSize * 0.085 * textScaler.scale(1)));
  return painter.height + padV * 2 + 2.4 + slop;
}

double _bibleBookSelectionGridHeight({
  required List<String> books,
  required double maxWidth,
  required double horizontalGap,
  required double verticalGap,
  required double padH,
  required double padV,
  required double bookAbbrFs,
  required TextScaler textScaler,
}) {
  final rows = _packBibleBookRows(
    books,
    maxWidth,
    horizontalGap,
    padH,
    bookAbbrFs,
    textScaler,
  );
  if (rows.isEmpty) return 0;
  final rowH = _bibleBookChipRowHeight(bookAbbrFs, padV, textScaler);
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
        final textScaler = MediaQuery.textScalerOf(context);
        final maxW = constraints.maxWidth;
        final rows = _packBibleBookRows(
          books,
          maxW,
          horizontalGap,
          padH,
          bookAbbrFs,
          textScaler,
        );
        final maxRowLen = rows.isEmpty
            ? 0
            : rows.map((r) => r.length).reduce(math.max);

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
                    // Неполный ряд: ширина по тексту, иначе при крупном шрифте/масштабе
                    // системы «Откр» обрезается до «От…» (ширина ячейки от полных рядов).
                    return Wrap(
                      spacing: horizontalGap,
                      runSpacing: verticalGap,
                      children: [
                        for (final book in row) _chip(context, book),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < row.length; c++) ...[
                        if (c > 0) SizedBox(width: horizontalGap),
                        Expanded(child: _chip(context, row[c])),
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

  Widget _chip(BuildContext context, String book) {
    final isCurrentBook = book == currentBook;
    if (isDark) {
      final borderGold = BorderSide(
        color: isCurrentBook
            ? BibleDarkPalette.accentGold
            : BibleDarkPalette.cardBorderGold,
        width: 1.2,
      );
      return TextButton(
        onPressed: () => onBookTap(book),
        style: TextButton.styleFrom(
          backgroundColor: isCurrentBook
              ? BibleDarkPalette.accentGold.withValues(alpha: 0.38)
              : BibleDarkPalette.cardBg,
          foregroundColor: isCurrentBook
              ? BibleDarkPalette.accentGoldLight
              : AppThemeColors.darkText(
                  context,
                  BibleDarkPalette.primaryText,
                ),
          side: borderGold,
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
                ? BibleDarkPalette.accentGoldLight
                : AppThemeColors.darkText(
                    context,
                    BibleDarkPalette.primaryText,
                  ),
            fontSize: bookAbbrFs,
            fontWeight: isCurrentBook ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }
    return TextButton(
      onPressed: () => onBookTap(book),
      style: TextButton.styleFrom(
        backgroundColor: isCurrentBook
            ? BibleLightPalette.primary
            : BibleLightPalette.activeBg,
        foregroundColor: isCurrentBook
            ? Colors.white
            : BibleLightPalette.primaryText,
        side: BorderSide(
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
          color: isCurrentBook ? Colors.white : BibleLightPalette.primaryText,
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

/// Горизонтальный жест с видимым сдвигом главы; смена только после порога или быстрого свайпа.
class _BibleChapterSwipeSurface extends StatefulWidget {
  const _BibleChapterSwipeSurface({
    required this.enabled,
    required this.canGoPrev,
    required this.canGoNext,
    required this.onGoPrev,
    required this.onGoNext,
    required this.chapterKey,
    required this.child,
  });

  final bool enabled;
  final bool canGoPrev;
  final bool canGoNext;
  final Future<void> Function() onGoPrev;
  final Future<void> Function() onGoNext;
  final String chapterKey;
  final Widget child;

  @override
  State<_BibleChapterSwipeSurface> createState() =>
      _BibleChapterSwipeSurfaceState();
}

class _BibleChapterSwipeSurfaceState extends State<_BibleChapterSwipeSurface>
    with SingleTickerProviderStateMixin {
  static const _snapDuration = Duration(milliseconds: 320);
  static const _commitDuration = Duration(milliseconds: 240);
  static const _velocityThreshold = 420.0;
  static const _distanceFactor = 0.2;

  late final AnimationController _settleController;
  Animation<double>? _settleAnim;
  double _dragOffset = 0;
  bool _transitioning = false;

  @override
  void initState() {
    super.initState();
    _settleController = AnimationController(vsync: this)
      ..addListener(() {
        final anim = _settleAnim;
        if (anim != null && mounted) {
          setState(() => _dragOffset = anim.value);
        }
      });
  }

  @override
  void didUpdateWidget(covariant _BibleChapterSwipeSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chapterKey != widget.chapterKey && !_transitioning) {
      _settleController.stop();
      _settleController.reset();
      _dragOffset = 0;
    }
  }

  @override
  void dispose() {
    _settleController.dispose();
    super.dispose();
  }

  double _maxDrag(double width) => width * 0.42;

  double _rubberBand(double overflow) => overflow * 0.16;

  Future<void> _animateTo(
    double target, {
    required Duration duration,
    Curve curve = Curves.easeOutCubic,
  }) async {
    if (!mounted) return;
    if ((_dragOffset - target).abs() < 0.5) {
      setState(() => _dragOffset = target);
      return;
    }
    _settleController.duration = duration;
    _settleAnim = Tween<double>(begin: _dragOffset, end: target).animate(
      CurvedAnimation(parent: _settleController, curve: curve),
    );
    _settleController.reset();
    await _settleController.forward();
    if (mounted) setState(() => _dragOffset = target);
  }

  Future<void> _snapBack() =>
      _animateTo(0, duration: _snapDuration, curve: Curves.easeOutCubic);

  void _onDragUpdate(DragUpdateDetails details, double width) {
    if (!widget.enabled || _transitioning) return;
    var next = _dragOffset + details.delta.dx;
    if (next > 0 && !widget.canGoPrev) {
      next = _rubberBand(next);
    } else if (next < 0 && !widget.canGoNext) {
      next = -_rubberBand(-next);
    }
    final max = _maxDrag(width);
    setState(() => _dragOffset = next.clamp(-max, max));
  }

  Future<void> _onDragEnd(DragEndDetails details, double width) async {
    if (!widget.enabled || _transitioning) return;
    final velocity = details.primaryVelocity ?? 0;

    final commitPrev = widget.canGoPrev &&
        (_dragOffset > width * _distanceFactor || velocity > _velocityThreshold);
    final commitNext = widget.canGoNext &&
        (_dragOffset < -width * _distanceFactor ||
            velocity < -_velocityThreshold);

    if (commitPrev) {
      await _commitChapter(toPrev: true, width: width);
    } else if (commitNext) {
      await _commitChapter(toPrev: false, width: width);
    } else {
      await _snapBack();
    }
  }

  Future<void> _commitChapter({required bool toPrev, required double width}) async {
    if (_transitioning) return;
    _transitioning = true;
    final exitTarget = toPrev ? width : -width;
    await _animateTo(
      exitTarget,
      duration: _commitDuration,
      curve: Curves.easeInCubic,
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() => _dragOffset = -exitTarget * 0.92);
    if (toPrev) {
      await widget.onGoPrev();
    } else {
      await widget.onGoNext();
    }
    if (!mounted) return;
    await _animateTo(0, duration: _snapDuration, curve: Curves.easeOutCubic);
    _transitioning = false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final dragT = width <= 0 ? 0.0 : (_dragOffset.abs() / width).clamp(0.0, 1.0);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragUpdate: (d) => _onDragUpdate(d, width),
          onHorizontalDragEnd: (d) => unawaited(_onDragEnd(d, width)),
          onHorizontalDragCancel: () => unawaited(_snapBack()),
          child: ClipRect(
            child: Transform.translate(
              offset: Offset(_dragOffset, 0),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 80),
                opacity: 1.0 - dragT * 0.07,
                child: widget.child,
              ),
            ),
          ),
        );
      },
    );
  }
}

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  final ItemScrollController _verseItemScrollController = ItemScrollController();

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
      color: _bibleScreenIsDark(context)
          ? BibleDarkPalette.accentGold
          : Colors.blue,
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

  /// Стих для мгновенного [initialScrollIndex] при открытии главы из поиска/плана.
  int? _pendingScrollVerse;

  /// Отменяет устаревшие вызовы [_scrollToVerse] при быстрых повторных переходах.
  int _scrollToVerseGeneration = 0;

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
      if (!bibleTabIsActive.value) return;
      final r = bibleVerseJumpRequest.value;
      if (r == null) return;
      bibleVerseJumpRequest.value = null;
      unawaited(_consumeBibleVerseJumpFromPlan(r));
    };
    bibleVerseJumpRequest.addListener(_bibleVerseJumpListener!);
  }

  /// План, push: быстрый переход; ждём загрузки Библии (ВЗ и НЗ), иначе НЗ не откроется.
  Future<void> _consumeBibleVerseJumpFromPlan(BibleVerseJumpRequest r) async {
    final app = Provider.of<AppProvider>(context, listen: false);
    await app.waitUntilInitialized();
    if (!mounted) return;
    if (app.currentBook != r.book || app.currentChapter != r.chapter) {
      await app.changeBookAndChapter(r.book, r.chapter, persist: false);
    }
    for (var i = 0; i < 120; i++) {
      if (!mounted) return;
      if (app.currentBook == r.book && app.currentChapter == r.chapter) {
        final verses = app.getCurrentVerses();
        if (verses.any((v) => v['verse'] == r.verse)) {
          await _scrollToVerse(r.verse, quick: true);
          unawaited(app.persistLastPosition());
          return;
        }
      }
      await WidgetsBinding.instance.endOfFrame;
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

  int? _verseListIndex(List<Map<String, dynamic>> verses, int verseNum) {
    for (var i = 0; i < verses.length; i++) {
      final vn = verses[i]['verse'];
      final n = vn is int ? vn : (vn as num).toInt();
      if (n == verseNum) return i;
    }
    return null;
  }

  void _jumpToVerseCentered(int verseNum) {
    final verses =
        Provider.of<AppProvider>(context, listen: false).getCurrentVerses();
    final index = _verseListIndex(verses, verseNum);
    if (index == null || index < 0) return;
    if (!_verseItemScrollController.isAttached) return;
    _verseItemScrollController.jumpTo(index: index, alignment: 0.5);
  }

  void _scheduleVerseFocus(
    int verseNum,
    int generation, {
    bool expectInitialScroll = false,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollToVerseGeneration) return;
      if (!expectInitialScroll) {
        _jumpToVerseCentered(verseNum);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _scrollToVerseGeneration) return;
        _jumpToVerseCentered(verseNum);
        _pendingScrollVerse = null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || generation != _scrollToVerseGeneration) return;
          _highlightVerseTemporarily(verseNum);
        });
      });
    });
  }

  Future<void> _scrollToVerse(int verseNum, {bool quick = false}) async {
    if (!mounted) return;
    final generation = ++_scrollToVerseGeneration;
    _pendingScrollVerse = verseNum;
    setState(() {});
    if (quick) {
      _scheduleVerseFocusQuick(verseNum, generation);
    } else {
      _scheduleVerseFocus(verseNum, generation);
    }
  }

  void _scheduleVerseFocusQuick(int verseNum, int generation) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _scrollToVerseGeneration) return;
      _jumpToVerseCentered(verseNum);
      _pendingScrollVerse = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _scrollToVerseGeneration) return;
        _highlightVerseTemporarily(verseNum);
      });
    });
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
    final appBarBg = _bibleScreenAppBarBg(context);
    final buttonBg = _bibleScreenButtonBg(context);
    final chromeTextColor = _bibleScreenChromeTitleFg(context);
    const verseBg = Colors.transparent;
    final verseTextColor = _bibleScreenChromeFg(context);
    final iconFg = _bibleScreenIsDark(context)
        ? AppThemeColors.darkText(context, BibleDarkPalette.chromeMutedGold)
        : BibleLightPalette.iconActive;
    final iconFgDisabled = _bibleScreenIsDark(context)
        ? AppThemeColors.darkText(context, BibleDarkPalette.chromeMutedGold)
            .withValues(alpha: 0.42)
        : BibleLightPalette.disabledText;
    final lightChromeOutline = _bibleScreenIsDark(context)
        ? _bibleChromeOutlineSide(context)
        : BibleLightPalette.chromePillOutlineSide;

    final toolbarH =
        AppProvider.toolbarHeightForChrome(appProvider.chromeButtonSize);

    final scaffold = Scaffold(
      backgroundColor:
          isDark ? BibleDarkPalette.screenBg : Colors.transparent,
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
            child: _buildBibleChapterCard(
              isDark: isDark,
              appProvider: appProvider,
              verses: verses,
              verseBg: verseBg,
              verseTextColor: verseTextColor,
              chromeTextColor: chromeTextColor,
              buttonBg: buttonBg,
            ),
          ),
        ],
      ),
    );

    return scaffold;
  }

  Widget _buildBibleChapterCard({
    required bool isDark,
    required AppProvider appProvider,
    required List<Map<String, dynamic>> verses,
    required Color verseBg,
    required Color verseTextColor,
    required Color chromeTextColor,
    required Color buttonBg,
  }) {
    final chapterKey =
        '${appProvider.currentBook}_${appProvider.currentChapter}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: isDark ? BibleDarkPalette.cardBg : null,
          gradient:
              isDark ? null : AppThemeColors.lightVerseCardGradient(context),
          border: Border.all(
            color: isDark
                ? BibleDarkPalette.cardBorderGold
                : BibleLightPalette.border,
            width: 1,
          ),
          boxShadow: isDark
              ? BibleDarkPalette.verseCardShadow
              : BibleLightPalette.verseCardShadow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: IgnorePointer(
            ignoring: !_isBibleInteractionActive,
            child: _BibleChapterSwipeSurface(
              enabled: _isBibleInteractionActive,
              canGoPrev: appProvider.canGoPrevBible,
              canGoNext: appProvider.canGoNextBible,
              onGoPrev: appProvider.goPrev,
              onGoNext: appProvider.goNext,
              chapterKey: chapterKey,
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
    );
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
        isDark ? BibleDarkPalette.iconActive : BibleLightPalette.iconActive;
    final overlayChromeOutline = isDark
        ? BibleDarkPalette.chromeButtonOutline
        : BibleLightPalette.chromePillOutlineSide;
    final overlayButtonBg = _bibleScreenOverlayButtonBg(context);

    return appProvider.isLoading
        ? const Center(child: CircularProgressIndicator())
        : verses.isEmpty
            ? const Center(child: Text('Глава не найдена'))
            : Stack(
                clipBehavior: Clip.none,
                children: [
                  Builder(
                    builder: (context) {
                      final pending = _pendingScrollVerse;
                      var initialIndex = 0;
                      var initialAlignment = 0.0;
                      if (pending != null) {
                        final idx = _verseListIndex(verses, pending);
                        if (idx != null && idx >= 0) {
                          initialIndex = idx;
                          initialAlignment = 0.5;
                        }
                      }
                      return ScrollablePositionedList.builder(
                        key: ValueKey(
                          '${appProvider.currentBook}_${appProvider.currentChapter}_'
                          '${appProvider.verseFontPreset}',
                        ),
                        itemCount: verses.length,
                        itemScrollController: _verseItemScrollController,
                        initialScrollIndex: initialIndex,
                        initialAlignment: initialAlignment,
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
                          final showDivider = index < verses.length - 1;
                          final dividerColor = isDark
                              ? BibleDarkPalette.divider
                              : BibleLightPalette.verseDivider;
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
                                      ? Border(
                                          bottom: BorderSide(
                                            color: dividerColor,
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
                      final generation = ++_scrollToVerseGeneration;
                      final expectInitialScroll =
                          appProvider.currentBook != book ||
                              appProvider.currentChapter != chapter;
                      _pendingScrollVerse = verse;
                      await appProvider.changeBookAndChapter(book, chapter);
                      if (!mounted || generation != _scrollToVerseGeneration) {
                        return;
                      }
                      setState(() {});
                      _scheduleVerseFocus(
                        verse,
                        generation,
                        expectInitialScroll: expectInitialScroll,
                      );
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
            final maxDialogH = _bibleModalMaxDialogHeight(
              dialogContext,
              screenHeight: h,
              verticalViewPadding: mq.viewPadding.vertical,
              chromeButtonSize: app.chromeButtonSize,
              minHeight: 120.0,
            );
            final dialogMaxW = (w - 16).clamp(280.0, 440.0);
            const padH = 16.0;
            const padTop = 16.0;
            const padBottom = 14.0;
            const gapAfterTitle = 10.0;
            final estimatedContentW = pickerEstimatedContentWidth(
              screenWidth: w,
              dialogMaxW: dialogMaxW,
              horizontalPad: padH,
              uiFs: uiFs,
            );
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
              textScaler: MediaQuery.textScalerOf(dialogContext),
            )..layout(maxWidth: estimatedContentW);
            final headerH = padTop + titlePainter.height + gapAfterTitle;
            final bodyMaxH = (maxDialogH - headerH - padBottom).clamp(48.0, maxDialogH);
            const scrollContentBottomPad = 12.0;
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
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    shape: const CircleBorder(),
                                    elevation: 0,
                                    backgroundColor: isCurrent
                                        ? (isLight
                                            ? BibleLightPalette.primary
                                            : BibleDarkPalette.accentGold)
                                        : (isLight
                                            ? BibleLightPalette.activeBg
                                            : BibleDarkPalette.cardBg),
                                    foregroundColor: isCurrent
                                        ? (isLight
                                            ? Colors.white
                                            : BibleDarkPalette.screenBg)
                                        : (isLight
                                            ? BibleLightPalette.primaryText
                                            : AppThemeColors.darkText(
                                                context,
                                                BibleDarkPalette.primaryText,
                                              )),
                                    side: isLight
                                        ? BorderSide(
                                            color: isCurrent
                                                ? BibleLightPalette.primaryDark
                                                : BibleLightPalette
                                                    .chromePillOutlineColor,
                                            width: 1.2,
                                          )
                                        : BorderSide(
                                            color: isCurrent
                                                ? BibleDarkPalette.accentGoldDark
                                                : BibleDarkPalette.cardBorderGold,
                                            width: 1.2,
                                          ),
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
            horizontal: pickerDialogInsetHorizontal(uiFs),
            vertical: (uiFs * 0.375).clamp(4.0, 12.0),
          ),
          child: _biblePickerDialogShell(
            context: dialogContext,
            borderRadius: 22,
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
                child: LayoutBuilder(
                  builder: (context, box) {
                    final layout = layoutCirclePickerGridBody(
                      contentW: box.maxWidth,
                      bodyMaxH: bodyMaxH,
                      itemCount: chapterCount,
                      cell: chapterCell,
                      gap: wrapGap,
                      scrollContentBottomPad: scrollContentBottomPad,
                    );
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          titleText,
                          style: titleStyle,
                        ),
                        const SizedBox(height: gapAfterTitle),
                        buildCirclePickerGridBody(
                          needsScroll: layout.needsScroll,
                          bodyH: layout.bodyH,
                          scrollContentBottomPad: scrollContentBottomPad,
                          grid: chapterGrid,
                        ),
                      ],
                    );
                  },
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
            final textScaler = MediaQuery.textScalerOf(dialogContext);
            final h = mq.size.height;
            final w = mq.size.width;
            final maxH = _bibleModalMaxDialogHeight(
              dialogContext,
              screenHeight: h,
              verticalViewPadding: mq.viewPadding.vertical,
              chromeButtonSize: app.chromeButtonSize,
              minHeight: 280.0,
            );
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
              textScaler: textScaler,
            )..layout(maxWidth: contentW);
            final oldSectionPainter = TextPainter(
              text: TextSpan(text: 'Ветхий Завет:', style: sectionStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              textScaler: textScaler,
            )..layout(maxWidth: contentW);
            final newSectionPainter = TextPainter(
              text: TextSpan(text: 'Новый Завет:', style: sectionStyle),
              textDirection: TextDirection.ltr,
              maxLines: 1,
              textScaler: textScaler,
            )..layout(maxWidth: contentW);
            final oldGridH = _bibleBookSelectionGridHeight(
              books: oldTestamentBooks,
              maxWidth: contentW,
              horizontalGap: wrapH,
              verticalGap: wrapV,
              padH: padH,
              padV: padV,
              bookAbbrFs: bookAbbrFs,
              textScaler: textScaler,
            );
            final newGridH = _bibleBookSelectionGridHeight(
              books: newTestamentBooks,
              maxWidth: contentW,
              horizontalGap: wrapH,
              verticalGap: wrapV,
              padH: padH,
              padV: padV,
              bookAbbrFs: bookAbbrFs,
              textScaler: textScaler,
            );
            /// Высота блока «ВЗ + НЗ» без заголовка «Выберите книгу»: только для [SizedBox]/скролла.
            /// Раньше ошибочно суммировали с заголовком и сравнивали с уже «урезанной» [bodyMaxH] —
            /// прокрутка не включалась, список НЗ обрезался.
            final bookListBodyH = oldSectionPainter.height +
                gapSm +
                oldGridH +
                gapMd +
                newSectionPainter.height +
                gapSm +
                newGridH;
            final headerH = padTop + titlePainter.height + gapSm;
            final bodyMaxH =
                (maxH - headerH - padBottom).clamp(80.0, maxH);
            const scrollContentBottomPad = 12.0;
            final gridContentH = bookListBodyH + scrollContentBottomPad;
            final needsScroll = gridContentH > bodyMaxH;
            final bodyH = needsScroll ? bodyMaxH : gridContentH;
            final initialScrollOffset = bookPickerSavedScrollOffset > 0
                ? bookPickerSavedScrollOffset
                : computeBookPickerScrollOffsetForBook(
                    book: app.currentBook,
                    oldBooks: oldTestamentBooks,
                    newBooks: newTestamentBooks,
                    contentW: contentW,
                    wrapH: wrapH,
                    wrapV: wrapV,
                    padH: padH,
                    padV: padV,
                    bookAbbrFs: bookAbbrFs,
                    textScaler: textScaler,
                    oldSectionH: oldSectionPainter.height,
                    newSectionH: newSectionPainter.height,
                    gapSm: gapSm,
                    gapMd: gapMd,
                  );
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
              child: _biblePickerDialogShell(
                context: dialogContext,
                borderRadius: 22,
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
                          child: BookPickerScrollMemory(
                            needsScroll: needsScroll,
                            initialScrollOffset: initialScrollOffset,
                            scrollContentBottomPad: scrollContentBottomPad,
                            child: bookList,
                          ),
                        ),
                      ],
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
  });

  final ScrollController controller;
  final Color thumbColor;
  final Color trackHintColor;
  final double thumbSize;

  @override
  State<_BibleRailScrollHandle> createState() => _BibleRailScrollHandleState();
}

class _BibleRailScrollHandleState extends State<_BibleRailScrollHandle> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant _BibleRailScrollHandle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (mounted) setState(() {});
  }

  Widget _scrollGripLine(BuildContext context, double width) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: width,
      height: 2.5,
      decoration: BoxDecoration(
        color: dark ? BibleDarkPalette.accentGold : Colors.black,
        borderRadius: BorderRadius.circular(1.25),
      ),
    );
  }

  Widget _scrollGripLines(BuildContext context, double ts) {
    final gap = (ts * 0.11).clamp(3.0, 6.0);
    final lineW = (ts * 0.55).clamp(14.0, 28.0);
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _scrollGripLine(context, lineW),
        SizedBox(height: gap),
        _scrollGripLine(context, lineW),
        SizedBox(height: gap),
        _scrollGripLine(context, lineW),
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
                  },
                  child: Material(
                    color: widget.thumbColor,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: Theme.of(context).brightness == Brightness.dark
                          ? BibleDarkPalette.chromeButtonOutline
                          : BibleLightPalette.chromePillOutlineSide,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: SizedBox(
                      width: ts,
                      height: ts,
                      child: Center(child: _scrollGripLines(context, ts)),
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
    return SizedBox(
      height: panelRowHeight,
      child: Align(
        alignment: Alignment.center,
        child: child,
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

class _BibleSearchDialogState extends State<_BibleSearchDialog>
    with WidgetsBindingObserver {
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
  double _lastViewInsetBottom = 0;
  bool _showHistorySuggestions = false;
  List<String> _querySegmentsCache = const [];
  bool _resultsMayHaveMore = false;

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
    _querySegmentsCache = widget.initialQuery
        .toLowerCase()
        .trim()
        .split(RegExp(r'\s+'))
        .where((segment) => segment.isNotEmpty)
        .toSet()
        .toList();
    _resultsMayHaveMore = _results.length >= _kBibleSearchResultsCap;
    _trackedResultsScrollOffset =
        widget.initialScrollOffset < 0 ? 0.0 : widget.initialScrollOffset;
    _resultsScrollController.addListener(_onResultsScroll);
    WidgetsBinding.instance.addObserver(this);
    if (_trackedResultsScrollOffset > 0 && _results.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _applyRestoredScrollOffset();
        _lastViewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
      });
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _lastViewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
      });
    }
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    _applyKeyboardInset(MediaQuery.viewInsetsOf(context).bottom);
  }

  void _applyKeyboardInset(double bottom) {
    if (_lastViewInsetBottom > 48 && bottom < 48) {
      _hideHistorySuggestions();
    }
    _lastViewInsetBottom = bottom;
  }

  void _hideHistorySuggestions() {
    if (!_showHistorySuggestions || !mounted) return;
    setState(() => _showHistorySuggestions = false);
  }

  void _maybeShowHistorySuggestions() {
    if (_showHistorySuggestions || !mounted || !_focusNode.hasFocus) return;
    if (MediaQuery.viewInsetsOf(context).bottom < 48) return;
    setState(() => _showHistorySuggestions = true);
    _watchKeyboardWhileSuggestionsOpen();
  }

  /// Пока открыт список подсказок — каждый кадр проверяем, не спрятали ли клавиатуру.
  void _watchKeyboardWhileSuggestionsOpen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_showHistorySuggestions) return;
      if (MediaQuery.viewInsetsOf(context).bottom < 48) {
        _hideHistorySuggestions();
        return;
      }
      _watchKeyboardWhileSuggestionsOpen();
    });
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
    WidgetsBinding.instance.removeObserver(this);
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

  void _runSearch({bool unfocus = true, bool hideSuggestions = false}) {
    if (hideSuggestions) {
      _hideHistorySuggestions();
    }
    if (unfocus) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    final q = _queryCtrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _results = [];
        _hasRunSearch = false;
        _selectedResultIndices.clear();
        _resultsMayHaveMore = false;
        _querySegmentsCache = const [];
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
      maxResults: _kBibleSearchResultsCap,
    );
    final segments = _querySegments();
    setState(() {
      _results = list;
      _hasRunSearch = true;
      _selectedResultIndices.clear();
      _resultsMayHaveMore = list.length >= _kBibleSearchResultsCap;
      _querySegmentsCache = segments;
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

  @override
  Widget build(BuildContext context) {
    final padBg = _bibleScreenButtonBg(context);
    final fg = _bibleScreenChromeFg(context);
    final headingFg = _bibleScreenPanelHeadingFg(context);
    final verseBg = _bibleSearchSolidSurfaceBg(context);
    final rowHi = _bibleScreenRowHighlight(context);
    final hintColor = _bibleScreenIsDark(context)
        ? AppThemeColors.darkText(context, BibleDarkPalette.secondaryText)
        : BibleLightPalette.disabledText;
    final divColor = _bibleScreenIsDark(context)
        ? BibleDarkPalette.divider
        : BibleLightPalette.cardDivider;
    final iconToolFg = _bibleScreenIsDark(context)
        ? BibleDarkPalette.iconActive
        : BibleLightPalette.iconActive;
    final searchChromeOutline = _bibleScreenIsDark(context)
        ? BibleDarkPalette.chromeButtonOutline
        : BibleLightPalette.chromePillOutlineSide;
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
    final previewBase = app.bibleVerseTextStyle(
      color: fg,
      fontWeight: FontWeight.normal,
    );
    final previewHi = previewBase.copyWith(
      backgroundColor: _bibleScreenSearchMatchHighlight(context),
      fontWeight: FontWeight.w700,
    );
    final resultHeaderStyle = app.bibleVerseTextStyle(
      color: fg,
      fontWeight: FontWeight.w600,
    );
    final resultsCountLabel = _resultsMayHaveMore
        ? 'Найдено совпадений: ${_results.length}+ (уточните запрос — в списке первые ${_results.length})'
        : 'Найдено совпадений: ${_results.length}';

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
                  ? BibleDarkPalette.accentGold
                  : BibleLightPalette.primary;
              final segActiveFg =
                  isDark ? BibleDarkPalette.screenBg : Colors.white;
              final segInactiveFg = isDark
                  ? AppThemeColors.darkText(
                      context,
                      BibleDarkPalette.secondaryText,
                    )
                  : BibleLightPalette.secondaryText;
              final rowLabelStyle = TextStyle(
                fontSize: searchPanelLabelFs,
                fontWeight: FontWeight.w600,
                color: fg,
                height: 1.15,
              );
              final wholeWordLabelStyle = rowLabelStyle.copyWith(
                color: isDark
                    ? AppThemeColors.darkText(
                        context,
                        BibleDarkPalette.titleGold,
                      )
                    : BibleLightPalette.primaryDark,
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
                  ? BibleDarkPalette.divider
                  : BibleLightPalette.chromePillOutlineColor;
              final panelBorder = Border.all(
                color: isDark
                    ? BibleDarkPalette.cardBorderGold
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
                                      return isDark
                                          ? BibleDarkPalette.iconInactive
                                          : segActive;
                                    }),
                                    trackColor:
                                        WidgetStateProperty.resolveWith((s) {
                                      if (s.contains(WidgetState.selected)) {
                                        return isDark
                                            ? BibleDarkPalette.accentGold
                                            : BibleLightPalette.primary;
                                      }
                                      return isDark
                                          ? BibleDarkPalette.divider
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
                if (!_showHistorySuggestions) {
                  return const Iterable<String>.empty();
                }
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
                _runSearch(unfocus: false, hideSuggestions: true);
              },
              fieldViewBuilder:
                  (context, controller, focusNode, onFieldSubmitted) {
                final isDark = _bibleScreenIsDark(context);
                final fieldFill = _bibleSearchControlPanelTrackColor(context);
                final panelRadius =
                    _bibleSearchControlPanelRadius(panelRowHeight);
                final outlineIdle = isDark
                    ? BibleDarkPalette.cardBorderGold
                    : BibleLightPalette.chromePillOutlineColor;
                final outlineFocus = isDark
                    ? BibleDarkPalette.accentGold
                    : BibleLightPalette.primary;
                OutlineInputBorder fieldOutline(Color color) =>
                    OutlineInputBorder(
                      borderRadius: BorderRadius.circular(panelRadius),
                      borderSide: BorderSide(
                        color: color,
                        width: ChromeOutline.width,
                      ),
                    );
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
                        border: fieldOutline(outlineIdle),
                        enabledBorder: fieldOutline(outlineIdle),
                        focusedBorder: fieldOutline(outlineFocus),
                      ),
                      onChanged: (_) {
                        _maybeShowHistorySuggestions();
                        _scheduleDebouncedSearch();
                      },
                      onSubmitted: (_) =>
                          _runSearch(hideSuggestions: true),
                    );
                  },
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                if (!_showHistorySuggestions || options.isEmpty) {
                  return const SizedBox.shrink();
                }
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
                                    ? BibleDarkPalette.cardBorderGold
                                    : BibleLightPalette.chromePillOutlineColor,
                                width: ChromeOutline.width,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: NotificationListener<ScrollStartNotification>(
                                    onNotification: (_) {
                                      _hideHistorySuggestions();
                                      return false;
                                    },
                                    child: ScrollConfiguration(
                                      behavior: ScrollConfiguration.of(context)
                                          .copyWith(scrollbars: false),
                                      child: ListView.separated(
                                      controller: _resultsScrollController,
                                      addAutomaticKeepAlives: false,
                                      cacheExtent: 128,
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
                                      return RepaintBoundary(
                                        child: Material(
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
                                                  style: resultHeaderStyle,
                                                ),
                                                const SizedBox(height: 4),
                                                Text.rich(
                                                  TextSpan(
                                                    children:
                                                        _bibleSearchPreviewSpans(
                                                      fullText: text,
                                                      baseStyle: previewBase,
                                                      hiStyle: previewHi,
                                                      segments:
                                                          _querySegmentsCache,
                                                      wholeWordsOnly:
                                                          _wholeWords,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      );
                                      },
                                    ),
                                  ),
                                ),
                                ),
                                const SizedBox(width: 4),
                                _BibleRailScrollHandle(
                                  controller: _resultsScrollController,
                                  thumbColor: padBg,
                                  trackHintColor: _bibleScreenIsDark(context)
                                      ? BibleDarkPalette.divider
                                      : BibleLightPalette.activeBg,
                                  thumbSize: (widget.appProvider.chromeButtonSize *
                                          0.68)
                                      .clamp(26.0, 36.0),
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
                resultsCountLabel,
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
    final favIconFg = _bibleScreenIsDark(context)
        ? BibleDarkPalette.iconActive
        : BibleLightPalette.iconActive;
    final favOutline = _bibleScreenIsDark(context)
        ? BibleDarkPalette.chromeButtonOutline
        : BibleLightPalette.chromePillOutlineSide;

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
                                ? BibleDarkPalette.divider
                                : BibleLightPalette.cardDivider,
                          ),
                          itemBuilder: (context, i) {
                            final e = _entries[i];
                            final n = i + 1;
                            final picked = _selectedEntryIndices.contains(i);
                            final multi = _selectedEntryIndices.isNotEmpty;
                            final bodyStyle = _favoritesPanelTextStyle(
                              app,
                              color: fg,
                              fontWeight: FontWeight.normal,
                            );
                            final headerLineStyle = _favoritesPanelTextStyle(
                              app,
                              color: fg,
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
                  border: Border.all(
                    color: BibleDarkPalette.cardBorderGold,
                    width: 1,
                  ),
                  boxShadow: BibleDarkPalette.verseCardShadow,
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
