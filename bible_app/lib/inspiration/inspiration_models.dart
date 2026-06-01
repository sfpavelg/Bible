/// Модели плана «Стих для вдохновения».

/// Значение из выбора книги «Случайный» (особый день — стих из всей Библии).
const inspirationRandomBookPickerValue = '__inspiration_random__';

class InspirationVerseRef {
  const InspirationVerseRef({
    required this.book,
    required this.chapter,
    required this.verse,
  });

  final String book;
  final int chapter;
  final int verse;

  Map<String, dynamic> toJson() => {
        'book': book,
        'chapter': chapter,
        'verse': verse,
      };

  static InspirationVerseRef? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final book = raw['book'];
    final chapter = raw['chapter'];
    final verse = raw['verse'];
    if (book is! String || book.isEmpty) return null;
    final ch = chapter is int ? chapter : (chapter as num?)?.toInt();
    final v = verse is int ? verse : (verse as num?)?.toInt();
    if (ch == null || ch < 1 || v == null || v < 1) return null;
    return InspirationVerseRef(book: book, chapter: ch, verse: v);
  }
}

/// Результат выбора стиха для особого дня.
class InspirationCustomDayVerseChoice {
  const InspirationCustomDayVerseChoice.specific(this.ref)
      : random = false;

  const InspirationCustomDayVerseChoice.random()
      : ref = null,
        random = true;

  final InspirationVerseRef? ref;
  final bool random;
}

class InspirationPlanSettings {
  const InspirationPlanSettings({
    this.remindersEnabled = false,
    this.notifyTimeMinutes = 420,
    this.useOrthodoxCalendar = false,
    this.useProtestantCalendar = false,
    this.lastRescheduleDateIso,
  });

  final bool remindersEnabled;
  final int notifyTimeMinutes;
  final bool useOrthodoxCalendar;
  final bool useProtestantCalendar;
  final String? lastRescheduleDateIso;

  InspirationPlanSettings copyWith({
    bool? remindersEnabled,
    int? notifyTimeMinutes,
    bool? useOrthodoxCalendar,
    bool? useProtestantCalendar,
    String? lastRescheduleDateIso,
    bool clearLastRescheduleDate = false,
  }) {
    return InspirationPlanSettings(
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      notifyTimeMinutes: notifyTimeMinutes ?? this.notifyTimeMinutes,
      useOrthodoxCalendar: useOrthodoxCalendar ?? this.useOrthodoxCalendar,
      useProtestantCalendar:
          useProtestantCalendar ?? this.useProtestantCalendar,
      lastRescheduleDateIso: clearLastRescheduleDate
          ? null
          : (lastRescheduleDateIso ?? this.lastRescheduleDateIso),
    );
  }

  Map<String, dynamic> toJson() => {
        'remindersEnabled': remindersEnabled,
        'notifyTimeMinutes': notifyTimeMinutes,
        'useOrthodoxCalendar': useOrthodoxCalendar,
        'useProtestantCalendar': useProtestantCalendar,
        if (lastRescheduleDateIso != null)
          'lastRescheduleDateIso': lastRescheduleDateIso,
      };

  static InspirationPlanSettings fromJson(Map<String, dynamic>? json) {
    if (json == null) return const InspirationPlanSettings();
    return InspirationPlanSettings(
      remindersEnabled: json['remindersEnabled'] == true,
      notifyTimeMinutes: (json['notifyTimeMinutes'] as num?)?.toInt() ?? 420,
      useOrthodoxCalendar: json['useOrthodoxCalendar'] == true,
      useProtestantCalendar: json['useProtestantCalendar'] == true,
      lastRescheduleDateIso: json['lastRescheduleDateIso'] as String?,
    );
  }
}

class InspirationCustomDay {
  const InspirationCustomDay({
    required this.id,
    required this.name,
    required this.month,
    required this.day,
    required this.verseRefs,
    this.useRandomVerse = false,
    this.enabled = true,
  });

  final String id;
  final String name;
  final int month;
  final int day;
  final List<InspirationVerseRef> verseRefs;
  final bool useRandomVerse;
  final bool enabled;

  InspirationCustomDay copyWith({
    String? name,
    int? month,
    int? day,
    List<InspirationVerseRef>? verseRefs,
    bool? useRandomVerse,
    bool? enabled,
  }) {
    return InspirationCustomDay(
      id: id,
      name: name ?? this.name,
      month: month ?? this.month,
      day: day ?? this.day,
      verseRefs: verseRefs ?? this.verseRefs,
      useRandomVerse: useRandomVerse ?? this.useRandomVerse,
      enabled: enabled ?? this.enabled,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'month': month,
        'day': day,
        'enabled': enabled,
        'useRandomVerse': useRandomVerse,
        'verseRefs': verseRefs.map((e) => e.toJson()).toList(),
      };

  static InspirationCustomDay? fromJson(dynamic raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final name = raw['name'];
    final month = (raw['month'] as num?)?.toInt();
    final day = (raw['day'] as num?)?.toInt();
    if (id is! String || id.isEmpty) return null;
    if (name is! String || name.isEmpty) return null;
    if (month == null || month < 1 || month > 12) return null;
    if (day == null || day < 1 || day > 31) return null;
    final refsRaw = raw['verseRefs'];
    final refs = <InspirationVerseRef>[];
    if (refsRaw is List) {
      for (final item in refsRaw) {
        final r = InspirationVerseRef.fromJson(item);
        if (r != null) refs.add(r);
      }
    }
    return InspirationCustomDay(
      id: id,
      name: name,
      month: month,
      day: day,
      verseRefs: refs,
      useRandomVerse: raw['useRandomVerse'] == true,
      enabled: raw['enabled'] != false,
    );
  }
}

/// Тип события на дату для UI и уведомлений.
enum InspirationEventKind {
  dailyRandom,
  churchHoliday,
  customDay,
}

class InspirationDayEvent {
  const InspirationDayEvent({
    required this.kind,
    required this.eventId,
    required this.displayName,
    required this.verseRef,
    this.traditionLabel,
  });

  final InspirationEventKind kind;
  final String eventId;
  final String displayName;
  final InspirationVerseRef verseRef;
  final String? traditionLabel;
}

class InspirationHolidayDefinition {
  const InspirationHolidayDefinition({
    required this.id,
    required this.name,
    required this.tradition,
    required this.fixedMonth,
    required this.fixedDay,
    this.easterOffsetDays,
    required this.verseRefs,
  });

  final String id;
  final String name;
  final String tradition;
  final int? fixedMonth;
  final int? fixedDay;
  final int? easterOffsetDays;
  final List<InspirationVerseRef> verseRefs;

  bool get isEasterBased => easterOffsetDays != null;
}
