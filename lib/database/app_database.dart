import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';

import 'package:bee_reading/database/tables/bookmarks.dart';
import 'package:bee_reading/database/tables/books.dart';
import 'package:bee_reading/database/tables/highlights.dart';
import 'package:bee_reading/database/tables/reading_sessions.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [Books, Highlights, Bookmarks, ReadingSessions])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? e]) : super(e ?? _openConnection());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      beforeOpen: (details) async {
        await customStatement('PRAGMA foreign_keys = ON;');
      },
    );
  }

  static QueryExecutor _openConnection() {
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return NativeDatabase.memory();
    }
    return driftDatabase(name: 'bee_reading_db');
  }

  // --- Books Queries ---
  Stream<List<Book>> watchAllBooks() {
    return (select(books)..orderBy([(t) => OrderingTerm.desc(t.lastReadAt)])).watch();
  }

  Future<List<Book>> getAllBooks() {
    return (select(books)..orderBy([(t) => OrderingTerm.desc(t.lastReadAt)])).get();
  }

  Stream<Book?> watchBookById(String id) {
    return (select(books)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  Future<int> insertOrUpdateBook(BooksCompanion companion) {
    return into(books).insertOnConflictUpdate(companion);
  }

  Future<int> deleteBookById(String id) {
    return (delete(books)..where((t) => t.id.equals(id))).go();
  }

  Future<void> toggleFavorite(String id, bool isFavorite) {
    return (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        isFavorite: Value(isFavorite),
      ),
    );
  }

  Future<void> updateReadingProgress({
    required String id,
    required double progress,
    String? cfi,
    int? page,
  }) {
    return (update(books)..where((t) => t.id.equals(id))).write(
      BooksCompanion(
        progress: Value(progress),
        lastLocationCfi: Value(cfi),
        currentPage: page != null ? Value(page) : const Value.absent(),
        lastReadAt: Value(DateTime.now()),
      ),
    );
  }

  // --- Highlights Queries ---
  Stream<List<Highlight>> watchHighlightsForBook(String bookId) {
    return (select(highlights)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> addHighlight(HighlightsCompanion companion) {
    return into(highlights).insert(companion);
  }

  Future<int> deleteHighlight(String id) {
    return (delete(highlights)..where((t) => t.id.equals(id))).go();
  }

  // --- Bookmarks Queries ---
  Stream<List<Bookmark>> watchBookmarksForBook(String bookId) {
    return (select(bookmarks)
          ..where((t) => t.bookId.equals(bookId))
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch();
  }

  Future<int> addBookmark(BookmarksCompanion companion) {
    return into(bookmarks).insert(companion);
  }

  Future<int> deleteBookmark(String id) {
    return (delete(bookmarks)..where((t) => t.id.equals(id))).go();
  }

  // --- Reading Sessions Queries ---
  Future<int> recordReadingSession({
    String? bookId,
    required int durationSeconds,
    DateTime? sessionDate,
  }) {
    return into(readingSessions).insert(
      ReadingSessionsCompanion(
        bookId: Value(bookId),
        durationSeconds: Value(durationSeconds),
        sessionDate: Value(sessionDate ?? DateTime.now()),
      ),
    );
  }

  Future<List<ReadingSession>> getAllReadingSessions() {
    return (select(readingSessions)..orderBy([(t) => OrderingTerm.desc(t.sessionDate)])).get();
  }

  Stream<List<ReadingSession>> watchAllReadingSessions() {
    return (select(readingSessions)..orderBy([(t) => OrderingTerm.desc(t.sessionDate)])).watch();
  }
}
