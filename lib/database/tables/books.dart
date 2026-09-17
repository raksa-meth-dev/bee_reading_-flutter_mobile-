import 'package:drift/drift.dart';

@TableIndex(name: 'books_last_read_idx', columns: {#lastReadAt})
@TableIndex(name: 'books_category_idx', columns: {#category})
class Books extends Table {
  TextColumn get id => text()();
  TextColumn get title => text().withLength(min: 1, max: 500)();
  TextColumn get author => text().withDefault(const Constant('Unknown Author'))();
  TextColumn get filePath => text()();
  TextColumn get format => text()(); // 'epub' | 'pdf'
  TextColumn get coverPath => text().nullable()();
  TextColumn get category => text().withDefault(const Constant('General'))();
  RealColumn get progress => real().withDefault(const Constant(0.0))();
  TextColumn get lastLocationCfi => text().nullable()();
  IntColumn get totalPages => integer().nullable()();
  IntColumn get currentPage => integer().withDefault(const Constant(0))();
  TextColumn get fileSize => text().withDefault(const Constant('0 MB'))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();
  TextColumn get emoji => text().withDefault(const Constant('📖'))();
  IntColumn get gradientStart => integer().withDefault(const Constant(0xFFF7BD38))();
  IntColumn get gradientEnd => integer().withDefault(const Constant(0xFFE5A922))();
  DateTimeColumn get lastReadAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();

  @override
  Set<Column> get primaryKey => {id};
}
