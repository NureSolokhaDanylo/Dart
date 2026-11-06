# Book Catalog (`book_catalog`)

Навчальний проєкт із розроблення програмного забезпечення мовою **Dart** (SDK `^3.13.2`), що охоплює повний цикл побудови модульного застосунку предметної області **«Каталог книг бібліотеки»** (Лабораторні роботи №1–4).

---

## Канонічна структура пакета (Лабораторна робота №4, `branch: lab4`)

```text
HomeLib/
├── bin/
│   ├── book_catalog.dart           # Тонка точка входу CLI та звіту ЛР1–4 (29 рядків)
│   └── server.dart                 # Окрема тонка точка входу HTTP-сервісу shelf (25 рядків)
├── lib/
│   ├── book_catalog.dart           # Єдина публічна бібліотека-фасад (директиви export)
│   └── src/                        # Приватна реалізація пакета
│       ├── lab1_functional.dart    # ЛР1: Записи (Records), регулярні вирази, конвеєри Iterable
│       ├── oop_models.dart         # ЛР2 + ЛР4: Клас Book, BookGenre, ручні toJson / fromJson
│       ├── book_hierarchy.dart     # ЛР2 + ЛР4: Запечатана ієрархія BookFormat + toJson / fromJson
│       ├── mixins_and_extensions.dart
│       ├── repository_and_patterns.dart
│       ├── async_repository.dart   # ЛР3: AsyncRepository<T>, Future.wait, ParallelWaitError
│       ├── stream_processor.dart   # ЛР3: Stream, async*, StreamController
│       ├── isolate_worker.dart     # ЛР3: Важкі обчислення в Isolate.run
│       ├── json_file_storage.dart  # ЛР4: books.json через p.join та потокове читання openRead()
│       ├── open_library_api_client.dart # ЛР4: Клієнт REST API OpenLibrary + 3 рівні відмов
│       ├── cli_runner.dart         # ЛР4: ArgParser (list, import, fetch, serve), stdout/stderr
│       └── shelf_server.dart       # ЛР4: HTTP-сервер shelf + shelf_router + Middleware
├── test/
│   └── book_catalog_test.dart      # 28 модульних тестів (package:test, MockClient, shelf Request)
├── books.json                      # Локальне JSON-сховище каталогу книг
├── analysis_options.yaml           # Суворі правила лінтера (package:lints/recommended.yaml)
├── CHANGELOG.md                    # Історія версій 1.0.0 .. 4.0.0
├── pubspec.yaml                    # Маніфест пакета та залежностей
└── README.md                       # Документація проєкту
```

---

## 1. Обґрунтування вибору архітектури та типів даних

1. **Поділ на публічний фасад (`lib/book_catalog.dart`) і приватну реалізацію (`lib/src/`)**:
   - Відповідно до домовленостей екосистеми Dart (`Effective Dart: Package Layout`), зовнішні споживачі (зокрема `bin/` та `test/`) імпортують лише `package:book_catalog/book_catalog.dart`, що забезпечує інкапсуляцію деталей реалізації в `lib/src/`.
2. **Ручна серіалізація JSON (`Map<String, Object?>`)**:
   - Замість небезпечного `Map<String, dynamic>` використано `Map<String, Object?>`. Це змушує компілятор перевіряти кожне поле через явне звуження типів (`is String`, `is num`, `is Map<String, Object?>`) до створення незмінного екземпляра `Book`.
3. **Асинхронне файлове сховище та потокове читання (`lib/src/json_file_storage.dart`)**:
   - Для конфігурації та знімків каталогу використано `File.readAsString` / `File.writeAsString` за кросплатформним шляхом `p.join(...)`.
   - Для обробки потенційно великих CSV/текстових наборів застосовано потоковий конвеєр `file.openRead().transform(utf8.decoder).transform(const LineSplitter())`, який споживає константний обсяг оперативної пам’яті `O(1)` незалежно від розміру файлу.
4. **Трирівнева модель відмов HTTP-клієнта (`lib/src/open_library_api_client.dart`)**:
   - Мережеві збої класифіковано переліченням `NetworkFailureLevel`:
     1. `connectionFailure` (`SocketException`, `http.ClientException`);
     2. `nonSuccessStatusCode` (HTTP-статус поза межами `200..299`, наприклад `404`, `500`);
     3. `malformedPayload` (`FormatException` при пошкодженому JSON або відсутності очікуваних полів).
