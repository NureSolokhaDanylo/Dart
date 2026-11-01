/// Обчислення у фоновому ізоляті через `Isolate.run`, перевірка ізоляції пам’яті
/// глобальних змінних та генерація зведеного звіту Лабораторної роботи №3 (Пункти 14, 15).
library;

import 'dart:async';
import 'dart:isolate';

import 'async_repository.dart';
import 'oop_models.dart';
import 'repository_and_patterns.dart';
import 'stream_processor.dart';

/// Глобальна змінна верхнього рівня для демонстрації ізоляції пам’яті між ізолятами (Пункт 15).
///
/// Кожний ізолят у Dart має власну купу (heap) і власну копію глобальних/статичних змінних,
/// тому зміна цієї змінної всередині `Isolate.run` не впливає на головний ізолят.
int globalIsolateMutationCounter = 0;

/// Результат важкого синхронного обчислення над синтетичним архівом каталогу (Пункт 14).
typedef HeavyArchiveComputationResult = ({
  int processedEditions,
  int primeVerifiedChecksums,
  int rollingHashSignature,
  double weightedRatingIndex,
});

/// Результат вимірювання часу важкого обчислення до та після винесення в `Isolate.run` (Пункт 14).
typedef IsolateBenchmarkResult = ({
  int mainIsolateSyncElapsedMs,
  int isolateRunSingleElapsedMs,
  int mainIsolateTwoTasksSeqMs,
  int isolateRunTwoTasksParallelMs,
  HeavyArchiveComputationResult computationResult,
});

/// Результат експерименту зі зміною глобальної змінної всередині `Isolate.run` (Пункт 15).
typedef IsolateGlobalMutationResult = ({
  int mainValueBeforeIsolate,
  int valueInsideWorkerIsolate,
  int mainValueAfterIsolate,
});

/// Виконує ресурсоємне синхронне обчислення: моделює обробку [syntheticCount]
/// архівних примірників на базі [seedBooks], обчислюючи поліноміальний хеш FNV-1a
/// та перевірку простих дільників контрольної суми (Пункт 14).
HeavyArchiveComputationResult computeHeavyCatalogSignatureSync(
  List<Book> seedBooks, {
  int syntheticCount = 180000,
}) {
  if (seedBooks.isEmpty) {
    return (
      processedEditions: 0,
      primeVerifiedChecksums: 0,
      rollingHashSignature: 0,
      weightedRatingIndex: 0.0,
    );
  }

  var rollingHash = 0x811c9dc5;
  var primeCount = 0;
  var weightedSum = 0.0;
  final seedLength = seedBooks.length;

  for (var i = 0; i < syntheticCount; i++) {
    final book = seedBooks[i % seedLength];
    final editionCode = (book.year * 31) ^ (book.pages * 17) ^ i;
    rollingHash = ((rollingHash ^ editionCode) * 0x01000193) & 0x7fffffff;
    weightedSum += book.rating * ((i % 5) + 1) * 0.0001;

    // Додаткове навантаження CPU: перевірка числа на простоту для кожного 40-го індексу
    if (i % 40 == 0) {
      final candidate = 10007 + (editionCode.abs() % 25000);
      if (_isPrimeNumber(candidate)) {
        primeCount += 1;
      }
    }
  }

  return (
    processedEditions: syntheticCount,
    primeVerifiedChecksums: primeCount,
    rollingHashSignature: rollingHash,
    weightedRatingIndex: weightedSum / syntheticCount,
  );
}

bool _isPrimeNumber(int n) {
  if (n < 2) {
    return false;
  }
  if (n.isEven) {
    return n == 2;
  }
  for (var d = 3; d * d <= n; d += 2) {
    if (n % d == 0) {
      return false;
    }
  }
  return true;
}

