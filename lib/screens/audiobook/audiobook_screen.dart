import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_bookmarks_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_car_mode_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_chapters_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_controls.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_speed_sheet.dart';
import 'package:bee_reading/screens/reader_screen.dart';
import 'package:bee_reading/services/book_content_service.dart';
import 'package:bee_reading/theme/app_theme.dart';
import 'package:bee_reading/widgets/cached_book_cover.dart';

/// Full-screen immersive Audiobook Player screen for bee_reading.
class AudiobookScreen extends ConsumerStatefulWidget {
  const AudiobookScreen({
    super.key,
    required this.book,
    this.initialChapterIndex,
    this.chapters = const [],
  });

  final LibraryBook book;
  final int? initialChapterIndex;
  final List<ChapterItemData> chapters;

  @override
  ConsumerState<AudiobookScreen> createState() => _AudiobookScreenState();
}

class _AudiobookScreenState extends ConsumerState<AudiobookScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  List<ChapterItemData> _chapters = [];

  @override
  void initState() {
    super.initState();
    _chapters = List.from(widget.chapters);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _pulseAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _pulseController.repeat(reverse: true);

    // If no content currently loaded for this book in TTS provider, initialize it
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndInitPlayback();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkAndInitPlayback() async {
    final ttsState = ref.read(readingTtsProvider);
    final ttsNotifier = ref.read(readingTtsProvider.notifier);
    ttsNotifier.setCurrentBook(widget.book);

    // If chapters were not passed in, load them asynchronously via BookContentService
    if (_chapters.isEmpty) {
      final contentService = ref.read(bookContentServiceProvider);
      final loaded = await contentService.loadChapters(widget.book);
      if (mounted) {
        setState(() {
          _chapters = loaded;
        });
      }
    }

    // If audio is already active for this book, ensure chapter title is synced
    if (ttsState.bookId == widget.book.id && ttsState.hasContent) {
      if (_chapters.isNotEmpty) {
        final currentIdx = ttsState.currentChapterOrPage;
        final matched = _chapters.firstWhere(
          (c) => c.index == currentIdx,
          orElse: () => _chapters.first,
        );
        ttsNotifier.setChapterInfo(
          title: matched.title,
          total: _chapters.length,
          current: currentIdx,
        );
      }
      return;
    }

    // Otherwise, load real speech chunks for saved chapter/page
    final startPageOrChapter = widget.initialChapterIndex ??
        (widget.book.currentPage > 0 ? widget.book.currentPage : 1);

    await ttsNotifier.changeChapterOrPage(
      book: widget.book,
      targetChapterOrPage: startPageOrChapter,
      autoPlay: false,
    );
  }

  void _showChapters() {
    final ttsState = ref.read(readingTtsProvider);
    final ttsNotifier = ref.read(readingTtsProvider.notifier);

    List<ChapterItemData> displayChapters = _chapters;
    if (displayChapters.isEmpty) {
      final total = widget.book.totalPages > 0 ? widget.book.totalPages : 20;
      displayChapters = List.generate(
        total,
        (i) => ChapterItemData(
          index: i + 1,
          title: widget.book.format.toUpperCase() == 'PDF'
              ? 'Page ${i + 1}'
              : 'Chapter ${i + 1}',
        ),
      );
    }

    AudiobookChaptersSheet.show(
      context: context,
      chapters: displayChapters,
      currentChapterIndex: ttsState.currentChapterOrPage,
      onChapterSelected: (newChapterIndex) {
        ttsNotifier.changeChapterOrPage(
          book: widget.book,
          targetChapterOrPage: newChapterIndex,
          autoPlay: ttsState.isPlaying,
        );
      },
    );
  }

  void _openBookmarks() {
    final ttsNotifier = ref.read(readingTtsProvider.notifier);
    AudiobookBookmarksSheet.show(
      context: context,
      bookId: widget.book.id,
      onJumpToLocation: (loc) {
        // e.g. "chapter:chunk"
        final parts = loc.split(':');
        if (parts.length >= 2) {
          final chapter = int.tryParse(parts[0]);
          final chunk = int.tryParse(parts[1]);
          if (chapter != null) {
            ttsNotifier.requestChapterJump(chapter);
          }
          if (chunk != null) {
            ttsNotifier.jumpToChunk(chunk);
          }
        }
      },
    );
  }

  void _openCarMode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AudiobookCarModeView(book: widget.book),
      ),
    );
  }

  void _switchToReader() {
    // Return to reader screen or push reader screen if opened directly from library
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ReaderScreen(book: widget.book),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(readingTtsProvider);
    final ttsNotifier = ref.read(readingTtsProvider.notifier);
    final isPlaying = ttsState.isPlaying;

    final currentChunkText = ttsState.currentChunk ??
        'Audiobook ready. Tap play to start recitation.';
    final currentChapterTitle = ttsState.currentChapterTitle ??
        'Chapter ${ttsState.currentChapterOrPage}';

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Top Navigation Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Row(
                children: [
                  // Collapse / Back button
                  IconButton(
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                    color: AppTheme.textDark,
                    tooltip: 'Minimize Player',
                    onPressed: () => Navigator.pop(context),
                  ),

                  // Title / Status
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'NOW PLAYING',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.book.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.textDark,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Bookmarks
                  IconButton(
                    icon: const Icon(Icons.bookmark_outline_rounded, size: 22),
                    color: AppTheme.textDark,
                    tooltip: 'Audio Bookmarks',
                    onPressed: _openBookmarks,
                  ),

                  // Voice & Pitch settings
                  IconButton(
                    icon: const Icon(Icons.tune_rounded, size: 22),
                    color: AppTheme.textDark,
                    tooltip: 'Voice Settings',
                    onPressed: () => AudiobookSpeedSheet.show(context),
                  ),
                ],
              ),
            ),

            // Scrollable Hero & Text area
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Column(
                  children: [
                    const SizedBox(height: 12),

                    // Book Cover Artwork with subtle pulse & drop shadow
                    Center(
                      child: ScaleTransition(
                        scale: isPlaying ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                        child: Container(
                          width: 200,
                          height: 290,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: isPlaying ? 0.35 : 0.15),
                                blurRadius: isPlaying ? 30 : 16,
                                spreadRadius: isPlaying ? 4 : 1,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(
                                  decoration: BoxDecoration(gradient: widget.book.coverGradient),
                                  child: Center(
                                    child: Text(widget.book.emoji, style: const TextStyle(fontSize: 72)),
                                  ),
                                ),
                                if (widget.book.coverUrl != null)
                                  CachedBookCover(
                                    imageUrl: widget.book.coverUrl!,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.center,
                                    memCacheWidth: 400,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Chapter Title Header with Quick Stepper Arrows
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, size: 28),
                          color: ttsState.canGoPreviousChapter ? AppTheme.textDark : AppTheme.textMuted.withValues(alpha: 0.25),
                          tooltip: 'Previous Chapter',
                          onPressed: ttsState.canGoPreviousChapter
                              ? () => ttsNotifier.previousChapter(widget.book)
                              : null,
                        ),
                        Expanded(
                          child: Text(
                            currentChapterTitle,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.chevron_right_rounded, size: 28),
                          color: ttsState.canGoNextChapter ? AppTheme.textDark : AppTheme.textMuted.withValues(alpha: 0.25),
                          tooltip: 'Next Chapter',
                          onPressed: ttsState.canGoNextChapter
                              ? () => ttsNotifier.nextChapter(widget.book)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'by ${widget.book.author}',
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppTheme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Synchronized Live Speech Box
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      constraints: const BoxConstraints(minHeight: 70, maxHeight: 110),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: AppTheme.surfaceMuted),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.format_quote_rounded,
                              size: 18,
                              color: AppTheme.primaryDark,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                currentChunkText,
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  height: 1.45,
                                  fontStyle: FontStyle.italic,
                                  color: AppTheme.textDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Controls Section (Progress bar + Main Playback Buttons)
            AudiobookControls(book: widget.book),

            const SizedBox(height: 12),

            // Bottom Secondary Actions Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Chapter List Button
                  TextButton.icon(
                    onPressed: _showChapters,
                    icon: const Icon(Icons.list_rounded, size: 20, color: AppTheme.textDark),
                    label: const Text(
                      'Chapters',
                      style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppTheme.surfaceMuted),
                      ),
                    ),
                  ),

                  // Car / Driving Mode Button
                  TextButton.icon(
                    onPressed: _openCarMode,
                    icon: const Icon(Icons.directions_car_rounded, size: 20, color: AppTheme.textDark),
                    label: const Text(
                      'Car Mode',
                      style: TextStyle(color: AppTheme.textDark, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: TextButton.styleFrom(
                      backgroundColor: AppTheme.surface,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: AppTheme.surfaceMuted),
                      ),
                    ),
                  ),

                  // Switch to Reading Mode
                  ElevatedButton.icon(
                    onPressed: _switchToReader,
                    icon: const Icon(Icons.auto_stories_rounded, size: 18),
                    label: const Text(
                      'Read',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
