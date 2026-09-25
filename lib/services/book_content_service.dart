import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:epub_pro/epub_pro.dart' hide Image;
import 'package:pdfrx/pdfrx.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_chapters_sheet.dart';
import 'package:bee_reading/services/book_text_extractor.dart';

/// Lightweight representation of an extracted chapter from an EPUB.
class ExtractedChapter {
  final int index; // 1-indexed
  final String title;
  final String htmlContent;

  const ExtractedChapter({
    required this.index,
    required this.title,
    required this.htmlContent,
  });
}

/// Service providing cached, high-performance extraction of chapters and speech chunks
/// from both EPUB and PDF eBook files.
class BookContentService {
  /// In-memory cache for parsed EPUB chapters mapped by file path.
  final Map<String, List<ExtractedChapter>> _epubChaptersCache = {};

  /// Cached active PDF document to avoid reopening from disk repeatedly.
  PdfDocument? _activePdfDoc;
  String? _activePdfPath;

  /// Offload EPUB byte parsing to a background isolate.
  static Future<EpubBook> _parseEpubBytes(List<int> bytes) async {
    return await EpubReader.readBook(bytes);
  }

  /// Loads and returns a list of chapters (1-indexed) for the given [book].
  Future<List<ChapterItemData>> loadChapters(LibraryBook book) async {
    final format = book.format.toUpperCase();

    if (format == 'PDF') {
      return await _loadPdfChapters(book);
    } else {
      // Default to EPUB / eBook handling
      return await _loadEpubChapters(book);
    }
  }

  /// Extracts structured speech chunks for the requested [chapterOrPage] (1-indexed).
  Future<List<String>> loadChunksForChapterOrPage({
    required LibraryBook book,
    required int chapterOrPage,
  }) async {
    final format = book.format.toUpperCase();

    if (format == 'PDF') {
      return await _loadPdfChunks(book, chapterOrPage);
    } else {
      return await _loadEpubChunks(book, chapterOrPage);
    }
  }

  // ---------------------------------------------------------------------------
  // EPUB Handling
  // ---------------------------------------------------------------------------

  Future<List<ChapterItemData>> _loadEpubChapters(LibraryBook book) async {
    final chapters = await _getOrParseEpubChapters(book);
    if (chapters.isEmpty) {
      final total = book.totalPages > 0 ? book.totalPages : 1;
      return List.generate(
        total,
        (i) => ChapterItemData(
          index: i + 1,
          title: 'Chapter ${i + 1}',
        ),
      );
    }

    return chapters.map((c) => ChapterItemData(
      index: c.index,
      title: c.title,
      subtitle: 'Chapter ${c.index}',
    )).toList();
  }

  Future<List<ExtractedChapter>> _getOrParseEpubChapters(LibraryBook book) async {
    final path = book.filePath;
    if (path == null || path.isEmpty) return const [];

    if (_epubChaptersCache.containsKey(path)) {
      return _epubChaptersCache[path]!;
    }

    final file = File(path);
    if (!file.existsSync()) return const [];

    try {
      final bytes = await file.readAsBytes();
      final epubBook = kIsWeb
          ? await EpubReader.readBook(bytes)
          : await compute(_parseEpubBytes, bytes);

      final extracted = _flattenEpubChapters(epubBook.chapters, epubBook.content);
      _epubChaptersCache[path] = extracted;
      return extracted;
    } catch (e) {
      debugPrint('Error parsing EPUB chapters: $e');
      return const [];
    }
  }

  List<ExtractedChapter> _flattenEpubChapters(List<EpubChapter> chapters, EpubContent? content) {
    final List<ExtractedChapter> result = [];
    int index = 1; // 1-indexed for consistent user-facing and TTS navigation

    void process(EpubChapter ch) {
      final title = ch.title?.trim() ?? '';
      final chapterHtml = ch.htmlContent ?? '';

      if (chapterHtml.trim().isNotEmpty) {
        result.add(ExtractedChapter(
          index: index,
          title: title.isNotEmpty ? title : 'Chapter $index',
          htmlContent: chapterHtml,
        ));
        index++;
      }

      for (final sub in ch.subChapters) {
        process(sub);
      }
    }

    for (final ch in chapters) {
      process(ch);
    }

    if (result.isEmpty && content?.html != null) {
      for (final entry in content!.html.entries) {
        final html = entry.value.content ?? '';
        if (html.trim().isNotEmpty) {
          result.add(ExtractedChapter(
            index: index,
            title: 'Section $index',
            htmlContent: html,
          ));
          index++;
        }
      }
    }

    return result;
  }

