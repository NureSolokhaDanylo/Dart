/// HTTP-сервіс каталогу книг на базі пакетів `shelf` та `shelf_router`
/// із власними проміжними обробниками `Middleware` та маршрутами
/// `GET /items`, `GET /items/<id>`, `POST /items` (Пункти 13–18).
library;

import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';

import 'async_repository.dart';
import 'json_file_storage.dart';
import 'lab1_functional.dart';
import 'oop_models.dart';

/// Розбирає початковий набір валідних книг із вбудованого CSV [rawBooksCsv].
List<Book> parseDefaultCatalogSeedBooks() {
  final books = <Book>[];
  for (final rawLine in rawBooksCsv) {
    final trimmed = rawLine.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final parsed = Book.tryParseCsv(trimmed);
    if (parsed != null) {
      books.add(parsed);
    }
  }
  return books;
}

/// Створює асинхронне сховище [AsyncRepository], ініціалізоване даними
/// зі спільного локального файлу `books.json` (або вбудованим CSV-набором,
/// якщо файл іще не створено) (Пункт 15).
Future<AsyncRepository<Book>> createSharedCatalogRepository({
  String fileName = defaultBooksJsonFileName,
  Duration operationDelay = const Duration(milliseconds: 5),
}) async {
  List<Book> initialBooks;
  try {
    initialBooks = await loadBooksFromJsonFile(fileName: fileName);
  } on FileSystemException {
    initialBooks = parseDefaultCatalogSeedBooks();
    await saveBooksToJsonFile(initialBooks, fileName: fileName);
  }
  return AsyncRepository<Book>(
    readDelay: operationDelay,
    writeDelay: operationDelay,
    initialItems: initialBooks,
  );
}

/// Стандартні заголовки відповіді JSON у кодуванні UTF-8 (Пункт 17).
const Map<String, String> jsonUtf8Headers = <String, String>{
  'content-type': 'application/json; charset=utf-8',
};

/// Допоміжна функція для формування [Response] із серіалізованим JSON-тілом (Пункт 17).
Response _jsonResponse(
  int statusCode,
  Map<String, Object?> body, {
  Map<String, String>? extraHeaders,
}) {
  final headers = <String, String>{...jsonUtf8Headers, ...?extraHeaders};
  return Response(
    statusCode,
    body: const JsonEncoder.withIndent('  ').convert(body),
    headers: headers,
  );
}

/// Власний проміжний обробник [Middleware] для журналювання HTTP-запитів
/// із вимірюванням часу виконання через [Stopwatch] (Пункт 16).
Middleware catalogRequestLogger({void Function(String message)? onLog}) {
  return (Handler innerHandler) {
    return (Request request) async {
      final watch = Stopwatch()..start();
      final response = await innerHandler(request);
      watch.stop();

      final elapsedMs = watch.elapsedMilliseconds;
      final querySuffix = request.requestedUri.hasQuery
          ? '?${request.requestedUri.query}'
          : '';
      final logLine =
          '[SHELF LOG] ${request.method} /${request.url.path}$querySuffix -> '
          '${response.statusCode} (${elapsedMs}ms)';
      if (onLog != null) {
        onLog(logLine);
      } else {
        stdout.writeln(logLine);
      }

      return response.change(
        headers: <String, String>{
          ...jsonUtf8Headers,
          ...response.headers,
          'x-response-time-ms': '$elapsedMs',
        },
      );
    };
  };
}

/// Власний проміжний обробник [Middleware] для єдиного перехоплення непередбачених
/// винятків і повернення структурованої JSON-помилки (Пункт 16).
Middleware catalogErrorBoundary({void Function(String message)? onLog}) {
  return (Handler innerHandler) {
    return (Request request) async {
      try {
        return await innerHandler(request);
      } on Object catch (error) {
        final msg = '[SHELF ERROR] Необроблений виняток: $error';
        if (onLog != null) {
          onLog(msg);
        } else {
          stderr.writeln(msg);
        }
        return _jsonResponse(500, <String, Object?>{
          'error': 'Internal Server Error',
          'message': 'Внутрішня помилка сервера під час обробки запиту.',
          'details': error.toString(),
        });
      }
    };
  };
}

