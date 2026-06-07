import 'dart:math' as math;

import 'package:bible_app/inspiration/inspiration_models.dart';
import 'package:bible_app/models/bible_model.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:bible_app/theme/bible_light_palette.dart';
import 'package:bible_app/widgets/chrome_frost_glass_panel.dart';
import 'package:bible_app/widgets/main_chrome_tab_bar.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

bool _pickerIsDark(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark;

Color _pickerHeadingFg(BuildContext context) => _pickerIsDark(context)
    ? BibleDarkPalette.titleGold
    : BibleLightPalette.primaryDark;

double _pickerModalMaxHeight(
  BuildContext context, {
  required double screenHeight,
  required double verticalViewPadding,
  required double chromeButtonSize,
  double extraMargin = 12.0,
  double minHeight = 200.0,
}) {
  final topReserve = AppProvider.toolbarHeightForChrome(chromeButtonSize) + 8.0;
  final bottomReserve = mainChromeTabBarTotalHeight(context) + 10.0;
  return (screenHeight - verticalViewPadding - topReserve - bottomReserve - extraMargin)
      .clamp(minHeight, screenHeight);
}

double pickerDialogInsetHorizontal(double uiFs) => (uiFs * 0.5).clamp(6.0, 14.0);

/// Ширина контента диалога с учётом [Dialog.insetPadding], не только [dialogMaxW].
double pickerEstimatedContentWidth({
  required double screenWidth,
  required double dialogMaxW,
  required double horizontalPad,
  required double uiFs,
}) {
  final inset = pickerDialogInsetHorizontal(uiFs);
  final dialogW = math.min(dialogMaxW, screenWidth - inset * 2);
  return math.max(0, dialogW - horizontalPad * 2);
}

/// Число колонок Wrap, гарантированно помещающихся в [maxWidth].
int circlePickerGridColumnCount(double maxWidth, double cell, double gap) {
  if (maxWidth <= 0) return 1;
  var cols = math.max(1, ((maxWidth + gap) / (cell + gap)).floor());
  while (cols > 1 && cols * cell + (cols - 1) * gap > maxWidth + 0.5) {
    cols--;
  }
  return cols;
}

double circlePickerGridHeight(int itemCount, int cols, double cell, double gap) {
  final rowCount = (itemCount + cols - 1) ~/ cols;
  return rowCount * cell + math.max(0, rowCount - 1) * gap;
}

/// Высота тела сетки круглых кнопок по фактической ширине контента.
({double bodyH, bool needsScroll}) layoutCirclePickerGridBody({
  required double contentW,
  required double bodyMaxH,
  required int itemCount,
  required double cell,
  required double gap,
  double scrollContentBottomPad = 12.0,
}) {
  final cols = circlePickerGridColumnCount(contentW, cell, gap);
  final gridHeight = circlePickerGridHeight(itemCount, cols, cell, gap);
  final gridContentH = gridHeight + scrollContentBottomPad;
  final needsScroll = gridContentH > bodyMaxH;
  return (bodyH: needsScroll ? bodyMaxH : gridContentH, needsScroll: needsScroll);
}

Widget buildCirclePickerGridBody({
  required bool needsScroll,
  required double bodyH,
  required Widget grid,
  double scrollContentBottomPad = 12.0,
}) {
  return SizedBox(
    height: bodyH,
    child: ClipRect(
      child: needsScroll
          ? SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.only(bottom: scrollContentBottomPad),
                child: grid,
              ),
            )
          : Padding(
              padding: EdgeInsets.only(bottom: scrollContentBottomPad),
              child: grid,
            ),
    ),
  );
}

Widget _pickerDialogShell({
  required BuildContext context,
  required double borderRadius,
  required Widget child,
}) {
  if (_pickerIsDark(context)) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: BibleDarkPalette.cardBg,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: BibleDarkPalette.cardBorderGold, width: 1),
        boxShadow: BibleDarkPalette.verseCardShadow,
      ),
      child: child,
    );
  }
  return chromeFrostGlassPanelShell(borderRadius: borderRadius, child: child);
}

