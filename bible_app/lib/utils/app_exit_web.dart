import 'package:flutter/services.dart';

/// В браузере приложение не может принудительно закрыть вкладку.
void requestAppExit() {
  SystemNavigator.pop();
}
