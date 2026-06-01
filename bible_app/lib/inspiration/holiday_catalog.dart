import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:bible_app/inspiration/easter_date.dart';
import 'package:bible_app/inspiration/inspiration_models.dart';

/// Загрузка церковных праздников из assets (лениво).
class HolidayCatalog {
  HolidayCatalog._();
  static final HolidayCatalog instance = HolidayCatalog._();

  List<InspirationHolidayDefinition>? _orthodox;
  List<InspirationHolidayDefinition>? _protestant;

  Future<List<InspirationHolidayDefinition>> orthodoxHolidays() async {
    _orthodox ??= await _load('assets/inspiration/orthodox_holidays.json');
    return _orthodox!;
  }

  Future<List<InspirationHolidayDefinition>> protestantHolidays() async {
    _protestant ??= await _load('assets/inspiration/protestant_holidays.json');
    return _protestant!;
  }

  Future<List<InspirationHolidayDefinition>> _load(String path) async {
    final raw = await rootBundle.loadString(path);
    final decoded = jsonDecode(raw);
    if (decoded is! List) return [];
    final out = <InspirationHolidayDefinition>[];
    for (final item in decoded) {
      final h = _parseHoliday(item);
      if (h != null) out.add(h);
    }
    return out;
  }

  InspirationHolidayDefinition? _parseHoliday(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final tradition = raw['tradition'] as String? ?? 'orthodox';
    if (id is! String || name is! String) return null;

    int? fixedMonth;
    int? fixedDay;
    int? easterOffset;
    final dateRule = raw['dateRule'];
    if (dateRule is Map) {
      final type = dateRule['type'];
      if (type == 'fixed') {
        fixedMonth = (dateRule['month'] as num?)?.toInt();
        fixedDay = (dateRule['day'] as num?)?.toInt();
      } else if (type == 'easter') {
        easterOffset = (dateRule['offsetDays'] as num?)?.toInt() ?? 0;
      }
    }

    final refsRaw = raw['verseRefs'];
    final refs = <InspirationVerseRef>[];
    if (refsRaw is List) {
      for (final r in refsRaw) {
        final ref = InspirationVerseRef.fromJson(r);
        if (ref != null) refs.add(ref);
      }
    }
    if (refs.isEmpty) return null;

    return InspirationHolidayDefinition(
      id: id,
      name: name,
      tradition: tradition,
      fixedMonth: fixedMonth,
      fixedDay: fixedDay,
      easterOffsetDays: easterOffset,
      verseRefs: refs,
    );
  }

  /// Праздники на конкретную дату (месяц/день в локальном календаре).
  Future<List<InspirationHolidayDefinition>> holidaysOnDate(
    DateTime date, {
    required bool orthodox,
    required bool protestant,
  }) async {
    final year = date.year;
    final month = date.month;
    final day = date.day;
    final out = <InspirationHolidayDefinition>[];

    Future<void> scan(List<InspirationHolidayDefinition> list) async {
      for (final h in list) {
        if (_matchesDate(h, year, month, day)) out.add(h);
      }
    }

    if (orthodox) await scan(await orthodoxHolidays());
    if (protestant) await scan(await protestantHolidays());
    return out;
  }

  bool _matchesDate(
    InspirationHolidayDefinition h,
    int year,
    int month,
    int day,
  ) {
    if (h.isEasterBased) {
      final easter = easterSundayForTradition(year, h.tradition);
      final target = easter.add(Duration(days: h.easterOffsetDays!));
      return target.month == month && target.day == day;
    }
    return h.fixedMonth == month && h.fixedDay == day;
  }

  /// Список праздников на год для экрана просмотра.
  Future<List<({DateTime date, InspirationHolidayDefinition holiday})>>
      holidaysInYear(
    int year, {
    required bool orthodox,
    required bool protestant,
  }) async {
    final out = <({DateTime date, InspirationHolidayDefinition holiday})>[];
    final lists = <List<InspirationHolidayDefinition>>[];
    if (orthodox) lists.add(await orthodoxHolidays());
    if (protestant) lists.add(await protestantHolidays());

    for (final list in lists) {
      for (final h in list) {
        final date = _resolveDate(h, year);
        if (date != null) {
          out.add((date: date, holiday: h));
        }
      }
    }
    out.sort((a, b) {
      final c = a.date.month.compareTo(b.date.month);
      if (c != 0) return c;
      final d = a.date.day.compareTo(b.date.day);
      if (d != 0) return d;
      return a.holiday.name.compareTo(b.holiday.name);
    });
    return out;
  }

  DateTime? _resolveDate(InspirationHolidayDefinition h, int year) {
    if (h.isEasterBased) {
      final easter = easterSundayForTradition(year, h.tradition);
      return easter.add(Duration(days: h.easterOffsetDays!));
    }
    if (h.fixedMonth != null && h.fixedDay != null) {
      return DateTime(year, h.fixedMonth!, h.fixedDay!);
    }
    return null;
  }

  String traditionDisplayLabel(String tradition) {
    switch (tradition) {
      case 'protestant':
        return 'протестантский календарь';
      case 'orthodox':
      default:
        return 'православный календарь';
    }
  }
}