double _bookChipMinWidth(
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

List<List<String>> _packBookRows(
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
        .map((b) => _bookChipMinWidth(b, fontSize, padH, textScaler))
        .fold(0.0, math.max);
  }

  double equalCellWidth(int count) {
    if (count <= 0) return maxWidth;
    return (maxWidth - spacing * (count - 1)) / count;
  }

  for (final book in books) {
    final minW = _bookChipMinWidth(book, fontSize, padH, textScaler);
    while (true) {
      final tryCount = row.length + 1;
      final cellW = equalCellWidth(tryCount);
      final maxMin = row.isEmpty ? minW : math.max(rowMaxMinWidth(), minW);
      if (row.isEmpty || cellW >= maxMin) {
        row.add(book);
        break;
      }
      rows.add(List<String>.from(row));
      row = [];
    }
  }
  if (row.isNotEmpty) rows.add(row);
  return rows;
}

double _bookChipRowHeight(
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
  final slop =
      math.max(1.25, math.min(8.5, fontSize * 0.085 * textScaler.scale(1)));
  return painter.height + padV * 2 + 2.4 + slop;
}

double _bookSelectionGridHeight({
  required List<String> books,
  required double maxWidth,
  required double horizontalGap,
  required double verticalGap,
  required double padH,
  required double padV,
  required double bookAbbrFs,
  required TextScaler textScaler,
}) {
  final rows = _packBookRows(
    books,
    maxWidth,
    horizontalGap,
    padH,
    bookAbbrFs,
    textScaler,
  );
  if (rows.isEmpty) return 0;
  final rowH = _bookChipRowHeight(bookAbbrFs, padV, textScaler);
  return rows.length * rowH + math.max(0, rows.length - 1) * verticalGap;
}

/// Сохранённая позиция прокрутки панели «Выберите книгу» между открытиями.
double bookPickerSavedScrollOffset = 0;

/// Смещение прокрутки к строке с [book] (если сохранённого offset ещё нет).
double computeBookPickerScrollOffsetForBook({
  required String? book,
  required List<String> oldBooks,
  required List<String> newBooks,
  required double contentW,
  required double wrapH,
  required double wrapV,
  required double padH,
  required double padV,
  required double bookAbbrFs,
  required TextScaler textScaler,
  required double oldSectionH,
  required double newSectionH,
  required double gapSm,
  required double gapMd,
  double leadHeight = 0,
}) {
  if (book == null || book.isEmpty) return 0;

  double offsetInGrid(String target, List<String> books) {
    final rows = _packBookRows(
      books,
      contentW,
      wrapH,
      padH,
      bookAbbrFs,
      textScaler,
    );
    final rowH = _bookChipRowHeight(bookAbbrFs, padV, textScaler);
    for (var r = 0; r < rows.length; r++) {
      if (rows[r].contains(target)) {
        return r * (rowH + wrapV);
      }
    }
    return 0;
  }

  if (!oldBooks.contains(book) && !newBooks.contains(book)) return 0;

  var y = leadHeight + oldSectionH + gapSm;
  if (oldBooks.contains(book)) {
    y += offsetInGrid(book, oldBooks);
    return math.max(0, y - 32);
  }
  y += _bookSelectionGridHeight(
        books: oldBooks,
        maxWidth: contentW,
        horizontalGap: wrapH,
        verticalGap: wrapV,
        padH: padH,
        padV: padV,
        bookAbbrFs: bookAbbrFs,
        textScaler: textScaler,
      ) +
      gapMd +
      newSectionH +
      gapSm;
  y += offsetInGrid(book, newBooks);
  return math.max(0, y - 32);
}

/// Прокрутка списка книг с запоминанием позиции между открытиями диалога.
class BookPickerScrollMemory extends StatefulWidget {
  const BookPickerScrollMemory({
    super.key,
    required this.needsScroll,
    required this.initialScrollOffset,
    required this.child,
    this.scrollContentBottomPad = 12.0,
  });

  final bool needsScroll;
  final double initialScrollOffset;
  final Widget child;
  final double scrollContentBottomPad;

  @override
  State<BookPickerScrollMemory> createState() => _BookPickerScrollMemoryState();
}

