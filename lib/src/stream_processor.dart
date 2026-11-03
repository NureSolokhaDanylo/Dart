/// Потокова обробка подій каталогу книг через `Stream`, генератори `async*`,
/// `StreamController` та конвеєри трансформації (Пункти 7–13 Лабораторної роботи №3).
library;

import 'dart:async';

import 'async_repository.dart';
import 'oop_models.dart';

/// Запечатаний базовий клас подій предметної області «Каталог книг» (Пункт 9).
sealed class CatalogEvent {
  /// Базовий константний конструктор події каталогу.
  const CatalogEvent();

  /// Книга, якої стосується подія.
  Book get book;

  /// Часова мітка виникнення події.
  DateTime get timestamp;

  /// Короткий опис типу події.
  String get eventDescription;
}

/// Подія додавання нової книги до каталогу.
final class const BookAddedEvent({
  @override required final Book book,
  @override required final DateTime timestamp,
}) extends CatalogEvent {
  @override
  String get eventDescription =>
      'Додано книгу [${book.id}] "${book.title}" (★${book.rating})';
}

/// Подія оновлення читацького рейтингу книги.
final class const BookRatingUpdatedEvent({
  @override required final Book book,
  @override required final DateTime timestamp,
  required final double previousRating,
  required final double newRating,
}) extends CatalogEvent {
  @override
  String get eventDescription =>
      'Оновлено рейтинг [${book.id}] "${book.title}": '
      '$previousRating -> $newRating';
}

/// Подія зміни статусу видачі книги читачеві.
final class const BookLoanStatusChangedEvent({
  @override required final Book book,
  @override required final DateTime timestamp,
  required final bool isLoanedOut,
  required final String readerName,
}) extends CatalogEvent {
  @override
  String get eventDescription => isLoanedOut
      ? 'Книгу [${book.id}] "${book.title}" видано читачу $readerName'
      : 'Книгу [${book.id}] "${book.title}" повернено до сховища ($readerName)';
}

/// Генераторна функція `async*`, яка видає сутності [Book] із заданим інтервалом [interval] (Пункти 7, 8).
///
/// На початку тіла функції викликає [onLog] (або `print`), щоб довести лінивість генератора:
/// код усередині `async*` не запускається до моменту появи підписника (`await for` або `listen`).
Stream<Book> generateBooksLazyStream(
  List<Book> books, {
  Duration interval = const Duration(milliseconds: 40),
  void Function(String message)? onLog,
}) async* {
  onLog?.call(
    '[Тіло async*] Генератор стартував! Починаємо видачу ${books.length} книг...',
  );
  for (final book in books) {
    await Future<void>.delayed(interval);
    onLog?.call('[Тіло async*] yield -> ${book.id} "${book.title}"');
    yield book;
  }
  onLog?.call('[Тіло async*] Генератор завершив роботу.');
}

/// Результат демонстрації лінивості генератора `async*` та споживання через `await for` (Пункти 7, 8).
typedef LazyGeneratorDemoResult = ({
  List<String> traceLog,
  List<Book> consumedBooks,
});

/// Доводить лінивість генератора `async*` та споживає потік через `await for` (Пункти 7, 8).
Future<LazyGeneratorDemoResult> demonstrateGeneratorLaziness(
  List<Book> books, {
  Duration interval = const Duration(milliseconds: 30),
}) async {
  final trace = <String>[];
  final subset = books.take(3).toList();

  trace.add('Крок 1: Викликаємо generateBooksLazyStream() без підписки');
  final stream = generateBooksLazyStream(
    subset,
    interval: interval,
    onLog: trace.add,
  );
  trace.add(
    'Крок 2: Об’єкт Stream створено, але жодного рядка з [Тіло async*] ще немає!',
  );
  trace.add('Крок 3: Починаємо цикл await for (підписка на потік)...');

  final consumed = <Book>[];
  await for (final book in stream) {
    consumed.add(book);
    trace.add('Крок 4 (await for): Отримано книгу ${book.id}');
  }

  trace.add('Крок 5: Цикл await for завершено.');
  return (traceLog: trace, consumedBooks: consumed);
}

