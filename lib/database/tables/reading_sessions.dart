import 'package:drift/drift.dart';

import 'package:bee_reading/database/tables/books.dart';

@TableIndex(name: 'reading_sessions_book_id_idx', columns: {#bookId})
class ReadingSessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bookId => text().nullable().references(Books, #id, onDelete: KeyAction.cascade)();
  IntColumn get durationSeconds => integer().withDefault(const Constant(0))();
  DateTimeColumn get sessionDate => dateTime().withDefault(currentDateAndTime)();
}