/// Запускає важке обчислення спочатку синхронно у головному потоці, а потім
/// у фоновому ізоляті через `Isolate.run` (та паралельно у 2 ізолятах),
/// вимірюючи час за допомогою [Stopwatch] (Пункт 14).
Future<IsolateBenchmarkResult> benchmarkHeavyIsolateComputation(
  List<Book> seedBooks, {
  int syntheticCount = 180000,
}) async {
  // 1. Синхронне виконання у головному ізоляті (блокує Event Loop)
  final syncWatch = Stopwatch()..start();
  final syncResult = computeHeavyCatalogSignatureSync(
    seedBooks,
    syntheticCount: syntheticCount,
  );
  syncWatch.stop();

  // 2. Винесення одного обчислення в окремий потік через Isolate.run
  final singleIsolateWatch = Stopwatch()..start();
  final isolateResult = await Isolate.run<HeavyArchiveComputationResult>(
    () => computeHeavyCatalogSignatureSync(
      seedBooks,
      syntheticCount: syntheticCount,
    ),
  );
  singleIsolateWatch.stop();

  // 3. Порівняння виконання двох важких пакетів: послідовно в 1 потоці vs паралельно у 2 Isolate.run
  final twoSyncWatch = Stopwatch()..start();
  computeHeavyCatalogSignatureSync(seedBooks, syntheticCount: syntheticCount);
  computeHeavyCatalogSignatureSync(seedBooks, syntheticCount: syntheticCount);
  twoSyncWatch.stop();

  final twoParallelIsolatesWatch = Stopwatch()..start();
  await Future.wait<HeavyArchiveComputationResult>(
    <Future<HeavyArchiveComputationResult>>[
      Isolate.run(
        () => computeHeavyCatalogSignatureSync(
          seedBooks,
          syntheticCount: syntheticCount,
        ),
      ),
      Isolate.run(
        () => computeHeavyCatalogSignatureSync(
          seedBooks,
          syntheticCount: syntheticCount,
        ),
      ),
    ],
  );
  twoParallelIsolatesWatch.stop();

  return (
    mainIsolateSyncElapsedMs: syncWatch.elapsedMilliseconds,
    isolateRunSingleElapsedMs: singleIsolateWatch.elapsedMilliseconds,
    mainIsolateTwoTasksSeqMs: twoSyncWatch.elapsedMilliseconds,
    isolateRunTwoTasksParallelMs: twoParallelIsolatesWatch.elapsedMilliseconds,
    computationResult:
        isolateResult.rollingHashSignature == syncResult.rollingHashSignature
        ? isolateResult
        : syncResult,
  );
}

/// Демонструє спробу модифікації глобальної змінної [globalIsolateMutationCounter]
/// всередині `Isolate.run` і доводить ізольованість пам’яті ізолятів (Пункт 15).
Future<IsolateGlobalMutationResult>
demonstrateIsolateGlobalVariableMutation() async {
  globalIsolateMutationCounter = 10;
  final beforeInMain = globalIsolateMutationCounter;

  final valueInsideWorker = await Isolate.run<int>(() {
    // У новому ізоляті globalIsolateMutationCounter ініціалізується власним
    // початковим значенням (0) і модифікується лише у власній купі цього ізолята.
    globalIsolateMutationCounter += 500;
    return globalIsolateMutationCounter;
  });

  final afterInMain = globalIsolateMutationCounter;

  return (
    mainValueBeforeIsolate: beforeInMain,
    valueInsideWorkerIsolate: valueInsideWorker,
    mainValueAfterIsolate: afterInMain,
  );
}