/// Будує маршрутизатор [Router] для HTTP-сервісу каталогу книг над спільним
/// асинхронним сховищем [repository] (Пункти 14, 15, 17).
///
/// Реалізує три обов’язкові маршрути:
/// - `GET /items` із підтримкою фільтрації за параметрами запиту (`genre`, `minRating`, `year`, `q`);
/// - `GET /items/<id>` із поверненням `200 OK` або `404 Not Found`;
/// - `POST /items` із валідацією JSON-тіла через [Book.fromJson] та поверненням `201 Created` або `400 Bad Request`.
Router buildCatalogRouter(
  AsyncRepository<Book> repository, {
  String? persistFileName,
}) {
  final router = Router();

  // Маршрут 1: GET /items (з фільтрацією за query-параметрами)
  router.get('/items', (Request request) async {
    final queryParams = request.url.queryParameters;
    final genreParam = queryParams['genre']?.trim().toLowerCase();
    final searchParam = queryParams['q']?.trim().toLowerCase();
    final minRatingRaw = queryParams['minRating'];
    final yearRaw = queryParams['year'];

    double? minRatingFilter;
    if (minRatingRaw != null && minRatingRaw.isNotEmpty) {
      final parsedRating = double.tryParse(minRatingRaw);
      if (parsedRating == null || parsedRating < 0.0 || parsedRating > 5.0) {
        return _jsonResponse(400, <String, Object?>{
          'error': 'Bad Request',
          'message':
              'Некоректний параметр запиту "minRating": "$minRatingRaw" (очікується число 0.0..5.0).',
        });
      }
      minRatingFilter = parsedRating;
    }

    int? yearFilter;
    if (yearRaw != null && yearRaw.isNotEmpty) {
      final parsedYear = int.tryParse(yearRaw);
      if (parsedYear == null || parsedYear < 1450 || parsedYear > 2026) {
        return _jsonResponse(400, <String, Object?>{
          'error': 'Bad Request',
          'message':
              'Некоректний параметр запиту "year": "$yearRaw" (очікується рік 1450..2026).',
        });
      }
      yearFilter = parsedYear;
    }

    final allBooks = await repository.loadAll();
    final filteredBooks = allBooks.where((book) {
      if (genreParam != null && genreParam.isNotEmpty) {
        final matchesGenre =
            book.genre.name.toLowerCase() == genreParam ||
            book.genre.displayName.toLowerCase() == genreParam;
        if (!matchesGenre) {
          return false;
        }
      }
      if (minRatingFilter != null && book.rating < minRatingFilter) {
        return false;
      }
      if (yearFilter != null && book.year != yearFilter) {
        return false;
      }
      if (searchParam != null && searchParam.isNotEmpty) {
        final inTitle = book.title.toLowerCase().contains(searchParam);
        final inAuthor = book.author.toLowerCase().contains(searchParam);
        if (!inTitle && !inAuthor) {
          return false;
        }
      }
      return true;
    }).toList();

    return _jsonResponse(200, <String, Object?>{
      'count': filteredBooks.length,
      'items': filteredBooks.map((book) => book.toJson()).toList(),
    });
  });

  // Маршрут 2: GET /items/<id> (200 OK або 404 Not Found)
  router.get('/items/<id>', (Request request, String id) async {
    final trimmedId = Uri.decodeComponent(id).trim();
    final book = await repository.load(trimmedId);
    if (book == null) {
      return _jsonResponse(404, <String, Object?>{
        'error': 'Not Found',
        'message':
            'Книгу з ідентифікатором "$trimmedId" не знайдено у сховищі.',
        'id': trimmedId,
      });
    }
    return _jsonResponse(200, book.toJson());
  });

  // Маршрут 3: POST /items (перевірка тіла запиту, 201 Created або 400 Bad Request)
  router.post('/items', (Request request) async {
    final rawBody = await request.readAsString(utf8);
    if (rawBody.trim().isEmpty) {
      return _jsonResponse(400, <String, Object?>{
        'error': 'Bad Request',
        'message': 'Тіло POST-запиту не може бути порожнім.',
      });
    }

    final Object? decoded;
    try {
      decoded = jsonDecode(rawBody);
    } on FormatException catch (e) {
      return _jsonResponse(400, <String, Object?>{
        'error': 'Bad Request',
        'message': 'Невалідний синтаксис JSON у тілі запиту: ${e.message}',
      });
    }

    if (decoded is! Map<String, Object?>) {
      return _jsonResponse(400, <String, Object?>{
        'error': 'Bad Request',
        'message': 'Тіло запиту повинно бути JSON-об’єктом книги.',
      });
    }

    final Book createdBook;
    try {
      createdBook = Book.fromJson(decoded);
    } on FormatException catch (e) {
      return _jsonResponse(400, <String, Object?>{
        'error': 'Bad Request',
        'message': 'Помилка валідації полів книги: ${e.message}',
      });
    }

    await repository.save(createdBook);
    if (persistFileName != null && persistFileName.isNotEmpty) {
      final allCurrent = await repository.loadAll();
      await saveBooksToJsonFile(allCurrent, fileName: persistFileName);
    }

    return _jsonResponse(201, <String, Object?>{
      'status': 'created',
      'item': createdBook.toJson(),
    });
  });

  // Fallback для невідомих маршрутів (усі відповіді — JSON з UTF-8)
  router.all('/<ignored|.*>', (Request request) {
    return _jsonResponse(404, <String, Object?>{
      'error': 'Not Found',
      'message': 'Маршрут "${request.method} /${request.url.path}" не існує.',
    });
  });

  return router;
}

/// Будує повний конвеєр обробників `shelf` за допомогою
/// `Pipeline().addMiddleware(...).addHandler(...)` (Пункт 14).
Handler buildCatalogServerHandler(
  AsyncRepository<Book> repository, {
  void Function(String message)? onLog,
  String? persistFileName,
}) {
  final router = buildCatalogRouter(
    repository,
    persistFileName: persistFileName,
  );
  return const Pipeline()
      .addMiddleware(catalogRequestLogger(onLog: onLog))
      .addMiddleware(catalogErrorBoundary(onLog: onLog))
      .addHandler(router.call);
}

/// Запускає HTTP-сервер `shelf` на вказаному хості та порту (Пункти 14, 15).
Future<HttpServer> startCatalogHttpServer(
  AsyncRepository<Book> repository, {
  Object address = '127.0.0.1',
  int port = 8080,
  void Function(String message)? onLog,
  String? persistFileName,
}) async {
  final handler = buildCatalogServerHandler(
    repository,
    onLog: onLog,
    persistFileName: persistFileName,
  );
  final server = await shelf_io.serve(handler, address, port);
  return server;
}
