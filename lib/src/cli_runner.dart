/// Інтерфейс командного рядка (CLI) на основі пакета `args` та розділення
/// потоків виведення `stdout` / `stderr` (Пункти 6, 12).
library;

import 'dart:io';

import 'package:args/args.dart';

import 'json_file_storage.dart';
import 'oop_models.dart';
import 'open_library_api_client.dart';

/// Розпізнана конфігурація запуску консольного застосунку (Пункт 6).
class CliInvocationConfig {
  /// Назва команди (`list`, `import`, `fetch`, `serve` або `demo`).
  final String command;

  /// Чи запитано виведення довідки (`--help` / `-h`).
  final bool showHelp;

  /// Шлях до локального JSON-файлу (`--file` / `-f`).
  final String filePath;

  /// Опціональний фільтр за жанром (`--genre` / `-g`).
  final String? genreFilter;

  /// Мінімальний рейтинг (`--min-rating` / `-r`).
  final double minRating;

  /// Максимальна кількість записів (`--limit` / `-l`).
  final int limit;

  /// Пошуковий запит для команди `fetch` (`--query` / `-q`).
  final String query;

  /// Порт HTTP-сервера для команди `serve` (`--port` / `-p`).
  final int port;

  /// Створює конфігурацію виклику CLI.
  const CliInvocationConfig({
    required this.command,
    required this.showHelp,
    required this.filePath,
    this.genreFilter,
    required this.minRating,
    required this.limit,
    required this.query,
    required this.port,
  });
}

/// Створює парсер аргументів командного рядка `ArgParser` (Пункт 6).
///
/// Підтримує 4 команди (`list`, `import`, `fetch`, `serve`) та 6 опцій/прапорців
/// (`--help`, `--file`, `--genre`, `--min-rating`, `--limit`, `--port`).
ArgParser buildCatalogArgParser() {
  final listParser = ArgParser()
    ..addOption(
      'genre',
      abbr: 'g',
      help: 'Фільтрувати каталог за назвою жанру.',
    )
    ..addOption(
      'min-rating',
      abbr: 'r',
      defaultsTo: '0.0',
      help: 'Мінімальний поріг рейтингу книги (1.0..5.0).',
    )
    ..addOption(
      'limit',
      abbr: 'l',
      defaultsTo: '20',
      help: 'Максимальна кількість записів для виведення.',
    );

  final importParser = ArgParser()
    ..addOption(
      'limit',
      abbr: 'l',
      defaultsTo: '50',
      help: 'Максимальна кількість книг для імпорту з CSV у JSON.',
    );

  final fetchParser = ArgParser()
    ..addOption(
      'query',
      abbr: 'q',
      defaultsTo: 'clean code',
      help: 'Пошуковий запит до зовнішнього REST API OpenLibrary.',
    )
    ..addOption(
      'limit',
      abbr: 'l',
      defaultsTo: '3',
      help: 'Кількість записів для завантаження з мережі.',
    );

  final serveParser = ArgParser()
    ..addOption(
      'port',
      abbr: 'p',
      defaultsTo: '8080',
      help: 'TCP-порт для запуску HTTP-сервісу shelf.',
    );

  return ArgParser()
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Вивести довідку щодо команд та опцій CLI.',
    )
    ..addOption(
      'file',
      abbr: 'f',
      defaultsTo: 'books.json',
      help: 'Шлях до локального файлу каталогу у форматі JSON.',
    )
    ..addOption(
      'genre',
      abbr: 'g',
      help: 'Глобальний фільтр за жанром (для режиму list).',
    )
    ..addOption(
      'min-rating',
      abbr: 'r',
      defaultsTo: '0.0',
      help: 'Глобальний мінімальний рейтинг книги.',
    )
    ..addOption(
      'limit',
      abbr: 'l',
      defaultsTo: '20',
      help: 'Глобальне обмеження кількості записів.',
    )
    ..addCommand('list', listParser)
    ..addCommand('import', importParser)
    ..addCommand('fetch', fetchParser)
    ..addCommand('serve', serveParser);
}

/// Формує текст довідки CLI на основі `ArgParser.usage`.
String formatCliUsage(ArgParser parser) {
  final buffer = StringBuffer()
    ..writeln('Використання: dart run bin/book_catalog.dart <команда> [опції]')
    ..writeln()
    ..writeln('Доступні команди:')
    ..writeln('  list     Вивести список книг із локального JSON-файлу')
    ..writeln('  import   Імпортувати вбудований CSV-набір у локальний JSON')
    ..writeln('  fetch    Завантажити книги із зовнішнього REST API у JSON')
    ..writeln('  serve    Запустити HTTP-сервер каталогу (shelf)')
    ..writeln()
    ..writeln('Глобальні опції:')
    ..writeln(parser.usage);
  return buffer.toString();
}

