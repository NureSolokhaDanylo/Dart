import 'package:book_catalog/book_catalog.dart';

/// Точка входу консольної програми каталогу книг.
void main(List<String> arguments) {
  final parseResults = parseCsvDataset(rawBooksCsv);
  final parsedBooks = parseResults
      .map((result) => result.book)
      .whereType<BookRecord>()
      .toList();
  final validationResults = validateBooks(parsedBooks);
  final validBooks = validationResults
      .where((item) => item.isValid)
      .map((item) => item.book)
      .toList();

  print('Усього CSV-рядків: ${rawBooksCsv.length}');
  print('Успішно розібрано: ${parsedBooks.length}');
  print('Пройшли валідацію діапазонів та ISBN: ${validBooks.length}');
}
