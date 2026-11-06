import 'dart:io';

import 'package:book_catalog/book_catalog.dart';

/// Тонка точка входу консольного застосунку каталогу книг (Лабораторні роботи №1–4).
Future<void> main(List<String> arguments) async {
  if (arguments.isNotEmpty) {
    final seedBooks = parseDefaultCatalogSeedBooks();
    await executeCatalogCli(arguments, seedBooks: seedBooks);
    return;
  }

  final referenceDate = DateTime(2026, 10, 22);
  stdout.writeln(
    buildFullDiagnosticReport(
      rawBooksCsv,
      topCount: 5,
      ascending: false,
      separator: ' | ',
      referenceDate: referenceDate,
    ),
  );
  stdout.writeln();
  stdout.writeln(buildOopCatalogReport(rawBooksCsv));
  stdout.writeln();
  stdout.writeln(await buildLab3AsyncReport(rawBooksCsv));
  stdout.writeln();
  stdout.writeln(await buildLab4ModularReport(rawBooksCsv));
}
