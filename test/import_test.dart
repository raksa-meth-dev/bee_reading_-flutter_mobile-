import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bee_reading/database/app_database.dart';
import 'package:bee_reading/main.dart';
import 'package:bee_reading/providers/database_provider.dart';
import 'package:bee_reading/screens/home_screen.dart';
import 'package:bee_reading/services/book_import_service.dart';
import 'package:bee_reading/services/ebook_cover_extractor.dart';

final class FakeTestPlatformFile extends PlatformFile {
  FakeTestPlatformFile({
    required this.testName,
    required this.testSize,
    this.testPath,
    Uint8List? testBytes,
  }) : _bytes = testBytes ?? Uint8List(0);

  final String testName;
  final int testSize;
  final String? testPath;
  final Uint8List _bytes;

  @override
  XFile get xFile => XFile(testPath ?? '/mock/$testName', name: testName);

  @override
  String get name => testName;

  @override
  int? lengthSync() => testSize;

  @override
  Future<int> length() async => testSize;

  @override
  String? get path => testPath;

  @override
  Uri get uri => Uri.file(testPath ?? '/mock/$testName');

  @override
  Future<Uint8List> readAsBytes() async => _bytes;

  @override
  Stream<Uint8List> readAsByteStream() => Stream.value(_bytes);
}

class FakeFilePickerAdapter implements FilePickerAdapter {
  FakeFilePickerAdapter({this.fileToReturn});

  PlatformFile? fileToReturn;

  @override
  Future<PlatformFile?> pickBookFile() async => fileToReturn;
}

Uint8List createMockEpubBytes({
  String title = "Ender's Game",
  String author = 'Orson Scott Card',
  bool includeCover = true,
}) {
  final archive = Archive();

  const containerXml = '''<?xml version="1.0"?>
<container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container">
  <rootfiles>
    <rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/>
  </rootfiles>
</container>''';
  final containerBytes = utf8.encode(containerXml);
  archive.addFile(ArchiveFile('META-INF/container.xml', containerBytes.length, containerBytes));

  final opfXml = '''<?xml version="1.0" encoding="utf-8"?>
<package xmlns="http://www.idpf.org/2007/opf" version="3.0">
  <metadata xmlns:dc="http://purl.org/dc/elements/1.1/">
    <dc:title>$title</dc:title>
    <dc:creator>$author</dc:creator>
  </metadata>
  <manifest>
    ${includeCover ? '<item id="cover-image" href="images/cover.jpg" media-type="image/jpeg" properties="cover-image"/>' : ''}
  </manifest>
</package>''';
  final opfBytes = utf8.encode(opfXml);
  archive.addFile(ArchiveFile('OEBPS/content.opf', opfBytes.length, opfBytes));

  if (includeCover) {
    final fakeJpeg = Uint8List.fromList([
      0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01,
      0x01, 0x01, 0x00, 0x60, 0x00, 0x60, 0x00, 0x00, 0xFF, 0xD9,
    ]);
    archive.addFile(ArchiveFile('OEBPS/images/cover.jpg', fakeJpeg.length, fakeJpeg));
  }

  final zipBytes = ZipEncoder().encode(archive);
  return Uint8List.fromList(zipBytes);
}

