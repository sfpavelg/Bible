class BibleBook {
  final String name;
  final String abbreviation;
  final int chapters;
  final String testament;

  BibleBook({
    required this.name,
    required this.abbreviation,
    required this.chapters,
    required this.testament,
  });

  /// Полное церковно-издательское название книги (для подписей в диалогах и т.п.).
  static String liturgicalDisplayName(String bookName) =>
      _liturgicalTitles[bookName] ?? bookName;

  static const Map<String, String> _liturgicalTitles = {
    // Ветхий Завет
    'Бытие': 'Первая книга Моисеева, именуемая Бытие',
    'Исход': 'Вторая книга Моисеева, именуемая Исход',
    'Левит': 'Третья книга Моисеева, именуемая Левит',
    'Числа': 'Четвёртая книга Моисеева, именуемая Числа',
    'Второзаконие': 'Пятая книга Моисеева, именуемая Второзаконие',
    'Иисус Навин': 'Книга Иисуса Навина',
    'Судьи': 'Книга Судей Израилевых',
    'Руфь': 'Книга Руфи',
    '1 Царств': 'Первая книга Царств',
    '2 Царств': 'Вторая книга Царств',
    '3 Царств': 'Третья книга Царств',
    '4 Царств': 'Четвёртая книга Царств',
    '1 Паралипоменон': 'Первая книга Паралипоменон',
    '2 Паралипоменон': 'Вторая книга Паралипоменон',
    'Ездра': 'Книга Ездры',
    'Неемия': 'Книга Неемии',
    'Есфирь': 'Книга Есфири',
    'Иов': 'Книга Иова',
    'Псалтирь': 'Псалтирь',
    'Притчи': 'Книга Притчей Соломоновых',
    'Екклесиаст': 'Книга Екклесиаста, или Проповедника',
    'Песня Песней': 'Песнь Песней Соломона',
    'Исаия': 'Книга пророка Исаии',
    'Иеремия': 'Книга пророка Иеремии',
    'Плач Иеремии': 'Плач Иеремии',
    'Иезекииль': 'Книга пророка Иезекииля',
    'Даниил': 'Книга пророка Даниила',
    'Осия': 'Книга пророка Осии',
    'Иоиль': 'Книга пророка Иоиля',
    'Амос': 'Книга пророка Амоса',
    'Авдий': 'Книга пророка Авдия',
    'Иона': 'Книга пророка Ионы',
    'Михей': 'Книга пророка Михея',
    'Наум': 'Книга пророка Наума',
    'Аввакум': 'Книга пророка Аввакума',
    'Софония': 'Книга пророка Софонии',
    'Аггей': 'Книга пророка Аггея',
    'Захария': 'Книга пророка Захарии',
    'Малахия': 'Книга пророка Малахии',
    // Новый Завет
    'Матфея': 'Святое Евангелие от Матфеа',
    'Марка': 'Святое Евангелие от Марка',
    'Луки': 'Святое Евангелие от Луки',
    'Иоанна': 'Святое Евангелие от Иоанна',
    'Деяния': 'Деяния святых Апостолов',
    'Иакова': 'Соборное послание святого Апостола Иакова',
    '1 Петра': 'Первое соборное послание святого Апостола Петра',
    '2 Петра': 'Второе соборное послание святого Апостола Петра',
    '1 Иоанна': 'Первое соборное послание святого Апостола Иоанна Богослова',
    '2 Иоанна': 'Второе соборное послание святого Апостола Иоанна Богослова',
    '3 Иоанна': 'Третье соборное послание святого Апостола Иоанна Богослова',
    'Иуды': 'Соборное послание святого Апостола Иуды',
    'Римлянам': 'Послание к Римлянам святого Апостола Павла',
    '1 Коринфянам':
        'Первое послание Коринфянам святого Апостола Павла',
    '2 Коринфянам':
        'Второе послание Коринфянам святого Апостола Павла',
    'Галатам': 'Послание к Галатам святого Апостола Павла',
    'Ефесянам': 'Послание к Ефесянам святого Апостола Павла',
    'Филиппийцам': 'Послание к Филиппийцам святого Апостола Павла',
    'Колоссянам': 'Послание к Колоссянам святого Апостола Павла',
    '1 Фессалоникийцам':
        'Первое послание к Фессалоникийцам святого Апостола Павла',
    '2 Фессалоникийцам':
        'Второе послание к Фессалоникийцам святого Апостола Павла',
    '1 Тимофею': 'Первое послание к Тимофею святого Апостола Павла',
    '2 Тимофею': 'Второе послание к Тимофею святого Апостола Павла',
    'Титу': 'Послание к Титу святого Апостола Павла',
    'Филимону': 'Послание к Филимону святого Апостола Павла',
    'Евреям': 'Послание к Евреям святого Апостола Павла',
    'Откровение': 'Откровение святого Иоанна Богослова',
  };

  // Список книг Библии
  static List<BibleBook> get books => [
    // Ветхий Завет
    BibleBook(name: 'Бытие', abbreviation: 'Быт', chapters: 50, testament: 'old'),
    BibleBook(name: 'Исход', abbreviation: 'Исх', chapters: 40, testament: 'old'),
    BibleBook(name: 'Левит', abbreviation: 'Лев', chapters: 27, testament: 'old'),
    BibleBook(name: 'Числа', abbreviation: 'Чис', chapters: 36, testament: 'old'),
    BibleBook(name: 'Второзаконие', abbreviation: 'Втор', chapters: 34, testament: 'old'),
    BibleBook(name: 'Иисус Навин', abbreviation: 'Нав', chapters: 24, testament: 'old'),
    BibleBook(name: 'Судьи', abbreviation: 'Суд', chapters: 21, testament: 'old'),
    BibleBook(name: 'Руфь', abbreviation: 'Руф', chapters: 4, testament: 'old'),
    BibleBook(name: '1 Царств', abbreviation: '1Цар', chapters: 31, testament: 'old'),
    BibleBook(name: '2 Царств', abbreviation: '2Цар', chapters: 24, testament: 'old'),
    BibleBook(name: '3 Царств', abbreviation: '3Цар', chapters: 22, testament: 'old'),
    BibleBook(name: '4 Царств', abbreviation: '4Цар', chapters: 25, testament: 'old'),
    BibleBook(name: '1 Паралипоменон', abbreviation: '1Пар', chapters: 29, testament: 'old'),
    BibleBook(name: '2 Паралипоменон', abbreviation: '2Пар', chapters: 36, testament: 'old'),
    BibleBook(name: 'Ездра', abbreviation: 'Езд', chapters: 10, testament: 'old'),
    BibleBook(name: 'Неемия', abbreviation: 'Неем', chapters: 13, testament: 'old'),
    BibleBook(name: 'Есфирь', abbreviation: 'Есф', chapters: 10, testament: 'old'),
    BibleBook(name: 'Иов', abbreviation: 'Иов', chapters: 42, testament: 'old'),
    BibleBook(name: 'Псалтирь', abbreviation: 'Пс', chapters: 150, testament: 'old'),
    BibleBook(name: 'Притчи', abbreviation: 'Прит', chapters: 31, testament: 'old'),
    BibleBook(name: 'Екклесиаст', abbreviation: 'Еккл', chapters: 12, testament: 'old'),
    BibleBook(name: 'Песня Песней', abbreviation: 'Песн', chapters: 8, testament: 'old'),
    BibleBook(name: 'Исаия', abbreviation: 'Ис', chapters: 66, testament: 'old'),
    BibleBook(name: 'Иеремия', abbreviation: 'Иер', chapters: 52, testament: 'old'),
    BibleBook(name: 'Плач Иеремии', abbreviation: 'Плач', chapters: 5, testament: 'old'),
    BibleBook(name: 'Иезекииль', abbreviation: 'Иез', chapters: 48, testament: 'old'),
    BibleBook(name: 'Даниил', abbreviation: 'Дан', chapters: 12, testament: 'old'),
    BibleBook(name: 'Осия', abbreviation: 'Ос', chapters: 14, testament: 'old'),
    BibleBook(name: 'Иоиль', abbreviation: 'Иоил', chapters: 3, testament: 'old'),
    BibleBook(name: 'Амос', abbreviation: 'Ам', chapters: 9, testament: 'old'),
    BibleBook(name: 'Авдий', abbreviation: 'Авд', chapters: 1, testament: 'old'),
    BibleBook(name: 'Иона', abbreviation: 'Ион', chapters: 4, testament: 'old'),
    BibleBook(name: 'Михей', abbreviation: 'Мих', chapters: 7, testament: 'old'),
    BibleBook(name: 'Наум', abbreviation: 'Наум', chapters: 3, testament: 'old'),
    BibleBook(name: 'Аввакум', abbreviation: 'Авв', chapters: 3, testament: 'old'),
    BibleBook(name: 'Софония', abbreviation: 'Соф', chapters: 3, testament: 'old'),
    BibleBook(name: 'Аггей', abbreviation: 'Агг', chapters: 2, testament: 'old'),
    BibleBook(name: 'Захария', abbreviation: 'Зах', chapters: 14, testament: 'old'),
    BibleBook(name: 'Малахия', abbreviation: 'Мал', chapters: 4, testament: 'old'),
    
    // Новый Завет
    BibleBook(name: 'Матфея', abbreviation: 'Мф', chapters: 28, testament: 'new'),
    BibleBook(name: 'Марка', abbreviation: 'Мк', chapters: 16, testament: 'new'),
    BibleBook(name: 'Луки', abbreviation: 'Лк', chapters: 24, testament: 'new'),
    BibleBook(name: 'Иоанна', abbreviation: 'Ин', chapters: 21, testament: 'new'),
    BibleBook(name: 'Деяния', abbreviation: 'Деян', chapters: 28, testament: 'new'),
    BibleBook(name: 'Иакова', abbreviation: 'Иак', chapters: 5, testament: 'new'),
    BibleBook(name: '1 Петра', abbreviation: '1Пет', chapters: 5, testament: 'new'),
    BibleBook(name: '2 Петра', abbreviation: '2Пет', chapters: 3, testament: 'new'),
    BibleBook(name: '1 Иоанна', abbreviation: '1Ин', chapters: 5, testament: 'new'),
    BibleBook(name: '2 Иоанна', abbreviation: '2Ин', chapters: 1, testament: 'new'),
    BibleBook(name: '3 Иоанна', abbreviation: '3Ин', chapters: 1, testament: 'new'),
    BibleBook(name: 'Иуды', abbreviation: 'Иуд', chapters: 1, testament: 'new'),
    BibleBook(name: 'Римлянам', abbreviation: 'Рим', chapters: 16, testament: 'new'),
    BibleBook(name: '1 Коринфянам', abbreviation: '1Кор', chapters: 16, testament: 'new'),
    BibleBook(name: '2 Коринфянам', abbreviation: '2Кор', chapters: 13, testament: 'new'),
    BibleBook(name: 'Галатам', abbreviation: 'Гал', chapters: 6, testament: 'new'),
    BibleBook(name: 'Ефесянам', abbreviation: 'Еф', chapters: 6, testament: 'new'),
    BibleBook(name: 'Филиппийцам', abbreviation: 'Флп', chapters: 4, testament: 'new'),
    BibleBook(name: 'Колоссянам', abbreviation: 'Кол', chapters: 4, testament: 'new'),
    BibleBook(name: '1 Фессалоникийцам', abbreviation: '1Фес', chapters: 5, testament: 'new'),
    BibleBook(name: '2 Фессалоникийцам', abbreviation: '2Фес', chapters: 3, testament: 'new'),
    BibleBook(name: '1 Тимофею', abbreviation: '1Тим', chapters: 6, testament: 'new'),
    BibleBook(name: '2 Тимофею', abbreviation: '2Тим', chapters: 4, testament: 'new'),
    BibleBook(name: 'Титу', abbreviation: 'Тит', chapters: 3, testament: 'new'),
    BibleBook(name: 'Филимону', abbreviation: 'Флм', chapters: 1, testament: 'new'),
    BibleBook(name: 'Евреям', abbreviation: 'Евр', chapters: 13, testament: 'new'),
    BibleBook(name: 'Откровение', abbreviation: 'Откр', chapters: 22, testament: 'new'),
  ];
}

class BibleVerse {
  final String book;
  final int chapter;
  final int verse;
  final String text;
  final String type;
  final String? speaker;
  
  BibleVerse({
    required this.book,
    required this.chapter,
    required this.verse,
    required this.text,
    this.type = 'narrative',
    this.speaker,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'book': book,
      'chapter': chapter,
      'verse': verse,
      'text': text,
      'type': type,
      'speaker': speaker,
    };
  }
  
  @override
  String toString() {
    return '$book $chapter:$verse - $text';
  }
}