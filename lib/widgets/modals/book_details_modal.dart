import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/screens/audiobook/audiobook_screen.dart';
import 'package:bee_reading/screens/reader_screen.dart';
import 'package:bee_reading/theme/app_theme.dart';
import 'package:bee_reading/widgets/cached_book_cover.dart';

/// Displays detailed information about a book and options to favorite or read.
void showBookDetailsModal(BuildContext context, WidgetRef ref, LibraryBook book) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 108,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.10),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(gradient: book.coverGradient),
                            child: Center(
                              child: Text(book.emoji, style: const TextStyle(fontSize: 36)),
                            ),
                          ),
                          if (book.coverUrl != null)
                            CachedBookCover(
                              imageUrl: book.coverUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              memCacheWidth: 200,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.accentLight,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                book.category,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.surfaceMuted,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                book.format,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          book.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'by ${book.author}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Book Information',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Format: ${book.format} • Size: ${book.fileSize} • Pages: ${book.totalPages}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      ref.read(booksProvider.notifier).toggleFavorite(book.id);
                      Navigator.pop(sheetContext);
                    },
                    icon: Icon(
                      book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                      size: 22,
                      color: book.isFavorite ? Colors.redAccent : AppTheme.textDark,
                    ),
                    tooltip: book.isFavorite ? 'Favorited' : 'Add to Favorites',
                    style: IconButton.styleFrom(
                      side: const BorderSide(color: AppTheme.surfaceMuted),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.all(12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => AudiobookScreen(book: book),
                          ),
                        );
                      },
                      icon: const Icon(Icons.headphones_rounded, size: 18),
                      label: const Text('Audiobook'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textDark,
                        side: const BorderSide(color: AppTheme.surfaceMuted),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(sheetContext);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReaderScreen(book: book),
                          ),
                        );
                      },
                      icon: const Icon(Icons.auto_stories_rounded, size: 18),
                      label: const Text('Read Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
