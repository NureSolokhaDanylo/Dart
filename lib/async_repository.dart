/// Асинхронний шар доступу до даних каталогу книг (Лабораторна робота №3).
///
/// Містить узагальнене асинхронне сховище [AsyncRepository], демонстрацію
/// помилки «забутий `await`», порівняння послідовного та паралельного очікування
/// через [Stopwatch] і обробку помилок у групах [Future].
library;

import 'dart:async';

import 'oop_models.dart';

/// Виняток асинхронних операцій доступу до каталогу книг.
class CatalogAsyncException implements Exception {
  /// Створює виняток із повідомленням [message] та ідентифікатором операції [operationId].
  const CatalogAsyncException(this.message, {this.operationId});

  /// Опис причини помилки.
  final String message;

  /// Ідентифікатор сутності або запиту, під час якого виникла помилка.
  final String? operationId;

  @override
  String toString() =>
      'CatalogAsyncException(operationId: ${operationId ?? "n/a"}, message: $message)';
}

/// Асинхронне сховище сутностей предметної області (Пункт 2).
///
/// Усі операції читання, запису та видалення імітують мережеву/дискову затримку
/// через [Future.delayed] і повертають об’єкт [Future].
class AsyncRepository<T extends Identifiable> {
  /// Створює асинхронне сховище з налаштовуваними затримками операцій.
  AsyncRepository({
    this.readDelay = const Duration(milliseconds: 300),
    this.writeDelay = const Duration(milliseconds: 200),
    this.streamInterval = const Duration(milliseconds: 100),
    Iterable<T>? initialItems,
  }) {
    if (initialItems != null) {
      for (final item in initialItems) {
        _items[item.id] = item;
      }
    }
  }

  /// Імітована затримка операції завантаження [load].
  final Duration readDelay;

  /// Імітована затримка операцій збереження [save] та видалення [delete].
  final Duration writeDelay;

  /// Інтервал між елементами у потоковому генераторі [watchAll].
  final Duration streamInterval;

  final Map<String, T> _items = <String, T>{};

  /// Поточна кількість елементів у сховищі (синхронний знімок для діагностики).
  int get currentCount => _items.length;

  /// Асинхронно завантажує сутність за ідентифікатором [id] або повертає `null`.
  Future<T?> load(String id, {Duration? customDelay}) async {
    await Future<void>.delayed(customDelay ?? readDelay);
    return _items[id];
  }

  /// Асинхронно завантажує сутність за [id] або генерує [CatalogAsyncException],
  /// якщо запит імітує збій з’єднання або сутність відсутня.
  Future<T> loadOrThrow(
    String id, {
    Duration? customDelay,
    bool simulateFailure = false,
  }) async {
    await Future<void>.delayed(customDelay ?? readDelay);
    if (simulateFailure) {
      throw CatalogAsyncException(
        'Збій читання з віддаленого вузла для "$id"',
        operationId: id,
      );
    }
    final found = _items[id];
    if (found == null) {
      throw CatalogAsyncException(
        'Сутність з ідентифікатором "$id" не знайдено у сховищі',
        operationId: id,
      );
    }
    return found;
  }

  /// Асинхронно зберігає або оновлює сутність [item] у сховищі.
  Future<void> save(T item, {Duration? customDelay}) async {
    await Future<void>.delayed(customDelay ?? writeDelay);
    _items[item.id] = item;
  }

  /// Асинхронно видаляє сутність за [id]. Повертає `true`, якщо елемент було видалено.
  Future<bool> delete(String id, {Duration? customDelay}) async {
    await Future<void>.delayed(customDelay ?? writeDelay);
    return _items.remove(id) != null;
  }

  /// Асинхронно повертає незмінний список усіх сутностей у сховищі.
  Future<List<T>> loadAll({Duration? customDelay}) async {
    await Future<void>.delayed(customDelay ?? readDelay);
    return List<T>.unmodifiable(_items.values);
  }

  /// Генератор `async*`, який видає сутності по одній у міру «надходження» (Пункт 7).
  Stream<T> watchAll({
    Duration? customInterval,
    void Function(String message)? onLifecycleLog,
  }) async* {
    onLifecycleLog?.call(
      '[watchAll async*] Генератор почав виконання тіла функції',
    );
    final snapshot = List<T>.of(_items.values);
    for (final item in snapshot) {
      await Future<void>.delayed(customInterval ?? streamInterval);
      onLifecycleLog?.call('[watchAll async*] Видача елемента ${item.id}');
      yield item;
    }
    onLifecycleLog?.call(
      '[watchAll async*] Генератор завершив видачу всіх елементів',
    );
  }
}

