import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/database/app_database.dart';

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

final allBooksStreamProvider = StreamProvider<List<Book>>((ref) {
  final db = ref.watch(databaseProvider);
  return db.watchAllBooks();
});
