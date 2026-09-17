import 'package:drift/drift.dart';

import 'package:bee_reading/database/tables/books.dart';

@TableIndex(name: 'highlights_book_id_idx', columns: {#bookId})
class Highlights extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get cfiRange => text()();
  TextColumn get selectedText => text()();
  TextColumn get note => text().nullable()();
  IntColumn get colorHex => integer().withDefault(const Constant(0xFFFFE082))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
