import 'package:book_catalog/book_catalog.dart';

/// Точка входу консольної програми каталогу книг.
void main(List<String> arguments) {
  final parseResults = parseCsvDataset(rawBooksCsv);
  final validBooks = parseResults
      .map((result) => result.book)
      .whereType<BookRecord>()
      .where((book) => validateBook(book).isEmpty)
      .toList();

  final grouped = groupBooksByGenre(validBooks);
  final statsByGenre = calculateStatsByGenre(grouped);

  print('Групування за жанрами (${statsByGenre.length} категорії):');
  for (final entry in statsByGenre.entries) {
    final stat = entry.value;
    print(
      ' - ${stat.genre}: ${stat.count} кн., '
      'середній рейтинг ${stat.averageRating.toStringAsFixed(2)}, '
      'усього ${stat.totalPages} стор.',
    );
  }

  final topByRating = sortBooksByRating(validBooks, ascending: false).take(3);
  print('\nТоп-3 за рейтингом:');
  for (final book in topByRating) {
    print(' * ${book.title} (${book.year}) — ${book.rating}');
  }
}
