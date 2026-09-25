import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/screens/audiobook/audiobook_screen.dart';
import 'package:bee_reading/theme/app_theme.dart';
import 'package:bee_reading/widgets/cached_book_cover.dart';
import 'package:bee_reading/widgets/modals/import_book_modal.dart';

/// Audiobook Hub Screen displayed when tapping the "Audiobooks" tab in the bottom navigation.
class AudiobookHubScreen extends ConsumerStatefulWidget {
  const AudiobookHubScreen({super.key});

  @override
  ConsumerState<AudiobookHubScreen> createState() => _AudiobookHubScreenState();
}

class _AudiobookHubScreenState extends ConsumerState<AudiobookHubScreen> {
  String _selectedFilter = 'All';
  final TextEditingController _searchController = TextEditingController();

  final List<String> _filters = ['All', 'Continue Listening', 'Favorites'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _openAudiobookPlayer(LibraryBook book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudiobookScreen(book: book),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allBooks = ref.watch(booksProvider);
    final ttsState = ref.watch(readingTtsProvider);
    final ttsNotifier = ref.read(readingTtsProvider.notifier);

    // Active playing book if any
    final activeBook = allBooks.cast<LibraryBook?>().firstWhere(
      (b) => b?.id == ttsState.bookId,
      orElse: () => null,
    );

    // Filter books
    final filteredBooks = allBooks.where((book) {
      if (_selectedFilter == 'Favorites' && !book.isFavorite) return false;
      if (_selectedFilter == 'Continue Listening' && book.progress <= 0.0) return false;

      final query = _searchController.text.trim().toLowerCase();
      if (query.isNotEmpty) {
        final matchTitle = book.title.toLowerCase().contains(query);
        final matchAuthor = book.author.toLowerCase().contains(query);
        if (!matchTitle && !matchAuthor) return false;
      }

      return true;
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Top App Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.accentLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.headphones_rounded,
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
                            'Audiobooks',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            'Listen to any eBook with natural voice',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_rounded, color: AppTheme.primaryDark, size: 26),
                      tooltip: 'Import Book',
                      onPressed: () => showImportBookModal(context, ref),
                    ),
                  ],
                ),
              ),
            ),

            // Now Playing / Active Session Hero Card (if active)
            if (activeBook != null && ttsState.hasContent)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: _buildNowPlayingHeroCard(activeBook, ttsState, ttsNotifier),
                ),
              ),

            // Search Bar
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceMuted),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: 'Search audiobooks...',
                      hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                      border: InputBorder.none,
                      icon: const Icon(Icons.search_rounded, color: AppTheme.textMuted, size: 20),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 18, color: AppTheme.textMuted),
                              onPressed: () {
                                _searchController.clear();
                                setState(() {});
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),

            // Category / Filter Chips
            SliverToBoxAdapter(
              child: SizedBox(
                height: 40,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  scrollDirection: Axis.horizontal,
                  itemCount: _filters.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final filter = _filters[index];
                    final isSelected = _selectedFilter == filter;
                    return ChoiceChip(
                      label: Text(filter),
                      selected: isSelected,
                      onSelected: (val) {
                        if (val) setState(() => _selectedFilter = filter);
                      },
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSelected ? AppTheme.primary : AppTheme.surfaceMuted,
                        ),
                      ),
                      showCheckmark: false,
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Book List Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'All Audiobooks (${filteredBooks.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Books Grid / List
            if (filteredBooks.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: _buildEmptyState(allBooks.isEmpty),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final book = filteredBooks[index];
                      final isCurrentPlaying = activeBook?.id == book.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildAudiobookCard(book, isCurrentPlaying, ttsState),
                      );
                    },
                    childCount: filteredBooks.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildNowPlayingHeroCard(
    LibraryBook book,
    ReadingTtsState ttsState,
    ReadingTtsNotifier ttsNotifier,
  ) {
    final chapterTitle = ttsState.currentChapterTitle ?? 'Chapter ${ttsState.currentChapterOrPage}';
    final currentBlock = ttsState.totalChunks > 0 ? (ttsState.currentChunkIndex + 1) : 0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => _openAudiobookPlayer(book),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E261B), Color(0xFF1E1911)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top label
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          ttsState.isPlaying ? Icons.volume_up_rounded : Icons.pause_circle_rounded,
                          color: AppTheme.primary,
                          size: 14,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          ttsState.isPlaying ? 'NOW PLAYING' : 'PAUSED',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Tap for full player',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white54, size: 16),
                ],
              ),
              const SizedBox(height: 12),

              // Book Details Row
              Row(
                children: [
                  // Book Thumbnail
                  Container(
                    width: 52,
                    height: 74,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(gradient: book.coverGradient),
                            child: Center(
                              child: Text(book.emoji, style: const TextStyle(fontSize: 24)),
                            ),
                          ),
                          if (book.coverUrl != null)
                            CachedBookCover(
                              imageUrl: book.coverUrl!,
                              fit: BoxFit.cover,
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Title & Meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          chapterTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Block $currentBlock of ${ttsState.totalChunks} • ${ttsState.speedMultiplier}x speed',
                          style: const TextStyle(
                            color: AppTheme.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Play / Pause action
                  Material(
                    color: AppTheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => ttsNotifier.togglePlayPause(),
                      child: Container(
                        width: 46,
                        height: 46,
                        alignment: Alignment.center,
                        child: Icon(
                          ttsState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.black87,
                          size: 26,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAudiobookCard(
    LibraryBook book,
    bool isCurrentPlaying,
    ReadingTtsState ttsState,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isCurrentPlaying ? AppTheme.primary : AppTheme.surfaceMuted,
          width: isCurrentPlaying ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _openAudiobookPlayer(book),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                // Cover Art
                Container(
                  width: 58,
                  height: 82,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(gradient: book.coverGradient),
                          child: Center(
                            child: Text(book.emoji, style: const TextStyle(fontSize: 26)),
                          ),
                        ),
                        if (book.coverUrl != null)
                          CachedBookCover(
                            imageUrl: book.coverUrl!,
                            fit: BoxFit.cover,
                          ),
                        // Format Badge
                        Positioned(
                          top: 4,
                          left: 4,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.65),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              book.format,
                              style: const TextStyle(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 14),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        book.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textMuted,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Progress Bar
                      Row(
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: book.progress.clamp(0.0, 1.0),
                                minHeight: 5,
                                backgroundColor: AppTheme.surfaceMuted,
                                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${(book.progress * 100).toInt()}%',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Action Listen Button
                ElevatedButton(
                  onPressed: () => _openAudiobookPlayer(book),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isCurrentPlaying ? AppTheme.primaryDark : AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(12),
                  ),
                  child: Icon(
                    isCurrentPlaying && ttsState.isPlaying
                        ? Icons.volume_up_rounded
                        : Icons.headphones_rounded,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isLibraryEmpty) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(Icons.headphones_rounded, size: 40, color: AppTheme.primaryDark),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              isLibraryEmpty ? 'No Books in Library' : 'No Matching Audiobooks',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isLibraryEmpty
                  ? 'Import any EPUB or PDF book to listen to it as an audiobook.'
                  : 'Try clearing your search or switching category filters.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (isLibraryEmpty)
              ElevatedButton.icon(
                onPressed: () => showImportBookModal(context, ref),
                icon: const Icon(Icons.add_rounded, size: 20),
                label: const Text('Import eBook / Audiobook'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