/// Результат демонстрації буферизації `StreamController` та явного скасування `StreamSubscription` (Пункти 9, 10).
typedef BufferedControllerDemoResult = ({
  List<CatalogEvent> receivedEvents,
  List<String> lifecycleLog,
  bool subscriptionExplicitlyCancelled,
});

/// Створює одноразовий [StreamController], додає 3 події ДО підписки,
/// споживає потік через `listen()` зі збереженням [StreamSubscription]
/// та явно скасовує підписку (Пункти 9, 10).
Future<BufferedControllerDemoResult> demonstrateBufferedControllerAndListen(
  List<Book> books,
) async {
  final controller = StreamController<CatalogEvent>();
  final log = <String>[];
  final received = <CatalogEvent>[];
  final now = DateTime.utc(2026, 10, 14, 12, 0);

  final b1 = books[0];
  final b2 = books.length > 1 ? books[1] : b1;
  final b3 = books.length > 2 ? books[2] : b1;

  // Додаємо три події ДО того, як на потік хтось підписався (Пункт 9)
  controller.add(BookAddedEvent(book: b1, timestamp: now));
  controller.add(
    BookRatingUpdatedEvent(
      book: b2,
      timestamp: now.add(const Duration(minutes: 5)),
      previousRating: 4.7,
      newRating: 4.9,
    ),
  );
  controller.add(
    BookLoanStatusChangedEvent(
      book: b3,
      timestamp: now.add(const Duration(minutes: 10)),
      isLoanedOut: true,
      readerName: 'Шевченко Тарас',
    ),
  );
  log.add(
    'До підписки у StreamController додано 3 події '
    '(вони збережені у внутрішній черзі буфера контролера).',
  );

  final completer = Completer<void>();

  // Підписуємося через listen() та зберігаємо StreamSubscription (Пункт 10)
  final StreamSubscription<CatalogEvent> subscription = controller.stream
      .listen((CatalogEvent event) {
        received.add(event);
        log.add('listen() отримав: ${event.eventDescription}');
        if (received.length == 3 && !completer.isCompleted) {
          completer.complete();
        }
      });

  await completer.future;

  // Явна точка скасування підписки згідно з правилом дисципліни (Пункт 10)
  await subscription.cancel();
  var cancelled = true;
  log.add(
    'StreamSubscription явно скасовано через await subscription.cancel().',
  );

  await controller.close();
  return (
    receivedEvents: received,
    lifecycleLog: log,
    subscriptionExplicitlyCancelled: cancelled,
  );
}

/// Результат порівняння обробки помилки всередині потоку через `await for` та `listen` (Пункт 11).
typedef StreamErrorHandlingComparison = ({
  List<String> awaitForReceivedIds,
  String awaitForCaughtError,
  List<String> listenReceivedIds,
  List<String> listenCaughtErrors,
});

/// Допоміжна функція, що формує потік із помилкою посередині: `[Книга 1, Книга 2, ПОМИЛКА, Книга 3]`.
Stream<Book> _createBookStreamWithMidError(List<Book> books) {
  final controller = StreamController<Book>();
  final b1 = books[0];
  final b2 = books.length > 1 ? books[1] : b1;
  final b3 = books.length > 2 ? books[2] : b1;

  controller.add(b1);
  controller.add(b2);
  controller.addError(
    const CatalogAsyncException(
      'Помилка читання сектора потоку після 2-го елемента',
      operationId: 'STREAM-MID-ERR',
    ),
  );
  controller.add(b3);
  unawaited(controller.close());

  return controller.stream;
}