void main() {
  group('BookImportService Unit Tests', () {
    test('cleanBookTitle formats raw filenames into clean book titles', () {
      expect(BookImportService.cleanBookTitle('the_hobbit.epub'), 'The Hobbit');
      expect(BookImportService.cleanBookTitle('learning-flutter-in-2026.pdf'), 'Learning Flutter In 2026');
      expect(BookImportService.cleanBookTitle('sapiens_yuval_noah_harari.mobi'), 'Sapiens Yuval Noah Harari');
      expect(BookImportService.cleanBookTitle(''), 'Untitled eBook');
    });

    test('formatFileSize formats byte counts into human-readable strings', () {
      expect(BookImportService.formatFileSize(0), '0 KB');
      expect(BookImportService.formatFileSize(45000), '44 KB');
      expect(BookImportService.formatFileSize(2500000), '2.4 MB');
      expect(BookImportService.formatFileSize(15728640), '15.0 MB');
    });

    test('imports PlatformFile into database with generated visual metadata', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final fakePicker = FakeFilePickerAdapter();
      final service = BookImportService(db, fakePicker);

      final fakeFile = FakeTestPlatformFile(
        testName: 'the_pragmatic_programmer.epub',
        testSize: 3600000,
        testPath: '/storage/the_pragmatic_programmer.epub',
      );

      final book = await service.importPlatformFile(fakeFile, category: 'Tech & Coding');

      expect(book.title, 'The Pragmatic Programmer');
      expect(book.format, 'EPUB');
      expect(book.fileSize, '3.4 MB');
      expect(book.category, 'Tech & Coding');
      expect(book.emoji, isNotEmpty);

      // Verify row persisted in Drift database
      final allRows = await db.getAllBooks();
      expect(allRows.length, 1);
      expect(allRows.first.title, 'The Pragmatic Programmer');
      expect(allRows.first.format, 'epub');
      expect(allRows.first.category, 'Tech & Coding');

      await db.close();
    });

    test('extractMetadataAndCover extracts cover image, title, and author from EPUB archive', () async {
      final epubBytes = createMockEpubBytes(
        title: 'Dune Messiah',
        author: 'Frank Herbert',
        includeCover: true,
      );

      final metadata = await EbookCoverExtractor.extractMetadataAndCover(
        bookId: 'test-book-cover',
        format: 'EPUB',
        fileBytes: epubBytes,
      );

      expect(metadata.title, 'Dune Messiah');
      expect(metadata.author, 'Frank Herbert');
      expect(metadata.coverPath, isNotNull);
      expect(File(metadata.coverPath!).existsSync(), isTrue);

      // Verify file contains valid JPEG header bytes
      final savedBytes = await File(metadata.coverPath!).readAsBytes();
      expect(savedBytes.length, greaterThan(10));
      expect(savedBytes[0], 0xFF);
      expect(savedBytes[1], 0xD8);

      // Cleanup
      await File(metadata.coverPath!).delete();
    });

    test('importPlatformFile extracts cover and persists coverPath in SQLite database', () async {
      final db = AppDatabase(NativeDatabase.memory());
      final fakePicker = FakeFilePickerAdapter();
      final service = BookImportService(db, fakePicker);

      final epubBytes = createMockEpubBytes(
        title: 'Foundation',
        author: 'Isaac Asimov',
        includeCover: true,
      );

      final fakeFile = FakeTestPlatformFile(
        testName: 'foundation.epub',
        testSize: epubBytes.length,
        testBytes: epubBytes,
      );

      final book = await service.importPlatformFile(fakeFile, category: 'Sci-Fi & Space');

      expect(book.title, 'Foundation');
      expect(book.author, 'Isaac Asimov');
      expect(book.coverUrl, isNotNull);
      expect(File(book.coverUrl!).existsSync(), isTrue);

      // Verify row in SQLite database includes coverPath
      final allRows = await db.getAllBooks();
      expect(allRows.length, 1);
      expect(allRows.first.title, 'Foundation');
      expect(allRows.first.author, 'Isaac Asimov');
      expect(allRows.first.coverPath, book.coverUrl);

      // Cleanup cover file
      if (book.coverUrl != null && File(book.coverUrl!).existsSync()) {
        await File(book.coverUrl!).delete();
      }
      await db.close();
    });
  });

  group('Import Book Widget Tests', () {
    testWidgets('Add Book FAB in Library imports book and adds to library state', (WidgetTester tester) async {
      final inMemoryDb = AppDatabase(NativeDatabase.memory());
      final fakePicker = FakeFilePickerAdapter(
        fileToReturn: FakeTestPlatformFile(
          testName: 'steve_jobs_biography.epub',
          testSize: 4200000,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(inMemoryDb),
            filePickerAdapterProvider.overrideWithValue(fakePicker),
          ],
          child: const MyApp(),
        ),
      );

      // Skip welcome screen
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();

      // Go to Library tab
      await tester.tap(find.byIcon(Icons.menu_book_outlined));
      await tester.pumpAndSettle();

      // Verify initial library has 0 books
      expect(find.text('0'), findsWidgets);
      expect(find.text('Add Book'), findsOneWidget);

      // Tap 'Add Book' FAB
      await tester.tap(find.text('Add Book'));
      await tester.pumpAndSettle();

      // Verify imported book title is rendered in library
      expect(find.text('Steve Jobs Biography'), findsOneWidget);
      // Verify book count increased to 1
      expect(find.text('1'), findsWidgets);
      // Verify success snackbar was displayed
      expect(find.text('Imported "Steve Jobs Biography" into library!'), findsOneWidget);

      await inMemoryDb.close();
    });

    testWidgets('Top bar import modal Choose from Device imports file', (WidgetTester tester) async {
      final inMemoryDb = AppDatabase(NativeDatabase.memory());
      final fakePicker = FakeFilePickerAdapter(
        fileToReturn: FakeTestPlatformFile(
          testName: 'flutter_architecture_guide.pdf',
          testSize: 8500000,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(inMemoryDb),
            filePickerAdapterProvider.overrideWithValue(fakePicker),
          ],
          child: const MaterialApp(home: HomeScreen()),
        ),
      );

      // Tap import button in top bar
      final importButtonFinder = find.byTooltip('Import book');
      await tester.tap(importButtonFinder);
      await tester.pumpAndSettle();

      // Tap 'Choose from Device' in modal
      await tester.tap(find.text('Choose from Device'));
      await tester.pumpAndSettle();

      // Verify success snackbar was displayed
      expect(find.text('Imported "Flutter Architecture Guide" into library!'), findsOneWidget);

      await inMemoryDb.close();
    });
  });
}
