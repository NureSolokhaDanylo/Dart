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
    },
  );

  test('Валідація виявляє порушення діапазонів та маскує ISBN', () {
    final parsed = parseLine(rawBooksCsv.first);
    expect(parsed, isNotNull);
    if (parsed != null) {
      expect(validateBook(parsed), isEmpty);
      expect(maskIsbn(parsed.isbn), equals('978-966-***-***-6'));
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

    final found = findBookById(validBooks, 'BK-007');
    expect(found?.title, equals('Дюна'));
  });

  test(
    'Групування за жанром та сортування за двома критеріями працюють коректно',
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
    },
  );
}
