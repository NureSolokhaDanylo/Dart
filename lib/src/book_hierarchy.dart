/// Ієрархія форматів видання книг на основі запечатаного класу `sealed class` (Пункти 3, 5, 6).
///
/// Демонструє:
/// - запечатаний базовий клас [BookFormat] із поліморфними методами;
/// - чотири підтипи ([PrintedFormat], [EBookFormat], [AudioBookFormat], [CollectorFormat]),
///   оголошені за допомогою первинних константних конструкторів Dart 3.13 (`class const`);
/// - вичерпне зіставлення зі зразком через `switch`-вирази без гілки `default`.
library;

/// Запечатаний базовий клас, що описує фізичний або цифровий формат видання книги.
sealed class BookFormat {
  /// Базовий константний конструктор формату книги.
  const BookFormat();

  /// Коротка назва формату видання.
  String get formatName;

  /// Поліморфний метод: повертає опис умов зберігання або доступу до примірника.
  String describeStorageRequirements();

  /// Поліморфний метод: обчислює орієнтовну фізичну масу примірника в грамах
  /// залежно від кількості сторінок [pages] (`0.0` для суто цифрових видань).
  double estimatePhysicalWeightGrams(int pages);

  /// Перетворює об’єкт формату [BookFormat] на словник для JSON-серіалізації (Пункт 9).
  Map<String, Object?> toJson() {
    return switch (this) {
      PrintedFormat(:final isHardcover, :final paperDensityGrams) =>
        <String, Object?>{
          'type': 'printed',
          'isHardcover': isHardcover,
          'paperDensityGrams': paperDensityGrams,
        },
      EBookFormat(
        :final fileExtension,
        :final fileSizeMb,
        :final hasDrmProtection,
      ) =>
        <String, Object?>{
          'type': 'ebook',
          'fileExtension': fileExtension,
          'fileSizeMb': fileSizeMb,
          'hasDrmProtection': hasDrmProtection,
        },
      AudioBookFormat(
        :final durationMinutes,
        :final narrator,
        :final bitrateKbps,
      ) =>
        <String, Object?>{
          'type': 'audiobook',
          'durationMinutes': durationMinutes,
          'narrator': narrator,
          'bitrateKbps': bitrateKbps,
        },
      CollectorFormat(
        :final printRunLimit,
        :final isSignedByAuthor,
        :final slipcaseMaterial,
      ) =>
        <String, Object?>{
          'type': 'collector',
          'printRunLimit': printRunLimit,
          'isSignedByAuthor': isSignedByAuthor,
          'slipcaseMaterial': slipcaseMaterial,
        },
    };
  }

  /// Десеріалізує екземпляр [BookFormat] із JSON-словника [json] з явними приведеннями типів (Пункт 9).
  static BookFormat fromJson(Map<String, Object?> json) {
    final type = json['type'] as String? ?? 'printed';
    return switch (type) {
      'ebook' => EBookFormat(
        fileExtension: json['fileExtension'] as String? ?? 'EPUB',
        fileSizeMb: ((json['fileSizeMb'] as num?) ?? 1.0).toDouble(),
        hasDrmProtection: json['hasDrmProtection'] as bool? ?? false,
      ),
      'audiobook' => AudioBookFormat(
        durationMinutes: ((json['durationMinutes'] as num?) ?? 60).toInt(),
        narrator: json['narrator'] as String? ?? 'Невідомий диктор',
        bitrateKbps: ((json['bitrateKbps'] as num?) ?? 192).toInt(),
      ),
      'collector' => CollectorFormat(
        printRunLimit: ((json['printRunLimit'] as num?) ?? 500).toInt(),
        isSignedByAuthor: json['isSignedByAuthor'] as bool? ?? false,
        slipcaseMaterial:
            json['slipcaseMaterial'] as String? ?? 'Шкіряний футляр',
      ),
      _ => PrintedFormat(
        isHardcover: json['isHardcover'] as bool? ?? true,
        paperDensityGrams: ((json['paperDensityGrams'] as num?) ?? 80).toInt(),
      ),
    };
  }
}

