import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

const _key = 'notebook_email_history';
const _max = 12;

class NotebookMailHistory {
  static Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => e.toString()).where((e) => e.isNotEmpty).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> remember(String email) async {
    final trimmed = email.trim();
    if (trimmed.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final current = await load();
    final next = <String>[trimmed, ...current.where((e) => e != trimmed)]
        .take(_max)
        .toList();
    await prefs.setString(_key, jsonEncode(next));
  }
}
