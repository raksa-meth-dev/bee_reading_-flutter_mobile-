import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/screens/reader_screen.dart';
import 'package:bee_reading/theme/app_theme.dart';
import 'package:bee_reading/widgets/cached_book_cover.dart';
import 'package:bee_reading/widgets/modals/book_actions_modal.dart';

export 'package:bee_reading/models/library_book.dart';

class LibraryFilterNotifier extends Notifier<LibraryFilter> {
  @override
  LibraryFilter build() => LibraryFilter.all;

  void setFilter(LibraryFilter filter) {
    state = filter;
  }
}

final libraryFilterProvider =
    NotifierProvider<LibraryFilterNotifier, LibraryFilter>(() {
  return LibraryFilterNotifier();
});

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key, this.isStandalone = false});

  final bool isStandalone;

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  LibrarySort _activeSort = LibrarySort.recent;
  bool _isGridView = true;
  String _selectedShelf = 'All';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  final List<String> _shelves = [
    'All',
    'Self-Growth',
    'Sci-Fi & Space',
    'Tech & Coding',
    'Philosophy',
    'Imported',
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<LibraryBook> _getFilteredBooks(List<LibraryBook> allBooks, LibraryFilter activeFilter) {
    var list = allBooks.where((book) {
      // 1. Shelf filter
      if (_selectedShelf != 'All' && book.category != _selectedShelf) {
        return false;
      }

      // 2. Segment filter
      switch (activeFilter) {
        case LibraryFilter.all:
          break;
        case LibraryFilter.reading:
          if (!book.isReading) return false;
          break;
        case LibraryFilter.completed:
          if (!book.isCompleted) return false;
          break;
        case LibraryFilter.downloaded:
          if (!book.isDownloaded) return false;
          break;
        case LibraryFilter.favorites:
          if (!book.isFavorite) return false;
          break;
      }

      // 3. Search query
      if (_searchController.text.trim().isNotEmpty) {
        final q = _searchController.text.trim().toLowerCase();
        final matchTitle = book.title.toLowerCase().contains(q);
        final matchAuthor = book.author.toLowerCase().contains(q);
        final matchCategory = book.category.toLowerCase().contains(q);
        if (!matchTitle && !matchAuthor && !matchCategory) return false;
      }

      return true;
    }).toList();

    // Sorting
    switch (_activeSort) {
      case LibrarySort.recent:
        break; // Preserves natural recent list
      case LibrarySort.title:
        list.sort((a, b) => a.title.compareTo(b.title));
        break;
      case LibrarySort.author:
        list.sort((a, b) => a.author.compareTo(b.author));
        break;
      case LibrarySort.progress:
        list.sort((a, b) => b.progress.compareTo(a.progress));
        break;
    }

    return list;
  }

  void _toggleFavorite(String bookId) {
    ref.read(booksProvider.notifier).toggleFavorite(bookId);
  }

  void _openReader(LibraryBook book) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReaderScreen(book: book),
      ),
    );
  }

  Future<void> _handleImportBook() async {
    try {
      final imported = await ref.read(booksProvider.notifier).pickAndImportBook(
        category: _selectedShelf != 'All' ? _selectedShelf : null,
      );
      if (!mounted) return;
      if (imported != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text('Imported "${imported.title}" into library!')),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file picker: $e\nPlease restart the app if newly updated.'),
          backgroundColor: Colors.red.shade700,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _showSortMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'Sort Library By',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _buildSortTile('Recently Read', LibrarySort.recent, Icons.schedule_rounded),
                _buildSortTile('Book Title (A-Z)', LibrarySort.title, Icons.sort_by_alpha_rounded),
                _buildSortTile('Author Name', LibrarySort.author, Icons.person_outline_rounded),
                _buildSortTile('Reading Progress', LibrarySort.progress, Icons.trending_up_rounded),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSortTile(String title, LibrarySort sort, IconData icon) {
    final isSelected = _activeSort == sort;
    return ListTile(
      leading: Icon(
        icon,
        color: isSelected ? AppTheme.primaryDark : AppTheme.textMuted,
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isSelected ? AppTheme.primaryDark : AppTheme.textDark,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_rounded, color: AppTheme.primaryDark)
          : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onTap: () {
        setState(() => _activeSort = sort);
        Navigator.pop(context);
      },
    );
  }

  void _showBookActionsModal(LibraryBook book) {
    showBookActionsModal(
      context: context,
      ref: ref,
      book: book,
      onOpenReader: () => _openReader(book),
    );
  }

  void _showNewShelfDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: AppTheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Create New Shelf', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: textController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'e.g. Summer Reading 2026',
              hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
              filled: true,
              fillColor: AppTheme.background,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              onPressed: () {
                final name = textController.text.trim();
                if (name.isNotEmpty) {
                  setState(() {
                    _shelves.add(name);
                    _selectedShelf = name;
                  });
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  ({int reading, int completed, int favorites, int downloaded}) _computeCounts(List<LibraryBook> books) {
    int reading = 0;
    int completed = 0;
    int favorites = 0;
    int downloaded = 0;
    for (final b in books) {
      if (b.isReading) reading++;
      if (b.isCompleted) completed++;
      if (b.isFavorite) favorites++;
      if (b.isDownloaded) downloaded++;
    }
    return (
      reading: reading,
      completed: completed,
      favorites: favorites,
      downloaded: downloaded,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<LibraryFilter>(libraryFilterProvider, (previous, next) {
      if (next == LibraryFilter.reading) {
        setState(() {
          _selectedShelf = 'All';
          _searchController.clear();
          _isSearching = false;
        });
      }
    });

    final activeFilter = ref.watch(libraryFilterProvider);
    final allBooks = ref.watch(booksProvider);
    final filtered = _getFilteredBooks(allBooks, activeFilter);
    final counts = _computeCounts(allBooks);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        automaticallyImplyLeading: widget.isStandalone,
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                style: const TextStyle(color: AppTheme.textDark, fontSize: 15),
                decoration: InputDecoration(
                  hintText: 'Search title, author, shelf...',
                  hintStyle: const TextStyle(color: AppTheme.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _isSearching = false);
                    },
                  ),
                ),
                onChanged: (_) => setState(() {}),
              )
            : Row(
                children: [
                  const Text(
                    'My Library',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.accentLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${allBooks.length}',
                      style: const TextStyle(
                        color: AppTheme.primaryDark,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
        actions: [
          if (!_isSearching) ...[
            IconButton(
              icon: const Icon(Icons.search_rounded, color: AppTheme.textDark),
              tooltip: 'Search Library',
              onPressed: () => setState(() => _isSearching = true),
            ),
            IconButton(
              icon: Icon(
                _isGridView ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                color: AppTheme.textDark,
              ),
              tooltip: _isGridView ? 'Switch to List View' : 'Switch to Grid View',
              onPressed: () => setState(() => _isGridView = !_isGridView),
            ),
            IconButton(
              icon: const Icon(Icons.tune_rounded, color: AppTheme.textDark),
              tooltip: 'Sort Options',
              onPressed: _showSortMenu,
            ),
          ],
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // Shelf Selector Carousel
          Container(
            height: 42,
            margin: const EdgeInsets.only(top: 6, bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                ..._shelves.map((shelf) {
                  final isSelected = _selectedShelf == shelf;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(shelf),
                      selected: isSelected,
                      selectedColor: AppTheme.primary,
                      backgroundColor: AppTheme.surface,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : AppTheme.textDark,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        fontSize: 12,
                      ),
                      side: BorderSide(
                        color: isSelected ? AppTheme.primary : AppTheme.surfaceMuted,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onSelected: (val) {
                        if (val) setState(() => _selectedShelf = shelf);
                      },
                    ),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16, color: AppTheme.primaryDark),
                  label: const Text('New Shelf'),
                  labelStyle: const TextStyle(
                    color: AppTheme.primaryDark,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                  backgroundColor: AppTheme.accentLight,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onPressed: _showNewShelfDialog,
                ),
              ],
            ),
          ),

          // Segment Filter Pills (All, Reading, Completed, Downloaded, Favorites)
          Container(
            height: 38,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              children: [
                _buildSegmentFilter('All', LibraryFilter.all, allBooks.length, activeFilter),
                _buildSegmentFilter('Reading', LibraryFilter.reading, counts.reading, activeFilter),
                _buildSegmentFilter('Finished', LibraryFilter.completed, counts.completed, activeFilter),
                _buildSegmentFilter('Favorites', LibraryFilter.favorites, counts.favorites, activeFilter),
                _buildSegmentFilter('Downloaded', LibraryFilter.downloaded, counts.downloaded, activeFilter),
              ],
            ),
          ),

          // Main Books Container
          Expanded(
            child: filtered.isEmpty
                ? _buildEmptyState()
                : _isGridView
                    ? _buildGridView(filtered)
                    : _buildListView(filtered),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _handleImportBook,
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add Book',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildSegmentFilter(String label, LibraryFilter filter, int count, LibraryFilter activeFilter) {
    final isSelected = activeFilter == filter;
    return GestureDetector(
      onTap: () => ref.read(libraryFilterProvider.notifier).setFilter(filter),
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.textDark : AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.textDark : AppTheme.surfaceMuted,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? Colors.white : AppTheme.textDark,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.2) : AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGridView(List<LibraryBook> books) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 80),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.53,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _LibraryGridCard(
          key: ValueKey(book.id),
          book: book,
          onTap: () => _openReader(book),
          onMoreTap: () => _showBookActionsModal(book),
          onFavoriteTap: () => _toggleFavorite(book.id),
        );
      },
    );
  }

  Widget _buildListView(List<LibraryBook> books) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 80),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return _LibraryListTile(
          key: ValueKey(book.id),
          book: book,
          onTap: () => _openReader(book),
          onMoreTap: () => _showBookActionsModal(book),
          onFavoriteTap: () => _toggleFavorite(book.id),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                color: AppTheme.accentLight,
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text('📚', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No Books Found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppTheme.textDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'No books match the selected shelf or filter. Try switching filters or import an eBook.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: AppTheme.textMuted,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                ref.read(libraryFilterProvider.notifier).setFilter(LibraryFilter.all);
                setState(() {
                  _selectedShelf = 'All';
                  _searchController.clear();
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reset Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LibraryGridCard extends StatelessWidget {
  const _LibraryGridCard({
    super.key,
    required this.book,
    required this.onTap,
    this.onMoreTap,
    required this.onFavoriteTap,
  });

  final LibraryBook book;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: GestureDetector(
        onTap: onTap,
        onLongPress: onMoreTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Book Jacket with standard 2:3 aspect ratio
            AspectRatio(
              aspectRatio: 2 / 3,
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          decoration: BoxDecoration(gradient: book.coverGradient),
                          child: Center(
                            child: Text(book.emoji, style: const TextStyle(fontSize: 44)),
                          ),
                        ),
                        if (book.coverUrl != null)
                          CachedBookCover(
                            imageUrl: book.coverUrl!,
                            fit: BoxFit.cover,
                            alignment: Alignment.center,
                            memCacheWidth: 360,
                          ),
                      // Shading gradient for contrast
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.20),
                              Colors.transparent,
                              Colors.black.withValues(alpha: 0.45),
                            ],
                          ),
                        ),
                      ),
                      // Spine line
                      Positioned(
                        left: 8,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 2,
                          color: Colors.white.withValues(alpha: 0.30),
                        ),
                      ),
                    ],
                  ),
                ),
                // Top format badge
                Positioned(
                  top: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.40),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      book.format,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                // Top right actions
                Positioned(
                  top: 2,
                  right: 2,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        padding: const EdgeInsets.all(4),
                        icon: Icon(
                          book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: book.isFavorite ? Colors.redAccent : Colors.white,
                          size: 18,
                        ),
                        onPressed: onFavoriteTap,
                      ),
                      if (onMoreTap != null)
                        IconButton(
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                          padding: const EdgeInsets.all(4),
                          icon: const Icon(Icons.more_vert_rounded, color: Colors.white, size: 18),
                          tooltip: 'Options',
                          onPressed: onMoreTap,
                        ),
                    ],
                  ),
                ),
                // Progress Pill at Bottom
                if (book.progress > 0)
                  Positioned(
                    bottom: 8,
                    right: 8,
                    left: 8,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: book.progress,
                        minHeight: 5,
                        backgroundColor: Colors.white.withValues(alpha: 0.35),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          book.isCompleted ? const Color(0xFF4CAF50) : Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
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
              fontSize: 11,
              color: AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              Text(
                book.isCompleted
                    ? 'Finished'
                    : '${(book.progress * 100).toInt()}% • p. ${book.currentPage}',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: book.isCompleted ? const Color(0xFF2E7D32) : AppTheme.primaryDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ),);
  }
}