class _BookPickerScrollMemoryState extends State<BookPickerScrollMemory> {
  late final ScrollController _controller;

  @override
  void initState() {
    super.initState();
    _controller = ScrollController(
      initialScrollOffset: widget.initialScrollOffset,
    );
  }

  void _persistOffset() {
    if (_controller.hasClients) {
      bookPickerSavedScrollOffset = _controller.offset;
    }
  }

  @override
  void dispose() {
    _persistOffset();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padded = Padding(
      padding: EdgeInsets.only(bottom: widget.scrollContentBottomPad),
      child: widget.child,
    );
    if (!widget.needsScroll) return padded;
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        if (notification is ScrollEndNotification) _persistOffset();
        return false;
      },
      child: SingleChildScrollView(
        controller: _controller,
        physics: const ClampingScrollPhysics(),
        child: padded,
      ),
    );
  }
}

class _BookSelectionChipGrid extends StatelessWidget {
  const _BookSelectionChipGrid({
    required this.books,
    required this.selectedBook,
    required this.isDark,
    required this.horizontalGap,
    required this.verticalGap,
    required this.padH,
    required this.padV,
    required this.bookAbbrFs,
    required this.onBookTap,
  });

  final List<String> books;
  final String? selectedBook;
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
        final rows = _packBookRows(
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
                    return Wrap(
                      spacing: horizontalGap,
                      runSpacing: verticalGap,
                      children: [for (final b in row) _chip(b)],
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
    final isSelected = book == selectedBook;
    if (isDark) {
      final borderGold = BorderSide(
        color: isSelected
            ? BibleDarkPalette.accentGold
            : BibleDarkPalette.cardBorderGold,
        width: 1.2,
      );
      return TextButton(
        onPressed: () => onBookTap(book),
        style: TextButton.styleFrom(
          backgroundColor: isSelected
              ? BibleDarkPalette.accentGold.withValues(alpha: 0.38)
              : BibleDarkPalette.cardBg,
          foregroundColor: isSelected
              ? BibleDarkPalette.accentGoldLight
              : BibleDarkPalette.primaryText,
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
            color: isSelected
                ? BibleDarkPalette.accentGoldLight
                : BibleDarkPalette.primaryText,
            fontSize: bookAbbrFs,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }
    return TextButton(
      onPressed: () => onBookTap(book),
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? BibleLightPalette.primary
            : BibleLightPalette.activeBg,
        foregroundColor:
            isSelected ? Colors.white : BibleLightPalette.primaryText,
        side: BorderSide(
          color: isSelected
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
          color: isSelected ? Colors.white : BibleLightPalette.primaryText,
          fontSize: bookAbbrFs,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Выбор книги — сетка ВЗ/НЗ как на экране Библии.
Future<String?> showBibleBookPickerDialog({
  required BuildContext context,
  String? selectedBook,
  bool includeRandomOption = false,
  bool randomSelected = false,
}) {
  return showDialog<String>(
    context: context,
    builder: (dialogContext) {
      return Consumer<AppProvider>(
        builder: (ctx, app, _) {
          final uiFs = app.fontSize;
          final titleFs = AppProvider.panelTitleFontSize(uiFs);
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
          final maxH = _pickerModalMaxHeight(
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
          final headingFg = _pickerHeadingFg(dialogContext);
          final isLight = !_pickerIsDark(dialogContext);
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
          final oldGridH = _bookSelectionGridHeight(
            books: oldTestamentBooks,
            maxWidth: contentW,
            horizontalGap: wrapH,
            verticalGap: wrapV,
            padH: padH,
            padV: padV,
            bookAbbrFs: bookAbbrFs,
            textScaler: textScaler,
          );
          final newGridH = _bookSelectionGridHeight(
            books: newTestamentBooks,
            maxWidth: contentW,
            horizontalGap: wrapH,
            verticalGap: wrapV,
            padH: padH,
            padV: padV,
            bookAbbrFs: bookAbbrFs,
            textScaler: textScaler,
          );
          final headerH = padTop + titlePainter.height + gapSm;
          final bodyMaxH = (maxH - headerH - padBottom).clamp(80.0, maxH);
          const scrollContentBottomPad = 12.0;
          final leadHeight = includeRandomOption
              ? _bookChipRowHeight(bookAbbrFs, padV, textScaler) + gapMd
              : 0.0;
          final bookListBodyH = leadHeight +
              oldSectionPainter.height +
              gapSm +
              oldGridH +
              gapMd +
              newSectionPainter.height +
              gapSm +
              newGridH;
          final gridContentH = bookListBodyH + scrollContentBottomPad;
          final needsScroll = gridContentH > bodyMaxH;
          final bodyH = needsScroll ? bodyMaxH : gridContentH;
          final initialScrollOffset = bookPickerSavedScrollOffset > 0
              ? bookPickerSavedScrollOffset
              : computeBookPickerScrollOffsetForBook(
                  book: selectedBook,
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
                  leadHeight: leadHeight,
                );
          final bookList = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (includeRandomOption) ...[
                _BookPickerLabeledChip(
                  label: 'Случайный',
                  isSelected: randomSelected,
                  isDark: !isLight,
                  padH: padH,
                  padV: padV,
                  fontSize: bookAbbrFs,
                  onTap: () => Navigator.pop(
                    dialogContext,
                    inspirationRandomBookPickerValue,
                  ),
                ),
                SizedBox(height: gapMd),
              ],
              Text('Ветхий Завет:', style: sectionStyle),
              SizedBox(height: gapSm),
              _BookSelectionChipGrid(
                books: oldTestamentBooks,
                selectedBook: selectedBook,
                isDark: !isLight,
                horizontalGap: wrapH,
                verticalGap: wrapV,
                padH: padH,
                padV: padV,
                bookAbbrFs: bookAbbrFs,
                onBookTap: (book) => Navigator.pop(dialogContext, book),
              ),
              SizedBox(height: gapMd),
              Text('Новый Завет:', style: sectionStyle),
              SizedBox(height: gapSm),
              _BookSelectionChipGrid(
                books: newTestamentBooks,
                selectedBook: selectedBook,
                isDark: !isLight,
                horizontalGap: wrapH,
                verticalGap: wrapV,
                padH: padH,
                padV: padV,
                bookAbbrFs: bookAbbrFs,
                onBookTap: (book) => Navigator.pop(dialogContext, book),
              ),
            ],
          );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: (uiFs * 0.5).clamp(6.0, 14.0),
              vertical: (uiFs * 0.375).clamp(4.0, 12.0),
            ),
            child: _pickerDialogShell(
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

class _BookPickerLabeledChip extends StatelessWidget {
  const _BookPickerLabeledChip({
    required this.label,
    required this.isSelected,
    required this.isDark,
    required this.padH,
    required this.padV,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final bool isDark;
  final double padH;
  final double padV;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (isDark) {
      final borderGold = BorderSide(
        color: isSelected
            ? BibleDarkPalette.accentGold
            : BibleDarkPalette.cardBorderGold,
        width: 1.2,
      );
      return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          backgroundColor: isSelected
              ? BibleDarkPalette.accentGold.withValues(alpha: 0.38)
              : BibleDarkPalette.cardBg,
          foregroundColor: isSelected
              ? BibleDarkPalette.accentGoldLight
              : BibleDarkPalette.primaryText,
          side: borderGold,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isSelected
                ? BibleDarkPalette.accentGoldLight
                : BibleDarkPalette.primaryText,
            fontSize: fontSize,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      );
    }
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        backgroundColor: isSelected
            ? BibleLightPalette.primary
            : BibleLightPalette.activeBg,
        foregroundColor:
            isSelected ? Colors.white : BibleLightPalette.primaryText,
        side: BorderSide(
          color: isSelected
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
        label,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: isSelected ? Colors.white : BibleLightPalette.primaryText,
          fontSize: fontSize,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}

/// Круглые кнопки в сетке — глава или стих, как на экране Библии.
Future<int?> showBibleCircleNumberPickerDialog({
  required BuildContext context,
  required String title,
  required int count,
  int? selected,
}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return Consumer<AppProvider>(
        builder: (ctx, app, _) {
          final uiFs = app.fontSize;
          final titleFs = AppProvider.panelTitleFontSize(uiFs);
          final numFs = (uiFs * 0.875).clamp(12.0, 24.0);
          final cell = (uiFs * 2.5).clamp(34.0, 56.0);
          final wrapGap = (uiFs * 0.25).clamp(3.0, 10.0);
          final mq = MediaQuery.of(dialogContext);
          final h = mq.size.height;
          final w = mq.size.width;
          final maxDialogH = _pickerModalMaxHeight(
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
          final titleStyle = TextStyle(
            fontSize: titleFs,
            fontWeight: FontWeight.w600,
            color: _pickerHeadingFg(dialogContext),
            height: 1.2,
          );
          final titlePainter = TextPainter(
            text: TextSpan(text: title, style: titleStyle),
            textDirection: TextDirection.ltr,
            maxLines: 4,
            textScaler: MediaQuery.textScalerOf(dialogContext),
          )..layout(maxWidth: estimatedContentW);
          final headerH = padTop + titlePainter.height + gapAfterTitle;
          final bodyMaxH = (maxDialogH - headerH - padBottom).clamp(48.0, maxDialogH);
          const scrollContentBottomPad = 12.0;
          final isLight = !_pickerIsDark(dialogContext);
          final buttons = List.generate(count, (index) {
            final number = index + 1;
            final isCurrent = number == selected;
            return SizedBox(
              width: cell,
              height: cell,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, number),
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
                          : BibleDarkPalette.primaryText),
                  side: isLight
                      ? BorderSide(
                          color: isCurrent
                              ? BibleLightPalette.primaryDark
                              : BibleLightPalette.chromePillOutlineColor,
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
                  '$number',
                  style: TextStyle(
                    fontSize: numFs,
                    fontWeight:
                        isCurrent ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            );
          });
          final grid = Wrap(
            spacing: wrapGap,
            runSpacing: wrapGap,
            alignment: WrapAlignment.center,
            children: buttons,
          );

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: pickerDialogInsetHorizontal(uiFs),
              vertical: (uiFs * 0.375).clamp(4.0, 12.0),
            ),
            child: _pickerDialogShell(
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
                        itemCount: count,
                        cell: cell,
                        gap: wrapGap,
                        scrollContentBottomPad: scrollContentBottomPad,
                      );
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: titleStyle),
                          const SizedBox(height: gapAfterTitle),
                          buildCirclePickerGridBody(
                            needsScroll: layout.needsScroll,
                            bodyH: layout.bodyH,
                            scrollContentBottomPad: scrollContentBottomPad,
                            grid: grid,
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

Future<int?> showBibleChapterPickerDialog({
  required BuildContext context,
  required String book,
  int? selectedChapter,
}) {
  final chapterCount = BibleService().getChapterCount(book);
  return showBibleCircleNumberPickerDialog(
    context: context,
    title: 'Выберите главу (${BibleBook.liturgicalDisplayName(book)})',
    count: chapterCount,
    selected: selectedChapter,
  );
}

Future<int?> showBibleVersePickerDialog({
  required BuildContext context,
  required String book,
  required int chapter,
  int? selectedVerse,
}) {
  final verses = BibleService().getVerses(book, chapter);
  final count = verses.isEmpty ? 1 : verses.last.verse;
  final abbr = BibleService().getBookAbbreviation(book);
  return showBibleCircleNumberPickerDialog(
    context: context,
    title: 'Выберите стих ($abbr $chapter)',
    count: count,
    selected: selectedVerse,
  );
}

const _calendarMonthNames = [
  'январь',
  'февраль',
  'март',
  'апрель',
  'май',
  'июнь',
  'июль',
  'август',
  'сентябрь',
  'октябрь',
  'ноябрь',
  'декабрь',
];

String calendarMonthLabel(int month) =>
    _calendarMonthNames[(month - 1).clamp(0, 11)];

/// День месяца — круги в сетке, как выбор главы.
Future<int?> showCalendarDayPickerDialog({
  required BuildContext context,
  int? selectedDay,
}) {
  return showBibleCircleNumberPickerDialog(
    context: context,
    title: 'День',
    count: 31,
    selected: selectedDay,
  );
}

double _labelChipMinWidth(
  String label,
  double fontSize,
  double padH,
  TextScaler textScaler,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: label,
      style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    textScaler: textScaler,
  )..layout();
  return painter.width + padH * 2;
}

List<List<int>> _packLabelRows(
  List<String> labels,
  double maxWidth,
  double spacing,
  double padH,
  double fontSize,
  TextScaler textScaler,
) {
  if (labels.isEmpty || maxWidth <= 0) return const [];

  final rows = <List<int>>[];
  var row = <int>[];

  double rowMaxMinWidth() {
    if (row.isEmpty) return 0;
    return row
        .map((i) => _labelChipMinWidth(labels[i], fontSize, padH, textScaler))
        .fold(0.0, math.max);
  }

  double equalCellWidth(int count) {
    if (count <= 0) return maxWidth;
    return (maxWidth - spacing * (count - 1)) / count;
  }

  for (var i = 0; i < labels.length; i++) {
    final minW = _labelChipMinWidth(labels[i], fontSize, padH, textScaler);
    while (true) {
      final tryCount = row.length + 1;
      final cellW = equalCellWidth(tryCount);
      final maxMin = row.isEmpty ? minW : math.max(rowMaxMinWidth(), minW);
      if (row.isEmpty || cellW >= maxMin) {
        row.add(i);
        break;
      }
      rows.add(List<int>.from(row));
      row = [];
    }
  }
  if (row.isNotEmpty) rows.add(row);
  return rows;
}

double _labelChipGridHeight({
  required List<String> labels,
  required double maxWidth,
  required double horizontalGap,
  required double verticalGap,
  required double padH,
  required double padV,
  required double fontSize,
  required TextScaler textScaler,
}) {
  final rows = _packLabelRows(
    labels,
    maxWidth,
    horizontalGap,
    padH,
    fontSize,
    textScaler,
  );
  if (rows.isEmpty) return 0;
  final rowH = _bookChipRowHeight(fontSize, padV, textScaler);
  return rows.length * rowH + math.max(0, rows.length - 1) * verticalGap;
}

class _LabelSelectionChipGrid extends StatelessWidget {
  const _LabelSelectionChipGrid({
    required this.labels,
    required this.selectedIndex,
    required this.isDark,
    required this.horizontalGap,
    required this.verticalGap,
    required this.padH,
    required this.padV,
    required this.fontSize,
    required this.onSelected,
  });

  final List<String> labels;
  final int? selectedIndex;
  final bool isDark;
  final double horizontalGap;
  final double verticalGap;
  final double padH;
  final double padV;
  final double fontSize;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final textScaler = MediaQuery.textScalerOf(context);
        final maxW = constraints.maxWidth;
        final rows = _packLabelRows(
          labels,
          maxW,
          horizontalGap,
          padH,
          fontSize,
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
                    return Wrap(
                      spacing: horizontalGap,
                      runSpacing: verticalGap,
                      children: [
                        for (final i in row) _chip(labels[i], i),
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var c = 0; c < row.length; c++) ...[
                        if (c > 0) SizedBox(width: horizontalGap),
                        Expanded(child: _chip(labels[row[c]], row[c])),
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

  Widget _chip(String label, int index) {
    return _BookPickerLabeledChip(
      label: label,
      isSelected: selectedIndex == index,
      isDark: isDark,
      padH: padH,
      padV: padV,
      fontSize: fontSize,
      onTap: () => onSelected(index),
    );
  }
}

/// Месяц — кнопки в строках, как выбор книг.
Future<int?> showCalendarMonthPickerDialog({
  required BuildContext context,
  int? selectedMonth,
}) {
  return showDialog<int>(
    context: context,
    builder: (dialogContext) {
      return Consumer<AppProvider>(
        builder: (ctx, app, _) {
          final uiFs = app.fontSize;
          final titleFs = AppProvider.panelTitleFontSize(uiFs);
          final chipFs = (uiFs * 0.75).clamp(11.0, 22.0);
          final gapSm = (uiFs * 0.5).clamp(6.0, 14.0);
          final wrapH = (uiFs * 0.5).clamp(6.0, 12.0);
          final wrapV = (uiFs * 0.25).clamp(3.0, 10.0);
          final padH = (uiFs * 0.5).clamp(6.0, 16.0);
          final padV = (uiFs * 0.25).clamp(3.0, 10.0);
          final mq = MediaQuery.of(dialogContext);
          final textScaler = MediaQuery.textScalerOf(dialogContext);
          final h = mq.size.height;
          final w = mq.size.width;
          final maxH = _pickerModalMaxHeight(
            dialogContext,
            screenHeight: h,
            verticalViewPadding: mq.viewPadding.vertical,
            chromeButtonSize: app.chromeButtonSize,
            minHeight: 200.0,
          );
          final dialogMaxW = (w - 16).clamp(280.0, 560.0);
          const padDialogH = 18.0;
          const padTop = 18.0;
          const padBottom = 16.0;
          final contentW = dialogMaxW - padDialogH * 2;
          final headingFg = _pickerHeadingFg(dialogContext);
          final isLight = !_pickerIsDark(dialogContext);
          final titleStyle = TextStyle(
            fontSize: titleFs,
            fontWeight: FontWeight.w600,
            color: headingFg,
            height: 1.2,
          );
          const titleText = 'Месяц';
          final titlePainter = TextPainter(
            text: TextSpan(text: titleText, style: titleStyle),
            textDirection: TextDirection.ltr,
            maxLines: 2,
            textScaler: textScaler,
          )..layout(maxWidth: contentW);
          final gridH = _labelChipGridHeight(
            labels: _calendarMonthNames,
            maxWidth: contentW,
            horizontalGap: wrapH,
            verticalGap: wrapV,
            padH: padH,
            padV: padV,
            fontSize: chipFs,
            textScaler: textScaler,
          );
          final headerH = padTop + titlePainter.height + gapSm;
          final bodyMaxH = (maxH - headerH - padBottom).clamp(80.0, maxH);
          const scrollContentBottomPad = 12.0;
          final needsScroll = gridH > bodyMaxH;
          final bodyH =
              needsScroll ? bodyMaxH : gridH + scrollContentBottomPad;
          final selectedIndex =
              selectedMonth == null ? null : selectedMonth - 1;

          return Dialog(
            backgroundColor: Colors.transparent,
            insetPadding: EdgeInsets.symmetric(
              horizontal: (uiFs * 0.5).clamp(6.0, 14.0),
              vertical: (uiFs * 0.375).clamp(4.0, 12.0),
            ),
            child: _pickerDialogShell(
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
                      Text(titleText, style: titleStyle),
                      SizedBox(height: gapSm),
                      SizedBox(
                        height: bodyH,
                        child: needsScroll
                            ? SingleChildScrollView(
                                physics: const ClampingScrollPhysics(),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                    bottom: scrollContentBottomPad,
                                  ),
                                  child: _LabelSelectionChipGrid(
                                    labels: _calendarMonthNames,
                                    selectedIndex: selectedIndex,
                                    isDark: !isLight,
                                    horizontalGap: wrapH,
                                    verticalGap: wrapV,
                                    padH: padH,
                                    padV: padV,
                                    fontSize: chipFs,
                                    onSelected: (i) =>
                                        Navigator.pop(dialogContext, i + 1),
                                  ),
                                ),
                              )
                            : Padding(
                                padding: const EdgeInsets.only(
                                  bottom: scrollContentBottomPad,
                                ),
                                child: _LabelSelectionChipGrid(
                                  labels: _calendarMonthNames,
                                  selectedIndex: selectedIndex,
                                  isDark: !isLight,
                                  horizontalGap: wrapH,
                                  verticalGap: wrapV,
                                  padH: padH,
                                  padV: padV,
                                  fontSize: chipFs,
                                  onSelected: (i) =>
                                      Navigator.pop(dialogContext, i + 1),
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
      );
    },
  );
}
