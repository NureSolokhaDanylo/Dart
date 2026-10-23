import 'package:book_catalog/book_catalog.dart';

/// Точка входу консольної програми каталогу книг (Лабораторна робота №1).
void main(List<String> arguments) {
  final referenceDate = DateTime(2026, 10, 22);

  // 1. Повний діагностичний та аналітичний звіт за константним набором CSV
  final fullReport = buildFullDiagnosticReport(
    rawBooksCsv,
    topCount: 5,
    ascending: false,
    separator: ' | ',
    referenceDate: referenceDate,
  );
  print(fullReport);

  // 2. Демонстрація сортування за другим критерієм (рік видання, за зростанням)
  final validBooks = parseCsvDataset(rawBooksCsv)
      .map((r) => r.book)
      .whereType<BookRecord>()
      .where((b) => validateBook(b).isEmpty)
      .toList();

  print('--- Сортування за роком видання (за зростанням, перші 4 книги) ---');
  final chronological = sortBooksByYear(validBooks, ascending: true).take(4);
  for (final book in chronological) {
    print(
      '  ${book.year} р. — "${book.title}" (${book.author}, ${book.pages} стор.)',
    );
  }

  // 3. Демонстрація пошуку через firstOrNull та firstWhere з orElse
  print('\n--- Пошук елементів у колекції ---');
  final foundById = findBookById(validBooks, 'BK-004');
  if (foundById != null) {
    final segments = extractIsbnSegments(foundById.isbn);
    print(
      'Знайдено за ID (firstOrNull): "${foundById.title}", '
      'ISBN префікс=${segments?.prefix}, група=${segments?.group}, '
      'маскований ISBN=${maskIsbn(foundById.isbn)}',
    );
  }

  final fallbackBook = validBooks.first;
  final foundByTitle = findBookByTitleOrDefault(
    validBooks,
    'Неіснуюча назва',
    fallbackBook,
  );
  print(
    'Пошук із резервним значенням (firstWhere + orElse): '
    'отримано "${foundByTitle.title}" [${foundByTitle.id}]',
  );
}
