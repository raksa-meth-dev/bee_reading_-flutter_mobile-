import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import 'package:bee_reading/database/app_database.dart';
import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/database_provider.dart';
import 'package:bee_reading/services/ebook_cover_extractor.dart';

/// Adapter interface for picking files from storage to allow easy mocking in tests.
abstract class FilePickerAdapter {
  Future<PlatformFile?> pickBookFile();
}

/// Default implementation using file_picker plugin.
class DefaultFilePickerAdapter implements FilePickerAdapter {
  @override
  Future<PlatformFile?> pickBookFile() async {
    try {
      List<PlatformFile> files;
      try {
        files = await FilePicker.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['epub', 'pdf', 'mobi'],
        );
      } catch (customErr) {
        debugPrint('Custom FileType picker error, falling back to FileType.any: $customErr');
        files = await FilePicker.pickFiles(
          type: FileType.any,
        );
      }
      if (files.isNotEmpty) {
        return files.first;
      }
    } catch (e) {
      debugPrint('FilePicker error: $e');
      rethrow;
    }
    return null;
  }
}

final filePickerAdapterProvider = Provider<FilePickerAdapter>((ref) {
  return DefaultFilePickerAdapter();
});

class BookImportService {
  BookImportService(this._db, this._pickerAdapter);

  final AppDatabase _db;
  final FilePickerAdapter _pickerAdapter;

