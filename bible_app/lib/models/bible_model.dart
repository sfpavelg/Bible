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
    BibleBook(name: 'От Матфея', abbreviation: 'Мф', chapters: 28, testament: 'new'),
    BibleBook(name: 'От Марка', abbreviation: 'Мк', chapters: 16, testament: 'new'),
    BibleBook(name: 'От Луки', abbreviation: 'Лк', chapters: 24, testament: 'new'),
    BibleBook(name: 'От Иоанна', abbreviation: 'Ин', chapters: 21, testament: 'new'),
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