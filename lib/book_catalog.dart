/// Бібліотека для функціональної обробки каталогу книг (Лабораторна робота №1).
///
/// Містить оголошення типів записів (Records), вхідний набір CSV-даних,
/// функції безпечного розбору, валідації діапазонів, регулярних виразів та дат.
/// Використання ключового слова `class` у цій версії заборонено.
library;

/// Запис, що представляє окрему книгу в каталозі.
///
/// Поля запису:
/// - [id] — унікальний ідентифікатор книги;
/// - [title] — назва книги;
/// - [author] — автор книги;
/// - [genre] — жанр або тематична категорія;
/// - [year] — рік видання;
/// - [pages] — кількість сторінок;
/// - [rating] — середня оцінка читачів (від 0.0 до 5.0);
/// - [isbn] — міжнародний стандартний номер книги у форматі ISBN-13;
/// - [addedDate] — дата внесення запису до каталогу.
typedef BookRecord = ({
  String id,
  String title,
  String author,
  String genre,
  int year,
  int pages,
  double rating,
  String isbn,
  DateTime addedDate,
});

/// Детальний результат розбору одного CSV-рядка.
///
/// Якщо розбір успішний, поле [book] містить створений запис, а [error] дорівнює `null`.
/// Якщо сталася помилка формату, [book] дорівнює `null`, а [error] містить опис причини.
typedef ParseResult = ({
  int lineNumber,
  String rawLine,
  BookRecord? book,
  String? error,
});

/// Результат валідації логічних діапазонів і форматів полів книги.
typedef ValidationResult = ({
  BookRecord book,
  List<String> violations,
  bool isValid,
});

/// Розібрані сегменти номера ISBN-13 з іменованих груп регулярного виразу.
typedef IsbnSegments = ({
  String prefix,
  String group,
  String publisher,
  String title,
  String check,
});

/// Агрегована статистика для однієї категорії (жанру) книг.
typedef GenreStats = ({
  String genre,
  int count,
  int totalPages,
  double averageRating,
  BookRecord? topRatedBook,
});

/// Роздільник полів у вхідному CSV-наборі даних.
const String csvFieldDelimiter = ';';

/// Очікувана кількість полів у кожному CSV-рядку.
const int expectedCsvFieldCount = 9;

/// Регулярний вираз для перевірки та розбору номера ISBN-13 з іменованими групами:
/// - `prefix` — префікс GS1 (`978` або `979`);
/// - `group` — ідентифікатор мовної або національної групи;
/// - `publisher` — код видавництва;
/// - `title` — ідентифікатор конкретного видання;
/// - `check` — контрольна цифра.
final RegExp isbn13RegExp = RegExp(
  r'^(?<prefix>97[89])-(?<group>\d{1,5})-(?<publisher>\d{1,7})-(?<title>\d{1,6})-(?<check>\d)$',
);

/// Константний вхідний набір даних у CSV-подібному форматі (18 записів).
///
/// Формат полів:
/// `id;title;author;genre;year;pages;rating;isbn;addedDate`
///
/// Набір містить:
/// - 12 повністю коректних записів різних жанрів;
/// - 4 навмисно пошкоджені рядки (відсутні поля, нечисловий рік, нечисловий рейтинг, некоректна дата);
/// - 2 синтаксично розбірні рядки з порушенням допустимих діапазонів або формату ISBN.
const List<String> rawBooksCsv = <String>[
  'BK-001;Тигролови;Іван Багряний;Класика;1944;304;4.9;978-966-038-840-6;2025-01-15',
  'BK-002;Місто;Валер’ян Підмогильний;Класика;1928;288;4.8;978-617-754-420-2;2025-02-10',
  'BK-003;Захар Беркут;Іван Франко;Класика;1883;240;4.7;978-966-105-231-3;2025-03-05',
  'BK-004;Чистий код;Роберт Мартін;Програмування;2008;464;4.8;978-617-095-285-1;2025-01-20',
  'BK-005;Прагматичний програміст;Ендрю Гант;Програмування;2019;352;4.9;978-966-982-110-2;2025-04-12',
  'BK-006;Шаблони проєктування;Еріх Гамма;Програмування;1994;395;4.6;978-617-782-109-9;2025-05-18',
  'BK-007;Дюна;Френк Герберт;Фантастика;1965;656;4.9;978-617-122-554-1;2025-02-28',
  'BK-008;Фундація;Айзек Азімов;Фантастика;1951;255;4.7;978-617-123-890-9;2025-06-01',
  'BK-009;Соляріс;Станіслав Лем;Фантастика;1961;288;4.6;978-966-148-773-3;2025-07-14',
  'BK-010;Брама Європи;Сергій Плохій;Історія;2015;496;4.9;978-617-120-220-7;2025-03-22',
  'BK-011;Історія України-Руси;Михайло Грушевський;Історія;1898;640;4.8;978-966-001-318-6;2025-08-09',
  'BK-012;Подолати минуле;Ярослав Грицак;Історія;2021;432;4.7;978-617-796-599-1;2025-09-19',
  // Пошкоджений рядок №1: відсутні поля (лише 5 полів замість 9)
  'BK-ERR1;Неповний запис;Невідомий автор;Класика;2020',
  // Пошкоджений рядок №2: нечислове значення у полі року та кількості сторінок
  'BK-ERR2;Помилковий рік;Олександр Довженко;Класика;тисяча_дев_ятсот;триста;4.5;978-966-038-111-7;2025-04-01',
  // Пошкоджений рядок №3: нечислове значення у полі рейтингу
  'BK-ERR3;Зламаний рейтинг;Леся Українка;Класика;1911;210;відмінно;978-966-038-222-3;2025-04-15',
  // Пошкоджений рядок №4: некоректний формат дати
  'BK-ERR4;Некоректна дата;Айзек Азімов;Фантастика;1982;412;4.4;978-617-123-444-4;2025-19-99',
  // Запис із порушенням діапазонів (рік у майбутньому, від’ємні сторінки, рейтинг > 5.0)
  'BK-VAL1;Книга з майбутнього;Тестовий Автор;Фантастика;2099;-50;6.5;978-617-123-000-2;2025-10-01',
  // Запис із некоректним форматом ISBN-13
  'BK-VAL2;Книга з хибним ISBN;Тестовий Автор;Програмування;2022;320;4.2;123-INVALID-ISBN;2025-10-05',
];

