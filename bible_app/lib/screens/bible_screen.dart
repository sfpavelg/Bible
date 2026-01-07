import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/providers/app_provider.dart';

class BibleScreen extends StatefulWidget {
  const BibleScreen({super.key});

  @override
  State<BibleScreen> createState() => _BibleScreenState();
}

class _BibleScreenState extends State<BibleScreen> {
  @override
  Widget build(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context);
    final verses = appProvider.getCurrentVerses();

    return Scaffold(
      appBar: AppBar(
        title: Text('${appProvider.currentBook} ${appProvider.currentChapter}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog(context);
            },
          ),
          IconButton(
            icon: const Icon(Icons.bookmark),
            onPressed: () {
              // TODO: Добавить закладку
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'settings') {
                // TODO: Перейти к настройкам
              } else if (value == 'change_book') {
                _showBookSelectionDialog(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'change_book',
                child: Text('Выбрать книгу'),
              ),
              const PopupMenuItem<String>(
                value: 'settings',
                child: Text('Настройки'),
              ),
            ],
          ),
        ],
      ),
      body: appProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : verses.isEmpty
              ? const Center(child: Text('Глава не найдена'))
              : ListView.builder(
                  itemCount: verses.length,
                  itemBuilder: (context, index) {
                    final verse = verses[index];
                    final verseText = '${verse['verse']}. ${verse['text']}';
                    
                    // Определяем цвет текста в зависимости от типа контента
                    Color textColor = Colors.black;
                    if (verse['type'] == 'speech') {
                      textColor = Colors.red; // Красный для слов Иисуса и Бога
                    }
                    
                    return ListTile(
                      title: Text(
                        verseText,
                        style: TextStyle(
                          fontSize: appProvider.fontSize,
                          color: textColor,
                          fontWeight: verse['type'] == 'speech' ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      onTap: () {
                        // TODO: Показать действия со стихом
                      },
                    );
                  },
                ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            mini: true,
            onPressed: () {
              if (appProvider.currentChapter > 1) {
                appProvider.changeBookAndChapter(
                  appProvider.currentBook,
                  appProvider.currentChapter - 1,
                );
              }
            },
            child: const Icon(Icons.arrow_back),
          ),
          const SizedBox(height: 8),
          FloatingActionButton(
            mini: true,
            onPressed: () {
              final chapterCount = appProvider.currentBook == 'Бытие' ? 50 : 40; // TODO: Заменить на реальное количество глав
              if (appProvider.currentChapter < chapterCount) {
                appProvider.changeBookAndChapter(
                  appProvider.currentBook,
                  appProvider.currentChapter + 1,
                );
              }
            },
            child: const Icon(Icons.arrow_forward),
          ),
        ],
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        final searchController = TextEditingController();
        return AlertDialog(
          title: const Text('Поиск по Библии'),
          content: TextField(
            controller: searchController,
            decoration: const InputDecoration(hintText: 'Введите текст для поиска'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            TextButton(
              onPressed: () {
                final query = searchController.text;
                if (query.isNotEmpty) {
                  // TODO: Реализовать поиск и отображение результатов
                  Navigator.pop(context);
                }
              },
              child: const Text('Найти'),
            ),
          ],
        );
      },
    );
  }

  void _showBookSelectionDialog(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Выберите книгу'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: appProvider.getBooks('old').length + appProvider.getBooks('new').length,
              itemBuilder: (context, index) {
                final oldTestamentBooks = appProvider.getBooks('old');
                if (index < oldTestamentBooks.length) {
                  final book = oldTestamentBooks[index];
                  return ListTile(
                    title: Text(book),
                    onTap: () {
                      appProvider.changeBookAndChapter(book, 1);
                      Navigator.pop(context);
                    },
                  );
                } else {
                  final newIndex = index - oldTestamentBooks.length;
                  final book = appProvider.getBooks('new')[newIndex];
                  return ListTile(
                    title: Text(book),
                    onTap: () {
                      appProvider.changeBookAndChapter(book, 1);
                      Navigator.pop(context);
                    },
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }
}