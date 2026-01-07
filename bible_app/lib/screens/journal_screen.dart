import 'package:flutter/material.dart';

class JournalScreen extends StatelessWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Журнал'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () {
              // TODO: Показать календарь прочтения
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Раздел Журнала - в разработке'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Добавить запись в журнал
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}