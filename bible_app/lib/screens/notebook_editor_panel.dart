import 'dart:async';
import 'dart:math' as math;

import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';

/// Редактор заметки без собственного [Scaffold] — внутри вкладки «Блокнот».
class NotebookEditorPanel extends StatefulWidget {
  const NotebookEditorPanel({
    super.key,
    required this.repo,
    required this.relativePath,
    this.onDirtyChanged,
    this.onDocumentDeleted,
  });

  final NotebookRepository repo;
  final String relativePath;
  final ValueChanged<bool>? onDirtyChanged;
  final VoidCallback? onDocumentDeleted;

  @override
  NotebookEditorPanelState createState() => NotebookEditorPanelState();
}

class NotebookEditorPanelState extends State<NotebookEditorPanel>
    with WidgetsBindingObserver {
  late final TextEditingController _controller;
  late UndoHistoryController _undoHistoryController;
  Timer? _debounce;
  bool _dirty = false;
  bool _loading = true;
  final FocusNode _focus = FocusNode();
  final GlobalKey _textFieldKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();
  double _lastViewInsetBottom = 0;
  int _revealCursorFramesLeft = 0;

  bool get isDirty => _dirty;

  /// Для кнопок «назад / вперёд» в шапке блокнота ([ListenableBuilder]).
  UndoHistoryController get undoHistoryController => _undoHistoryController;

  void _resetUndoHistory() {
    _undoHistoryController.dispose();
    _undoHistoryController = UndoHistoryController();
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _undoHistoryController = UndoHistoryController();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _controller.addListener(_onTextChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _lastViewInsetBottom = MediaQuery.viewInsetsOf(context).bottom;
    });
  }

  @override
  void didChangeMetrics() {
    if (!mounted) return;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final keyboardOpened = bottom > _lastViewInsetBottom;
    if (bottom != _lastViewInsetBottom) {
      setState(() {});
    }
    if (keyboardOpened && _focus.hasFocus) {
      _nudgeSelectionForScroll();
      _revealCursor();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revealCursor();
      });
    }
    _lastViewInsetBottom = bottom;
  }

  void _nudgeSelectionForScroll() {
    final sel = _controller.selection;
    if (!sel.isValid) return;
    _controller.value = _controller.value.copyWith(selection: sel);
  }

  RenderEditable? _findRenderEditable(RenderObject? root) {
    RenderEditable? found;
    void visit(RenderObject node) {
      if (found != null) return;
      if (node is RenderEditable) {
        found = node;
        return;
      }
      node.visitChildren(visit);
    }
    if (root != null) visit(root);
    return found;
  }

  EditableTextState? _findEditableTextState() {
    EditableTextState? found;
    void visit(Element element) {
      if (found != null) return;
      if (element is StatefulElement && element.state is EditableTextState) {
        found = element.state as EditableTextState;
        return;
      }
      element.visitChildren(visit);
    }
    final root = _textFieldKey.currentContext;
    if (root is Element) visit(root);
    return found;
  }

  /// Как [EditableText._getOffsetToRevealCaret], с опциональным запасом под курсор.
  double _offsetToRevealCaret(
    RenderEditable renderEditable,
    ScrollPosition position,
    Rect caretRect, {
    double extraBelow = 0,
  }) {
    final lineHeight = renderEditable.preferredLineHeight;
    final expandedRect = Rect.fromLTWH(
      caretRect.left,
      caretRect.top,
      caretRect.width,
      math.max(caretRect.height, lineHeight) + extraBelow,
    );

    final editableSize = renderEditable.size;
    final double additionalOffset;
    if (expandedRect.height >= editableSize.height) {
      additionalOffset = editableSize.height / 2 - expandedRect.center.dy;
    } else {
      additionalOffset = clampDouble(
        0.0,
        expandedRect.bottom - editableSize.height,
        expandedRect.top,
      );
    }

    return (additionalOffset + position.pixels).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
  }

  void _bringCursorIntoView({bool afterInsert = false}) {
    if (!mounted) return;

    final textLen = _controller.text.length;
    final cursorOffset =
        _controller.selection.extentOffset.clamp(0, textLen);
    final cursorPosition = TextPosition(offset: cursorOffset);

    final editableText = _findEditableTextState();
    if (editableText != null && !afterInsert) {
      editableText.bringIntoView(cursorPosition);
      return;
    }

    if (!_scrollController.hasClients) return;
    final renderEditable = _findRenderEditable(
      _textFieldKey.currentContext?.findRenderObject(),
    );
    if (renderEditable == null) return;

    final position = _scrollController.position;
    if (!position.hasContentDimensions) return;

    final caretRect =
        renderEditable.getLocalRectForCaret(cursorPosition);
    final lineHeight = renderEditable.preferredLineHeight;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    // После вставки курсор в конце текста — добавляем строку запаса снизу,
    // как если бы пользователь нажал Enter (Flutter сам так прокручивает).
    final extraBelow = afterInsert ? lineHeight : 0.0;

    final target = _offsetToRevealCaret(
      renderEditable,
      position,
      caretRect,
      extraBelow: extraBelow,
    );

    if ((position.pixels - target).abs() > 0.5) {
      _scrollController.jumpTo(target);
    }

    final bottomPad = keyboardInset + 48 + (afterInsert ? lineHeight : 0);
    renderEditable.showOnScreen(
      rect: EdgeInsets.fromLTRB(24, 24, 24, bottomPad)
          .inflateRect(caretRect),
    );
  }

  void _revealCursor() {
    _bringCursorIntoView();
  }

  void _scheduleRevealCursorAfterInsert() {
    _revealCursorFramesLeft = 24;
    _revealCursorTick();
  }

  void _revealCursorTick() {
    if (!mounted || _revealCursorFramesLeft <= 0) return;
    _revealCursorFramesLeft--;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bringCursorIntoView(afterInsert: true);
      _revealCursorTick();
    });
  }

  @override
  void didUpdateWidget(NotebookEditorPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.relativePath != widget.relativePath) {
      _debounce?.cancel();
      _resetUndoHistory();
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _dirty = false;
    });
    widget.onDirtyChanged?.call(false);
    try {
      final text = await widget.repo.readFile(widget.relativePath);
      if (!mounted) return;
      _controller.text = text;
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Не удалось открыть файл: $e');
    }
  }

  void _onTextChanged() {
    if (!_dirty) {
      setState(() => _dirty = true);
      widget.onDirtyChanged?.call(true);
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _saveQuiet);
  }

  Future<void> _saveQuiet() async {
    if (!_dirty) return;
    try {
      await widget.repo.writeFile(widget.relativePath, _controller.text);
      if (mounted) {
        setState(() => _dirty = false);
        widget.onDirtyChanged?.call(false);
      }
    } catch (e) {
      if (mounted) _showError('Ошибка сохранения: $e');
    }
  }

  /// Сохранить перед закрытием редактора или сменой вкладки.
  Future<void> flushSave() async {
    _debounce?.cancel();
    if (!_dirty) return;
    try {
      await widget.repo.writeFile(widget.relativePath, _controller.text);
      if (mounted) {
        setState(() => _dirty = false);
        widget.onDirtyChanged?.call(false);
      }
    } catch (e) {
      if (mounted) _showError('Ошибка сохранения: $e');
    }
  }

  /// Вставляет [text] в текущую позицию курсора (или вместо выделения).
  void insertTextAtCursor(String text) {
    if (text.isEmpty) return;
    final value = _controller.value;
    final selection = value.selection;
    final hasValidSelection =
        selection.start >= 0 &&
        selection.end >= 0 &&
        selection.start <= value.text.length &&
        selection.end <= value.text.length;
    final start = hasValidSelection ? selection.start : value.text.length;
    final end = hasValidSelection ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, text);
    final cursor = start + text.length;
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
    _focus.requestFocus();
    _scheduleRevealCursorAfterInsert();
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    unawaited(flushSave());
    _controller.dispose();
    _undoHistoryController.dispose();
    _focus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final app = context.watch<AppProvider>();
    final fs = app.fontSize;
    final lh = app.lineHeight;
    final hintColor = Theme.of(context).hintColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor =
        isDark ? BibleDarkPalette.primaryText : null;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        key: _textFieldKey,
        controller: _controller,
        focusNode: _focus,
        scrollController: _scrollController,
        undoController: _undoHistoryController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
        scrollPadding: EdgeInsets.fromLTRB(24, 24, 24, keyboardInset + 48),
        style: TextStyle(
          fontSize: fs,
          height: lh,
          color: textColor,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          hintText:
              'Пишите здесь. Переключайтесь на Библию и вставляйте текст.',
          hintStyle: TextStyle(
            fontSize: fs,
            height: lh,
            color: hintColor,
          ),
        ),
      ),
    );
  }
}