/// Розбирає один CSV-рядок [line] у запис книги [BookRecord] разом з описом помилки.
///
/// Не використовує `try/catch` для очікуваних помилок формату — натомість
/// застосовує `split`, `int.tryParse`, `double.tryParse` та `DateTime.tryParse`.
ParseResult parseLineWithDiagnostics(
  String line, {
  int lineNumber = 0,
  String delimiter = csvFieldDelimiter,
}) {
  final trimmedLine = line.trim();
  if (trimmedLine.isEmpty) {
    return (
      lineNumber: lineNumber,
      rawLine: line,
      book: null,
      error: 'Рядок порожній',
    );
  }

  final parts = trimmedLine
      .split(delimiter)
      .map((part) => part.trim())
      .toList();
  if (parts.length != expectedCsvFieldCount) {
    return (
      lineNumber: lineNumber,
      rawLine: line,
      book: null,
      error:
          'Некоректна кількість полів: очікувалося $expectedCsvFieldCount, отримано ${parts.length}',
    );
  }

  final id = parts[0];
  final title = parts[1];
  final author = parts[2];
  final genre = parts[3];
  final yearStr = parts[4];
  final pagesStr = parts[5];
  final ratingStr = parts[6];
  final isbn = parts[7];
  final dateStr = parts[8];

  if (id.isEmpty ||
      title.isEmpty ||
      author.isEmpty ||
      genre.isEmpty ||
      isbn.isEmpty) {
    return (
      lineNumber: lineNumber,
      rawLine: line,
      book: null,
      error: 'Одне з обов’язкових текстових полів порожнє',
    );
  }

  final year = int.tryParse(yearStr);
  if (year == null) {
    return (
      lineNumber: lineNumber,
      rawLine: line,
      book: null,
      error: 'Некоректне ціле число в полі року видання: "$yearStr"',
    );
  }

  final pages = int.tryParse(pagesStr);
  if (pages == null) {
    return (
      lineNumber: lineNumber,
      rawLine: line,
      book: null,
      error: 'Некоректне ціле число в полі кількості сторінок: "$pagesStr"',
    );
  }

  final rating = double.tryParse(ratingStr);
  if (rating == null) {
    return (
      lineNumber: lineNumber,
      rawLine: line,
      book: null,
      error: 'Некоректне дробове число в полі рейтингу: "$ratingStr"',
    );
  }

  final datePattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');
  final parsedDate = datePattern.hasMatch(dateStr)
      ? DateTime.tryParse(dateStr)
      : null;
  // DateTime.tryParse може нормалізувати неіснуючі дати на кшталт 2025-19-99,
  // тому додатково звіряємо компоненти розібраної дати з вхідним рядком.
  final dateParts = dateStr.split('-');
  final expectedYear = dateParts.length == 3
      ? int.tryParse(dateParts[0])
      : null;
  final expectedMonth = dateParts.length == 3
      ? int.tryParse(dateParts[1])
      : null;
  final expectedDay = dateParts.length == 3 ? int.tryParse(dateParts[2]) : null;

  final isStrictValidDate =
      parsedDate != null &&
      parsedDate.year == expectedYear &&
      parsedDate.month == expectedMonth &&
      parsedDate.day == expectedDay;

  if (!isStrictValidDate) {
    return (
      lineNumber: lineNumber,
      rawLine: line,
      book: null,
      error: 'Некоректна дата додавання (очікується YYYY-MM-DD): "$dateStr"',
    );
  }

  return (
    lineNumber: lineNumber,
    rawLine: line,
    book: (
      id: id,
      title: title,
      author: author,
      genre: genre,
      year: year,
      pages: pages,
      rating: rating,
      isbn: isbn,
      addedDate: parsedDate,
    ),
    error: null,
  );
}

