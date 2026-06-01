import 'package:bible_app/inspiration/holiday_catalog.dart';
import 'package:bible_app/inspiration/inspiration_hash.dart';
import 'package:bible_app/inspiration/inspiration_models.dart';
import 'package:bible_app/services/bible_service.dart';

/// События дня и тексты уведомлений.
class InspirationEngine {
  InspirationEngine({
    BibleService? bible,
    HolidayCatalog? catalog,
  })  : _bible = bible ?? BibleService(),
        _catalog = catalog ?? HolidayCatalog.instance;

  final BibleService _bible;
  final HolidayCatalog _catalog;

  Future<List<InspirationDayEvent>> eventsForDate(
    DateTime date,
    InspirationPlanSettings settings,
    List<InspirationCustomDay> customDays,
  ) async {
    final local = DateTime(date.year, date.month, date.day);
    final out = <InspirationDayEvent>[];

    final holidays = await _catalog.holidaysOnDate(
      local,
      orthodox: settings.useOrthodoxCalendar,
      protestant: settings.useProtestantCalendar,
    );
    final hasChurchHolidayOnDate = holidays.isNotEmpty;

    for (final h in holidays) {
      final ref = _pickFromList(
        h.verseRefs,
        '${inspirationDateSeed(local)}|${h.id}',
      );
      if (ref == null) continue;
      out.add(
        InspirationDayEvent(
          kind: InspirationEventKind.churchHoliday,
          eventId: 'holiday_${h.tradition}_${h.id}',
          displayName: h.name,
          verseRef: ref,
          traditionLabel: _catalog.traditionDisplayLabel(h.tradition),
        ),
      );
    }

    for (final d in customDays) {
      if (!d.enabled) continue;
      if (d.month != local.month || d.day != local.day) continue;
      final InspirationVerseRef? ref;
      if (d.useRandomVerse) {
        ref = _pickDailyRandom(
          local,
          seedSuffix: 'custom_random_${d.id}',
        );
      } else {
        if (d.verseRefs.isEmpty) continue;
        ref = d.verseRefs.first;
      }
      if (ref == null) continue;
      out.add(
        InspirationDayEvent(
          kind: InspirationEventKind.customDay,
          eventId: 'custom_${d.id}',
          displayName: d.name,
          verseRef: ref,
        ),
      );
    }

    // На церковный праздник — только стихи из списка праздника (и особые дни);
    // общий «стих дня» по всей Библии не выбирается.
    if (!hasChurchHolidayOnDate && out.isEmpty) {
      final ref = _pickDailyRandom(local);
      if (ref != null) {
        out.add(
          InspirationDayEvent(
            kind: InspirationEventKind.dailyRandom,
            eventId: 'daily_random',
            displayName: '',
            verseRef: ref,
          ),
        );
      }
    }

    return out;
  }

  InspirationVerseRef? _pickFromList(
    List<InspirationVerseRef> refs,
    String seed,
  ) {
    if (refs.isEmpty) return null;
    final i = inspirationPickIndex(seed, refs.length);
    return refs[i];
  }

  InspirationVerseRef? _pickDailyRandom(
    DateTime date, {
    String? seedSuffix,
  }) {
    final n = _bible.totalVerseCount;
    if (n <= 0) return null;
    final seed = seedSuffix == null
        ? inspirationDateSeed(date)
        : '${inspirationDateSeed(date)}|$seedSuffix';
    final i = inspirationPickIndex(seed, n);
    final p = _bible.verseAtGlobalIndex(i);
    if (p == null) return null;
    return InspirationVerseRef(
      book: p.book,
      chapter: p.chapter,
      verse: p.verse,
    );
  }

  String formatReference(InspirationVerseRef ref) {
    final abbr = _bible.getBookAbbreviation(ref.book);
    return '$abbr ${ref.chapter}:${ref.verse}';
  }

  String notificationBody(InspirationDayEvent event) {
    final ref = formatReference(event.verseRef);
    if (event.kind == InspirationEventKind.dailyRandom) {
      return '$ref — откройте для размышления';
    }
    return '$ref — откройте для размышления, сегодня ${event.displayName}!';
  }

  /// Праздники на дату для предупреждения при создании личного дня.
  Future<List<InspirationHolidayDefinition>> churchHolidaysOnMonthDay(
    int month,
    int day, {
    required bool orthodox,
    required bool protestant,
  }) async {
    final year = DateTime.now().year;
    DateTime probe;
    try {
      probe = DateTime(year, month, day);
    } catch (_) {
      probe = DateTime(year + 1, month, day);
    }
    return _catalog.holidaysOnDate(
      probe,
      orthodox: orthodox,
      protestant: protestant,
    );
  }
}