  Future<List<String>> _loadEpubChunks(LibraryBook book, int chapterIndex) async {
    final chapters = await _getOrParseEpubChapters(book);
    if (chapters.isEmpty) {
      return ['Welcome to ${book.title} by ${book.author}.'];
    }

    // 1-indexed to 0-indexed lookup
    final targetIndex = (chapterIndex - 1).clamp(0, chapters.length - 1);
    final chapter = chapters[targetIndex];

    final chunks = BookTextExtractor.extractFromHtml(chapter.htmlContent);
    if (chunks.isEmpty) {
      return ['${chapter.title}. This chapter contains no readable text.'];
    }
    return chunks;
  }

  // ---------------------------------------------------------------------------
  // PDF Handling
  // ---------------------------------------------------------------------------

  Future<PdfDocument?> _getPdfDocument(LibraryBook book) async {
    final path = book.filePath;
    if (path == null || path.isEmpty) return null;

    if (_activePdfPath == path && _activePdfDoc != null) {
      return _activePdfDoc;
    }

    final file = File(path);
    if (!file.existsSync()) return null;

    try {
      await _activePdfDoc?.dispose();
      _activePdfDoc = await PdfDocument.openFile(path);
      _activePdfPath = path;
      return _activePdfDoc;
    } catch (e) {
      debugPrint('Error opening PDF document: $e');
      return null;
    }
  }

  Future<List<ChapterItemData>> _loadPdfChapters(LibraryBook book) async {
    final doc = await _getPdfDocument(book);
    final totalPages = doc?.pages.length ?? (book.totalPages > 0 ? book.totalPages : 1);

    if (doc != null) {
      try {
        final outline = await doc.loadOutline();
        if (outline.isNotEmpty) {
          final List<ChapterItemData> items = [];
          for (final item in outline) {
            final pageNum = item.dest?.pageNumber ?? 1;
            final title = item.title.trim();
            items.add(ChapterItemData(
              index: pageNum,
              title: title.isNotEmpty ? title : 'Page $pageNum',
              subtitle: 'Page $pageNum of $totalPages',
            ));
          }
          if (items.isNotEmpty) {
            return items;
          }
        }
      } catch (e) {
        debugPrint('Error loading PDF outline: $e');
      }
    }

    // Default to page-by-page chapters if no outline is present
    return List.generate(
      totalPages,
      (i) => ChapterItemData(
        index: i + 1,
        title: 'Page ${i + 1}',
        subtitle: 'Page ${i + 1} of $totalPages',
      ),
    );
  }

  Future<List<String>> _loadPdfChunks(LibraryBook book, int pageNumber) async {
    final doc = await _getPdfDocument(book);
    if (doc == null || pageNumber < 1 || pageNumber > doc.pages.length) {
      return ['Page $pageNumber contains no readable text.'];
    }

    try {
      final page = doc.pages[pageNumber - 1];
      final text = await page.loadText();
      final raw = text?.fullText ?? '';

      final chunks = BookTextExtractor.extractFromPdfText(raw);
      if (chunks.isEmpty) {
        return ['Page $pageNumber contains no readable text.'];
      }
      return chunks;
    } catch (e) {
      debugPrint('Error reading PDF page text: $e');
      return ['Unable to read text on page $pageNumber.'];
    }
  }

  /// Cleans up resources (disposes open PDF documents and clears EPUB caches).
  void dispose() {
    final doc = _activePdfDoc;
    if (doc != null) {
      unawaited(doc.dispose());
    }
    _activePdfDoc = null;
    _activePdfPath = null;
    _epubChaptersCache.clear();
  }
}

final bookContentServiceProvider = Provider<BookContentService>((ref) {
  final service = BookContentService();
  ref.onDispose(() {
    service.dispose();
  });
  return service;
});
