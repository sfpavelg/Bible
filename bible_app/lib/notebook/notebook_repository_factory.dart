import 'package:bible_app/notebook/notebook_repository.dart';
import 'package:bible_app/notebook/notebook_repository_io.dart'
    if (dart.library.html) 'package:bible_app/notebook/notebook_repository_web.dart'
        as notebook_repo_impl;

Future<NotebookRepository> createNotebookRepository() =>
    notebook_repo_impl.openNotebookRepository();
