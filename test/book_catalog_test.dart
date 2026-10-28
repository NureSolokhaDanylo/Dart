import 'package:book_catalog/book_catalog.dart';
import 'package:test/test.dart';

void main() {
  group('Лабораторна робота №1: Функції та колекції', () {
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

    test(
      'Замикання та конвеєри where-map-fold обчислюють коректні агрегати',
      () {
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
      },
    );

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
        expect(
          sortedDesc.first.year,
          greaterThanOrEqualTo(sortedDesc.last.year),
        );

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
  });

  group('Лабораторна робота №2: Об’єктно-орієнтована модель', () {
    test(
      'Конструктори Book.fromCsv, Book.fromCsvCached, == та hashCode у Set',
      () {
        Book.clearCache();
        final book1 = Book.fromCsv(rawBooksCsv.first);
        final book2 = Book.fromCsv(rawBooksCsv.first);

        expect(identical(book1, book2), isFalse);
        expect(book1, equals(book2));
        expect(book1.hashCode, equals(book2.hashCode));

        final bookSet = <Book>{book1, book2};
        expect(bookSet.length, equals(1));

        final cached1 = Book.fromCsvCached(rawBooksCsv.first);
        final cached2 = Book.fromCsvCached(rawBooksCsv.first);
        expect(identical(cached1, cached2), isTrue);
        expect(Book.cacheHitCount, equals(1));

        final fallback = Book.fromCsvCached('некоректний;рядок');
        expect(fallback.id, equals('BK-DEFAULT'));
      },
    );

    test('Запечатана ієрархія BookFormat та вичерпний switch без default', () {
      const formats = <BookFormat>[
        PrintedFormat(isHardcover: true, paperDensityGrams: 80),
        EBookFormat(fileExtension: 'EPUB', fileSizeMb: 5.0),
        AudioBookFormat(durationMinutes: 360, narrator: 'Диктор'),
        CollectorFormat(printRunLimit: 250, isSignedByAuthor: true),
      ];

      for (final fmt in formats) {
        expect(calculateFormatHandlingCost(fmt, 300), greaterThan(0));
        expect(formatCarrierBadge(fmt), isNotEmpty);
        expect(fmt.describeStorageRequirements(), isNotEmpty);
      }
    });

    test('Домішка CatalogExportable, розширення та Repository<T extends Identifiable>', () {
      final (:repository, :rejectedLines, :cacheHits) = importBooksToRepository(
        rawBooksCsv,
      );
      expect(repository.count, equals(12));
      expect(rejectedLines.length, equals(6));
      expect(cacheHits, equals(0));

      final dune = repository.findById('BK-007');
      expect(dune, isNotNull);
      if (dune != null) {
        expect(dune.toCatalogCardLine(), contains('BK-007'));
        expect(classifyBookWithPatterns(dune), contains('Музейний раритет'));
      }

      final (minBook, maxBook, (:totalPages, :averageRating, :modernCount)) =
          computeCatalogOverview(repository);
      expect(minBook, isNotNull);
      expect(maxBook, isNotNull);
      expect(totalPages, equals(4810));
      expect(averageRating, closeTo(4.775, 0.01));
      expect(modernCount, equals(4));

      final oopReport = buildOopCatalogReport(rawBooksCsv);
      expect(oopReport, contains('ЗВІТ ЛАБОРАТОРНОЇ РОБОТИ №2'));
    });
  });
}
