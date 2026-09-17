import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bee_reading/database/app_database.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    // In-memory database for testing
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('can insert, read, and update books with reading progress', () async {
    // 1. Insert a book
    await db.insertOrUpdateBook(
      BooksCompanion.insert(
        id: 'book-1',
        title: 'Atomic Habits',
        filePath: '/storage/books/atomic_habits.epub',
        format: 'epub',
        author: const Value('James Clear'),
        category: const Value('Self-Growth'),
      ),
    );

    // 2. Query books
    final books = await db.getAllBooks();
    expect(books.length, 1);
    expect(books.first.title, 'Atomic Habits');
    expect(books.first.progress, 0.0);

    // 3. Update reading progress
    await db.updateReadingProgress(
      id: 'book-1',
      progress: 0.62,
      cfi: 'epubcfi(/6/4[chapter4]!/4/2/10)',
      page: 124,
    );

    final updated = await db.watchBookById('book-1').first;
    expect(updated?.progress, 0.62);
    expect(updated?.lastLocationCfi, 'epubcfi(/6/4[chapter4]!/4/2/10)');
    expect(updated?.currentPage, 124);
  });

  test('cascades delete on highlights when book is deleted', () async {
    await db.insertOrUpdateBook(
      BooksCompanion.insert(
        id: 'book-2',
        title: 'Dune',
        filePath: '/storage/books/dune.epub',
        format: 'epub',
      ),
    );

    await db.addHighlight(
      HighlightsCompanion.insert(
        id: 'hl-1',
        bookId: 'book-2',
        cfiRange: 'cfi-range-1',
        selectedText: 'Fear is the mind-killer.',
      ),
    );

    var highlights = await db.watchHighlightsForBook('book-2').first;
    expect(highlights.length, 1);
    expect(highlights.first.selectedText, 'Fear is the mind-killer.');

    // Delete the book
    await db.deleteBookById('book-2');

    highlights = await db.watchHighlightsForBook('book-2').first;
    expect(highlights, isEmpty);
  });
}
