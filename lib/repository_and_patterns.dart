/// Узагальнене сховище [Repository], повернення та деструктуризація записів (Records)
/// і зіставлення зі зразком з охоронцями `when` (Пункти 4, 9, 11, 12).
library;

import 'book_catalog.dart' as lab1;
import 'book_hierarchy.dart';
import 'mixins_and_extensions.dart';
import 'oop_models.dart';

/// Узагальнений клас-сховище сутностей, які реалізують контракт [Identifiable] (Пункт 9).
///
/// Обмеження параметра типу `T extends Identifiable`:
/// 1. Забороняє інстанціювання сховища примітивами чи непов’язаними класами (наприклад, `Repository<int>`);
/// 2. Відкриває компілятору прямий доступ до гетера `item.id` всередині методів [add] та [addAll]
///    без необхідності динамічних перевірок чи приведення типів.
class Repository<T extends Identifiable> {
  final Map<String, T> _items = <String, T>{};

  /// Додає або оновлює сутність [item] у сховищі за ключем `item.id`.
  void add(T item) => _items[item.id] = item;

  /// Додає колекцію сутностей [items] до сховища.
  void addAll(Iterable<T> items) {
    for (final item in items) {
      add(item);
    }
  }

  /// Повертає сутність за ідентифікатором [id] або `null`, якщо її не знайдено.
  T? findById(String id) => _items[id];

  /// Видаляє сутність за ідентифікатором [id]. Повертає `true`, якщо елемент існував.
  bool removeById(String id) => _items.remove(id) != null;

  /// Фільтрує елементи сховища за предикатом [test].
  Iterable<T> where(bool Function(T) test) => _items.values.where(test);

  /// Повертає незмінний список усіх елементів у сховищі.
  List<T> get all => List<T>.unmodifiable(_items.values);

  /// Загальна кількість збережених елементів.
  int get count => _items.length;
}

/// Результат імпорту CSV-рядків у типізоване сховище [Repository] (Пункт 11).
typedef RepositoryImportSummary = ({
  Repository<Book> repository,
  List<({int lineNumber, String reason})> rejectedLines,
  int cacheHits,
});

/// Комплексний кортеж аналітики сховища для демонстрації позиційної та іменованої деструктуризації.
typedef CatalogOverviewRecord = (
  Book? minRatedBook,
  Book? maxRatedBook,
  ({int totalPages, double averageRating, int modernCount}) stats,
);

/// Завантажує список CSV-рядків [csvLines] у сховище `Repository<Book>` і повертає
/// запис [RepositoryImportSummary] із трьома значеннями (Пункт 11).
RepositoryImportSummary importBooksToRepository(
  List<String> csvLines, {
  String delimiter = lab1.csvFieldDelimiter,
}) {
  Book.clearCache();
  final repository = Repository<Book>();
  final rejected = <({int lineNumber, String reason})>[];

  for (final (index, rawLine) in csvLines.indexed) {
    final lineNumber = index + 1;
    final diagnostic = lab1.parseLineWithDiagnostics(
      rawLine,
      lineNumber: lineNumber,
      delimiter: delimiter,
    );
    final parsedRecord = diagnostic.book;
    if (parsedRecord == null) {
      rejected.add((
        lineNumber: lineNumber,
        reason: diagnostic.error ?? 'Помилка синтаксичного розбору',
      ));
      continue;
    }

    final violations = lab1.validateBook(parsedRecord);
    if (violations.isNotEmpty) {
      rejected.add((lineNumber: lineNumber, reason: violations.join('; ')));
      continue;
    }

    final book = Book.fromCsvCached(rawLine, delimiter: delimiter);
    repository.add(book);
  }

  return (
    repository: repository,
    rejectedLines: rejected,
    cacheHits: Book.cacheHitCount,
  );
}

