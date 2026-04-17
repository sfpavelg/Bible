import 'package:flutter/foundation.dart';

/// Глобальный запрос на переключение вкладки в [MainScreen]:
/// 0 — Библия, 1 — Блокнот, 2 — План.
final ValueNotifier<int?> appTabSwitchRequest = ValueNotifier<int?>(null);