/// Результат демонстрації помилки «забутий `await`» (Пункт 3).
typedef ForgottenAwaitResult = ({
  bool existsImmediatelyWithoutAwait,
  bool existsAfterFutureCompletes,
  bool existsImmediatelyWithAwait,
  List<String> executionOrderLog,
});

/// Демонструє різницю у поведінці програми при виклику асинхронної операції
/// без `await` (обгорнутої в `unawaited`, щоб не порушувати правило лінтера
/// `unawaited_futures`) та з `await` (Пункт 3).
Future<ForgottenAwaitResult> demonstrateForgottenAwait(
  Book sampleBook, {
  Duration saveDelay = const Duration(milliseconds: 50),
}) async {
  final repo = AsyncRepository<Book>(
    readDelay: Duration.zero,
    writeDelay: saveDelay,
  );
  final log = <String>[];

  // Сценарій 1: Виклик save() без await
  log.add('1. Викликаємо repo.save("${sampleBook.id}") БЕЗ await');
  final pendingSave = repo.save(sampleBook);
  unawaited(pendingSave);

  final immediateCheck = repo.currentCount > 0;
  log.add(
    '2. Перевірка стану одразу після виклику без await: '
    'елементів у сховищі = ${repo.currentCount} (наявність = $immediateCheck)',
  );

  await pendingSave;
  final afterCompletionCheck = repo.currentCount > 0;
  log.add(
    '3. Після фактичного завершення відкладеного Future: '
    'елементів у сховищі = ${repo.currentCount} (наявність = $afterCompletionCheck)',
  );

  // Сценарій 2: Коректний виклик із await
  await repo.delete(sampleBook.id, customDelay: Duration.zero);
  log.add('4. Викликаємо await repo.save("${sampleBook.id}") З await');
  await repo.save(sampleBook);
  final withAwaitCheck = repo.currentCount > 0;
  log.add(
    '5. Перевірка стану після await repo.save: '
    'елементів у сховищі = ${repo.currentCount} (наявність = $withAwaitCheck)',
  );

  return (
    existsImmediatelyWithoutAwait: immediateCheck,
    existsAfterFutureCompletes: afterCompletionCheck,
    existsImmediatelyWithAwait: withAwaitCheck,
    executionOrderLog: log,
  );
}

/// Результат вимірювання часу послідовного та паралельного виконання (Пункт 4).
typedef TimingComparisonResult = ({
  int sequentialElapsedMs,
  int concurrentElapsedMs,
  List<Book?> loadedBooks,
});

/// Вимірює за допомогою [Stopwatch] час послідовного (`await` по черзі)
/// та одночасного (`Future.wait`) виконання трьох операцій по [operationDelay]
/// (за замовчуванням 500 мс кожна, Пункт 4).
Future<TimingComparisonResult> measureSequentialVsConcurrent(
  AsyncRepository<Book> repository,
  List<String> threeIds, {
  Duration operationDelay = const Duration(milliseconds: 500),
}) async {
  final ids = threeIds.take(3).toList();
  while (ids.length < 3) {
    ids.add('BK-001');
  }

  // 1. Послідовне виконання трьох операцій через await
  final sequentialWatch = Stopwatch()..start();
  final first = await repository.load(ids[0], customDelay: operationDelay);
  final second = await repository.load(ids[1], customDelay: operationDelay);
  final third = await repository.load(ids[2], customDelay: operationDelay);
  sequentialWatch.stop();

  // 2. Одночасне (конкурентне) виконання трьох операцій через Future.wait
  final concurrentWatch = Stopwatch()..start();
  final concurrentResults = await Future.wait<Book?>(<Future<Book?>>[
    repository.load(ids[0], customDelay: operationDelay),
    repository.load(ids[1], customDelay: operationDelay),
    repository.load(ids[2], customDelay: operationDelay),
  ]);
  concurrentWatch.stop();

  return (
    sequentialElapsedMs: sequentialWatch.elapsedMilliseconds,
    concurrentElapsedMs: concurrentWatch.elapsedMilliseconds,
    loadedBooks: <Book?>[
      first ?? concurrentResults[0],
      second ?? concurrentResults[1],
      third ?? concurrentResults[2],
    ],
  );
}