/// Розбирає рядок [line] у запис предметної області [BookRecord].
///
/// Повертає `null`, якщо рядок не відповідає очікуваному CSV-формату.
BookRecord? parseLine(String line, {String delimiter = csvFieldDelimiter}) {
  return parseLineWithDiagnostics(line, delimiter: delimiter).book;
}

/// Розбирає список вхідних CSV-рядків [lines] у список діагностичних результатів [ParseResult].
List<ParseResult> parseCsvDataset(
  List<String> lines, {
  String delimiter = csvFieldDelimiter,
}) {
  return lines.indexed
      .map(
        (entry) => parseLineWithDiagnostics(
          entry.$2,
          lineNumber: entry.$1 + 1,
          delimiter: delimiter,
        ),
      )
      .toList();
}

/// Перевіряє відповідність рядка [isbn] формату ISBN-13 за допомогою [isbn13RegExp].
bool isValidIsbn13(String isbn) => isbn13RegExp.hasMatch(isbn);

/// Витягує іменовані групи з номера [isbn], якщо він відповідає формату ISBN-13.
IsbnSegments? extractIsbnSegments(String isbn) {
  final match = isbn13RegExp.firstMatch(isbn);
  if (match == null) {
    return null;
  }
  final prefix = match.namedGroup('prefix');
  final group = match.namedGroup('group');
  final publisher = match.namedGroup('publisher');
  final title = match.namedGroup('title');
  final check = match.namedGroup('check');

  if (prefix == null ||
      group == null ||
      publisher == null ||
      title == null ||
      check == null) {
    return null;
  }

  return (
    prefix: prefix,
    group: group,
    publisher: publisher,
    title: title,
    check: check,
  );
}

/// Маскує код видавництва та видання в номері [isbn] за допомогою `replaceAllMapped`
/// та іменованих груп регулярного виразу [isbn13RegExp].
///
/// Приклад: `978-966-038-840-6` -> `978-966-***-***-6`.
String maskIsbn(String isbn, {String maskChar = '*'}) {
  return isbn.replaceAllMapped(isbn13RegExp, (match) {
    if (match is! RegExpMatch) {
      return match.group(0) ?? isbn;
    }
    final prefix = match.namedGroup('prefix') ?? '';
    final group = match.namedGroup('group') ?? '';
    final publisher = match.namedGroup('publisher') ?? '';
    final title = match.namedGroup('title') ?? '';
    final check = match.namedGroup('check') ?? '';
    final maskedPublisher = maskChar * publisher.length;
    final maskedTitle = maskChar * title.length;
    return '$prefix-$group-$maskedPublisher-$maskedTitle-$check';
  });
}

/// Перевіряє діапазони значень та формат полів запису [book].
///
/// Повертає список текстових описів виявлених порушень (порожній список, якщо запис валідний).
List<String> validateBook(
  BookRecord book, {
  int minYear = 1450,
  int maxYear = 2026,
  int minPages = 1,
  int maxPages = 5000,
  double minRating = 0.0,
  double maxRating = 5.0,
}) {
  final violations = <String>[];

  if (book.year < minYear || book.year > maxYear) {
    violations.add(
      'Рік видання (${book.year}) виходить за межі допустимого діапазону [$minYear..$maxYear]',
    );
  }

  if (book.pages < minPages || book.pages > maxPages) {
    violations.add(
      'Кількість сторінок (${book.pages}) виходить за межі діапазону [$minPages..$maxPages]',
    );
  }

  if (book.rating < minRating || book.rating > maxRating) {
    violations.add(
      'Рейтинг (${book.rating}) виходить за межі діапазону [$minRating..$maxRating]',
    );
  }

  if (!isValidIsbn13(book.isbn)) {
    violations.add(
      'Номер ISBN ("${book.isbn}") не відповідає формату ISBN-13 (978/979-група-видавець-видання-контроль)',
    );
  }

  return violations;
}

/// Виконує валідацію списку розібраних книг [books] і повертає результати перевірки.
List<ValidationResult> validateBooks(
  List<BookRecord> books, {
  int minYear = 1450,
  int maxYear = 2026,
}) {
  return books.map((book) {
    final violations = validateBook(book, minYear: minYear, maxYear: maxYear);
    return (book: book, violations: violations, isValid: violations.isEmpty);
  }).toList();
}

/// Обчислює вік запису книги [book] у повних днях відносно [referenceDate]
/// за допомогою `DateTime.difference` та `Duration`.
int calculateRecordAgeInDays(BookRecord book, {DateTime? referenceDate}) {
  final effectiveReference = referenceDate ?? DateTime.now();
  final Duration difference = effectiveReference.difference(book.addedDate);
  return difference.inDays;
}