/// Обчислює агрегований запис [CatalogOverviewRecord] для сховища книг [repository] (Пункт 11).
CatalogOverviewRecord computeCatalogOverview(Repository<Book> repository) {
  final books = repository.all;
  if (books.isEmpty) {
    return (null, null, (totalPages: 0, averageRating: 0.0, modernCount: 0));
  }

  Book? minBook;
  Book? maxBook;
  var modernCount = 0;

  for (final book in books) {
    if (minBook == null || book.rating < minBook.rating) {
      minBook = book;
    }
    if (maxBook == null || book.rating > maxBook.rating) {
      maxBook = book;
    }
    if (book.isModernEdition) {
      modernCount += 1;
    }
  }

  return (
    minBook,
    maxBook,
    (
      totalPages: books.totalPages,
      averageRating: books.averageRating,
      modernCount: modernCount,
    ),
  );
}

/// Класифікує книгу [book] за допомогою зіставлення зі зразком (pattern matching)
/// об’єктних шаблонів та охоронців `when` (Пункт 12).
String classifyBookWithPatterns(Book book) {
  return switch (book) {
    Book(
      :final rating,
      format: CollectorFormat(:final isSignedByAuthor, :final printRunLimit),
    )
        when rating >= 4.8 && isSignedByAuthor && printRunLimit <= 1000 =>
      'Музейний раритет (підпис автора, наклад $printRunLimit прим., ★$rating)',
    Book(genre: BookGenre.programming, :final rating, :final year)
        when rating >= 4.7 && year >= 2005 =>
      'Сучасний бестселер з інженерії ПЗ ($year р., ★$rating)',
    Book(:final rating, :final pages) when rating >= 4.8 && pages >= 450 =>
      'Монументальне високорейтингове видання ($pages стор., ★$rating)',
    Book(:final year, :final rating) when year < 1950 && rating >= 4.7 =>
      'Золотий фонд класичної спадщини ($year р., ★$rating)',
    Book(format: AudioBookFormat(:final durationMinutes, :final narrator))
        when durationMinutes >= 300 =>
      'Повноформатна аудіовистава ($durationMinutes хв, диктор: $narrator)',
    Book(:final rating) when rating >= 4.5 =>
      'Рекомендоване видання основного фонду (★$rating)',
    Book() => 'Стандартний примірник каталогу',
  };
}

/// Демонструє роботу `Set<Book>` із перевизначеними `==` і `hashCode` (Пункт 4).
///
/// Створює два незалежні екземпляри [Book] з однаковими значеннями полів і перевіряє
/// дедуплікацію в множині `Set<Book>`.
({
  int setLength,
  bool areEqual,
  bool areIdentical,
  int firstHash,
  int secondHash,
})
verifySetEqualityBehavior() {
  final firstCopy = Book(
    id: 'BK-001',
    title: 'Тигролови',
    author: 'Іван Багряний',
    genre: BookGenre.classics,
    year: 1944,
    pages: 304,
    rating: 4.9,
    isbn: '978-966-038-840-6',
    addedDate: DateTime.utc(2025, 1, 15),
  );
  final secondCopy = Book(
    id: 'BK-001',
    title: 'Тигролови',
    author: 'Іван Багряний',
    genre: BookGenre.classics,
    year: 1944,
    pages: 304,
    rating: 4.9,
    isbn: '978-966-038-840-6',
    addedDate: DateTime.utc(2025, 1, 15),
  );

  final bookSet = <Book>{firstCopy, secondCopy};
  return (
    setLength: bookSet.length,
    areEqual: firstCopy == secondCopy,
    areIdentical: identical(firstCopy, secondCopy),
    firstHash: firstCopy.hashCode,
    secondHash: secondCopy.hashCode,
  );
}

