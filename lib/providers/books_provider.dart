import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/database_provider.dart';
import 'package:bee_reading/services/book_import_service.dart';

class BooksNotifier extends Notifier<List<LibraryBook>> {
  @override
  List<LibraryBook> build() {
    _loadStoredBooks();
    return const [];
  }

  Future<void> _loadStoredBooks() async {
    try {
      final db = ref.read(databaseProvider);
      final storedRows = await db.getAllBooks();
      if (storedRows.isEmpty) {
        return;
      }

      final existingIds = state.map((b) => b.id).toSet();
      final List<LibraryBook> importedBooks = [];

      for (final row in storedRows) {
        if (!existingIds.contains(row.id)) {
          importedBooks.add(
            LibraryBook(
              id: row.id,
              title: row.title,
              author: row.author,
              filePath: row.filePath,
              format: row.format.toUpperCase(),
              category: row.category,
              emoji: row.emoji,
              coverGradient: LinearGradient(
                colors: [Color(row.gradientStart), Color(row.gradientEnd)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              coverUrl: row.coverPath,
              progress: row.progress,
              totalPages: row.totalPages ?? (row.format.toLowerCase() == 'pdf' ? 50 : 200),
              currentPage: row.currentPage,
              fileSize: row.fileSize,
              lastReadTime: row.lastReadAt != null ? 'Recently' : 'Not read yet',
              highlightsCount: 0,
              isFavorite: row.isFavorite,
              isDownloaded: true,
            ),
          );
        }
      }

      if (importedBooks.isNotEmpty) {
        state = [...importedBooks, ...state];
      }
    } catch (e) {
      debugPrint('Error loading stored books from database: $e');
    }
  }

  /// Prompts the system file picker and imports the selected file into the library.
  Future<LibraryBook?> pickAndImportBook({String? category}) async {
    final importService = ref.read(bookImportServiceProvider);
    final newBook = await importService.pickAndImportBook(category: category);
    if (newBook != null) {
      state = [newBook, ...state.where((b) => b.id != newBook.id)];
    }
    return newBook;
  }

  /// Directly imports a [PlatformFile] into the library.
  Future<LibraryBook> importFile(PlatformFile file, {String? category}) async {
    final importService = ref.read(bookImportServiceProvider);
    final newBook = await importService.importPlatformFile(file, category: category);
    state = [newBook, ...state.where((b) => b.id != newBook.id)];
    return newBook;
  }

  void addBook(LibraryBook book) {
    if (!state.any((b) => b.id == book.id || b.title == book.title)) {
      state = [book, ...state];
    }
  }

  void toggleFavorite(String bookId) {
    state = [
      for (final book in state)
        if (book.id == bookId)
          book.copyWith(isFavorite: !book.isFavorite)
        else
          book,
    ];

    try {
      final updatedBook = state.firstWhere((b) => b.id == bookId);
      ref.read(databaseProvider).toggleFavorite(bookId, updatedBook.isFavorite);
    } catch (_) {}
  }

  Future<void> deleteBook(String bookId) async {
    final bookToRemove = state.where((b) => b.id == bookId).firstOrNull;
    state = state.where((b) => b.id != bookId).toList();

    try {
      await ref.read(databaseProvider).deleteBookById(bookId);
      if (bookToRemove?.filePath != null && bookToRemove!.filePath!.isNotEmpty) {
        final file = File(bookToRemove.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (bookToRemove?.coverUrl != null &&
          bookToRemove!.coverUrl!.isNotEmpty &&
          !bookToRemove.coverUrl!.startsWith('http')) {
        final coverFile = File(bookToRemove.coverUrl!);
        if (await coverFile.exists()) {
          await coverFile.delete();
        }
      }
    } catch (e) {
      debugPrint('Error deleting book: $e');
    }
  }

  Future<void> updateReadingProgress({
    required String bookId,
    required double progress,
    int? currentPage,
    int? totalPages,
    String? cfi,
  }) async {
    if (!ref.mounted) return;
    final clamped = progress.clamp(0.0, 1.0);
    state = [
      for (final book in state)
        if (book.id == bookId)
          book.copyWith(
            progress: clamped,
            currentPage: currentPage ?? book.currentPage,
            totalPages: totalPages ?? book.totalPages,
            lastReadTime: 'Just now',
          )
        else
          book,
    ];

    try {
      if (!ref.mounted) return;
      await ref.read(databaseProvider).updateReadingProgress(
        id: bookId,
        progress: clamped,
        page: currentPage,
        cfi: cfi,
      );
    } catch (e) {
      debugPrint('Error saving reading progress: $e');
    }
  }
}

final booksProvider = NotifierProvider<BooksNotifier, List<LibraryBook>>(() {
  return BooksNotifier();
});
