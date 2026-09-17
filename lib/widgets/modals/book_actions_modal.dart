import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/theme/app_theme.dart';
import 'package:bee_reading/widgets/cached_book_cover.dart';

/// Shows confirmation dialog before deleting a book from the library.
void confirmDeleteBook({
  required BuildContext context,
  required WidgetRef ref,
  required LibraryBook book,
}) {
  showDialog(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Delete Book',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: AppTheme.textDark,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "${book.title}" from your library? This action cannot be undone.',
          style: const TextStyle(fontSize: 14, color: AppTheme.textMuted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              Navigator.pop(dialogContext);
              await ref.read(booksProvider.notifier).deleteBook(book.id);
              messenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 10),
                      Expanded(child: Text('Removed "${book.title}" from library')),
                    ],
                  ),
                  backgroundColor: const Color(0xFFC62828),
                  duration: const Duration(seconds: 3),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      );
    },
  );
}

/// Displays the options modal sheet for a book in the library.
void showBookActionsModal({
  required BuildContext context,
  required WidgetRef ref,
  required LibraryBook book,
  required VoidCallback onOpenReader,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (modalContext) {
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceMuted,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 72,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(gradient: book.coverGradient),
                            child: Center(
                              child: Text(book.emoji, style: const TextStyle(fontSize: 22)),
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
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          book.author,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(book.progress * 100).toInt()}% • Page ${book.currentPage} of ${book.totalPages}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.primaryDark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.auto_stories_rounded, color: AppTheme.primaryDark),
                title: const Text('Continue Reading', style: TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('Resume from page ${book.currentPage}'),
                onTap: () {
                  Navigator.pop(modalContext);
                  onOpenReader();
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.border_color_rounded, color: AppTheme.textDark),
                title: Text('Highlights & Notes (${book.highlightsCount})', style: const TextStyle(fontWeight: FontWeight.w600)),
                onTap: () {
                  Navigator.pop(modalContext);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: book.isFavorite ? Colors.red : AppTheme.textDark,
                ),
                title: Text(
                  book.isFavorite ? 'Remove from Favorites' : 'Add to Favorites',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  ref.read(booksProvider.notifier).toggleFavorite(book.id);
                  Navigator.pop(modalContext);
                },
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.share_rounded, color: AppTheme.textDark),
                title: const Text('Share Book Details', style: TextStyle(fontWeight: FontWeight.w600)),
                onTap: () => Navigator.pop(modalContext),
              ),
              const Divider(height: 24),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                title: const Text(
                  'Delete Book',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.redAccent,
                  ),
                ),
                subtitle: const Text(
                  'Remove this book from your library',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                onTap: () {
                  Navigator.pop(modalContext);
                  confirmDeleteBook(context: context, ref: ref, book: book);
                },
              ),
            ],
          ),
        ),
      );
    },
  );
}