class _LibraryListTile extends StatelessWidget {
  const _LibraryListTile({
    super.key,
    required this.book,
    required this.onTap,
    this.onMoreTap,
    required this.onFavoriteTap,
  });

  final LibraryBook book;
  final VoidCallback onTap;
  final VoidCallback? onMoreTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
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
        child: InkWell(
          onTap: onTap,
          onLongPress: onMoreTap,
          borderRadius: BorderRadius.circular(14),
          child: Row(
            children: [
              // Cover thumbnail
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

            // Book Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: AppTheme.accentLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          book.format,
                          style: const TextStyle(
                            color: AppTheme.primaryDark,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        book.category,
                        style: const TextStyle(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
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
                  const SizedBox(height: 2),
                  Text(
                    '${book.author} • ${book.fileSize}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.textMuted,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Progress Bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: book.progress,
                      minHeight: 4,
                      backgroundColor: AppTheme.surfaceMuted,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        book.isCompleted ? const Color(0xFF4CAF50) : AppTheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.isCompleted
                        ? 'Completed • ${book.totalPages} pages'
                        : '${(book.progress * 100).toInt()}% completed • Page ${book.currentPage} of ${book.totalPages}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Favorite Button
            IconButton(
              icon: Icon(
                book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: book.isFavorite ? Colors.redAccent : AppTheme.textMuted,
                size: 20,
              ),
              onPressed: onFavoriteTap,
            ),
            if (onMoreTap != null)
              IconButton(
                icon: const Icon(Icons.more_vert_rounded, color: AppTheme.textMuted, size: 20),
                tooltip: 'Book options',
                onPressed: onMoreTap,
              ),
          ],
        ),
      ),
    ),
  );
}
}
