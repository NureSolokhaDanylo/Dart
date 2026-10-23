import 'package:book_catalog/book_catalog.dart';
import 'package:test/test.dart';

void main() {
  test('Вхідний набір містить щонайменше 15 рядків', () {
    expect(rawBooksCsv.length, greaterThanOrEqualTo(15));
  });

  test(
    'Безпечний розбір коректно опрацьовує пошкоджені рядки без винятків',
    () {
      final results = parseCsvDataset(rawBooksCsv);
      final failed = results.where((r) => r.book == null).toList();
      expect(failed.length, greaterThanOrEqualTo(3));
      expect(parseLine('некоректний;рядок'), isNull);
    },
  );

  test('Валідація виявляє порушення діапазонів та маскує ISBN', () {
    final parsed = parseLine(rawBooksCsv.first);
    expect(parsed, isNotNull);
    if (parsed != null) {
      expect(validateBook(parsed), isEmpty);
      expect(maskIsbn(parsed.isbn), equals('978-966-***-***-6'));
      final segments = extractIsbnSegments(parsed.isbn);
      expect(segments?.prefix, equals('978'));
      expect(segments?.group, equals('966'));
      expect(segments?.check, equals('6'));
    }
  });

  test('Замикання та конвеєри where-map-fold обчислюють коректні агрегати', () {
    final counter = createRecordCounter(0);
    expect(counter.increment(), equals(1));
    expect(counter.increment(), equals(2));
    expect(counter.current(), equals(2));
    counter.reset();
    expect(counter.current(), equals(0));

    final validBooks = parseCsvDataset(rawBooksCsv)
        .map((r) => r.book)
        .whereType<BookRecord>()
        .where((b) => validateBook(b).isEmpty)
        .toList();

    final pagesAgg = aggregatePagesPipeline(validBooks, genre: 'Класика');
    expect(pagesAgg.bookCount, equals(3));
    expect(pagesAgg.totalPages, equals(832));

    final ratingsAgg = aggregateRatingsPipeline(validBooks, fromYear: 2000);
    expect(ratingsAgg.bookCount, equals(4));
    expect(ratingsAgg.averageRating, closeTo(4.825, 0.01));

    final extremes = findExtremesPipeline(validBooks);
    expect(extremes.longestBook?.title, equals('Дюна'));
    expect(extremes.shortestBook?.title, equals('Захар Беркут'));

    final found = findBookById(validBooks, 'BK-007');
    expect(found?.title, equals('Дюна'));
    expect(findBookById(validBooks, 'UNKNOWN'), isNull);

    final fallback = validBooks.first;
    final foundOrFallback = findBookByTitleOrDefault(
      validBooks,
      'Відсутня книга',
      fallback,
    );
    expect(foundOrFallback.id, equals(fallback.id));
  });

  test(
    'Групування за жанром, сортування та арифметика дат працюють коректно',
    () {
      final validBooks = parseCsvDataset(rawBooksCsv)
          .map((r) => r.book)
          .whereType<BookRecord>()
          .where((b) => validateBook(b).isEmpty)
          .toList();

      final grouped = groupBooksByGenre(validBooks);
      expect(
        grouped.keys,
        containsAll(<String>[
          'Класика',
          'Програмування',
          'Фантастика',
          'Історія',
        ]),
      );

      final stats = calculateStatsByGenre(grouped);
      expect(stats['Історія']?.count, equals(3));

      final sortedAsc = sortBooksByYear(validBooks, ascending: true);
      final sortedDesc = sortBooksByYear(validBooks, ascending: false);
      expect(sortedAsc.first.year, lessThanOrEqualTo(sortedAsc.last.year));
      expect(sortedDesc.first.year, greaterThanOrEqualTo(sortedDesc.last.year));

      final firstBook = validBooks.first;
      final ageDays = calculateRecordAgeInDays(
        firstBook,
        referenceDate: DateTime(2025, 1, 25),
      );
      expect(ageDays, equals(10));
    },
  );

  test('Формування звіту через StringBuffer повертає непорожній текст', () {
    final report = buildFullDiagnosticReport(
      rawBooksCsv,
      topCount: 5,
      ascending: false,
      separator: ' | ',
      referenceDate: DateTime(2026, 10, 22),
    );
    expect(report, contains('ЗВІТ ПО КАТАЛОГУ КНИГ БІБЛІОТЕКИ'));
    expect(report, contains('978-966-***-***-6'));
  });
}
