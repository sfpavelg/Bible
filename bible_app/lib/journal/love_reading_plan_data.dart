/// Тематический план «Любовь»: один квартал, пять дней (как прочие тематические планы).

import 'package:bible_app/journal/thematic_reading_plan_models.dart';

const String kLovePlanPickerButtonLabel = 'Тематический: Любовь';

const int kLovePlanDayCount = 5;

const String kLoveQuarterHubTitle =
    'Любовь — основа христианской жизни';

const String kLoveQuarterReadingTips =
    'Советы по изучению:\n'
    'Задавайте вопрос: «Как этот стих меняет мое отношение к Богу/ближним?».\n'
    'Попробуйте применить один из принципов (например, 1 Кор. 13:4-7) в течение дня.\n'
    'Через функцию поиска, найдите еще места из Библии на тему Любовь и опишите для себя в Блокноте главную мысль стихов.';

const List<ThematicReadingDay> kLoveReadingPlanDays = [
  ThematicReadingDay(
    theme: 'Сущность Бога есть Любовь (Божественная любовь)',
    rows: [
      ThematicReadingRow(
        refDisplay: '1 Иоанна 4:7-8',
        book: '1 Иоанна',
        chapter: 4,
        startVerse: 7,
        idea: 'Бог есть любовь; всякий любящий рождён от Бога.',
      ),
      ThematicReadingRow(
        refDisplay: '1 Иоанна 4:16-19',
        book: '1 Иоанна',
        chapter: 4,
        startVerse: 16,
        idea: 'Совершенная любовь изгоняет страх.',
      ),
      ThematicReadingRow(
        refDisplay: 'Иоанна 3:16',
        book: 'Иоанна',
        chapter: 3,
        startVerse: 16,
        idea: 'Бог так возлюбил мир, что отдал Сына Своего Единородного.',
      ),
      ThematicReadingRow(
        refDisplay: 'Римлянам 5:8',
        book: 'Римлянам',
        chapter: 5,
        startVerse: 8,
        idea: 'Христос умер за нас, когда мы были ещё грешниками.',
      ),
      ThematicReadingRow(
        refDisplay: 'Иеремия 31:3',
        book: 'Иеремия',
        chapter: 31,
        startVerse: 3,
        idea: '«Любовью вечною Я возлюбил тебя».',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Заповедь любви к Богу и ближнему',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Матфея 22:37-39',
        book: 'Матфея',
        chapter: 22,
        startVerse: 37,
        idea:
            'Возлюби Господа всем сердцем… и ближнего своего, как самого себя.',
      ),
      ThematicReadingRow(
        refDisplay: 'Иоанна 13:34-35',
        book: 'Иоанна',
        chapter: 13,
        startVerse: 34,
        idea: 'Новая заповедь: любите друг друга, как Я возлюбил вас.',
      ),
      ThematicReadingRow(
        refDisplay: 'Римлянам 13:10',
        book: 'Римлянам',
        chapter: 13,
        startVerse: 10,
        idea: 'Любовь не делает ближнему зла; исполнение закона.',
      ),
      ThematicReadingRow(
        refDisplay: '1 Петра 4:8',
        book: '1 Петра',
        chapter: 4,
        startVerse: 8,
        idea: 'Ревностная любовь друг ко другу; любовь покрывает грехи многие.',
      ),
      ThematicReadingRow(
        refDisplay: '1 Иоанна 3:18',
        book: '1 Иоанна',
        chapter: 3,
        startVerse: 18,
        idea: 'Любить делом и истиною, а не только словом.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Характеристики и действия любви (1 Коринфянам 13)',
    rows: [
      ThematicReadingRow(
        refDisplay: '1 Коринфянам 13:4-7',
        book: '1 Коринфянам',
        chapter: 13,
        startVerse: 4,
        idea:
            'Любовь долготерпит, милосердствует, не завидует, не превозносится…',
      ),
      ThematicReadingRow(
        refDisplay: '1 Коринфянам 13:13',
        book: '1 Коринфянам',
        chapter: 13,
        startVerse: 13,
        idea: 'Вера, надежда, любовь — любовь из них больше.',
      ),
      ThematicReadingRow(
        refDisplay: 'Колоссянам 3:14',
        book: 'Колоссянам',
        chapter: 3,
        startVerse: 14,
        idea: 'Превыше всего — любовь, совокупность совершенства.',
      ),
      ThematicReadingRow(
        refDisplay: '1 Коринфянам 16:14',
        book: '1 Коринфянам',
        chapter: 16,
        startVerse: 14,
        idea: 'Всё делайте с любовью.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Любовь к врагам и жертвенность',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Матфея 5:44-45',
        book: 'Матфея',
        chapter: 5,
        startVerse: 44,
        idea: 'Любите врагов; благословляйте проклинающих вас.',
      ),
      ThematicReadingRow(
        refDisplay: 'Иоанна 15:13',
        book: 'Иоанна',
        chapter: 15,
        startVerse: 13,
        idea: 'Нет больше любви, как положить душу за друзей своих.',
      ),
      ThematicReadingRow(
        refDisplay: '1 Иоанна 3:16',
        book: '1 Иоанна',
        chapter: 3,
        startVerse: 16,
        idea: 'Любовь Бога: Он положил за нас душу Свою.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Жизнь в любви (Практическое применение)',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Римлянам 12:9-10',
        book: 'Римлянам',
        chapter: 12,
        startVerse: 9,
        idea: 'Любовь нелицемерна; братская любовь превыше прочего.',
      ),
      ThematicReadingRow(
        refDisplay: 'Ефесянам 5:1-2',
        book: 'Ефесянам',
        chapter: 5,
        startVerse: 1,
        idea: 'Подражайте Богу как чада возлюбленные; живите в любви.',
      ),
      ThematicReadingRow(
        refDisplay: '2 Тимофею 1:7',
        book: '2 Тимофею',
        chapter: 1,
        startVerse: 7,
        idea: 'Дух силы, любви и целомудрия — не дух боязни.',
      ),
      ThematicReadingRow(
        refDisplay: 'Псалтирь 90:14',
        book: 'Псалтирь',
        chapter: 90,
        startVerse: 14,
        idea: '«За то, что он возлюбил Меня… избавлю его».',
      ),
    ],
  ),
];
