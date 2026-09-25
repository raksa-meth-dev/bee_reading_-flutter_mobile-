import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/services/book_content_service.dart';

void main() {
  const sampleBook = LibraryBook(
    id: 'test_bcs_book',
    title: 'The Hobbit',
    author: 'J.R.R. Tolkien',
    format: 'EPUB',
    category: 'Fantasy',
    emoji: '🧙',
    coverGradient: LinearGradient(colors: [Colors.green, Colors.teal]),
    progress: 0.1,
    totalPages: 10,
    currentPage: 2,
    fileSize: '1.5 MB',
    lastReadTime: 'Yesterday',
    highlightsCount: 0,
  );

  const samplePdfBook = LibraryBook(
    id: 'test_bcs_pdf',
    title: 'Flutter Handbook',
    author: 'Google Devs',
    format: 'PDF',
    category: 'Tech',
    emoji: '📄',
    coverGradient: LinearGradient(colors: [Colors.blue, Colors.indigo]),
    progress: 0.5,
    totalPages: 25,
    currentPage: 5,
    fileSize: '4.2 MB',
    lastReadTime: 'Today',
    highlightsCount: 0,
  );

  group('BookContentService Tests', () {
    late BookContentService service;

    setUp(() {
      service = BookContentService();
    });

    tearDown(() {
      service.dispose();
    });

    test('loadChapters generates 1-indexed fallback chapters when filePath is missing', () async {
      final chapters = await service.loadChapters(sampleBook);
      expect(chapters.length, 10);
      expect(chapters.first.index, 1);
      expect(chapters.first.title, 'Chapter 1');
      expect(chapters.last.index, 10);
      expect(chapters.last.title, 'Chapter 10');
    });

    test('loadChapters generates 1-indexed page chapters for PDF when filePath is missing', () async {
      final chapters = await service.loadChapters(samplePdfBook);
      expect(chapters.length, 25);
      expect(chapters.first.index, 1);
      expect(chapters.first.title, 'Page 1');
      expect(chapters.last.index, 25);
      expect(chapters.last.title, 'Page 25');
    });

    test('loadChunksForChapterOrPage returns fallback chunk when file does not exist', () async {
      final chunks = await service.loadChunksForChapterOrPage(
        book: sampleBook,
        chapterOrPage: 1,
      );
      expect(chunks.isNotEmpty, isTrue);
      expect(chunks.first, contains('Welcome to The Hobbit'));
    });

    test('loadChunksForChapterOrPage returns fallback for PDF when file does not exist', () async {
      final chunks = await service.loadChunksForChapterOrPage(
        book: samplePdfBook,
        chapterOrPage: 3,
      );
      expect(chunks.isNotEmpty, isTrue);
      expect(chunks.first, contains('Page 3'));
    });
  });
}