/// Формує розгорнутий текстовий звіт по об’єктно-орієнтованій моделі каталогу (Лабораторна робота №2).
String buildOopCatalogReport(List<String> rawCsvLines) {
  final buffer = StringBuffer();

  // Пункт 11: Деструктуризація іменованого запису, поверненого з функції імпорту
  final (:repository, :rejectedLines, :cacheHits) = importBooksToRepository(
    rawCsvLines,
  );

  // Додаткове звернення до кешованого конструктора для перевірки роботи кешу
  Book.fromCsvCached(rawCsvLines.first);
  final updatedCacheHits = Book.cacheHitCount;

  buffer.writeln(
    '============================================================',
  );
  buffer.writeln(
    '      ЗВІТ ЛАБОРАТОРНОЇ РОБОТИ №2 (ООП-МОДЕЛЬ КАТАЛОГУ)     ',
  );
  buffer.writeln(
    '============================================================',
  );
  buffer.writeln(
    'Успішно імпортовано у Repository<Book>: ${repository.count} об’єктів',
  );
  buffer.writeln(
    'Відхилено пошкоджених/невалідних рядків: ${rejectedLines.length}',
  );
  buffer.writeln(
    'Влучань у кеш фабричного конструктора Book.fromCsvCached: '
    '$updatedCacheHits (під час первинного імпорту: $cacheHits)',
  );

  // Пункт 4: Перевірка рівності за значенням у Set<Book>
  final (:setLength, :areEqual, :areIdentical, :firstHash, :secondHash) =
      verifySetEqualityBehavior();
  buffer.writeln('');
  buffer.writeln('--- 1. Перевірка == та hashCode у Set<Book> (Пункт 4) ---');
  buffer.writeln(
    'Два окремі екземпляри Book("BK-001"): identical=$areIdentical, '
    'operator==: $areEqual',
  );
  buffer.writeln(
    'hashCode №1: $firstHash | hashCode №2: $secondHash | '
    'Розмір Set<Book>: $setLength',
  );

  // Пункт 11: Позиційна та вкладена іменована деструктуризація запису огляду
  final (minBook, maxBook, (:totalPages, :averageRating, :modernCount)) =
      computeCatalogOverview(repository);

  buffer.writeln('');
  buffer.writeln(
    '--- 2. Деструктуризація агрегованого запису та методи розширення (Пункти 8, 11) ---',
  );
  buffer.writeln(
    'Сумарно сторінок: $totalPages | Середній рейтинг: '
    '${averageRating.toStringAsFixed(2)} | Сучасних видань (з 2000 р.): $modernCount',
  );
  if (maxBook != null && minBook != null) {
    buffer.writeln(
      'Лідер рейтингу: "${maxBook.title}" (${maxBook.rating}) | '
      'Мінімальний рейтинг: "${minBook.title}" (${minBook.rating})',
    );
  }

  // Пункти 5, 6, 12: Ієрархія sealed class BookFormat, вичерпний switch та pattern matching з when
  buffer.writeln('');
  buffer.writeln(
    '--- 3. Поліморфізм BookFormat, switch без default та шаблони з when (Пункти 5, 6, 12) ---',
  );
  for (final book in repository.all.sortedByRating().take(6)) {
    final badge = formatCarrierBadge(book.format);
    final handlingCost = calculateFormatHandlingCost(book.format, book.pages);
    final weight = book.format.estimatePhysicalWeightGrams(book.pages);
    final classification = classifyBookWithPatterns(book);
    buffer.writeln(
      '${book.id} $badge "${book.title}" | '
      'Обслуговування: ${handlingCost.toStringAsFixed(2)} грн | '
      'Маса: ${weight.toStringAsFixed(0)} г',
    );
    buffer.writeln('   Умови: ${book.format.describeStorageRequirements()}');
    buffer.writeln('   Класифікація (when): $classification');
  }

  // Пункт 7 та 9: Домішка CatalogExportable на двох різних класах та Repository<ReaderLoanTicket>
  buffer.writeln('');
  buffer.writeln(
    '--- 4. Домішка CatalogExportable та узагальнений Repository<T> (Пункти 7, 9, 10) ---',
  );
  final ticketRepo = Repository<ReaderLoanTicket>();
  ticketRepo.add(
    ReaderLoanTicket(
      id: 'TCK-101',
      readerName: 'Коваленко Олена',
      bookId: 'BK-001',
      createdAt: DateTime.utc(2026, 10, 10),
      loanDays: BookGenre.classics.maxLoanDays,
    ),
  );

  final sampleBook = repository.findById('BK-001');
  final sampleTicket = ticketRepo.findById('TCK-101');
  if (sampleBook != null) {
    buffer.writeln('Картка книги (mixin): ${sampleBook.toCatalogCardLine()}');
    buffer.writeln(
      'Правило жанру (enum): ${sampleBook.genre.describeCatalogRule()}',
    );
  }
  if (sampleTicket != null) {
    buffer.writeln(
      'Картка формуляра (mixin): ${sampleTicket.toCatalogCardLine()}',
    );
  }

  return buffer.toString();
}
