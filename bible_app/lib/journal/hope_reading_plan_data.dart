/// Тематический план «Надежда»: один квартал, семь дней (структура как у «Вера»).

import 'package:bible_app/journal/thematic_reading_plan_models.dart';

const String kHopePlanPickerButtonLabel = 'Тематический: Надежда';

const int kHopePlanDayCount = 7;

/// Заголовок на карточке единственного квартала и в центре шапки списка дней.
const String kHopeQuarterHubTitle = 'Надежда, якорь для души';

const String kHopeQuarterReadingTips =
    'Ключевые стихи для запоминания\n'
    'Римлянам 15:13 (Бог — источник радости и надежды).\n'
    'Иеремия 29:11 (Обетование будущего).\n'
    'Исаия 40:31 (Сила для уставших).\n'
    'Советы по чтению:\n'
    'Выписывайте стихи в Блокнот, которые особенно коснулись сердца.\n'
    'Тема для молитвы: Просите Бога утвердить надежду в конкретной ситуации.\n'
    'Размышляйте: Не спешите, перечитывайте отрывок несколько раз.\n'
    'Через функцию поиска, найдите еще места из Библии на тему Надежда и опишите для себя в Блокноте главную мысль стихов.';

const List<ThematicReadingDay> kHopeReadingPlanDays = [
  ThematicReadingDay(
    theme: 'Основа надежды — Бог',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Иеремия 29:11',
        book: 'Иеремия',
        chapter: 29,
        startVerse: 11,
        idea:
            '«Ибо только Я знаю намерения, какие имею о вас… намерения во благо…»',
      ),
      ThematicReadingRow(
        refDisplay: 'Римлянам 15:13',
        book: 'Римлянам',
        chapter: 15,
        startVerse: 13,
        idea:
            '«Бог же надежды да исполнит вас всякой радости и мира…»',
      ),
      ThematicReadingRow(
        refDisplay: 'Псалтирь 61:6',
        book: 'Псалтирь',
        chapter: 61,
        startVerse: 6,
        idea:
            '«Только в Боге успокаивайся, душа моя! ибо на Него надежда моя».',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Надежда в испытаниях',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Римлянам 5:3-4',
        book: 'Римлянам',
        chapter: 5,
        startVerse: 3,
        idea:
            'От скорби — терпение, опытность и надежда.',
      ),
      ThematicReadingRow(
        refDisplay: 'Плач Иеремии 3:22-24',
        book: 'Плач Иеремии',
        chapter: 3,
        startVerse: 22,
        idea:
            'Милости Господа не исчерпались; они новые каждое утро.',
      ),
      ThematicReadingRow(
        refDisplay: 'Псалтирь 45:2',
        book: 'Псалтирь',
        chapter: 45,
        startVerse: 2,
        idea:
            '«Бог нам прибежище и сила, скорый помощник в бедах».',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Сила обновляется надеждой',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Исаия 40:31',
        book: 'Исаия',
        chapter: 40,
        startVerse: 31,
        idea:
            '«Надеющиеся на Господа обновятся в силе…»',
      ),
      ThematicReadingRow(
        refDisplay: 'Псалтирь 30:25',
        book: 'Псалтирь',
        chapter: 30,
        startVerse: 25,
        idea:
            '«Мужайтесь… все надеющиеся на Господа!»',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Надежда на будущее и вечность',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Евреям 11:1',
        book: 'Евреям',
        chapter: 11,
        startVerse: 1,
        idea:
            '«Вера есть осуществление ожидаемого и уверенность в невидимом».',
      ),
      ThematicReadingRow(
        refDisplay: 'Откровение 21:3-4',
        book: 'Откровение',
        chapter: 21,
        startVerse: 3,
        idea:
            'Бог с человеком; слёз и смерти не будет.',
      ),
      ThematicReadingRow(
        refDisplay: '1 Петра 1:3',
        book: '1 Петра',
        chapter: 1,
        startVerse: 3,
        idea:
            'Живое упование через воскресение Иисуса Христа.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Надежда против отчаяния',
    rows: [
      ThematicReadingRow(
        refDisplay: '2 Коринфянам 4:16-18',
        book: '2 Коринфянам',
        chapter: 4,
        startVerse: 16,
        idea:
            'Временное лёгкое страдание готовит вечную славу.',
      ),
      ThematicReadingRow(
        refDisplay: 'Псалтирь 41:6',
        book: 'Псалтирь',
        chapter: 41,
        startVerse: 6,
        idea:
            '«Что унываешь ты, душа моя… Уповай на Бога».',
      ),
      ThematicReadingRow(
        refDisplay: 'Римлянам 8:24-25',
        book: 'Римлянам',
        chapter: 8,
        startVerse: 24,
        idea:
            'Надеемся на невидимое и терпеливо ожидаем.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Надежда в Его Слове',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Псалтирь 118:114',
        book: 'Псалтирь',
        chapter: 118,
        startVerse: 114,
        idea:
            '«Ты покров мой и щит мой; на слово Твое уповаю».',
      ),
      ThematicReadingRow(
        refDisplay: 'Притчи 24:14',
        book: 'Притчи',
        chapter: 24,
        startVerse: 14,
        idea:
            '«…есть надежда, и она не потеряна для тебя».',
      ),
      ThematicReadingRow(
        refDisplay: 'Псалтирь 129:5',
        book: 'Псалтирь',
        chapter: 129,
        startVerse: 5,
        idea:
            '«Надеюсь на Господа… на слово Его уповаю».',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Активная надежда (вера в действии)',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Римлянам 12:12',
        book: 'Римлянам',
        chapter: 12,
        startVerse: 12,
        idea:
            '«Утешайтесь надеждою… в молитве постоянны».',
      ),
      ThematicReadingRow(
        refDisplay: '1 Тимофею 6:17',
        book: '1 Тимофею',
        chapter: 6,
        startVerse: 17,
        idea:
            'Возлагать надежду на Бога живого, дарящего всё обильно.',
      ),
      ThematicReadingRow(
        refDisplay: '1 Коринфянам 13:13',
        book: '1 Коринфянам',
        chapter: 13,
        startVerse: 13,
        idea:
            '«А теперь пребывают сии три: вера, надежда, любовь…»',
      ),
    ],
  ),
];
