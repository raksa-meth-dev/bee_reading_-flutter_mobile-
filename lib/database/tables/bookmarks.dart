import 'package:drift/drift.dart';

import 'package:bee_reading/database/tables/books.dart';

@TableIndex(name: 'bookmarks_book_id_idx', columns: {#bookId})
class Bookmarks extends Table {
  TextColumn get id => text()();
  TextColumn get bookId => text().references(Books, #id, onDelete: KeyAction.cascade)();
  TextColumn get location => text()();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