  static const List<({LinearGradient gradient, String emoji})> _palettes = [
    (
      gradient: LinearGradient(
        colors: [Color(0xFFF7BD38), Color(0xFFE5A922)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '📖',
    ),
    (
      gradient: LinearGradient(
        colors: [Color(0xFF6C63FF), Color(0xFF4A40D4)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '📘',
    ),
    (
      gradient: LinearGradient(
        colors: [Color(0xFFE28743), Color(0xFFC35817)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '📙',
    ),
    (
      gradient: LinearGradient(
        colors: [Color(0xFF2B5876), Color(0xFF4E4376)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '💻',
    ),
    (
      gradient: LinearGradient(
        colors: [Color(0xFF2E8B57), Color(0xFF1E5B37)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '🌿',
    ),
    (
      gradient: LinearGradient(
        colors: [Color(0xFF009688), Color(0xFF00695C)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '📗',
    ),
    (
      gradient: LinearGradient(
        colors: [Color(0xFFC0392B), Color(0xFF962D22)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      emoji: '📕',
    ),
  ];

  /// Prompts user to pick a file from device storage and imports it into the database.
  Future<LibraryBook?> pickAndImportBook({String? category}) async {
    final pickedFile = await _pickerAdapter.pickBookFile();
    if (pickedFile == null) return null;
    return await importPlatformFile(pickedFile, category: category);
  }

  /// Imports a [PlatformFile] into local storage and records it in the Drift database.
  Future<LibraryBook> importPlatformFile(PlatformFile file, {String? category}) async {
    final format = (file.extension ?? 'epub').toUpperCase();
    var title = cleanBookTitle(file.name);
    var author = 'Unknown Author';
    final fileSize = file.lengthSync() ?? await file.length();
    final fileSizeStr = formatFileSize(fileSize);
    final bookId = 'book-${DateTime.now().millisecondsSinceEpoch}';

    // Pick visual palette deterministically based on title hash
    final palette = _palettes[title.hashCode.abs() % _palettes.length];
    final selectedEmoji = format == 'PDF' ? '📄' : palette.emoji;

    final persistentPath = await _saveFileToDocuments(file);

    // Extract cover image and metadata (title, author) from eBook file
    List<int>? rawBytes;
    try {
      rawBytes = await file.readAsBytes();
      if (rawBytes.isEmpty && file.path != null && File(file.path!).existsSync()) {
        rawBytes = await File(file.path!).readAsBytes();
      }
      if (rawBytes.isEmpty && File(persistentPath).existsSync()) {
        rawBytes = await File(persistentPath).readAsBytes();
      }
    } catch (_) {}

    final metadata = await EbookCoverExtractor.extractMetadataAndCover(
      bookId: bookId,
      format: format,
      fileBytes: rawBytes,
      filePath: persistentPath,
    );

    if (metadata.title != null && metadata.title!.trim().isNotEmpty) {
      title = metadata.title!.trim();
    }
    if (metadata.author != null && metadata.author!.trim().isNotEmpty) {
      author = metadata.author!.trim();
    }
    final coverPath = metadata.coverPath;

    final libraryBook = LibraryBook(
      id: bookId,
      title: title,
      author: author,
      filePath: persistentPath,
      format: format,
      category: category ?? 'Imported',
      emoji: selectedEmoji,
      coverGradient: palette.gradient,
      coverUrl: coverPath,
      progress: 0.0,
      totalPages: format == 'PDF' ? 50 : 200,
      currentPage: 0,
      fileSize: fileSizeStr,
      lastReadTime: 'Imported today',
      highlightsCount: 0,
      isFavorite: false,
      isDownloaded: true,
    );

    // Save record to Drift SQLite database
    try {
      await _db.insertOrUpdateBook(
        BooksCompanion(
          id: drift.Value(libraryBook.id),
          title: drift.Value(libraryBook.title),
          author: drift.Value(libraryBook.author),
          filePath: drift.Value(libraryBook.filePath ?? ''),
          format: drift.Value(libraryBook.format.toLowerCase()),
          coverPath: drift.Value(coverPath),
          category: drift.Value(libraryBook.category),
          progress: drift.Value(libraryBook.progress),
          totalPages: drift.Value(libraryBook.totalPages),
          currentPage: drift.Value(libraryBook.currentPage),
          fileSize: drift.Value(libraryBook.fileSize),
          isFavorite: drift.Value(libraryBook.isFavorite),
          emoji: drift.Value(libraryBook.emoji),
          gradientStart: drift.Value(palette.gradient.colors.first.toARGB32()),
          gradientEnd: drift.Value(palette.gradient.colors.last.toARGB32()),
          createdAt: drift.Value(DateTime.now()),
        ),
      );
    } catch (e) {
      debugPrint('Database insert error in BookImportService: $e');
    }

    return libraryBook;
  }

  Future<String> _saveFileToDocuments(PlatformFile file) async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return file.path ?? '/local/books/${file.name}';
    }
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final booksDir = Directory('${docDir.path}/books');
      if (!booksDir.existsSync()) {
        await booksDir.create(recursive: true);
      }
      final targetPath = '${booksDir.path}/${file.name}';
      if (file.path != null && File(file.path!).existsSync()) {
        final savedFile = await File(file.path!).copy(targetPath);
        return savedFile.path;
      } else {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          final savedFile = File(targetPath);
          await savedFile.writeAsBytes(bytes);
          return savedFile.path;
        }
      }
    } catch (e) {
      debugPrint('File persistence note: $e');
    }
    return file.path ?? '/local/books/${file.name}';
  }

  static String cleanBookTitle(String filename) {
    var name = filename;
    final dotIdx = name.lastIndexOf('.');
    if (dotIdx > 0) {
      name = name.substring(0, dotIdx);
    }
    name = name.replaceAll(RegExp(r'[_\-]+'), ' ').trim();
    if (name.isEmpty) return 'Untitled eBook';
    return name.split(' ').map((word) {
      if (word.isEmpty) return '';
      return '${word[0].toUpperCase()}${word.substring(1)}';
    }).join(' ');
  }

  static String formatFileSize(int bytes) {
    if (bytes <= 0) return '0 KB';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

final bookImportServiceProvider = Provider<BookImportService>((ref) {
  final db = ref.watch(databaseProvider);
  final picker = ref.watch(filePickerAdapterProvider);
  return BookImportService(db, picker);
});