/// Розбирає список аргументів командного рядка у [CliInvocationConfig] (Пункт 6).
///
/// Кидає [FormatException], якщо передано невідому опцію, команду або
/// некоректне числове значення.
CliInvocationConfig parseCatalogCliArgs(List<String> arguments) {
  final parser = buildCatalogArgParser();
  final ArgResults results;
  try {
    results = parser.parse(arguments);
  } on ArgParserException catch (e) {
    throw FormatException('Помилка аргументів командного рядка: ${e.message}');
  }

  final showHelp = results['help'] as bool;
  final filePath = results['file'] as String;
  final cmdResults = results.command;

  if (results.rest.isNotEmpty && cmdResults == null) {
    throw FormatException(
      'Невідома команда або аргумент: "${results.rest.first}". '
      'Використайте --help для перегляду списку команд.',
    );
  }

  final commandName = cmdResults?.name ?? 'demo';

  String readOption(String key, String fallback) {
    if (cmdResults != null && cmdResults.options.contains(key)) {
      final val = cmdResults[key] as String?;
      if (val != null) {
        return val;
      }
    }
    if (results.options.contains(key)) {
      final val = results[key] as String?;
      if (val != null) {
        return val;
      }
    }
    return fallback;
  }

  String? readNullableOption(String key) {
    if (cmdResults != null && cmdResults.options.contains(key)) {
      final val = cmdResults[key] as String?;
      if (val != null) {
        return val;
      }
    }
    if (results.options.contains(key)) {
      return results[key] as String?;
    }
    return null;
  }

  final minRatingRaw = readOption('min-rating', '0.0');
  final minRating = double.tryParse(minRatingRaw);
  if (minRating == null || minRating < 0.0 || minRating > 5.0) {
    throw FormatException(
      'Некоректне значення --min-rating: "$minRatingRaw" (очікується 0.0..5.0).',
    );
  }

  final limitRaw = readOption('limit', '20');
  final limit = int.tryParse(limitRaw);
  if (limit == null || limit <= 0) {
    throw FormatException(
      'Некоректне значення --limit: "$limitRaw" (очікується ціле число > 0).',
    );
  }

  final portRaw = readOption('port', '8080');
  final port = int.tryParse(portRaw);
  if (port == null || port <= 0 || port > 65535) {
    throw FormatException(
      'Некоректне значення --port: "$portRaw" (очікується 1..65535).',
    );
  }

  final query = readOption('query', 'clean code');
  final genre = readNullableOption('genre');

  return CliInvocationConfig(
    command: commandName,
    showHelp: showHelp,
    filePath: filePath,
    genreFilter: genre,
    minRating: minRating,
    limit: limit,
    query: query,
    port: port,
  );
}

/// Виконує команду CLI з чітким розділенням потоків `stdout` та `stderr`
/// і встановленням глобального `exitCode` у разі помилки (Пункт 12).
///
/// Повертає підсумковий код завершення (`0` — успіх, `64` — помилка аргументів,
/// `1` — помилка виконання або файлу).
Future<int> executeCatalogCli(
  List<String> arguments, {
  required List<Book> seedBooks,
  StringSink? outSink,
  StringSink? errSink,
}) async {
  final out = outSink ?? stdout;
  final err = errSink ?? stderr;
  final parser = buildCatalogArgParser();

  final CliInvocationConfig config;
  try {
    config = parseCatalogCliArgs(arguments);
  } on FormatException catch (e) {
    err.writeln('[CLI ERROR] ${e.message}');
    err.writeln(formatCliUsage(parser));
    exitCode = 64;
    return 64;
  }

  if (config.showHelp) {
    out.writeln(formatCliUsage(parser));
    exitCode = 0;
    return 0;
  }

  try {
    switch (config.command) {
      case 'import':
        final imported = seedBooks.take(config.limit).toList();
        final savedPath = await saveBooksToJsonFile(
          imported,
          fileName: config.filePath,
        );
        out.writeln(
          '[CLI IMPORT] Успішно збережено ${imported.length} книг у файл "$savedPath".',
        );
        exitCode = 0;
        return 0;

      case 'list':
        List<Book> books;
        try {
          books = await loadBooksFromJsonFile(fileName: config.filePath);
        } on FileSystemException {
          books = seedBooks;
        }
        final genreFilter = config.genreFilter?.toLowerCase();
        final filtered = books
            .where((b) {
              final matchesGenre =
                  genreFilter == null ||
                  b.genre.displayName.toLowerCase() == genreFilter ||
                  b.genre.name.toLowerCase() == genreFilter;
              final matchesRating = b.rating >= config.minRating;
              return matchesGenre && matchesRating;
            })
            .take(config.limit)
            .toList();

        out.writeln(
          '[CLI LIST] Знайдено ${filtered.length} книг (файл: ${config.filePath}):',
        );
        for (final book in filtered) {
          out.writeln(
            '  - [${book.id}] "${book.title}" — ${book.author} '
            '(${book.genre.displayName}, ★ ${book.rating.toStringAsFixed(2)})',
          );
        }
        exitCode = 0;
        return 0;

      case 'fetch':
        final List<Book> apiBooks;
        try {
          apiBooks = await fetchBooksFromExternalApi(
            query: config.query,
            limit: config.limit,
          );
        } on CatalogNetworkException catch (netErr) {
          err.writeln(
            '[CLI FETCH ERROR] Рівень: ${netErr.level.name} — ${netErr.message}',
          );
          exitCode = 1;
          return 1;
        }
        final savedPath = await saveBooksToJsonFile(
          apiBooks,
          fileName: config.filePath,
        );
        out.writeln(
          '[CLI FETCH] Отримано з REST API та збережено ${apiBooks.length} книг '
          'за запитом "${config.query}" у "$savedPath".',
        );
        for (final book in apiBooks) {
          out.writeln('  * [${book.id}] "${book.title}" — ${book.author}');
        }
        exitCode = 0;
        return 0;

      default:
        exitCode = 0;
        return 0;
    }
  } on Exception catch (e) {
    err.writeln(
      '[CLI RUNTIME ERROR] Не вдалося виконати команду "${config.command}": $e',
    );
    exitCode = 1;
    return 1;
  }
}
