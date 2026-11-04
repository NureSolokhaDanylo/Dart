/// Збереження та читання каталогу книг у форматі JSON (`books.json`), побудова шляхів
/// через `package:path` (`p.join`) та потокове читання великих файлів через `openRead()`
/// (Пункти 7, 8 Лабораторної роботи №4).
library;

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import 'oop_models.dart';

/// Ім’я файлу локального JSON-сховища за замовчуванням.
const String defaultBooksJsonFileName = 'books.json';

/// Будує кросплатформний шлях до файлу каталогу за допомогою `p.join` (Пункт 7).
String resolveBooksJsonPath({
  String? directoryPath,
  String fileName = defaultBooksJsonFileName,
}) {
  final baseDir = directoryPath ?? Directory.current.path;
  return p.join(baseDir, fileName);
}

/// Зберігає список книг [books] у файл формату JSON за шляхом, побудованим через `p.join` (Пункт 7).
///
/// Повертає повний шлях до збереженого файлу.
Future<String> saveBooksToJsonFile(
  List<Book> books, {
  String? directoryPath,
  String fileName = defaultBooksJsonFileName,
}) async {
  final filePath = resolveBooksJsonPath(
    directoryPath: directoryPath,
    fileName: fileName,
  );
  final file = File(filePath);
  await file.parent.create(recursive: true);

  final payload = <String, Object?>{
    'version': 1,
    'generatedAt': DateTime.utc(2026, 10, 22).toIso8601String(),
    'count': books.length,
    'items': books.map((book) => book.toJson()).toList(),
  };

  const encoder = JsonEncoder.withIndent('  ');
  await file.writeAsString(encoder.convert(payload), encoding: utf8);
  return filePath;
}

/// Завантажує список книг [Book] із JSON-файлу за шляхом, побудованим через `p.join` (Пункт 7, 9).
///
/// Оскільки `jsonDecode` повертає `dynamic`, результат одразу перевіряється та
/// приводиться до типізованої структури `Map<String, Object?>` або `List<Object?>`
/// із викликом конструктора [Book.fromJson].
Future<List<Book>> loadBooksFromJsonFile({
  String? directoryPath,
  String fileName = defaultBooksJsonFileName,
}) async {
  final filePath = resolveBooksJsonPath(
    directoryPath: directoryPath,
    fileName: fileName,
  );
  final file = File(filePath);
  if (!await file.exists()) {
    throw FileSystemException('Файл каталогу не знайдено', filePath);
  }

  final rawContent = await file.readAsString(encoding: utf8);
  return decodeBooksJsonString(rawContent);
}

/// Декодує JSON-рядок [rawJson] (об’єкт з ключем `items` або масив книг) у список [Book].
List<Book> decodeBooksJsonString(String rawJson) {
  final Object? decoded = jsonDecode(rawJson);

  final List<Object?> rawItems;
  if (decoded is Map<String, Object?>) {
    final itemsField = decoded['items'];
    if (itemsField is! List<Object?>) {
      throw const FormatException(
        'У JSON-об’єкті каталогу відсутній масив "items".',
      );
    }
    rawItems = itemsField;
  } else if (decoded is List<Object?>) {
    rawItems = decoded;
  } else {
    throw const FormatException(
      'Очікувався JSON-об’єкт або JSON-масив записів книг.',
    );
  }

  final books = <Book>[];
  for (final entry in rawItems) {
    if (entry is! Map<String, Object?>) {
      throw const FormatException('Елемент масиву книг не є JSON-об’єктом.');
    }
    books.add(Book.fromJson(entry));
  }
  return books;
}

/// Результат потокового читання великого текстового файлу через `openRead()` (Пункт 8).
typedef StreamedFileReadSummary = ({
  int totalLinesRead,
  int validBooksParsed,
  int invalidLinesSkipped,
  List<Book> books,
});

/// Читає великий текстовий CSV/лог-файл порційно через `File.openRead()`
/// із конвеєром декодерів `utf8.decoder` та `LineSplitter()` без завантаження
/// всього файлу в оперативну пам’ять (Пункт 8).
Future<StreamedFileReadSummary> readLargeCatalogFileStreaming(
  String filePath, {
  String delimiter = ';',
}) async {
  final file = File(filePath);
  if (!await file.exists()) {
    throw FileSystemException('Файл для потокового читання не існує', filePath);
  }

  var totalLines = 0;
  var validCount = 0;
  var skippedCount = 0;
  final parsedBooks = <Book>[];

  final Stream<String> lines = file
      .openRead()
      .transform(utf8.decoder)
      .transform(const LineSplitter());

  await for (final line in lines) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) {
      continue;
    }
    totalLines += 1;
    final book = Book.tryParseCsv(trimmed, delimiter: delimiter);
    if (book != null) {
      validCount += 1;
      parsedBooks.add(book);
    } else {
      skippedCount += 1;
    }
  }

  return (
    totalLinesRead: totalLines,
    validBooksParsed: validCount,
    invalidLinesSkipped: skippedCount,
    books: parsedBooks,
  );
}