/// Друковане паперове видання (підтип №1), оголошене через первинний конструктор Dart 3.13.
final class const PrintedFormat({
  required final bool isHardcover,
  final int paperDensityGrams = 80,
}) extends BookFormat {
  @override
  String get formatName => isHardcover
      ? 'Друковане (тверда палітурка)'
      : 'Друковане (м’яка обкладинка)';

  @override
  String describeStorageRequirements() {
    final coverType = isHardcover ? 'тверда палітурка' : 'м’яка обкладинка';
    return 'Книжкова шафа (вологість 45–55%), $coverType, папір $paperDensityGrams г/м²';
  }

  @override
  double estimatePhysicalWeightGrams(int pages) {
    final coverWeight = isHardcover ? 140.0 : 45.0;
    final sheetWeight = pages * (paperDensityGrams * 0.015);
    return coverWeight + sheetWeight;
  }
}

/// Електронна текстова книга (підтип №2), оголошена через первинний конструктор Dart 3.13.
final class const EBookFormat({
  required final String fileExtension,
  required final double fileSizeMb,
  final bool hasDrmProtection = false,
}) extends BookFormat {
  @override
  String get formatName => 'Електронна книга ($fileExtension)';

  @override
  String describeStorageRequirements() {
    final drmStatus = hasDrmProtection ? 'із DRM-захистом' : 'без DRM';
    return 'Хмарне сховище формату $fileExtension (${fileSizeMb.toStringAsFixed(1)} МБ, $drmStatus)';
  }

  @override
  double estimatePhysicalWeightGrams(int pages) => 0.0;
}

/// Аудіокнига (підтип №3), оголошена через первинний конструктор Dart 3.13.
final class const AudioBookFormat({
  required final int durationMinutes,
  required final String narrator,
  final int bitrateKbps = 192,
}) extends BookFormat {
  @override
  String get formatName => 'Аудіокнига ($durationMinutes хв)';

  @override
  String describeStorageRequirements() {
    return 'Медіасервер потокового аудіо ($bitrateKbps кбіт/с, диктор: $narrator)';
  }

  @override
  double estimatePhysicalWeightGrams(int pages) => 0.0;
}

/// Колекційне подарункове видання з обмеженим накладом (підтип №4 для Пункту 6),
/// оголошене через первинний конструктор Dart 3.13.
final class const CollectorFormat({
  required final int printRunLimit,
  required final bool isSignedByAuthor,
  final String slipcaseMaterial = 'Шкіряний футляр',
}) extends BookFormat {
  @override
  String get formatName => 'Колекційне видання (наклад $printRunLimit прим.)';

  @override
  String describeStorageRequirements() {
    final signatureNote = isSignedByAuthor
        ? 'з автографом автора'
        : 'без автографа';
    return 'Сейфова вітрина з мікрокліматом, $slipcaseMaterial ($signatureNote)';
  }

  @override
  double estimatePhysicalWeightGrams(int pages) {
    return 320.0 + pages * 1.8;
  }
}

/// Обчислює вартість логістики або цифрового обслуговування видання [format]
/// за допомогою вичерпного `switch`-виразу без гілки `default` (Пункт 6).
///
/// Якщо до [BookFormat] додати новий підтип і не обробити його тут,
/// компілятор Dart видасть помилку `non_exhaustive_switch_expression`.
double calculateFormatHandlingCost(BookFormat format, int pages) {
  return switch (format) {
    PrintedFormat(:final isHardcover, :final paperDensityGrams) =>
      (isHardcover ? 65.0 : 35.0) + pages * (paperDensityGrams / 800.0),
    EBookFormat(:final fileSizeMb, :final hasDrmProtection) =>
      fileSizeMb * 1.5 + (hasDrmProtection ? 25.0 : 5.0),
    AudioBookFormat(:final durationMinutes, :final bitrateKbps) =>
      (durationMinutes / 60.0) * (bitrateKbps / 64.0) * 4.0,
    CollectorFormat(:final printRunLimit, :final isSignedByAuthor) =>
      250.0 + (isSignedByAuthor ? 150.0 : 50.0) + (10000.0 / printRunLimit),
  };
}

/// Повертає коротке маркування типу носія для звіту за допомогою `switch`-виразу без `default`.
String formatCarrierBadge(BookFormat format) {
  return switch (format) {
    PrintedFormat(isHardcover: true) => '[ДРУК:ТВЕРДА]',
    PrintedFormat(isHardcover: false) => '[ДРУК:М’ЯКА]',
    EBookFormat(:final fileExtension) => '[Е-КНИГА:$fileExtension]',
    AudioBookFormat(:final durationMinutes) => '[АУДІО:$durationMinutes хв]',
    CollectorFormat(:final printRunLimit) => '[КОЛЕКЦІЙНЕ:1/$printRunLimit]',
  };
}
