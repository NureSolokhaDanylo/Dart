import 'package:book_catalog/book_catalog.dart';

/// Точка входу консольної програми каталогу книг.
void main(List<String> arguments) {
  final counter = createRecordCounter();
  final parseResults = parseCsvDataset(rawBooksCsv);
  final parsedBooks = parseResults
      .map((result) => result.book)
      .whereType<BookRecord>()
      .toList();
  final validationResults = validateBooks(parsedBooks);
  final validBooks = validationResults.where((item) => item.isValid).map((
    item,
  ) {
    counter.increment();
    return item.book;
  }).toList();

  final pagesStats = aggregatePagesPipeline(validBooks, minRating: 4.7);
  final ratingStats = aggregateRatingsPipeline(validBooks, fromYear: 2000);
  final extremes = findExtremesPipeline(validBooks);

  print(
    'Оброблено валідних записів (лічильник-замикання): ${counter.current()}',
  );
  print(
    'Сторінки (рейтинг >= 4.7): усього ${pagesStats.totalPages}, '
    'середнє ${pagesStats.averagePages.toStringAsFixed(1)}',
  );
  print(
    'Середній рейтинг книг із 2000 року: '
    '${ratingStats.averageRating.toStringAsFixed(2)}',
  );
  print(
    'Найдовша книга: ${extremes.longestBook?.title} '
    '(${extremes.longestBook?.pages} стор.)',
  );
}
