/// Домішки (`mixin` з обмеженням `on`) та методи розширення (`extension`)
/// для предметної області «Каталог книг» (Пункти 7, 8).
library;

import 'lab1_functional.dart' as lab1;
import 'oop_models.dart';

/// Домішка з обмеженням `on Identifiable`, яка додає поведінку формування
/// картки обліку та експорту метаданих до сутностей із різних гілок ієрархії (Пункт 7).
///
/// Завдяки обмеженню `on Identifiable` домішка:
/// 1. Дозволяє підмішування лише до класів, які реалізують [Identifiable];
/// 2. Має прямий доступ до властивості [id] надтипу [Identifiable].
mixin CatalogExportable on Identifiable {
  /// Короткий опис сутності для включення в облікову картку.
  String get exportSummaryTitle;

  /// Формує уніфікований рядок облікової картки з використанням [id] із [Identifiable].
  String toCatalogCardLine({String separator = ' | '}) {
    return 'ID: $id$separator$exportSummaryTitle';
  }

  /// Формує словник контрольних метаданих сутності для журналу аудиту.
  Map<String, String> toAuditMetadata({DateTime? exportedAt}) {
    final timestamp = (exportedAt ?? DateTime.utc(2026, 10, 22))
        .toCatalogIsoDate();
    return <String, String>{
      'id': id,
      'summary': exportSummaryTitle,
      'exportedAt': timestamp,
    };
  }
}

/// Базовий абстрактний клас облікових документів абонемента (окрема гілка ієрархії,
/// не пов’язана спільним предком реалізації з класом [Book], але сумісна з [Identifiable]).
abstract class CirculationDocument implements Identifiable {
  /// Константний конструктор документа абонемента.
  const CirculationDocument({required this.createdAt});

  /// Дата оформлення документа.
  final DateTime createdAt;

  /// Тип документа в бібліотечній системі.
  String get documentType;
}

/// Читацький формуляр видачі книги, який успадковує [CirculationDocument]
/// та підмішує [CatalogExportable] (Пункт 7).
///
/// Оскільки [ReaderLoanTicket] вже має надклас [CirculationDocument], а [Book]
/// належить до окремої гілки бібліографічних сутностей, спільну поведінку
/// експорту винесено саме у домішку [CatalogExportable].
class ReaderLoanTicket extends CirculationDocument with CatalogExportable {
  /// Константний конструктор формуляра видачі книги.
  const ReaderLoanTicket({
    required this.id,
    required this.readerName,
    required this.bookId,
    required super.createdAt,
    required this.loanDays,
  });

  @override
  final String id;

  /// Прізвище та ім’я читача.
  final String readerName;

  /// Ідентифікатор виданої книги.
  final String bookId;

  /// Кількість днів, на яку видано книгу.
  final int loanDays;

  @override
  String get documentType => 'Формуляр видачі';

  @override
  String get exportSummaryTitle =>
      '$documentType: читач $readerName -> книга $bookId ($loanDays дн.)';
}

/// Методи розширення для вбудованого типу [String] (Пункт 8).
extension BookStringParsingExtension on String {
  /// Перевіряє, чи є рядок коректним номером ISBN-13.
  bool get isValidIsbn13Format => lab1.isValidIsbn13(trim());

  /// Повертає масковане представлення номера ISBN-13.
  String maskIsbn13({String maskChar = '*'}) =>
      lab1.maskIsbn(trim(), maskChar: maskChar);

  /// Намагається перетворити поточний CSV-рядок на екземпляр класу [Book].
  Book? toBookOrNull({String delimiter = lab1.csvFieldDelimiter}) =>
      Book.tryParseCsv(this, delimiter: delimiter);
}

/// Методи розширення для вбудованого типу [DateTime] (Пункт 8).
extension BookDateTimeExtension on DateTime {
  /// Обчислює кількість повних днів, що минули від цієї дати до [referenceDate].
  int daysElapsedUntil([DateTime? referenceDate]) {
    final target = referenceDate ?? DateTime(2026, 10, 22);
    return target.difference(this).inDays;
  }

  /// Форматує дату у стандартний вигляд `YYYY-MM-DD`.
  String toCatalogIsoDate() {
    final y = year.toString().padLeft(4, '0');
    final m = month.toString().padLeft(2, '0');
    final d = day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}

/// Методи розширення для колекцій `Iterable<Book>` (Пункт 8).
extension BookIterableAnalyticsExtension on Iterable<Book> {
  /// Обчислює сумарну кількість сторінок усіх книг у послідовності.
  int get totalPages => fold<int>(0, (sum, book) => sum + book.pages);

  /// Обчислює середній арифметичний рейтинг книг у послідовності.
  double get averageRating {
    final folded = fold<({int count, double sum})>((
      count: 0,
      sum: 0.0,
    ), (acc, book) => (count: acc.count + 1, sum: acc.sum + book.rating));
    return folded.count == 0 ? 0.0 : folded.sum / folded.count;
  }

  /// Групує книги за переліченням жанрів [BookGenre].
  Map<BookGenre, List<Book>> groupByGenre() {
    return fold<Map<BookGenre, List<Book>>>(<BookGenre, List<Book>>{}, (
      grouped,
      book,
    ) {
      grouped.putIfAbsent(book.genre, () => <Book>[]).add(book);
      return grouped;
    });
  }

  /// Повертає відсортований список книг за рейтингом (за замовчуванням за спаданням).
  List<Book> sortedByRating({bool ascending = false}) {
    final copy = toList();
    copy.sort((a, b) {
      final primary = a.rating.compareTo(b.rating);
      final cmp = primary != 0 ? primary : a.year.compareTo(b.year);
      return ascending ? cmp : -cmp;
    });
    return copy;
  }
}
