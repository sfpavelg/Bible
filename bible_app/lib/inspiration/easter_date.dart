/// Даты Пасхи: западная (протестантская) и православная (юлианская пасхалия → григорианская дата).

/// Пасха по григорианскому календарю (западная традиция).
DateTime gregorianEasterSunday(int year) {
  final a = year % 19;
  final b = year ~/ 100;
  final c = year % 100;
  final d = b ~/ 4;
  final e = c % 4;
  final f = (b + 8) ~/ 25;
  final g = (b - f + 1) ~/ 3;
  final h = (19 * a + b - d - g + 15) % 30;
  final i = c ~/ 4;
  final k = h % 15;
  final l = (32 + 2 * e + 2 * i - h - k) % 7;
  final m = (a + 11 * h + 22 * l) ~/ 451;
  final month = (h + l - 7 * m + 114) ~/ 31;
  final day = ((h + l - 7 * m + 114) % 31) + 1;
  return DateTime(year, month, day);
}

/// Православная Пасха (дата в григорианском календаре, когда празднуется в РПЦ).
DateTime orthodoxEasterSunday(int year) {
  final a = year % 19;
  final b = year % 7;
  final c = year % 4;
  final d = (19 * a + 15) % 30;
  final e = (2 * c + 4 * b - d + 34) % 7;
  final jMonth = (d + e + 114) ~/ 31;
  final jDay = ((d + e + 114) % 31) + 1;
  final julianMonth = jMonth == 3 ? 3 : 4;
  final julianDay = jDay;
  final delta = _julianToGregorianDelta(year);
  var gMonth = julianMonth;
  var gDay = julianDay + delta;
  var gYear = year;
  final daysInMonth = [31, _isLeapYear(gYear) ? 29 : 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
  while (gDay > daysInMonth[gMonth - 1]) {
    gDay -= daysInMonth[gMonth - 1];
    gMonth++;
    if (gMonth > 12) {
      gMonth = 1;
      gYear++;
    }
  }
  return DateTime(gYear, gMonth, gDay);
}

int _julianToGregorianDelta(int year) {
  if (year < 1583) return 10;
  if (year < 1700) return 10;
  if (year < 1800) return 11;
  if (year < 1900) return 12;
  if (year < 2100) return 13;
  if (year < 2200) return 14;
  return 15;
}

bool _isLeapYear(int year) =>
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;

DateTime easterSundayForTradition(int year, String tradition) {
  if (tradition == 'protestant' || tradition == 'western') {
    return gregorianEasterSunday(year);
  }
  return orthodoxEasterSunday(year);
}
