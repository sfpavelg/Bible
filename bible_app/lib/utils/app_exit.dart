import 'package:bible_app/utils/app_exit_io.dart'
    if (dart.library.html) 'package:bible_app/utils/app_exit_web.dart'
        as app_exit_impl;

void requestAppExit() => app_exit_impl.requestAppExit();
