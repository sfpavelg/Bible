import 'dart:convert';

import 'package:bible_app/inspiration/inspiration_engine.dart';
import 'package:bible_app/inspiration/inspiration_hash.dart';
import 'package:bible_app/inspiration/inspiration_models.dart';
import 'package:bible_app/inspiration/inspiration_repository.dart';
import 'package:bible_app/navigation/app_tab_switcher.dart';
import 'package:bible_app/services/bible_service.dart';
import 'package:bible_app/widgets/app_bottom_notice.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

const _channelId = 'inspiration_verse';
const _channelName = 'Стих для вдохновения';
const _scheduledIdsKey = 'inspiration_scheduled_notification_ids_v1';
const _planningHorizonDays = 14;
const _baseNotificationId = 900000;

/// Локальные напоминания плана «Стих для вдохновения».
class InspirationNotificationService {
  InspirationNotificationService._();
  static final InspirationNotificationService instance =
      InspirationNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  tz.Location? _localLocation;

  static int notificationIdForEvent(String eventId) {
    return _baseNotificationId + (inspirationHash32(eventId) % 49999);
  }

  Future<void> initialize() async {
    if (kIsWeb) return;
    if (_initialized) return;

    tz_data.initializeTimeZones();
    try {
      final tzInfo = await FlutterTimezone.getLocalTimezone();
      final name = tzInfo.identifier;
      _localLocation = tz.getLocation(name);
      tz.setLocalLocation(_localLocation!);
    } catch (_) {
      _localLocation = tz.UTC;
      tz.setLocalLocation(tz.UTC);
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    const init = InitializationSettings(android: android, iOS: ios);

    await _plugin.initialize(
      settings: init,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    _initialized = true;
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final map = jsonDecode(payload);
      if (map is! Map) return;
      final book = map['book'];
      final chapter = (map['chapter'] as num?)?.toInt();
      final verse = (map['verse'] as num?)?.toInt();
      if (book is! String || chapter == null || verse == null) return;
      appTabSwitchRequest.value = 0;
      bibleVerseJumpRequest.value = BibleVerseJumpRequest(
        book: book,
        chapter: chapter,
        verse: verse,
      );
    } catch (_) {}
  }

  Future<bool> notificationsEnabled() async {
    if (kIsWeb) return false;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.areNotificationsEnabled() ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final settings = await ios?.checkPermissions();
      return settings?.isEnabled ?? false;
    }
    return true;
  }

  /// Диалог из меню «⋯» на экране плана: проверка и запрос разрешения.
  Future<void> showPermissionCheckNotice(BuildContext context) async {
    if (kIsWeb) return;
    await initialize();
    if (!context.mounted) return;
    final enabled = await notificationsEnabled();
    if (!context.mounted) return;
    if (enabled) {
      showAppBottomNotice(
        context,
        'Уведомления для «Стих для вдохновения» уже разрешены в системе.',
      );
      return;
    }
    final granted = await requestNotificationPermission();
    if (!context.mounted) return;
    if (granted) {
      showAppBottomNotice(
        context,
        'Разрешение получено. Включите напоминания переключателем на экране плана.',
      );
      return;
    }
    showAppBottomNotice(
      context,
      'Разрешение не выдано. Откройте настройки Android → Приложения → Библия → Уведомления.',
    );
  }

  Future<bool> requestNotificationPermission() async {
    if (kIsWeb) return false;
    await initialize();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? false;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  Future<void> cancelAllScheduled() async {
    if (kIsWeb) return;
    await initialize();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_scheduledIdsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw);
        if (list is List) {
          for (final id in list) {
            final n = id is int ? id : (id as num?)?.toInt();
            if (n != null) await _plugin.cancel(id: n);
          }
        }
      } catch (_) {}
    }
    await prefs.remove(_scheduledIdsKey);
  }

  Future<void> rescheduleIfNeeded({
    required InspirationRepository repository,
    required InspirationEngine engine,
    required InspirationPlanSettings settings,
    required List<InspirationCustomDay> customDays,
    bool force = false,
  }) async {
    if (kIsWeb) return;
    if (!settings.remindersEnabled) {
      await cancelAllScheduled();
      return;
    }

    final todayIso = inspirationDateSeed(DateTime.now());
    if (!force && settings.lastRescheduleDateIso == todayIso) return;

    await initialize();
    await cancelAllScheduled();
    await BibleService().loadBibleData();

    final scheduledIds = <int>[];
    final now = DateTime.now();
    final hour = settings.notifyTimeMinutes ~/ 60;
    final minute = settings.notifyTimeMinutes % 60;

    for (var offset = 0; offset < _planningHorizonDays; offset++) {
      final day = DateTime(now.year, now.month, now.day + offset);
      final events = await engine.eventsForDate(day, settings, customDays);
      var eventIndex = 0;
      for (final event in events) {
        var scheduledTime = tz.TZDateTime(
          _localLocation ?? tz.local,
          day.year,
          day.month,
          day.day,
          hour,
          minute,
        ).add(Duration(seconds: eventIndex));
        eventIndex++;

        if (scheduledTime.isBefore(tz.TZDateTime.now(_localLocation ?? tz.local))) {
          continue;
        }

        final id = notificationIdForEvent(
          '${inspirationDateSeed(day)}|${event.eventId}',
        );
        final title = engine.notificationTitle(event);
        final body = engine.notificationBody(event);
        final payload = jsonEncode({
          'book': event.verseRef.book,
          'chapter': event.verseRef.chapter,
          'verse': event.verseRef.verse,
        });

        final androidDetails = AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Ежедневный стих для размышления',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
          styleInformation: BigTextStyleInformation(
            body,
            contentTitle: title,
          ),
        );
        const iosDetails = DarwinNotificationDetails();

        await _plugin.zonedSchedule(
          id: id,
          title: title,
          body: body,
          scheduledDate: scheduledTime,
          notificationDetails: NotificationDetails(
            android: androidDetails,
            iOS: iosDetails,
          ),
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
          payload: payload,
        );
        scheduledIds.add(id);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_scheduledIdsKey, jsonEncode(scheduledIds));
    await repository.saveSettings(
      settings.copyWith(lastRescheduleDateIso: todayIso),
    );
  }
}
