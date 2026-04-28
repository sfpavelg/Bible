/// Тематический план «Вера»: один квартал, семь дней, отрывки с пояснениями.

import 'package:bible_app/journal/thematic_reading_plan_models.dart';

/// Подпись кнопки в листе выбора плана; часть после «:» идёт в шапку «План чтения: …».
const String kFaithPlanPickerButtonLabel = 'Тематический: Вера';

const int kFaithPlanDayCount = 7;

/// Заголовок на карточке единственного квартала и в центре шапки списка дней.
const String kFaithQuarterHubTitle = '«Вера, движущая горы»';

const String kFaithQuarterReadingTips =
    'Советы для чтения:\n'
    'Перед чтением помолитесь: «Господь, укрепи мою веру через Твое Слово».\n'
    'Записывайте в Блокноте, что конкретно вы можете начать делать, доверяя Богу, после прочтения.\n'
    'Через функцию поиска, найдите еще места из Библии на тему Вера и опишите для себя в Блокноте главную мысль стихов.';

const List<ThematicReadingDay> kFaithReadingPlanDays = [
  ThematicReadingDay(
    theme: 'Что такое Вера? (Определение)',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Евреям 11:1-6',
        book: 'Евреям',
        chapter: 11,
        startVerse: 1,
        idea: 'Фундаментальное определение веры как уверенности в невидимом.',
      ),
      ThematicReadingRow(
        refDisplay: 'Римлянам 10:17',
        book: 'Римлянам',
        chapter: 10,
        startVerse: 17,
        idea: 'Вера от слышания Слова Божьего.',
      ),
      ThematicReadingRow(
        refDisplay: 'Ефесянам 2:8-9',
        book: 'Ефесянам',
        chapter: 2,
        startVerse: 8,
        idea: 'Вера как дар Божий, а не заслуга.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Вера и Спасение',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Иоанна 3:16',
        book: 'Иоанна',
        chapter: 3,
        startVerse: 16,
        idea: 'Вера в Сына — залог вечной жизни.',
      ),
      ThematicReadingRow(
        refDisplay: 'Римлянам 5:1-2',
        book: 'Римлянам',
        chapter: 5,
        startVerse: 1,
        idea: 'Оправдание верою и мир с Богом.',
      ),
      ThematicReadingRow(
        refDisplay: 'Галатам 2:16',
        book: 'Галатам',
        chapter: 2,
        startVerse: 16,
        idea: 'Вера в Иисуса Христа, а не дела закона.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Вера в действии (Сила веры)',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Евреям 11:7-16',
        book: 'Евреям',
        chapter: 11,
        startVerse: 7,
        idea: 'Вера Авраама и Ноя: послушание, когда ничего не понятно.',
      ),
      ThematicReadingRow(
        refDisplay: 'Марка 11:22-24',
        book: 'Марка',
        chapter: 11,
        startVerse: 22,
        idea: 'Вера с горчичным зерном: сила переставлять горы.',
      ),
      ThematicReadingRow(
        refDisplay: 'Иакова 2:14-17',
        book: 'Иакова',
        chapter: 2,
        startVerse: 14,
        idea: 'Вера без дел мертва.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Вера в трудные времена (Упование)',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Притчи 3:5-6',
        book: 'Притчи',
        chapter: 3,
        startVerse: 5,
        idea: 'Уповай на Господа всем сердцем.',
      ),
      ThematicReadingRow(
        refDisplay: 'Исаия 40:31',
        book: 'Исаия',
        chapter: 40,
        startVerse: 31,
        idea: 'Надеющиеся на Господа обновят силы.',
      ),
      ThematicReadingRow(
        refDisplay: 'Псалтирь 26:1-3',
        book: 'Псалтирь',
        chapter: 26,
        startVerse: 1,
        idea: 'Господь — крепость жизни моей.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Примеры веры в Новом Завете',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Матфея 8:5-10',
        book: 'Матфея',
        chapter: 8,
        startVerse: 5,
        idea: 'Вера сотника (удивление Христа).',
      ),
      ThematicReadingRow(
        refDisplay: 'Марка 5:25-34',
        book: 'Марка',
        chapter: 5,
        startVerse: 25,
        idea: 'Исцеление кровоточивой женщины: «Вера твоя спасла тебя».',
      ),
      ThematicReadingRow(
        refDisplay: 'Евреям 12:1-2',
        book: 'Евреям',
        chapter: 12,
        startVerse: 1,
        idea: 'Взирая на начальника и совершителя веры Иисуса.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Вера и Страх',
    rows: [
      ThematicReadingRow(
        refDisplay: 'Марка 4:35-41',
        book: 'Марка',
        chapter: 4,
        startVerse: 35,
        idea: 'Укрощение бури: «Почему вы так боязливы? Как у вас нет веры?».',
      ),
      ThematicReadingRow(
        refDisplay: 'Исаия 41:10',
        book: 'Исаия',
        chapter: 41,
        startVerse: 10,
        idea: '«Не бойся, ибо Я с тобою».',
      ),
      ThematicReadingRow(
        refDisplay: 'Псалтирь 55:4',
        book: 'Псалтирь',
        chapter: 55,
        startVerse: 4,
        idea: 'Когда мне страшно, я на Тебя уповаю.',
      ),
    ],
  ),
  ThematicReadingDay(
    theme: 'Победа Веры',
    rows: [
      ThematicReadingRow(
        refDisplay: '1 Иоанна 5:4-5',
        book: '1 Иоанна',
        chapter: 5,
        startVerse: 4,
        idea: 'Вера — победа, победившая мир.',
      ),
      ThematicReadingRow(
        refDisplay: '1 Коринфянам 16:13-14',
        book: '1 Коринфянам',
        chapter: 16,
        startVerse: 13,
        idea: '«Бодрствуйте, стойте в вере, будьте мужественны».',
      ),
      ThematicReadingRow(
        refDisplay: '2 Тимофею 4:7-8',
        book: '2 Тимофею',
        chapter: 4,
        startVerse: 7,
        idea: 'Сохранить веру до конца.',
      ),
    ],
  ),
];
