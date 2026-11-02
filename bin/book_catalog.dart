import 'package:book_catalog/book_catalog.dart';

/// Точка входу консольної програми каталогу книг (Лабораторні роботи №1, №2 та №3).
Future<void> main(List<String> arguments) async {
  final referenceDate = DateTime(2026, 10, 22);

  // Частина І. Функціональна модель (Лабораторна робота №1)
  final fullLab1Report = buildFullDiagnosticReport(
    rawBooksCsv,
    topCount: 5,
    ascending: false,
    separator: ' | ',
    referenceDate: referenceDate,
  );
  print(fullLab1Report);

  // Частина ІІ. Об’єктно-орієнтована модель предметної області (Лабораторна робота №2)
  print('');
  final fullLab2Report = buildOopCatalogReport(rawBooksCsv);
  print(fullLab2Report);

  // Частина ІІІ. Асинхронна, потокова та паралельна обробка даних (Лабораторна робота №3)
  print('');
  final fullLab3Report = await buildLab3AsyncReport(rawBooksCsv);
  print(fullLab3Report);
}
