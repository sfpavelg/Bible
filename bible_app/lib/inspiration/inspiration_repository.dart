import 'dart:convert';

import 'package:bible_app/inspiration/inspiration_hash.dart';
import 'package:bible_app/inspiration/inspiration_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InspirationRepository {
  InspirationRepository(this._prefs);

  static const _settingsKey = 'inspiration_plan_settings_v1';
  static const _customDaysKey = 'inspiration_custom_days_v1';
  static const _deviceSeedKey = 'inspiration_device_seed_v1';

  final SharedPreferences _prefs;

  InspirationPlanSettings loadSettings() {
    final raw = _prefs.getString(_settingsKey);
    if (raw == null || raw.isEmpty) {
      return const InspirationPlanSettings();
    }
    try {
      final json = jsonDecode(raw);
      if (json is Map<String, dynamic>) {
        return InspirationPlanSettings.fromJson(json);
      }
    } catch (_) {}
    return const InspirationPlanSettings();
  }

  Future<void> saveSettings(InspirationPlanSettings settings) async {
    await _prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
  }

  List<InspirationCustomDay> loadCustomDays() {
    final raw = _prefs.getString(_customDaysKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final json = jsonDecode(raw);
      if (json is! List) return [];
      final out = <InspirationCustomDay>[];
      for (final item in json) {
        final day = InspirationCustomDay.fromJson(item);
        if (day != null) out.add(day);
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> saveCustomDays(List<InspirationCustomDay> days) async {
    await _prefs.setString(
      _customDaysKey,
      jsonEncode(days.map((e) => e.toJson()).toList()),
    );
  }

  /// Соль устройства: у разных пользователей в один день разные «случайные» стихи.
  Future<String> getOrCreateDeviceSeed() async {
    var seed = _prefs.getString(_deviceSeedKey);
    if (seed != null && seed.isNotEmpty) return seed;
    seed =
        '${DateTime.now().microsecondsSinceEpoch}_${inspirationHash32(DateTime.now().toIso8601String())}';
    await _prefs.setString(_deviceSeedKey, seed);
    return seed;
  }
}
