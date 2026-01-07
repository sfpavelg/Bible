import 'package:flutter/material.dart';

class NotebookScreen extends StatelessWidget {
  const NotebookScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Блокнот'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              // TODO: Создать новую заметку
            },
          ),
        ],
      ),
      body: const Center(
        child: Text('Раздел Блокнота - в разработке'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Добавить новую заметку
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}