/// Порівнює поведінку `await for` (зупиняється на помилці) та `listen(cancelOnError: false)`
/// (продовжує прийом елементів після помилки) на потоці з помилкою посередині (Пункт 11).
Future<StreamErrorHandlingComparison> compareMidStreamErrorBehavior(
  List<Book> books,
) async {
  // 1. Споживання через await for
  final awaitForIds = <String>[];
  var awaitForError = '';

  final streamForLoop = _createBookStreamWithMidError(books);
  try {
    await for (final book in streamForLoop) {
      awaitForIds.add(book.id);
    }
  } on CatalogAsyncException catch (e) {
    awaitForError = e.toString();
  }

  // 2. Споживання через listen(..., cancelOnError: false)
  final listenIds = <String>[];
  final listenErrors = <String>[];
  final doneCompleter = Completer<void>();

  final streamForListen = _createBookStreamWithMidError(books);
  final StreamSubscription<Book> subscription = streamForListen.listen(
    (Book book) {
      listenIds.add(book.id);
    },
    onError: (Object error) {
      listenErrors.add(error.toString());
    },
    onDone: () {
      if (!doneCompleter.isCompleted) {
        doneCompleter.complete();
      }
    },
    cancelOnError: false,
  );

  await doneCompleter.future;
  await subscription.cancel();

  return (
    awaitForReceivedIds: awaitForIds,
    awaitForCaughtError: awaitForError,
    listenReceivedIds: listenIds,
    listenCaughtErrors: listenErrors,
  );
}

/// Результат демонстрації різниці між одноразовим та широкомовним потоком (Пункт 12).
typedef BroadcastComparisonResult = ({
  String singleSubscriptionSecondListenError,
  List<String> broadcastFirstListenerIds,
  List<String> broadcastSecondListenerIds,
});

/// Демонструє спробу повторної підписки на потік одноразової підписки (з перехопленням
/// `StateError: Bad state: Stream has already been listened to.`) та роботу двох
/// одночасних підписників на широкомовному потоці (Пункт 12).
Future<BroadcastComparisonResult> demonstrateSingleVsBroadcastStream(
  List<Book> books,
) async {
  final singleController = StreamController<Book>();
  for (final book in books.take(2)) {
    singleController.add(book);
  }
  unawaited(singleController.close());

  final singleStream = singleController.stream;

  // Перша підписка на одноразовий потік
  final firstSub = singleStream.listen((_) {});
  var secondListenError = '';

  try {
    // Друга підписка на той самий одноразовий потік викликає StateError
    final secondSub = singleStream.listen((_) {});
    await secondSub.cancel();
  } on StateError catch (error) {
    secondListenError = 'StateError: ${error.message}';
  }

  await firstSub.cancel();

  // Широкомовний потік (Broadcast Stream) дозволяє кільком підписникам слухати одночасно
  final broadcastController = StreamController<Book>.broadcast();
  final listener1Ids = <String>[];
  final listener2Ids = <String>[];

  final sub1 = broadcastController.stream.listen((book) {
    listener1Ids.add(book.id);
  });
  final sub2 = broadcastController.stream.listen((book) {
    listener2Ids.add(book.id);
  });

  for (final book in books.take(3)) {
    broadcastController.add(book);
  }

  await Future<void>.delayed(const Duration(milliseconds: 20));
  await sub1.cancel();
  await sub2.cancel();
  await broadcastController.close();

  return (
    singleSubscriptionSecondListenError: secondListenError,
    broadcastFirstListenerIds: listener1Ids,
    broadcastSecondListenerIds: listener2Ids,
  );
}

/// Побудова конвеєра трансформації потоку подій (`where -> map -> take`, Пункт 13).
///
/// Фільтрує події, що стосуються книг із рейтингом не нижче [minRating],
/// перетворює їх на відформатовані рядки сповіщень і обмежує вибірку [maxEvents] елементами.
Stream<String> buildEventTransformationPipeline(
  Stream<CatalogEvent> eventStream, {
  double minRating = 4.8,
  int maxEvents = 3,
}) {
  return eventStream
      .where((event) => event.book.rating >= minRating)
      .map(
        (event) =>
            '[СПОВІЩЕННЯ ★${event.book.rating}] ${event.eventDescription}',
      )
      .take(maxEvents);
}
