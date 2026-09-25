import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/providers/streak_provider.dart';
import 'package:bee_reading/screens/audiobook/audiobook_hub_screen.dart';
import 'package:bee_reading/screens/library_screen.dart';
import 'package:bee_reading/screens/reader_screen.dart';
import 'package:bee_reading/theme/app_theme.dart';
import 'package:bee_reading/widgets/cached_book_cover.dart';
import 'package:bee_reading/widgets/modals/book_details_modal.dart';
import 'package:bee_reading/widgets/modals/import_book_modal.dart';
import 'package:bee_reading/widgets/modals/streak_details_modal.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTabIndex = 0;
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _selectedCategory = 'All Books';

  static const List<String> _defaultCategories = [
    'All Books',
    'Self-Growth',
    'Sci-Fi & Space',
    'Tech & Coding',
    'Philosophy',
    'Imported',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _startSearch() {
    setState(() {
      _isSearching = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _stopSearch() {
    setState(() {
      _isSearching = false;
      _searchController.clear();
    });
    _searchFocusNode.unfocus();
  }

  void _showImportModal(BuildContext context) {
    showImportBookModal(context, ref);
  }

  void _showStreakDetailsModal(BuildContext context, StreakState streak) {
    showStreakDetailsModal(context, ref, streak);
  }

  void _showBookDetailsModal(BuildContext context, LibraryBook book) {
    showBookDetailsModal(context, ref, book);
  }

  AppBar _buildNormalAppBar(StreakState streak) {
    return AppBar(
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              '🐝',
              style: TextStyle(fontSize: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Bee Reading',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Welcome back, Bookworm!',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // Streak Counter Pill
        GestureDetector(
          key: const ValueKey('streak_counter_badge'),
          onTap: () => _showStreakDetailsModal(context, streak),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppTheme.accentLight,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppTheme.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔥', style: TextStyle(fontSize: 13)),
                const SizedBox(width: 4),
                Text(
                  '${streak.currentStreak}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ],
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.search_rounded, color: AppTheme.textDark),
          tooltip: 'Search books',
          onPressed: _startSearch,
        ),
        IconButton(
          icon: const Icon(Icons.file_upload_outlined, color: AppTheme.textDark),
          tooltip: 'Import book',
          onPressed: () => _showImportModal(context),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  AppBar _buildSearchAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textDark),
        tooltip: 'Close search',
        onPressed: _stopSearch,
      ),
      titleSpacing: 0,
      title: Container(
        height: 44,
        margin: const EdgeInsets.only(right: 16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppTheme.surfaceMuted),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocusNode,
          autofocus: true,
          textInputAction: TextInputAction.search,
          style: const TextStyle(
            fontSize: 14,
            color: AppTheme.textDark,
            fontWeight: FontWeight.w500,
          ),
          decoration: InputDecoration(
            hintText: 'Search books, authors, genres...',
            hintStyle: const TextStyle(
              color: AppTheme.textMuted,
              fontSize: 14,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: AppTheme.primaryDark,
              size: 20,
            ),
            suffixIcon: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _searchController,
              builder: (context, value, _) {
                if (value.text.isEmpty) return const SizedBox.shrink();
                return IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppTheme.textMuted,
                    size: 18,
                  ),
                  tooltip: 'Clear search',
                  onPressed: _searchController.clear,
                );
              },
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(String rawQuery, List<LibraryBook> allBooks) {
    final query = rawQuery.trim().toLowerCase();

    if (query.isEmpty) {
      if (allBooks.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('🔍', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Library is empty',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Import eBooks to search across your collection.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    _stopSearch();
                    _showImportModal(context);
                  },
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Import eBook'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      final tags = allBooks.map((b) => b.title).take(6).toList();

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Row(
            children: const [
              Icon(Icons.trending_up_rounded, size: 18, color: AppTheme.primaryDark),
              SizedBox(width: 8),
              Text(
                'Books in Library',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: tags.map((tag) {
              return ActionChip(
                label: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textDark,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                backgroundColor: AppTheme.surface,
                side: const BorderSide(color: AppTheme.surfaceMuted),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                onPressed: () {
                  _searchController.text = tag;
                  _searchController.selection = TextSelection.fromPosition(
                    TextPosition(offset: tag.length),
                  );
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          const Text(
            'Your Books',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.textDark,
            ),
          ),
          const SizedBox(height: 12),
          ...allBooks
              .take(4)
              .map((book) => _BookSearchResultCard(
                    key: ValueKey(book.id),
                    book: book,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(book: book),
                        ),
                      );
                    },
                    onLongPress: () => _showBookDetailsModal(context, book),
                  )),
        ],
      );
    }

    final results = allBooks
        .where((book) =>
            book.title.toLowerCase().contains(query) ||
            book.author.toLowerCase().contains(query) ||
            book.category.toLowerCase().contains(query))
        .toList();

    if (results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(
                  color: AppTheme.accentLight,
                  shape: BoxShape.circle,
                ),
                child: const Center(
                  child: Text('🔍', style: TextStyle(fontSize: 32)),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'No results for "$query"',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Try checking for typos or searching by author name or category.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _searchController.clear(),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Clear Search'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryDark,
                  side: const BorderSide(color: AppTheme.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: results.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              'Found ${results.length} ${results.length == 1 ? "book" : "books"}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textMuted,
              ),
            ),
          );
        }
        final book = results[index - 1];
        return _BookSearchResultCard(
          key: ValueKey(book.id),
          book: book,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ReaderScreen(book: book),
              ),
            );
          },
          onLongPress: () => _showBookDetailsModal(context, book),
        );
      },
    );
  }

  Widget _buildHomeContent(StreakState streak, List<LibraryBook> allBooks) {
    // Find continue reading book:
    // 1. Book currently being read (0 < progress < 1.0)
    // 2. Or book with progress > 0
    // 3. Or most recently added book
    final continueReadingBook = allBooks.where((b) => b.isReading).firstOrNull ??
        allBooks.where((b) => b.progress > 0).firstOrNull ??
        allBooks.firstOrNull;

    final categoriesSet = <String>{..._defaultCategories};
    for (final b in allBooks) {
      if (b.category.isNotEmpty) categoriesSet.add(b.category);
    }
    final categories = categoriesSet.toList();

    final displayedBooks = _selectedCategory == 'All Books'
        ? allBooks
        : allBooks.where((book) => book.category == _selectedCategory).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // Daily Reading Goal Card with Streak Counter
        GestureDetector(
          onTap: () => _showStreakDetailsModal(context, streak),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF7BD38), Color(0xFFE5A922)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primary.withValues(alpha: 0.28),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Daily Goal 🔥 ${streak.currentStreak} Day Streak',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${streak.todayMinutesRead} of ${streak.dailyGoalMinutes} mins read',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            streak.isTodayGoalReached
                                ? 'Awesome! Goal reached for today 🎉'
                                : 'Keep going! Only ${(streak.dailyGoalMinutes - streak.todayMinutesRead).clamp(0, 999)} mins to hit your streak.',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 68,
                          height: 68,
                          child: CircularProgressIndicator(
                            value: streak.progressPercentage,
                            strokeWidth: 7,
                            backgroundColor: Colors.white.withValues(alpha: 0.25),
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Text(
                          '${(streak.progressPercentage * 100).toInt()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Mini weekly tracker
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (index) {
                      final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                      final isActive = streak.weekActivity[index];
                      final isToday = (DateTime.now().weekday - 1) == index;
                      return Column(
                        children: [
                          Text(
                            days[index],
                            style: TextStyle(
                              color: isToday ? Colors.white : Colors.white70,
                              fontSize: 10,
                              fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isActive
                                  ? Colors.white
                                  : (isToday
                                      ? Colors.white.withValues(alpha: 0.35)
                                      : Colors.black.withValues(alpha: 0.10)),
                            ),
                            child: Center(
                              child: isActive
                                  ? const Text('🔥', style: TextStyle(fontSize: 11))
                                  : (isToday
                                      ? const Text('⏳', style: TextStyle(fontSize: 9))
                                      : null),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Continue Reading Section
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Continue Reading',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            if (allBooks.isNotEmpty)
              TextButton(
                onPressed: () {
                  ref.read(libraryFilterProvider.notifier).setFilter(LibraryFilter.reading);
                  setState(() => _currentTabIndex = 1);
                },
                child: const Text(
                  'See all',
                  style: TextStyle(color: AppTheme.primaryDark),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (continueReadingBook != null)
          GestureDetector(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ReaderScreen(book: continueReadingBook),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.surfaceMuted),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Container(
                            decoration: BoxDecoration(gradient: continueReadingBook.coverGradient),
                            child: Center(
                              child: Text(continueReadingBook.emoji, style: const TextStyle(fontSize: 32)),
                            ),
                          ),
                          if (continueReadingBook.coverUrl != null)
                            CachedBookCover(
                              imageUrl: continueReadingBook.coverUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.center,
                              memCacheWidth: 180,
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
                        Text(
                          continueReadingBook.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${continueReadingBook.author} • ${continueReadingBook.currentPage > 0 ? "Page ${continueReadingBook.currentPage}" : continueReadingBook.format}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: continueReadingBook.progress,
                            minHeight: 6,
                            backgroundColor: AppTheme.surfaceMuted,
                            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          continueReadingBook.isCompleted
                              ? 'Completed • ${continueReadingBook.totalPages} pages'
                              : '${(continueReadingBook.progress * 100).toInt()}% completed • ${continueReadingBook.currentPage} / ${continueReadingBook.totalPages} pages',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppTheme.surfaceMuted),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppTheme.accentLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text('📖', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Start Reading',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Import your first eBook to start reading and tracking progress.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: () => _showImportModal(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Import', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),

        // Explore Categories Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Explore Categories',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            if (_selectedCategory != 'All Books')
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedCategory = 'All Books';
                  });
                },
                child: const Text(
                  'View all',
                  style: TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: categories.map((cat) {
              return _CategoryChip(
                key: ValueKey('category_chip_$cat'),
                label: cat,
                isSelected: _selectedCategory == cat,
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                  });
                },
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 18),

        // Subheader showing category and book count
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              _selectedCategory == 'All Books'
                  ? 'Featured Picks'
                  : '$_selectedCategory Books',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                '${displayedBooks.length} Books',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Books in 2-column Grid or empty state
        if (displayedBooks.isNotEmpty)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayedBooks.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.55,
              crossAxisSpacing: 14,
              mainAxisSpacing: 18,
            ),
            itemBuilder: (context, index) {
              final book = displayedBooks[index];
              return _CategoryGridBookCard(
                key: ValueKey('${book.id}_$_selectedCategory'),
                book: book,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ReaderScreen(book: book),
                    ),
                  );
                },
                onLongPress: () => _showBookDetailsModal(context, book),
              );
            },
          )
        else
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.surfaceMuted),
            ),
            child: Column(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: AppTheme.accentLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: Text('📚', style: TextStyle(fontSize: 24)),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _selectedCategory == 'All Books'
                      ? 'No eBooks in Library'
                      : 'No books in "$_selectedCategory"',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Import EPUB or PDF files from your device to begin reading.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 14),
                ElevatedButton.icon(
                  onPressed: () => _showImportModal(context),
                  icon: const Icon(Icons.file_upload_outlined, size: 16),
                  label: const Text('Import eBook'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(streakProvider);
    final allBooks = ref.watch(booksProvider);

    return PopScope(
      canPop: !_isSearching,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (_isSearching) {
          _stopSearch();
        }
      },
      child: Scaffold(
        backgroundColor: AppTheme.background,
        appBar: _isSearching
            ? _buildSearchAppBar()
            : (_currentTabIndex == 0 ? _buildNormalAppBar(streak) : null),
        body: _isSearching
            ? ValueListenableBuilder<TextEditingValue>(
                valueListenable: _searchController,
                builder: (context, value, _) {
                  return _buildSearchResults(value.text, allBooks);
                },
              )
            : IndexedStack(
                index: _currentTabIndex,
                children: [
                  _buildHomeContent(streak, allBooks),
                  const LibraryScreen(),
                  const AudiobookHubScreen(),
                  const Center(
                    child: Text(
                      'Profile Coming Soon',
                      style: TextStyle(color: AppTheme.textMuted, fontSize: 16),
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentTabIndex,
          onDestinationSelected: (index) => setState(() => _currentTabIndex = index),
          backgroundColor: AppTheme.surface,
          indicatorColor: AppTheme.accentLight,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home, color: AppTheme.primaryDark),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.menu_book_outlined),
              selectedIcon: Icon(Icons.menu_book, color: AppTheme.primaryDark),
              label: 'Library',
            ),
            NavigationDestination(
              icon: Icon(Icons.headphones_outlined),
              selectedIcon: Icon(Icons.headphones, color: AppTheme.primaryDark),
              label: 'Audiobooks',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person, color: AppTheme.primaryDark),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppTheme.primary : AppTheme.surfaceMuted,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textDark,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _CategoryGridBookCard extends StatelessWidget {
  const _CategoryGridBookCard({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
  });

  final LibraryBook book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Cover with proper 2:3 book aspect ratio
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Container(
                        decoration: BoxDecoration(gradient: book.coverGradient),
                        child: Center(
                          child: Text(book.emoji, style: const TextStyle(fontSize: 42)),
                        ),
                      ),
                      if (book.coverUrl != null)
                        CachedBookCover(
                          imageUrl: book.coverUrl!,
                          fit: BoxFit.cover,
                          alignment: Alignment.center,
                          memCacheWidth: 320,
                        ),
                      // Shading gradient for book depth
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.15),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.40),
                            ],
                          ),
                        ),
                      ),
                      // Spine line
                      Positioned(
                        left: 7,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: Colors.white.withValues(alpha: 0.25),
                        ),
                      ),
                      // Category pill
                      Positioned(
                        top: 8,
                        left: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            book.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      // Format pill
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            book.format,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 8.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      if (book.progress > 0)
                        Positioned(
                          bottom: 6,
                          left: 8,
                          right: 8,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: book.progress,
                              minHeight: 4,
                              backgroundColor: Colors.white30,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                book.isCompleted ? const Color(0xFF4CAF50) : AppTheme.primary,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Title & Author
            Text(
              book.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppTheme.textMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookSearchResultCard extends StatelessWidget {
  const _BookSearchResultCard({
    super.key,
    required this.book,
    required this.onTap,
    this.onLongPress,
  });

  final LibraryBook book;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.surfaceMuted),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      book.author,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.surfaceMuted,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            book.category,
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            book.format,
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