5. **Архітектура HTTP-сервісу (`lib/src/shelf_server.dart`)**:
   - Конвеєр `shelf` побудовано через `Pipeline().addMiddleware(catalogRequestLogger()).addMiddleware(catalogErrorBoundary()).addHandler(router.call)`. Сервер і CLI-застосунок працюють над єдиним спільним сховищем `books.json` / `AsyncRepository<Book>`.

---

## 2. Обґрунтування використання `!`, `late` та `dynamic`

У всій кодовій базі проєкту (`lib/`, `bin/`, `test/`):
- **Оператор `!` (null assertion operator)** — **не використовується (0 входжень)**. Усі nullable-значення перевіряються через `if (x != null)` із автоматичним звуженням типу (type promotion) або оператор `??`.
- **Ключове слово `late`** — **не використовується (0 входжень)**. Навіть у модульних тестах із `setUp`/`tearDown` змінні ініціалізуються безпечними значеннями за замовчуванням без `late`.
- **Тип `dynamic`** — **явно не оголошується у коді проєкту (0 входжень слова `dynamic` у коді)**. Єдине місце непрямого зіткнення з `dynamic` — виклик стандартної функції `jsonDecode(String source)` із бібліотеки `dart:convert`, яка за сигнатурою SDK повертає `dynamic` (оскільки JSON може мати довільну вкладеність). Щоб негайно нейтралізувати `dynamic` і відновити статичну перевірку типів, результат `jsonDecode` одразу присвоюється у змінну типу `final Object? decoded = jsonDecode(...)`, після чого перевіряється оператором `is Map<String, Object?>` або `is List<Object?>`.

---

## 3. Обґрунтування кожної сторонньої залежності з `pub.dev`

### Прямі робочі залежності (`dependencies`):
1. **`path: ^1.9.1`**
   - **Навіщо потрібна:** Безпечна кросплатформна побудова шляхів до локальних файлів (`p.join`) без жорстко закодованих роздільників `/` або `\`.
   - **Які альтернативи розглядалися:** Ручна конкатенація через `Platform.pathSeparator` з `dart:io` (відхилено як менш надійну при роботі з відносними сегментами та кореневими дисками Windows/POSIX) або пакет `file` (надмірний для потреб локального сховища).
2. **`args: ^2.6.0`**
   - **Навіщо потрібна:** Декларативний розбір підкоманд (`list`, `import`, `fetch`, `serve`), іменованих опцій (`--file`, `--genre`, `--min-rating`, `--limit`, `--port`), скорочених прапорців (`-f`, `-g`, `-r`, `-l`, `-p`, `-h`) та автоматична генерація тексту довідки `--help`.
   - **Які альтернативи розглядалися:** Ручний розбір масиву `List<String> arguments` через цикл і `startsWith('--')` (відхилено через схильність до помилок при комбінуванні прапорців) або високорівневий пакет `cli_completion` (надмірний для навчального консольного застосунку).
3. **`http: ^1.2.2`**
   - **Навіщо потрібна:** Виконання клієнтських HTTP-запитів до зовнішнього REST API (`https://openlibrary.org/search.json`) через інтерфейс `http.Client`, а також безшовне підмінювання мережевого шару в модульних тестах за допомогою `MockClient` із `package:http/testing.dart`.
   - **Які альтернативи розглядалися:** Низькорівневий `HttpClient` із `dart:io` (відхилено через багатослівний API потоків і складність мокування в тестах) та стороння бібліотека `dio` (відхилено як важку залежність із зайвими функціями перехоплювачів, тоді як офіційний `package:http` є стандартом команди Dart).
4. **`shelf: ^1.4.2`**
   - **Навіщо потрібна:** Канонічний модульний вебсервер для Dart, що надає абстракції `Request`, `Response`, `Handler`, `Pipeline` та `Middleware`, дозволяючи тестувати HTTP-обробники безпосереднім викликом функції в пам’яті без відкриття мережевого сокета.
   - **Які альтернативи розглядалися:** Пряме використання `HttpServer.bind` із `dart:io` (відхилено через відсутність композиції `Middleware`) або фреймворк `dart_frog` (побудований поверх `shelf`, але вимагає кодогенерації).
