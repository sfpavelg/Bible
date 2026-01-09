import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:bible_app/providers/app_provider.dart';
import 'package:bible_app/services/bible_service.dart';

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
        backgroundColor: Colors.lightBlue[100], // Светло-голубой фон
        title: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth > 400;
            return Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Кнопка перехода к предыдущей главе
                Container(
                  decoration: BoxDecoration(
                    color: Colors.lightBlue[50], // Такой же фон как у кнопок книг
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36, // Уменьшенный диаметр
                    minHeight: 36, // Уменьшенный диаметр
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    iconSize: isWide ? 18 : 16, // Уменьшенный размер иконок
                    padding: const EdgeInsets.all(4), // Уменьшенные отступы
                    onPressed: () {
                      if (appProvider.currentChapter > 1) {
                        appProvider.changeBookAndChapter(
                          appProvider.currentBook,
                          appProvider.currentChapter - 1,
                        );
                      }
                    },
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // Кнопка названия книги
                Container(
                  decoration: BoxDecoration(
                    color: Colors.lightBlue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 36,
                  ),
                  child: TextButton(
                    onPressed: () {
                      _showBookSelectionDialog(context);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 8 : 4, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      BibleService().getBookAbbreviation(appProvider.currentBook),
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isWide ? 14 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // Кнопка номера главы
                Container(
                  decoration: BoxDecoration(
                    color: Colors.lightBlue[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36, // Фиксированная ширина для 2 символов
                    minHeight: 36,
                  ),
                  child: TextButton(
                    onPressed: () {
                      _showChapterSelectionDialog(context);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: isWide ? 8 : 4, vertical: 6),
                      minimumSize: Size.zero,
                    ),
                    child: Text(
                      '${appProvider.currentChapter}',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: isWide ? 14 : 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(width: 4),
                
                // Кнопка перехода к следующей главе
                Container(
                  decoration: BoxDecoration(
                    color: Colors.lightBlue[50], // Такой же фон как у кнопок книг
                    shape: BoxShape.circle,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 36, // Уменьшенный диаметр
                    minHeight: 36, // Уменьшенный диаметр
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_forward, color: Colors.black),
                    iconSize: isWide ? 18 : 16, // Уменьшенный размер иконок
                    padding: const EdgeInsets.all(4), // Уменьшенные отступы
                    onPressed: () {
                      final chapterCount = BibleService().getChapterCount(appProvider.currentBook);
                      if (appProvider.currentChapter < chapterCount) {
                        appProvider.changeBookAndChapter(
                          appProvider.currentBook,
                          appProvider.currentChapter + 1,
                        );
                      }
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
              color: Colors.lightBlue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.search, color: Colors.black),
              iconSize: 24,
              onPressed: () {
                _showSearchDialog(context);
              },
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.lightBlue[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, color: Colors.black),
              onSelected: (value) {
                if (value == 'settings') {
                  // TODO: Перейти к настройкам
                }
              },
              itemBuilder: (BuildContext context) => [
                const PopupMenuItem<String>(
                  value: 'settings',
                  child: Text('Настройки'),
                ),
              ],
            ),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragEnd: (details) {
          // Перелистывание пальцем влево/вправо
          if (details.primaryVelocity! > 0) {
            // Свайп вправо - предыдущая глава
            if (appProvider.currentChapter > 1) {
              appProvider.changeBookAndChapter(
                appProvider.currentBook,
                appProvider.currentChapter - 1,
              );
            }
          } else if (details.primaryVelocity! < 0) {
            // Свайп влево - следующая глава
            final chapterCount = BibleService().getChapterCount(appProvider.currentBook);
            if (appProvider.currentChapter < chapterCount) {
              appProvider.changeBookAndChapter(
                appProvider.currentBook,
                appProvider.currentChapter + 1,
              );
            }
          }
        },
        child: appProvider.isLoading
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
                      
                      return Container(
                        color: Colors.white, // Белый фон для текста стихов
                        child: ListTile(
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
                        ),
                      );
                    },
                  ),
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

  void _showChapterSelectionDialog(BuildContext context) {
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    
    // Получаем реальное количество глав для текущей книги
    final chapterCount = BibleService().getChapterCount(appProvider.currentBook);
    
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Выберите главу (${appProvider.currentBook})'),
          content: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 400,
              maxHeight: 300, // Ограничиваем высоту
            ),
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 4,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: List.generate(chapterCount, (index) {
                  final chapterNumber = index + 1;
                  final isCurrentChapter = chapterNumber == appProvider.currentChapter;
                  
                  return SizedBox(
                    width: 40,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: () {
                        appProvider.changeBookAndChapter(
                          appProvider.currentBook,
                          chapterNumber,
                        );
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        backgroundColor: isCurrentChapter 
                            ? Colors.blue // Синий фон для текущей главы
                            : Colors.lightBlue[50], // Светло-голубой для остальных
                        foregroundColor: isCurrentChapter 
                            ? Colors.white // Белый текст для текущей главы
                            : Colors.black, // Черный текст для остальных
                      ),
                      child: Text(
                        '$chapterNumber',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isCurrentChapter ? FontWeight.bold : FontWeight.normal,
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
      builder: (context) {
        return AlertDialog(
          title: const Text('Выберите книгу'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Ветхий Завет
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
                        appProvider.changeBookAndChapter(book, 1);
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: isCurrentBook 
                            ? Colors.blue // Синий фон для текущей книги
                            : Colors.lightBlue[50], // Светло-голубой для остальных
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        BibleService().getBookAbbreviation(book),
                        style: TextStyle(
                          color: isCurrentBook ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: isCurrentBook ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),
                
                // Новый Завет
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
                        appProvider.changeBookAndChapter(book, 1);
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(
                        backgroundColor: isCurrentBook 
                            ? Colors.blue // Синий фон для текущей книги
                            : Colors.lightBlue[50], // Светло-голубой для остальных
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        BibleService().getBookAbbreviation(book),
                        style: TextStyle(
                          color: isCurrentBook ? Colors.white : Colors.black,
                          fontSize: 12,
                          fontWeight: isCurrentBook ? FontWeight.bold : FontWeight.normal,
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