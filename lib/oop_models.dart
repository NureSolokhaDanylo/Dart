/// Об’єктно-орієнтована модель предметної області «Каталог книг» (Лабораторна робота №2).
///
/// Містить інтерфейс [Identifiable], розширене перелічення [BookGenre]
/// та незмінний клас сутності [Book] із генеративним, іменованим і фабричними
/// конструкторами, обчислюваними гетерами та перевизначенням `==` і `hashCode`.
library;

import 'book_catalog.dart' as lab1;

/// Базовий інтерфейс для всіх сутностей предметної області з унікальним ідентифікатором.
abstract interface class Identifiable {
  /// Унікальний рядковий ідентифікатор сутності.
  String get id;
}

/// Перелічення жанрів книг із полями, константним конструктором та методами (Пункт 10).
enum BookGenre {
  /// Класична художня література.
  classics(
    displayName: 'Класика',
    deweyCode: '800',
    maxLoanDays: 30,
    isTechnical: false,
  ),

  /// Професійна література з розроблення ПЗ та комп’ютерних наук.
  programming(
    displayName: 'Програмування',
    deweyCode: '005',
    maxLoanDays: 21,
    isTechnical: true,
  ),

  /// Наукова фантастика та футурологія.
  scienceFiction(
    displayName: 'Фантастика',
    deweyCode: '808.838762',
    maxLoanDays: 14,
    isTechnical: false,
  ),

  /// Історичні дослідження та монографії.
  history(
    displayName: 'Історія',
    deweyCode: '900',
    maxLoanDays: 28,
    isTechnical: false,
  );

  /// Константний конструктор перелічення жанру.
  const BookGenre({
    required this.displayName,
    required this.deweyCode,
    required this.maxLoanDays,
    required this.isTechnical,
  });

  /// Локалізована назва жанру українською мовою.
  final String displayName;

  /// Код десяткової класифікації Дьюї.
  final String deweyCode;

  /// Рекомендований максимальний термін видачі книги в днях.
  final int maxLoanDays;

  /// Ознака належності жанру до технічної/спеціалізованої літератури.
  final bool isTechnical;

  /// Формує текстову довідку про правила каталогізації жанру.
  String describeCatalogRule() {
    final categoryType = isTechnical ? 'технічна' : 'гуманітарна/художня';
    return '$displayName (УДК/Дьюї $deweyCode, $categoryType, до $maxLoanDays дн.)';
  }

  /// Розбирає текстову назву жанру [rawGenre] у значення перелічення [BookGenre].
  ///
  /// Повертає `null`, якщо назва не відповідає жодному відомому жанру.
  static BookGenre? tryParse(String rawGenre) {
    final normalized = rawGenre.trim().toLowerCase();
    for (final genre in BookGenre.values) {
      if (genre.displayName.toLowerCase() == normalized ||
          genre.name.toLowerCase() == normalized) {
        return genre;
      }
    }
    return null;
  }
}

/// Незмінний клас-сутність книги в каталозі бібліотеки (Пункти 1, 2, 4).
class Book implements Identifiable {
  /// Генеративний константний конструктор створення екземпляра [Book].
  const Book({
    required this.id,
    required this.title,
    required this.author,
    required this.genre,
    required this.year,
    required this.pages,
    required this.rating,
    required this.isbn,
    required this.addedDate,
  });

  /// Іменований конструктор, який створює об’єкт [Book] із рядка CSV [line] (Пункт 2).
  Book.fromCsv(String line, {String delimiter = lab1.csvFieldDelimiter})
    : this._fromParsedRecord(
        lab1.parseLine(line, delimiter: delimiter),
        rawLine: line,
      );

  /// Приватний делегуючий конструктор для ініціалізації полів із розібраного запису.
  Book._fromParsedRecord(lab1.BookRecord? record, {required String rawLine})
    : id = record?.id ?? 'INVALID',
      title = record?.title ?? 'Некоректний CSV-рядок: ${rawLine.trim()}',
      author = record?.author ?? 'Невідомий',
      genre =
          (record != null ? BookGenre.tryParse(record.genre) : null) ??
          BookGenre.classics,
      year = record?.year ?? 1900,
      pages = record?.pages ?? 1,
      rating = record?.rating ?? 0.0,
      isbn = record?.isbn ?? '000-000-000-000-0',
      addedDate = record?.addedDate ?? DateTime.utc(1970, 1, 1);

  /// Внутрішній кеш створених екземплярів [Book] за ключем [id].
  static final Map<String, Book> _instanceCache = <String, Book>{};

  /// Кількість звернень до фабричного конструктора, що повернули об’єкт із кешу.
  static int get cacheHitCount => _cacheHits;
  static int _cacheHits = 0;

  /// Очищує внутрішній кеш екземплярів [Book] та скидає лічильник влучань.
  static void clearCache() {
    _instanceCache.clear();
    _cacheHits = 0;
  }