/// Формує повний текстовий звіт із результатами всіх експериментів Лабораторної роботи №3.
Future<String> buildLab3AsyncReport(
  List<String> rawCsvLines, {
  Duration benchmarkOperationDelay = const Duration(milliseconds: 500),
  int isolateSyntheticCount = 180000,
}) async {
  final buffer = StringBuffer();
  final (:repository, rejectedLines: _, cacheHits: _) = importBooksToRepository(
    rawCsvLines,
  );
  final books = repository.all;
  final asyncRepo = AsyncRepository<Book>(initialItems: books);

  buffer.writeln(
    '============================================================',
  );
  buffer.writeln(
    '  ЗВІТ ЛАБОРАТОРНОЇ РОБОТИ №3 (АСИНХРОННІСТЬ, STREAM, ISOLATE)',
  );
  buffer.writeln(
    '============================================================',
  );

  // Пункти 2, 3: Забутий await
  final forgottenAwait = await demonstrateForgottenAwait(books.first);
  buffer.writeln('--- 1. Демонстрація помилки «забутий await» (Пункт 3) ---');
  for (final line in forgottenAwait.executionOrderLog) {
    buffer.writeln('  $line');
  }

  // Пункт 4: Послідовне vs одночасне виконання 3 операцій по 500 мс
  final timing = await measureSequentialVsConcurrent(asyncRepo, <String>[
    'BK-001',
    'BK-004',
    'BK-007',
  ], operationDelay: benchmarkOperationDelay);
  buffer.writeln('');
  buffer.writeln(
    '--- 2. Вимірювання Stopwatch: послідовні await vs Future.wait (Пункт 4) ---',
  );
  buffer.writeln(
    '  Послідовне виконання (3 x ${benchmarkOperationDelay.inMilliseconds} мс): '
    '${timing.sequentialElapsedMs} мс',
  );
  buffer.writeln(
    '  Одночасне виконання через Future.wait: '
    '${timing.concurrentElapsedMs} мс',
  );

  // Пункт 5: Future.wait vs ParallelWaitError
  final groupErrors = await compareGroupErrorHandling(asyncRepo);
  buffer.writeln('');
  buffer.writeln(
    '--- 3. Групова обробка помилок: Future.wait vs ParallelWaitError (Пункт 5) ---',
  );
  buffer.writeln(
    '  [Future.wait] Спіймано: ${groupErrors.futureWaitCaughtError} | '
    'Збережено успішних результатів: ${groupErrors.futureWaitRecoveredCount}',
  );
  buffer.writeln(
    '  [Iterable.wait / ParallelWaitError] Успішні значення values: '
    '${groupErrors.parallelWaitValuesTitles}',
  );
  buffer.writeln(
    '  [Iterable.wait / ParallelWaitError] Вектор помилок errors: '
    '${groupErrors.parallelWaitErrorMessages}',
  );

  // Пункт 6: Неспіймана асинхронна помилка в синхронному try/catch
  final uncaughtDemo = await demonstrateUncaughtAsyncError(asyncRepo);
  buffer.writeln('');
  buffer.writeln(
    '--- 4. Неспіймана асинхронна помилка без await (Пункт 6) ---',
  );
  buffer.writeln(
    '  Перехоплено синхронним try/catch: ${uncaughtDemo.caughtBySynchronousTryCatch} | '
    'Перехоплено обробником зони Event Loop: ${uncaughtDemo.caughtByZoneHandler}',
  );
  buffer.writeln('  Повідомлення у зоні: ${uncaughtDemo.zoneCaughtMessage}');

  // Пункти 7, 8: Лінивість генератора async* та await for
  final lazyDemo = await demonstrateGeneratorLaziness(books);
  buffer.writeln('');
  buffer.writeln(
    '--- 5. Генератор async*, await for та доказ лінивості (Пункти 7, 8) ---',
  );
  for (final traceLine in lazyDemo.traceLog) {
    buffer.writeln('  $traceLine');
  }

  // Пункти 9, 10: StreamController (3 події до підписки) та явне скасування StreamSubscription
  final controllerDemo = await demonstrateBufferedControllerAndListen(books);
  buffer.writeln('');
  buffer.writeln(
    '--- 6. StreamController (буферизація 3 подій) та StreamSubscription.cancel() (Пункти 9, 10) ---',
  );
  for (final logLine in controllerDemo.lifecycleLog) {
    buffer.writeln('  $logLine');
  }

  // Пункт 11: Помилка в середині потоку (await for vs listen з cancelOnError: false)
  final midErrorDemo = await compareMidStreamErrorBehavior(books);
  buffer.writeln('');
  buffer.writeln(
    '--- 7. Помилка всередині потоку: await for vs listen(cancelOnError: false) (Пункт 11) ---',
  );
  buffer.writeln(
    '  [await for] Отримані ID до обриву: ${midErrorDemo.awaitForReceivedIds} | '
    'Помилка: ${midErrorDemo.awaitForCaughtError}',
  );
  buffer.writeln(
    '  [listen(cancelOnError: false)] Отримані ID (включно з елементом після помилки): '
    '${midErrorDemo.listenReceivedIds}',
  );

  // Пункт 12: Одноразовий vs широкомовний потік
  final broadcastDemo = await demonstrateSingleVsBroadcastStream(books);
  buffer.writeln('');
  buffer.writeln(
    '--- 8. Одноразова підписка vs Broadcast Stream (Пункт 12) ---',
  );
  buffer.writeln(
    '  Повторна підписка на single-subscription Stream: '
    '${broadcastDemo.singleSubscriptionSecondListenError}',
  );
  buffer.writeln(
    '  Broadcast Stream — підписник #1: ${broadcastDemo.broadcastFirstListenerIds}, '
    'підписник #2: ${broadcastDemo.broadcastSecondListenerIds}',
  );

  // Пункт 13: Конвеєр трансформації потоку (where -> map -> take)
  final sourceController = StreamController<CatalogEvent>();
  final now = DateTime.utc(2026, 10, 15, 10, 0);
  for (final book in books) {
    sourceController.add(BookAddedEvent(book: book, timestamp: now));
  }
  unawaited(sourceController.close());

  final notifications = await buildEventTransformationPipeline(
    sourceController.stream,
    minRating: 4.9,
    maxEvents: 3,
  ).toList();

  buffer.writeln('');
  buffer.writeln(
    '--- 9. Конвеєр трансформації потоку where -> map -> take (Пункт 13) ---',
  );
  for (final note in notifications) {
    buffer.writeln('  $note');
  }

  // Пункти 14, 15: Isolate.run та ізоляція пам'яті глобальної змінної
  final isolateBench = await benchmarkHeavyIsolateComputation(
    books,
    syntheticCount: isolateSyntheticCount,
  );
  final globalMutation = await demonstrateIsolateGlobalVariableMutation();

  buffer.writeln('');
  buffer.writeln(
    '--- 10. Важке обчислення в Isolate.run та ізоляція пам’яті (Пункти 14, 15) ---',
  );
  buffer.writeln(
    '  1 задача (${isolateBench.computationResult.processedEditions} примірників): '
    'головний ізолят синхронно = ${isolateBench.mainIsolateSyncElapsedMs} мс | '
    'Isolate.run = ${isolateBench.isolateRunSingleElapsedMs} мс',
  );
  buffer.writeln(
    '  2 задачі підряд: послідовно в головному потоці = ${isolateBench.mainIsolateTwoTasksSeqMs} мс | '
    'паралельно у 2 Isolate.run = ${isolateBench.isolateRunTwoTasksParallelMs} мс',
  );
  buffer.writeln(
    '  Контрольна сума FNV-1a: ${isolateBench.computationResult.rollingHashSignature}, '
    'знайдено простих чисел: ${isolateBench.computationResult.primeVerifiedChecksums}',
  );
  buffer.writeln(
    '  Глобальна змінна globalIsolateMutationCounter: '
    'до Isolate.run = ${globalMutation.mainValueBeforeIsolate}, '
    'всередині Isolate.run = ${globalMutation.valueInsideWorkerIsolate}, '
    'після в головному ізоляті = ${globalMutation.mainValueAfterIsolate}',
  );

  return buffer.toString();
}