5. **`shelf_router: ^1.1.4`**
   - **Навіщо потрібна:** Декларативна маршрутизація HTTP-запитів (`router.get('/items', ...)`, `router.get('/items/<id>', ...)`, `router.post('/items', ...)`) із автоматичним вилученням параметрів шляху (`<id>`).
   - **Які альтернативи розглядалися:** Ручне розгалуження за `request.url.pathSegments` та `request.method` усередині єдиного `Handler` (відхилено, оскільки погіршує читабельність і масштабованість маршрутів).

### Залежності розроблення (`dev_dependencies`):
6. **`lints: ^6.0.0`**
   - **Навіщо потрібна:** Офіційний набір правил статичного аналізатора `package:lints/recommended.yaml` (доповнений правилами `unawaited_futures` та `discarded_futures`).
   - **Альтернативи:** `very_good_analysis` або `flutter_lints` (обрано офіційний базовий пакет `lints` для чистого Dart SDK).
7. **`test: ^1.25.6`**
   - **Навіщо потрібна:** Стандартний фреймворк модульного тестування (`group`, `setUp`, `tearDown`, `expect`, `expectLater`, асинхронні та потокові матчери).
   - **Альтернативи:** Самописні перевірки через `assert` (відхилено, оскільки не дають ізоляції тестів і звітів про проходження).

---

## 4. Приклади запуску консольного застосунку (CLI)

```bash
# 1. Повний демонстраційний запуск усіх 4 лабораторних робіт (ЛР1–ЛР4)
dart run bin/book_catalog.dart

# 2. Виведення довідки CLI (--help)
dart run bin/book_catalog.dart --help

# 3. Імпорт вбудованого CSV-каталогу в локальний файл books.json
dart run bin/book_catalog.dart import --file books.json --limit 12

# 4. Виведення відфільтрованого списку книг із books.json
dart run bin/book_catalog.dart list --file books.json --genre Програмування --min-rating 4.7 --limit 5

# 5. Завантаження книг із зовнішнього REST API OpenLibrary у файл api_books.json
dart run bin/book_catalog.dart fetch --query "clean code" --limit 3 --file api_books.json

# 6. Компіляція самодостатнього виконуваного файлу та його запуск
dart compile exe bin/book_catalog.dart -o build/book_catalog.exe
./build/book_catalog.exe list --limit 3
```

---

## 5. Запуск HTTP-сервісу та приклади запитів `curl`

### Запуск сервера:
```bash
dart run bin/server.dart 8080
# або через CLI-команду:
dart run bin/book_catalog.dart serve --port 8080
```

### Приклади звернень зовнішнім клієнтом `curl`:
```bash
# 1. Отримання списку книг із фільтрацією за жанром та мінімальним рейтингом (200 OK)
curl -i "http://127.0.0.1:8080/items?genre=programming&minRating=4.8"

# 2. Отримання книги за ідентифікатором BK-001 (200 OK)
curl -i "http://127.0.0.1:8080/items/BK-001"

# 3. Запит неіснуючої книги BK-999 (404 Not Found)
curl -i "http://127.0.0.1:8080/items/BK-999"

# 4. Додавання нової книги до каталогу (201 Created)
curl -i -X POST "http://127.0.0.1:8080/items" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{"id":"BK-105","title":"Dart in Action","author":"Chris Buckett","genre":"Програмування","year":2023,"pages":424,"rating":4.8,"isbn":"978-966-700-105-5","addedDate":"2026-10-22"}'

# 5. Надсилання некоректного запиту з порушенням обмежень (400 Bad Request)
curl -i -X POST "http://127.0.0.1:8080/items" \
  -H "Content-Type: application/json; charset=utf-8" \
  -d '{"id":"BK-BAD","year":9999}'
```

---

## 6. Перевірка якості коду, документації та тестів

```bash
# Форматування коду
dart format .

# Статичний аналіз (0 помилок, 0 попереджень)
dart analyze

# Запуск усіх 28 модульних тестів (ЛР1–ЛР4)
dart test

# Генерація HTML-документації пакета з коментарів ///
dart doc
```
