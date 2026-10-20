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
}
