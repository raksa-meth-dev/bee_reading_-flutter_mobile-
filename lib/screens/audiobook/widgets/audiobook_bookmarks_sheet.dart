import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/database/app_database.dart';
import 'package:bee_reading/providers/database_provider.dart';
import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/theme/app_theme.dart';

/// Bottom sheet displaying audio bookmarks and quotes for the current audiobook.
class AudiobookBookmarksSheet extends ConsumerStatefulWidget {
  const AudiobookBookmarksSheet({
    super.key,
    required this.bookId,
    required this.onJumpToLocation,
  });

  final String bookId;
  final ValueChanged<String> onJumpToLocation;

  static Future<void> show({
    required BuildContext context,
    required String bookId,
    required ValueChanged<String> onJumpToLocation,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AudiobookBookmarksSheet(
        bookId: bookId,
        onJumpToLocation: onJumpToLocation,
      ),
    );
  }

  @override
  ConsumerState<AudiobookBookmarksSheet> createState() => _AudiobookBookmarksSheetState();
}

class _AudiobookBookmarksSheetState extends ConsumerState<AudiobookBookmarksSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveCurrentPositionBookmark() async {
    final ttsState = ref.read(readingTtsProvider);
    final db = ref.read(databaseProvider);

    final currentChunk = ttsState.currentChunk ?? 'Current audio position';
    final location = '${ttsState.currentChapterOrPage}:${ttsState.currentChunkIndex}';
    final preview = currentChunk.length > 80
        ? '${currentChunk.substring(0, 80)}...'
        : currentChunk;

    final id = 'ab_${DateTime.now().millisecondsSinceEpoch}';

    await db.addBookmark(
      BookmarksCompanion.insert(
        id: id,
        bookId: widget.bookId,
        location: location,
        label: Value(preview),
      ),
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Audio quote bookmarked!'),
            ],
          ),
          backgroundColor: AppTheme.textDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final db = ref.watch(databaseProvider);

    return Material(
      color: AppTheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.75),
        child: SafeArea(
          top: false,
          child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag handle
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
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.bookmark_rounded,
                      color: AppTheme.primaryDark,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Audio Bookmarks & Quotes',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        Text(
                          'Quickly jump back to saved moments',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Quick Add Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: ElevatedButton.icon(
                onPressed: _saveCurrentPositionBookmark,
                icon: const Icon(Icons.bookmark_add_rounded, size: 18),
                label: const Text('Bookmark Current Audio Moment'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  elevation: 0,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: AppTheme.surfaceMuted, height: 1),

            // Saved bookmarks list
            Expanded(
              child: StreamBuilder<List<Bookmark>>(
                stream: db.watchBookmarksForBook(widget.bookId),
                builder: (context, snapshot) {
                  final bookmarks = snapshot.data ?? [];

                  if (bookmarks.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.bookmark_outline_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                          const SizedBox(height: 12),
                          const Text(
                            'No Bookmarks Saved Yet',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Tap the button above to bookmark memorable quotes',
                            style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                          ),
                        ],
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: bookmarks.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: AppTheme.surfaceMuted,
                      height: 1,
                      indent: 64,
                    ),
                    itemBuilder: (context, index) {
                      final bm = bookmarks[index];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.background,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppTheme.surfaceMuted),
                          ),
                          child: const Center(
                            child: Icon(Icons.format_quote_rounded, color: AppTheme.primaryDark, size: 18),
                          ),
                        ),
                        title: Text(
                          bm.label ?? 'Bookmark ${index + 1}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textDark,
                          ),
                        ),
                        subtitle: Text(
                          'Location: ${bm.location}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.textMuted),
                          onPressed: () => db.deleteBookmark(bm.id),
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          widget.onJumpToLocation(bm.location);
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
}
