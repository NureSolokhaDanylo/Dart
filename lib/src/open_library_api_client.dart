/// Клієнт для обміну даними із зовнішнім REST API (Open Library API) за протоколом HTTP
/// через `package:http` із трирівневою обробкою відмов (Пункти 10, 11 Лабораторної роботи №4).
library;

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'book_hierarchy.dart';
import 'oop_models.dart';

/// Перелічення трьох рівнів відмов мережевої взаємодії (Пункт 11).
enum NetworkFailureLevel {
  /// Рівень 1: Відсутність з’єднання, помилка DNS або розрив сокета (`SocketException` / `ClientException`).
  connectionFailure,

  /// Рівень 2: Сервер відповів кодом статусу, відмінним від `2xx` (наприклад, `404`, `429`, `500`, `503`).
  nonSuccessStatusCode,

  /// Рівень 3: Тіло відповіді пошкоджене або має неочікувану JSON-структуру (`FormatException`).
  malformedPayload,
}

/// Типізований виняток мережевої взаємодії із вказівкою рівня відмови [level].
class CatalogNetworkException implements Exception {
  /// Створює виняток мережевого рівня [level] із повідомленням [message].
  const CatalogNetworkException({
    required this.level,
    required this.message,
    this.statusCode,
    this.cause,
  });

  /// Класифікований рівень відмови (1 — з’єднання, 2 — HTTP-статус, 3 — формат тіла).
  final NetworkFailureLevel level;

  /// Людиночитабельний опис помилки українською мовою.
  final String message;

  /// Код статусу HTTP (за наявності, для відмов рівня 2).
  final int? statusCode;

  /// Первинний виняток (`SocketException`, `ClientException`, `FormatException`).
  final Object? cause;

  @override
  String toString() {
    final statusSuffix = statusCode != null ? ' (HTTP $statusCode)' : '';
    return 'CatalogNetworkException[${level.name}$statusSuffix]: $message';
  }
}

/// Виконує GET-запит до відкритого REST API Open Library (`https://openlibrary.org/search.json`)
/// через `http.Client`, перетворює знайдені записи на об’єкти [Book] та гарантовано
/// закриває клієнт у блоці `finally` (Пункти 10, 11).
///
/// Якщо передано власний [customClient] (наприклад, `MockClient` у модульних тестах),
/// управління його життєвим циклом контролюється параметром [closeClient].
Future<List<Book>> fetchBooksFromExternalApi({
  String query = 'clean code',
  int limit = 3,
  BookGenre defaultGenre = BookGenre.programming,
  Uri? customEndpoint,
  http.Client? customClient,
  bool closeClient = true,
}) async {
  final client = customClient ?? http.Client();
  final uri =
      customEndpoint ??
      Uri.https('openlibrary.org', '/search.json', <String, String>{
        'q': query,
        'limit': '$limit',
        'fields': 'key,title,author_name,first_publish_year,number_of_pages_median,ratings_average,isbn',
      });

  try {
    final http.Response response;
    try {
      // Рівень 1: Перехоплення помилок відсутності з'єднання (SocketException / ClientException)
      response = await client.get(
        uri,
        headers: const <String, String>{
          'accept': 'application/json',
          'user-agent': 'HomeLibDartLab/1.0 (Educational Console Project)',
        },
      );
    } on SocketException catch (error) {
      throw CatalogNetworkException(
        level: NetworkFailureLevel.connectionFailure,
        message:
            'Відсутнє мережеве з’єднання або вузол недоступний: ${error.message}',
        cause: error,
      );
    } on http.ClientException catch (error) {
      throw CatalogNetworkException(
        level: NetworkFailureLevel.connectionFailure,
        message:
            'Помилка HTTP-клієнта під час звернення до $uri: ${error.message}',
        cause: error,
      );
    }

    // Рівень 2: Явна перевірка коду відповіді HTTP (має належати діапазону 200..299)
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CatalogNetworkException(
        level: NetworkFailureLevel.nonSuccessStatusCode,
        statusCode: response.statusCode,
        message:
            'Зовнішній сервер повернув неуспішний статус HTTP ${response.statusCode}',
      );
    }

    // Рівень 3: Розбір JSON-тіла відповіді та перевірка очікуваної структури
    try {
      final bodyText = utf8.decode(response.bodyBytes);
      final Object? decoded = jsonDecode(bodyText);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Корінь відповіді API не є JSON-об’єктом.');
      }

      final docsField = decoded['docs'];
      if (docsField is! List<Object?>) {
        throw const FormatException('У відповіді API відсутній масив "docs".');
      }

      final resultBooks = <Book>[];
      for (final (index, rawDoc) in docsField.indexed) {
        if (rawDoc is! Map<String, Object?>) {
          throw const FormatException('Елемент "docs" не є JSON-об’єктом.');
        }
        resultBooks.add(
          _mapOpenLibraryDocToBook(
            rawDoc,
            index: index + 1,
            defaultGenre: defaultGenre,
          ),
        );
      }
      return resultBooks;
    } on FormatException catch (error) {
      throw CatalogNetworkException(
        level: NetworkFailureLevel.malformedPayload,
        message: 'Некоректне тіло відповіді REST API: ${error.message}',
        cause: error,
      );
    }
  } finally {
    if (closeClient && customClient == null) {
      client.close();
    } else if (closeClient && customClient != null) {
      customClient.close();
    }
  }
}

Book _mapOpenLibraryDocToBook(
  Map<String, Object?> doc, {
  required int index,
  required BookGenre defaultGenre,
}) {
  final rawKey = doc['key'] as String? ?? '/works/OL${100 + index}W';
  final cleanId = 'API-${rawKey.split('/').last}';
  final title = (doc['title'] as String?)?.trim();
  if (title == null || title.isEmpty) {
    throw const FormatException('У записі книги API відсутнє поле "title".');
  }

  var author = 'Невідомий автор';
  final rawAuthors = doc['author_name'];
  if (rawAuthors is List<Object?> && rawAuthors.isNotEmpty) {
    final firstAuthor = rawAuthors.first;
    if (firstAuthor is String && firstAuthor.trim().isNotEmpty) {
      author = firstAuthor.trim();
    }
  }

  final rawYear = doc['first_publish_year'];
  final year = rawYear is num ? rawYear.toInt().clamp(1450, 2026) : 2020;

  final rawPages = doc['number_of_pages_median'];
  final pages = rawPages is num ? rawPages.toInt().clamp(1, 5000) : 320;

  final rawRating = doc['ratings_average'];
  final rating = rawRating is num
      ? double.parse(rawRating.toDouble().clamp(0.0, 5.0).toStringAsFixed(1))
      : 4.5;

  final paddedIndex = index.toString().padLeft(3, '0');
  final isbn = '978-966-700-$paddedIndex-${index % 10}';

  return Book(
    id: cleanId,
    title: title,
    author: author,
    genre: defaultGenre,
    year: year,
    pages: pages,
    rating: rating,
    isbn: isbn,
    addedDate: DateTime.utc(2026, 10, 19),
    format: const EBookFormat(
      fileExtension: 'JSON/REST',
      fileSizeMb: 2.4,
      hasDrmProtection: false,
    ),
  );
}