  /// Фабричний конструктор, який реалізує кешування за [id] або повернення
  /// безпечного екземпляра за замовчуванням при порожньому [id] (Пункт 2).
  factory Book.cached({
    required String id,
    required String title,
    required String author,
    required BookGenre genre,
    required int year,
    required int pages,
    required double rating,
    required String isbn,
    required DateTime addedDate,
  }) {
    final normalizedId = id.trim();
    if (normalizedId.isEmpty) {
      return Book.fallback();
    }
    final existing = _instanceCache[normalizedId];
    if (existing != null) {
      _cacheHits += 1;
      return existing;
    }
    final created = Book(
      id: normalizedId,
      title: title,
      author: author,
      genre: genre,
      year: year,
      pages: pages,
      rating: rating,
      isbn: isbn,
      addedDate: addedDate,
    );
    _instanceCache[normalizedId] = created;
    return created;
  }

  /// Фабричний конструктор безпечного розбору CSV-рядка з кешуванням за [id].
  factory Book.fromCsvCached(
    String line, {
    String delimiter = lab1.csvFieldDelimiter,
  }) {
    final parsed = tryParseCsv(line, delimiter: delimiter);
    if (parsed == null) {
      return Book.fallback();
    }
    final cached = _instanceCache[parsed.id];
    if (cached != null) {
      _cacheHits += 1;
      return cached;
    }
    _instanceCache[parsed.id] = parsed;
    return parsed;
  }

  /// Фабричний конструктор, що повертає еталонний екземпляр книги за замовчуванням.
  factory Book.fallback([String fallbackId = 'BK-DEFAULT']) {
    return _instanceCache.putIfAbsent(
      fallbackId,
      () => Book(
        id: fallbackId,
        title: 'Резервний запис каталогу',
        author: 'Невідомий автор',
        genre: BookGenre.classics,
        year: 2000,
        pages: 100,
        rating: 3.5,
        isbn: '978-966-000-000-0',
        addedDate: DateTime.utc(2025, 1, 1),
      ),
    );
  }

  /// Безпечно розбирає CSV-рядок [line] і перевіряє діапазони значень.
  static Book? tryParseCsv(
    String line, {
    String delimiter = lab1.csvFieldDelimiter,
  }) {
    final record = lab1.parseLine(line, delimiter: delimiter);
    if (record == null) {
      return null;
    }
    final violations = lab1.validateBook(record);
    if (violations.isNotEmpty) {
      return null;
    }
    final parsedGenre = BookGenre.tryParse(record.genre);
    if (parsedGenre == null) {
      return null;
    }
    return Book(
      id: record.id,
      title: record.title,
      author: record.author,
      genre: parsedGenre,
      year: record.year,
      pages: record.pages,
      rating: record.rating,
      isbn: record.isbn,
      addedDate: record.addedDate,
    );
  }

  @override
  final String id;

  /// Назва книги.
  final String title;

  /// Автор книги.
  final String author;

  /// Категорія жанру книги (перелічення [BookGenre]).
  final BookGenre genre;

  /// Рік видання.
  final int year;

  /// Кількість сторінок.
  final int pages;

  /// Середня оцінка читачів за шкалою `0.0..5.0`.
  final double rating;

  /// Міжнародний номер книги у форматі ISBN-13.
  final String isbn;

  /// Дата внесення запису до каталогу.
  final DateTime addedDate;

  /// Гетер обчислюваної властивості: чи належить видання до сучасної літератури (з 2000 р.).
  bool get isModernEdition => year >= 2000;

  /// Гетер обчислюваної властивості: орієнтовний час читання у годинах (40 стор./год).
  double get estimatedReadingHours => pages / 40.0;

  /// Гетер обчислюваної властивості: маскований номер ISBN-13.
  String get maskedIsbn => lab1.maskIsbn(isbn);

  /// Гетер обчислюваної властивості: короткий бібліографічний шифр книги.
  String get bibliographicCode => '${genre.deweyCode}/$id-$year';

  /// Обчислює вік запису книги в каталозі у днях відносно [referenceDate].
  int ageInDays([DateTime? referenceDate]) {
    final effective = referenceDate ?? DateTime(2026, 10, 22);
    return effective.difference(addedDate).inDays;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is Book &&
        other.id == id &&
        other.title == title &&
        other.author == author &&
        other.genre == genre &&
        other.year == year &&
        other.pages == pages &&
        other.rating == rating &&
        other.isbn == isbn &&
        other.addedDate == addedDate;
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    author,
    genre,
    year,
    pages,
    rating,
    isbn,
    addedDate,
  );

  @override
  String toString() {
    return 'Book(id: $id, title: "$title", author: $author, '
        'genre: ${genre.displayName}, year: $year, pages: $pages, '
        'rating: ${rating.toStringAsFixed(1)}, isbn: $maskedIsbn)';
  }
}
