import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:bible_app/notebook/notebook_mail_history.dart';
import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class NotebookEditorScreen extends StatefulWidget {
  const NotebookEditorScreen({
    super.key,
    required this.repo,
    required this.relativePath,
  });

  final NotebookRepository repo;
  final String relativePath;

  @override
  State<NotebookEditorScreen> createState() => _NotebookEditorScreenState();
}

class _NotebookEditorScreenState extends State<NotebookEditorScreen> {
  late final TextEditingController _controller;
  Timer? _debounce;
  bool _dirty = false;
  bool _loading = true;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _load();
    _controller.addListener(_onTextChanged);
  }

  Future<void> _load() async {
    try {
      final text = await widget.repo.readFile(widget.relativePath);
      if (!mounted) return;
      _controller.text = text;
      setState(() {
        _loading = false;
        _dirty = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showError('Не удалось открыть файл: $e');
    }
  }

  void _onTextChanged() {
    if (!_dirty) setState(() => _dirty = true);
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 600), _saveQuiet);
  }

  Future<void> _saveQuiet() async {
    if (!_dirty) return;
    try {
      await widget.repo.writeFile(widget.relativePath, _controller.text);
      if (mounted) setState(() => _dirty = false);
    } catch (e) {
      if (mounted) _showError('Ошибка сохранения: $e');
    }
  }

  Future<void> _saveNow() async {
    _debounce?.cancel();
    try {
      await widget.repo.writeFile(widget.relativePath, _controller.text);
      if (mounted) {
        setState(() => _dirty = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сохранено')),
        );
      }
    } catch (e) {
      _showError('Ошибка сохранения: $e');
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String get _title => p.basename(widget.relativePath);

  Future<void> _share() async {
    await _saveQuiet();
    final text = _controller.text;
    if (widget.repo.isFileSystemBacked) {
      final path = await widget.repo.nativeFilePath(widget.relativePath);
      if (path != null && File(path).existsSync()) {
        await Share.shareXFiles(
          [XFile(path, mimeType: 'text/plain', name: _title)],
          text: _title,
        );
        return;
      }
    }
    await Share.share(text, subject: _title);
  }

  Future<void> _exportCopy() async {
    await _saveQuiet();
    final text = _controller.text;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Текст скопирован в буфер')),
    );
  }

  Future<void> _exportToDisk() async {
    if (kIsWeb) {
      await _share();
      return;
    }
    await _saveQuiet();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Сохранить документ',
      fileName: _title.toLowerCase().endsWith('.txt') ? _title : '$_title.txt',
      type: FileType.any,
    );
    if (path == null) return;
    try {
      final file = File(path);
      await file.writeAsString(_controller.text, encoding: utf8, flush: true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Файл записан: $path')),
        );
      }
    } catch (e) {
      _showError('Не удалось записать файл: $e');
    }
  }

  Future<void> _sendMail() async {
    await _saveQuiet();
    if (!mounted) return;
    final history = await NotebookMailHistory.load();
    if (!mounted) return;
    final emailCtrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Отправить на почту'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (history.isNotEmpty) ...[
                  const Text('Недавние адреса'),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: history
                        .map(
                          (e) => ActionChip(
                            label: Text(
                              e,
                              overflow: TextOverflow.ellipsis,
                            ),
                            onPressed: () => emailCtrl.text = e,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                ],
                const Text('Адрес получателя'),
                const SizedBox(height: 8),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    hintText: 'email@example.com',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty) return;
                await NotebookMailHistory.remember(email);
                if (!context.mounted) return;
                Navigator.pop(ctx);
                await _openMailto(email);
              },
              child: const Text('Открыть почту'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _openMailto(String email) async {
    final subject = Uri.encodeComponent(_title);
    final body = Uri.encodeComponent(_controller.text);
    final uri = Uri.parse('mailto:$email?subject=$subject&body=$body');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        _showError('Не удалось открыть почтовый клиент');
      }
    } catch (e) {
      if (mounted) _showError('Ошибка: $e');
    }
  }

  Future<void> _deleteDoc() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить документ?'),
        content: Text('«$_title» будет удалён без восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await widget.repo.delete(widget.relativePath);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      _showError('Не удалось удалить: $e');
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    unawaited(_saveQuiet());
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          if (_dirty)
            const Padding(
              padding: EdgeInsets.only(right: 8, top: 14),
              child: Text(
                '…',
                style: TextStyle(fontSize: 18, color: Colors.orange),
              ),
            ),
          IconButton(
            tooltip: 'Сохранить',
            icon: const Icon(Icons.save_outlined),
            onPressed: _saveNow,
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'share':
                  await _share();
                case 'export':
                  await _exportToDisk();
                case 'copy':
                  await _exportCopy();
                case 'mail':
                  await _sendMail();
                case 'del':
                  await _deleteDoc();
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'share', child: Text('Поделиться…')),
              PopupMenuItem(value: 'export', child: Text('Сохранить в файл…')),
              PopupMenuItem(value: 'copy', child: Text('Копировать весь текст')),
              PopupMenuItem(value: 'mail', child: Text('Отправить на почту…')),
              PopupMenuDivider(),
              PopupMenuItem(
                value: 'del',
                child: Text('Удалить документ'),
              ),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                keyboardType: TextInputType.multiline,
                style: const TextStyle(fontSize: 16, height: 1.35),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText:
                      'Пишите здесь. Текст из Библии — скопируйте и вставьте.',
                ),
              ),
            ),
    );
  }
}
