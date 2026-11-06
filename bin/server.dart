/// Окрема точка входу HTTP-сервісу каталогу книг на базі `shelf` (Пункти 2, 15).
library;

import 'dart:io';

import 'package:book_catalog/book_catalog.dart';

Future<void> main(List<String> arguments) async {
  final port = arguments.isNotEmpty
      ? (int.tryParse(arguments.first) ?? 8080)
      : 8080;

  final repository = await createSharedCatalogRepository();
  final server = await startCatalogHttpServer(
    repository,
    port: port,
    persistFileName: defaultBooksJsonFileName,
  );

  stdout.writeln(
    '[SHELF SERVER] HTTP-сервіс каталогу запущено: '
    'http://${server.address.host}:${server.port}',
  );
  stdout.writeln(
    '[SHELF SERVER] Маршрути: GET /items, GET /items/<id>, POST /items',
  );
}
