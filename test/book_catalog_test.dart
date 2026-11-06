import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:book_catalog/book_catalog.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:test/test.dart';

void main() {
  group('Лабораторна робота №1: Функції та колекції', () {
    test('Вхідний набір містить щонайменше 15 рядків', () {
      expect(rawBooksCsv.length, greaterThanOrEqualTo(15));
    });

    test(
      'Безпечний розбір коректно опрацьовує пошкоджені рядки без винятків',
      () {
        final results = parseCsvDataset(rawBooksCsv);
        final failed = results.where((r) => r.book == null).toList();
        expect(failed.length, greaterThanOrEqualTo(3));
        expect(parseLine('некоректний;рядок'), isNull);
      },
    );

    test('Валідація виявляє порушення діапазонів та маскує ISBN', () {
      final parsed = parseLine(rawBooksCsv.first);
      expect(parsed, isNotNull);
      if (parsed != null) {
        expect(validateBook(parsed), isEmpty);
        expect(maskIsbn(parsed.isbn), equals('978-966-***-***-6'));
        final segments = extractIsbnSegments(parsed.isbn);
        expect(segments?.prefix, equals('978'));
        expect(segments?.group, equals('966'));
        expect(segments?.check, equals('6'));
      }
    });

    test(
      'Замикання та конвеєри where-map-fold обчислюють коректні агрегати',
      () {
        final counter = createRecordCounter(0);
        expect(counter.increment(), equals(1));
        expect(counter.increment(), equals(2));
        expect(counter.current(), equals(2));
        counter.reset();
        expect(counter.current(), equals(0));

        final validBooks = parseCsvDataset(rawBooksCsv)
            .map((r) => r.book)
            .whereType<BookRecord>()
            .where((b) => validateBook(b).isEmpty)
            .toList();

        final pagesAgg = aggregatePagesPipeline(validBooks, genre: 'Класика');
        expect(pagesAgg.bookCount, equals(3));
        expect(pagesAgg.totalPages, equals(832));

        final ratingsAgg = aggregateRatingsPipeline(validBooks, fromYear: 2000);
        expect(ratingsAgg.bookCount, equals(4));
        expect(ratingsAgg.averageRating, closeTo(4.825, 0.01));

        final extremes = findExtremesPipeline(validBooks);
        expect(extremes.longestBook?.title, equals('Дюна'));
        expect(extremes.shortestBook?.title, equals('Захар Беркут'));

        final found = findBookById(validBooks, 'BK-007');
        expect(found?.title, equals('Дюна'));
        expect(findBookById(validBooks, 'UNKNOWN'), isNull);

        final fallback = validBooks.first;
        final foundOrFallback = findBookByTitleOrDefault(
          validBooks,
          'Відсутня книга',
          fallback,
        );
        expect(foundOrFallback.id, equals(fallback.id));
      },
    );

    test(
      'Групування за жанром, сортування та арифметика дат працюють коректно',
      () {
        final validBooks = parseCsvDataset(rawBooksCsv)
            .map((r) => r.book)
            .whereType<BookRecord>()
            .where((b) => validateBook(b).isEmpty)
            .toList();

        final grouped = groupBooksByGenre(validBooks);
        expect(
          grouped.keys,
          containsAll(<String>[
            'Класика',
            'Програмування',
            'Фантастика',
            'Історія',
          ]),
        );

        final stats = calculateStatsByGenre(grouped);
        expect(stats['Історія']?.count, equals(3));

        final sortedAsc = sortBooksByYear(validBooks, ascending: true);
        final sortedDesc = sortBooksByYear(validBooks, ascending: false);
        expect(sortedAsc.first.year, lessThanOrEqualTo(sortedAsc.last.year));
        expect(
          sortedDesc.first.year,
          greaterThanOrEqualTo(sortedDesc.last.year),
        );

        final firstBook = validBooks.first;
        final ageDays = calculateRecordAgeInDays(
          firstBook,
          referenceDate: DateTime(2025, 1, 25),
        );
        expect(ageDays, equals(10));
      },
    );

    test('Формування звіту через StringBuffer повертає непорожній текст', () {
      final report = buildFullDiagnosticReport(
        rawBooksCsv,
        topCount: 5,
        ascending: false,
        separator: ' | ',
        referenceDate: DateTime(2026, 10, 22),
      );
      expect(report, contains('ЗВІТ ПО КАТАЛОГУ КНИГ БІБЛІОТЕКИ'));
      expect(report, contains('978-966-***-***-6'));
    });
  });

  group('Лабораторна робота №2: Об’єктно-орієнтована модель', () {
    test(
      'Конструктори Book.fromCsv, Book.fromCsvCached, == та hashCode у Set',
      () {
        Book.clearCache();
        final book1 = Book.fromCsv(rawBooksCsv.first);
        final book2 = Book.fromCsv(rawBooksCsv.first);

        expect(identical(book1, book2), isFalse);
        expect(book1, equals(book2));
        expect(book1.hashCode, equals(book2.hashCode));

        final bookSet = <Book>{book1, book2};
        expect(bookSet.length, equals(1));

        final cached1 = Book.fromCsvCached(rawBooksCsv.first);
        final cached2 = Book.fromCsvCached(rawBooksCsv.first);
        expect(identical(cached1, cached2), isTrue);
        expect(Book.cacheHitCount, equals(1));

        final fallback = Book.fromCsvCached('некоректний;рядок');
        expect(fallback.id, equals('BK-DEFAULT'));
      },
    );

    test('Запечатана ієрархія BookFormat та вичерпний switch без default', () {
      const formats = <BookFormat>[
        PrintedFormat(isHardcover: true, paperDensityGrams: 80),
        EBookFormat(fileExtension: 'EPUB', fileSizeMb: 5.0),
        AudioBookFormat(durationMinutes: 360, narrator: 'Диктор'),
        CollectorFormat(printRunLimit: 250, isSignedByAuthor: true),
      ];

      for (final fmt in formats) {
        expect(calculateFormatHandlingCost(fmt, 300), greaterThan(0));
        expect(formatCarrierBadge(fmt), isNotEmpty);
        expect(fmt.describeStorageRequirements(), isNotEmpty);
      }
    });

    test('Домішка CatalogExportable, розширення та Repository<T extends Identifiable>', () {
      final (:repository, :rejectedLines, :cacheHits) = importBooksToRepository(
        rawBooksCsv,
      );
      expect(repository.count, equals(12));
      expect(rejectedLines.length, equals(6));
      expect(cacheHits, equals(0));

      final dune = repository.findById('BK-007');
      expect(dune, isNotNull);
      if (dune != null) {
        expect(dune.toCatalogCardLine(), contains('BK-007'));
        expect(classifyBookWithPatterns(dune), contains('Музейний раритет'));
      }

      final (minBook, maxBook, (:totalPages, :averageRating, :modernCount)) =
          computeCatalogOverview(repository);
      expect(minBook, isNotNull);
      expect(maxBook, isNotNull);
      expect(totalPages, equals(4810));
      expect(averageRating, closeTo(4.775, 0.01));
      expect(modernCount, equals(4));

      final oopReport = buildOopCatalogReport(rawBooksCsv);
      expect(oopReport, contains('ЗВІТ ЛАБОРАТОРНОЇ РОБОТИ №2'));
    });
  });

  group('Лабораторна робота №3: Асинхронність, потоки та ізоляти', () {
    var seedBooks = <Book>[];
    var asyncRepo = AsyncRepository<Book>();

    setUp(() {
      final (:repository, rejectedLines: _, cacheHits: _) =
          importBooksToRepository(rawBooksCsv);
      seedBooks = repository.all;
      asyncRepo = AsyncRepository<Book>(
        readDelay: const Duration(milliseconds: 15),
        writeDelay: const Duration(milliseconds: 15),
        streamInterval: const Duration(milliseconds: 10),
        initialItems: seedBooks.take(3),
      );
    });

    test('1. AsyncRepository виконує завантаження, збереження та видалення через Future', () async {
      await expectLater(
        asyncRepo.load('BK-001'),
        completion(isA<Book>().having((b) => b.title, 'title', 'Тигролови')),
      );

      final newBook = seedBooks[3];
      await asyncRepo.save(newBook);
      await expectLater(
        asyncRepo.load(newBook.id),
        completion(equals(newBook)),
      );

      await expectLater(asyncRepo.delete('BK-001'), completion(isTrue));
      await expectLater(asyncRepo.load('BK-001'), completion(isNull));
    });

    test('2. AsyncRepository.loadOrThrow генерує виняток CatalogAsyncException при помилці', () async {
      await expectLater(
        asyncRepo.loadOrThrow('BK-NOT-FOUND'),
        throwsA(
          isA<CatalogAsyncException>().having(
            (e) => e.operationId,
            'operationId',
            'BK-NOT-FOUND',
          ),
        ),
      );

      await expectLater(
        asyncRepo.loadOrThrow('BK-001', simulateFailure: true),
        throwsA(isA<CatalogAsyncException>()),
      );
    });

    test(
      '3. Одночасне виконання через Future.wait швидше за послідовні await',
      () async {
        final timing = await measureSequentialVsConcurrent(asyncRepo, <String>[
          'BK-001',
          'BK-002',
          'BK-003',
        ], operationDelay: const Duration(milliseconds: 60));
        expect(timing.sequentialElapsedMs, greaterThanOrEqualTo(150));
        expect(
          timing.concurrentElapsedMs,
          lessThan(timing.sequentialElapsedMs),
        );
        expect(timing.loadedBooks.whereType<Book>().length, equals(3));
      },
    );

    test('4. ParallelWaitError зберігає успішні значення та помилки окремо на відміну від Future.wait', () async {
      final comparison = await compareGroupErrorHandling(
        asyncRepo,
        firstValidId: 'BK-001',
        failingId: 'BK-002',
        thirdValidId: 'BK-003',
        operationDelay: const Duration(milliseconds: 15),
      );
      expect(comparison.futureWaitRecoveredCount, equals(0));
      expect(comparison.futureWaitCaughtError, contains('BK-002'));
      expect(
        comparison.parallelWaitValuesTitles,
        equals(<String?>['Тигролови', null, 'Захар Беркут']),
      );
      expect(comparison.parallelWaitErrorMessages[0], isNull);
      expect(comparison.parallelWaitErrorMessages[1], contains('BK-002'));
      expect(comparison.parallelWaitErrorMessages[2], isNull);
    });

    test('5. Генератор async* watchAll видає книги у суворо визначеному порядку (emitsInOrder)', () async {
      final idStream = asyncRepo.watchAll().map((book) => book.id);
      await expectLater(
        idStream,
        emitsInOrder(<Object>['BK-001', 'BK-002', 'BK-003', emitsDone]),
      );
    });

    test('6. StreamController буферизує 3 події до підписки, а конвеєр трансформує потік', () async {
      final bufferedResult = await demonstrateBufferedControllerAndListen(
        seedBooks,
      );
      expect(bufferedResult.receivedEvents.length, equals(3));
      expect(bufferedResult.subscriptionExplicitlyCancelled, isTrue);

      final controller = StreamController<CatalogEvent>();
      final now = DateTime.utc(2026, 10, 16);
      for (final book in seedBooks.take(5)) {
        controller.add(BookAddedEvent(book: book, timestamp: now));
      }
      unawaited(controller.close());

      final pipelineStream = buildEventTransformationPipeline(
        controller.stream,
        minRating: 4.9,
        maxEvents: 2,
      );

      await expectLater(
        pipelineStream,
        emitsInOrder(<Object>[
          contains('Тигролови'),
          contains('Прагматичний програміст'),
          emitsDone,
        ]),
      );
    });

    test('7. Потік з помилкою посередині та повторна підписка на одноразовий Stream', () async {
      final midErr = await compareMidStreamErrorBehavior(seedBooks);
      expect(midErr.awaitForReceivedIds, equals(<String>['BK-001', 'BK-002']));
      expect(
        midErr.listenReceivedIds,
        equals(<String>['BK-001', 'BK-002', 'BK-003']),
      );

      final broadcastDemo = await demonstrateSingleVsBroadcastStream(seedBooks);
      expect(
        broadcastDemo.singleSubscriptionSecondListenError,
        contains('Stream has already been listened to'),
      );
      expect(
        broadcastDemo.broadcastFirstListenerIds,
        equals(broadcastDemo.broadcastSecondListenerIds),
      );
    });

    test(
      '8. Isolate.run виконує важке обчислення та ізолює глобальну змінну',
      () async {
        final bench = await benchmarkHeavyIsolateComputation(
          seedBooks,
          syntheticCount: 20000,
        );
        expect(bench.computationResult.processedEditions, equals(20000));
        expect(bench.computationResult.rollingHashSignature, greaterThan(0));

        final mutation = await demonstrateIsolateGlobalVariableMutation();
        expect(mutation.mainValueBeforeIsolate, equals(10));
        expect(mutation.valueInsideWorkerIsolate, equals(500));
        expect(mutation.mainValueAfterIsolate, equals(10));
      },
    );
  });

  group('Лабораторна робота №4: Модульний застосунок, JSON, CLI, REST API та shelf', () {
    var tempDir = Directory.systemTemp;
    var seedBooks = <Book>[];
    var sharedRepo = AsyncRepository<Book>(
      readDelay: Duration.zero,
      writeDelay: Duration.zero,
    );
    var middlewareLogs = <String>[];

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('homelib_lab4_test_');
      seedBooks = parseDefaultCatalogSeedBooks();
      sharedRepo = AsyncRepository<Book>(
        readDelay: const Duration(milliseconds: 2),
        writeDelay: const Duration(milliseconds: 2),
        initialItems: seedBooks,
      );
      middlewareLogs = <String>[];
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
      exitCode = 0;
    });

    test('1. Ручна серіалізація toJson та fromJson для Book і BookFormat зберігає всі поля', () {
      for (final book in seedBooks) {
        final map = book.toJson();
        final restored = Book.fromJson(map);
        expect(restored, equals(book));
        expect(restored.format.formatName, equals(book.format.formatName));
      }

      expect(
        () => Book.fromJson(const <String, Object?>{'id': 'BROKEN'}),
        throwsFormatException,
      );
    });

    test(
      '2. Файлове сховище зберігає та читає books.json за шляхом через p.join',
      () async {
        final savedPath = await saveBooksToJsonFile(
          seedBooks,
          directoryPath: tempDir.path,
          fileName: 'catalog_test.json',
        );
        expect(File(savedPath).existsSync(), isTrue);

        final loaded = await loadBooksFromJsonFile(
          directoryPath: tempDir.path,
          fileName: 'catalog_test.json',
        );
        expect(loaded.length, equals(seedBooks.length));
        expect(loaded.first, equals(seedBooks.first));
      },
    );

    test(
      '3. Потокове читання через File.openRead, utf8.decoder та LineSplitter',
      () async {
        final csvPath = resolveBooksJsonPath(
          directoryPath: tempDir.path,
          fileName: 'large_catalog.csv',
        );
        await File(csvPath)
            .writeAsString(rawBooksCsv.join('\n'), encoding: utf8);

        final summary = await readLargeCatalogFileStreaming(csvPath);
        expect(summary.totalLinesRead, equals(rawBooksCsv.length));
        expect(summary.validBooksParsed, equals(seedBooks.length));
        expect(summary.invalidLinesSkipped, greaterThanOrEqualTo(4));
      },
    );

    test('4. Розбір аргументів командного рядка через ArgParser підтримує команди та опції', () {
      final listCfg = parseCatalogCliArgs(<String>[
        'list',
        '--file',
        'custom.json',
        '--genre',
        'Програмування',
        '--min-rating',
        '4.7',
        '--limit',
        '5',
      ]);
      expect(listCfg.command, equals('list'));
      expect(listCfg.filePath, equals('custom.json'));
      expect(listCfg.genreFilter, equals('Програмування'));
      expect(listCfg.minRating, equals(4.7));
      expect(listCfg.limit, equals(5));

      final serveCfg = parseCatalogCliArgs(<String>['serve', '--port', '9090']);
      expect(serveCfg.command, equals('serve'));
      expect(serveCfg.port, equals(9090));

      expect(
        () => parseCatalogCliArgs(<String>['--unknown-flag']),
        throwsFormatException,
      );
    });

    test('5. CLI розділяє потоки stdout і stderr та встановлює ненульовий exitCode при помилці', () async {
      final outBuf = StringBuffer();
      final errBuf = StringBuffer();

      final okCode = await executeCatalogCli(
        <String>['list', '--genre', 'Програмування', '--limit', '2'],
        seedBooks: seedBooks,
        outSink: outBuf,
        errSink: errBuf,
      );
      expect(okCode, equals(0));
      expect(outBuf.toString(), contains('[CLI LIST]'));
      expect(errBuf.toString(), isEmpty);

      final badOutBuf = StringBuffer();
      final badErrBuf = StringBuffer();
      final errCode = await executeCatalogCli(
        <String>['list', '--min-rating', '99.9'],
        seedBooks: seedBooks,
        outSink: badOutBuf,
        errSink: badErrBuf,
      );
      expect(errCode, equals(64));
      expect(exitCode, equals(64));
      expect(badOutBuf.toString(), isEmpty);
      expect(badErrBuf.toString(), contains('[CLI ERROR]'));
    });

    test(
      '6. HTTP-клієнт з MockClient успішно обробляє відповідь 200 OK',
      () async {
        final mock200 = MockClient((http.Request req) async {
          final body = jsonEncode(<String, Object?>{
            'docs': <Map<String, Object?>>[
              <String, Object?>{
                'key': '/works/OL101W',
                'title': 'Clean Architecture',
                'author_name': <String>['Robert C. Martin'],
                'first_publish_year': 2017,
                'number_of_pages_median': 432,
                'ratings_average': 4.8,
              },
            ],
          });
          return http.Response.bytes(utf8.encode(body), 200);
        });

        final books = await fetchBooksFromExternalApi(
          query: 'clean architecture',
          limit: 1,
          customClient: mock200,
        );
        expect(books, hasLength(1));
        expect(books.first.id, equals('API-OL101W'));
        expect(books.first.title, equals('Clean Architecture'));
        expect(books.first.author, equals('Robert C. Martin'));
      },
    );

    test('7. HTTP-клієнт з MockClient класифікує коди 404 та 500 як nonSuccessStatusCode', () async {
      final mock404 = MockClient(
        (http.Request req) async => http.Response('Not Found', 404),
      );
      await expectLater(
        () => fetchBooksFromExternalApi(customClient: mock404),
        throwsA(
          isA<CatalogNetworkException>()
              .having(
                (e) => e.level,
                'level',
                NetworkFailureLevel.nonSuccessStatusCode,
              )
              .having((e) => e.statusCode, 'statusCode', 404),
        ),
      );

      final mock500 = MockClient(
        (http.Request req) async => http.Response('Internal Server Error', 500),
      );
      await expectLater(
        () => fetchBooksFromExternalApi(customClient: mock500),
        throwsA(
          isA<CatalogNetworkException>()
              .having(
                (e) => e.level,
                'level',
                NetworkFailureLevel.nonSuccessStatusCode,
              )
              .having((e) => e.statusCode, 'statusCode', 500),
        ),
      );
    });

    test('8. HTTP-клієнт класифікує відсутність з’єднання (Рівень 1) та битий JSON (Рівень 3)', () async {
      final mockOffline = MockClient((http.Request req) async {
        throw const SocketException('Network is unreachable');
      });
      await expectLater(
        () => fetchBooksFromExternalApi(customClient: mockOffline),
        throwsA(
          isA<CatalogNetworkException>().having(
            (e) => e.level,
            'level',
            NetworkFailureLevel.connectionFailure,
          ),
        ),
      );

      final mockMalformed = MockClient(
        (http.Request req) async => http.Response('<<<NOT_VALID_JSON>>>', 200),
      );
      await expectLater(
        () => fetchBooksFromExternalApi(customClient: mockMalformed),
        throwsA(
          isA<CatalogNetworkException>().having(
            (e) => e.level,
            'level',
            NetworkFailureLevel.malformedPayload,
          ),
        ),
      );
    });

    test('9. Обробник shelf GET /items підтримує фільтрацію та додає заголовки middleware', () async {
      final handler = buildCatalogServerHandler(
        sharedRepo,
        onLog: middlewareLogs.add,
      );
      final response = await handler(
        shelf.Request(
          'GET',
          Uri.parse(
            'http://localhost:8080/items?genre=programming&minRating=4.8',
          ),
        ),
      );

      expect(response.statusCode, equals(200));
      expect(
        response.headers['content-type'],
        equals('application/json; charset=utf-8'),
      );
      expect(response.headers['x-response-time-ms'], isNotNull);
      expect(middlewareLogs, isNotEmpty);

      final Object? body = jsonDecode(await response.readAsString());
      expect(body, isA<Map<String, Object?>>());
      if (body is Map<String, Object?>) {
        expect(body['count'], equals(2));
      }
    });

    test('10. Обробник shelf GET /items/<id> повертає 200 OK для наявної книги та 404 Not Found для відсутньої', () async {
      final handler = buildCatalogServerHandler(
        sharedRepo,
        onLog: middlewareLogs.add,
      );

      final okResp = await handler(
        shelf.Request('GET', Uri.parse('http://localhost:8080/items/BK-001')),
      );
      expect(okResp.statusCode, equals(200));
      final Object? okJson = jsonDecode(await okResp.readAsString());
      if (okJson is Map<String, Object?>) {
        expect(Book.fromJson(okJson), equals(seedBooks.first));
      }

      final notFoundResp = await handler(
        shelf.Request(
          'GET',
          Uri.parse('http://localhost:8080/items/BK-UNKNOWN'),
        ),
      );
      expect(notFoundResp.statusCode, equals(404));
      expect(
        notFoundResp.headers['content-type'],
        equals('application/json; charset=utf-8'),
      );
    });

    test('11. Обробник shelf POST /items створює нову книгу (201 Created) або відхиляє невалідні дані (400 Bad Request)', () async {
      final handler = buildCatalogServerHandler(
        sharedRepo,
        onLog: middlewareLogs.add,
      );

      final newBookPayload = <String, Object?>{
        ...seedBooks.first.toJson(),
        'id': 'BK-777',
        'title': 'Нова книга через POST',
      };

      final postOkResp = await handler(
        shelf.Request(
          'POST',
          Uri.parse('http://localhost:8080/items'),
          body: jsonEncode(newBookPayload),
          headers: jsonUtf8Headers,
        ),
      );
      expect(postOkResp.statusCode, equals(201));
      final savedInRepo = await sharedRepo.load('BK-777');
      expect(savedInRepo?.title, equals('Нова книга через POST'));

      final postBadResp = await handler(
        shelf.Request(
          'POST',
          Uri.parse('http://localhost:8080/items'),
          body: '{"id": "BK-BAD", "year": 9999}',
          headers: jsonUtf8Headers,
        ),
      );
      expect(postBadResp.statusCode, equals(400));
    });
  });
}
