import 'package:book_catalog/book_catalog.dart';
import 'package:test/test.dart';

void main() {
  test('Вхідний набір містить щонайменше 15 рядків', () {
    expect(rawBooksCsv.length, greaterThanOrEqualTo(15));
  });
}
