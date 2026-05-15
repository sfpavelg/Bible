import 'dart:async';

import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/theme/bible_dark_palette.dart';
import 'package:flutter/material.dart';
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

class NotebookEditorPanelState extends State<NotebookEditorPanel> {
  late final TextEditingController _controller;
  late UndoHistoryController _undoHistoryController;
  Timer? _debounce;
  bool _dirty = false;
  bool _loading = true;
  final FocusNode _focus = FocusNode();

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
    _load();
    _controller.addListener(_onTextChanged);
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
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(flushSave());
    _controller.dispose();
    _undoHistoryController.dispose();
    _focus.dispose();
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
    return Padding(
      padding: const EdgeInsets.all(12),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        undoController: _undoHistoryController,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        keyboardType: TextInputType.multiline,
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
