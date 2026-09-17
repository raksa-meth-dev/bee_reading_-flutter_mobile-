import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/providers/streak_provider.dart';
import 'package:bee_reading/screens/reader/epub_reader_view.dart';
import 'package:bee_reading/screens/reader/pdf_reader_view.dart';
import 'package:bee_reading/screens/reader/reader_theme.dart';
import 'package:bee_reading/services/book_text_extractor.dart';
import 'package:bee_reading/theme/app_theme.dart';
import 'package:bee_reading/widgets/reader/reader_tts_bar.dart';

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({
    super.key,
    required this.book,
  });

  final LibraryBook book;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late ReaderThemeMode _themeMode;
  late double _fontSize;
  bool _isToolbarVisible = true;
  late int _currentPage;
  late int _totalPages;
  late double _progress;
  List<ReaderChapter> _epubChapters = [];
  List<PdfOutlineItem> _pdfOutlines = [];

  // Controllers
  late final PdfBookController _pdfController;
  late final EpubBookController _epubController;

  // Active reading timer
  Timer? _readingTimer;
  Timer? _saveProgressDebounce;
  Timer? _ttsDebounceTimer;

  @override
  void initState() {
    super.initState();
    _themeMode = ReaderThemeMode.light;
    _fontSize = 16.0;
    _currentPage = widget.book.currentPage > 0 ? widget.book.currentPage : 1;
    _totalPages = widget.book.totalPages > 0 ? widget.book.totalPages : 1;
    _progress = widget.book.progress;

    _booksNotifier = ref.read(booksProvider.notifier);
    _ttsNotifier = ref.read(readingTtsProvider.notifier);
    _streakNotifier = ref.read(streakProvider.notifier);

    _pdfController = PdfBookController();
    _epubController = EpubBookController();

    _lastRecordedReadingTime = DateTime.now();

    // Track active reading time: persists real reading sessions to database every 60 seconds
    _readingTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        _lastRecordedReadingTime = DateTime.now();
        _streakNotifier.recordReadingSeconds(
              bookId: widget.book.id,
              seconds: 60,
            );
      }
    });

    // Register TTS auto-advance callback
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _ttsNotifier.onAutoAdvanceRequested = _handleTtsAutoAdvance;
      }
    });
  }

  DateTime _lastRecordedReadingTime = DateTime.now();
  late final BooksNotifier _booksNotifier;
  late final ReadingTtsNotifier _ttsNotifier;
  late final StreakNotifier _streakNotifier;

  @override
  void dispose() {
    _readingTimer?.cancel();
    _saveProgressDebounce?.cancel();
    _ttsDebounceTimer?.cancel();
    final elapsedSinceLastTick = DateTime.now().difference(_lastRecordedReadingTime).inSeconds;
    if (elapsedSinceLastTick >= 10) {
      _streakNotifier.recordReadingSeconds(
            bookId: widget.book.id,
            seconds: elapsedSinceLastTick,
          );
    }
    _saveProgress(immediate: true);
    _ttsNotifier.cleanup();
    _epubController.dispose();
    _pdfController.dispose();
    super.dispose();
  }

  Future<void> _loadTtsForCurrentPage({bool autoPlay = false}) async {
    final isPdf = widget.book.format.toUpperCase() == 'PDF';
    final isEpub = widget.book.format.toUpperCase() == 'EPUB';
    List<String> chunks = [];

    if (isEpub) {
      final chapterIdx = _currentPage - 1;
      if (chapterIdx >= 0 && chapterIdx < _epubChapters.length) {
        final html = _epubChapters[chapterIdx].htmlContent;
        chunks = BookTextExtractor.extractFromHtml(html);
      }
    } else if (isPdf) {
      final pageText = await _pdfController.getPageText(_currentPage);
      if (pageText != null) {
        chunks = BookTextExtractor.extractFromPdfText(pageText);
      }
    }

    if (mounted) {
      _ttsNotifier.loadContent(
        bookId: widget.book.id,
        chapterOrPage: _currentPage,
        chunks: chunks,
        autoStart: autoPlay,
      );
    }
  }

  void _toggleTtsPlayer() {
    if (!mounted) return;
    final ttsState = ref.read(readingTtsProvider);

    if (!ttsState.isPlayerVisible) {
      _ttsNotifier.setPlayerVisible(true);
      if (!ttsState.hasContent || ttsState.currentChapterOrPage != _currentPage) {
        _loadTtsForCurrentPage(autoPlay: true);
      } else {
        _ttsNotifier.play();
      }
    } else {
      _ttsNotifier.togglePlayPause();
    }
  }

  void _handleTtsAutoAdvance() {
    final isPdf = widget.book.format.toUpperCase() == 'PDF';
    final isEpub = widget.book.format.toUpperCase() == 'EPUB';

    if (isEpub) {
      if (_currentPage < _totalPages) {
        _epubController.nextPage();
      } else {
        _ttsNotifier.stop();
      }
    } else if (isPdf) {
      if (_currentPage < _totalPages) {
        _pdfController.nextPage();
      } else {
        _ttsNotifier.stop();
      }
    }
  }

  void _saveProgress({String? cfi, bool immediate = false}) {
    final bookId = widget.book.id;
    final progress = _progress;
    final currentPage = _currentPage;
    final totalPages = _totalPages;

    void executeSave() {
      Future.microtask(() {
        _booksNotifier.updateReadingProgress(
          bookId: bookId,
          progress: progress,
          currentPage: currentPage,
          totalPages: totalPages,
          cfi: cfi,
        );
      });
    }

    if (immediate) {
      _saveProgressDebounce?.cancel();
      executeSave();
    } else {
      _saveProgressDebounce?.cancel();
      _saveProgressDebounce = Timer(const Duration(milliseconds: 500), executeSave);
    }
  }

  void _toggleToolbars() {
    setState(() {
      _isToolbarVisible = !_isToolbarVisible;
    });
  }

  void _showChaptersModal(BuildContext context, ReaderThemeData theme) {
    final isPdf = widget.book.format.toUpperCase() == 'PDF';
    final hasItems = isPdf ? _pdfOutlines.isNotEmpty : _epubChapters.isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.toolbarColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final screenHeight = MediaQuery.sizeOf(context).height;
        final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;

        if (!hasItems) {
          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_rounded, color: theme.secondaryTextColor, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'No Table of Contents Available',
                    style: TextStyle(color: theme.textColor, fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'This document does not provide chapter markers.',
                    style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
                  ),
                ],
              ),
            ),
          );
        }

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: screenHeight * (isLandscape ? 0.9 : 0.75),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPdf ? 'Table of Contents' : 'Chapters',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: theme.toolbarIconColor),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: isPdf ? _pdfOutlines.length : _epubChapters.length,
                  separatorBuilder: (_, _) => Divider(height: 1, color: theme.dividerColor),
                  itemBuilder: (context, index) {
                    if (isPdf) {
                      final item = _pdfOutlines[index];
                      final title = item.title.trim();
                      final isCurrent = item.pageNumber == _currentPage;
                      return ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 20.0 + (item.level * 16.0).clamp(0.0, 48.0),
                          vertical: 2,
                        ),
                        title: Text(
                          title.isNotEmpty ? title : 'Page ${item.pageNumber}',
                          style: TextStyle(
                            color: isCurrent ? AppTheme.primaryDark : theme.textColor,
                            fontSize: 14,
                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                        trailing: Text(
                          'p. ${item.pageNumber}',
                          style: TextStyle(
                            color: isCurrent ? AppTheme.primaryDark : theme.secondaryTextColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onTap: () {
                          Navigator.pop(ctx);
                          if (item.dest != null) {
                            _pdfController.goToDest(item.dest);
                          } else {
                            _pdfController.jumpToPage(item.pageNumber);
                          }
                        },
                      );
                    } else {
                      final chapter = _epubChapters[index];
                      final title = chapter.title.trim();
                      return ListTile(
                        title: Text(
                          title.isNotEmpty ? title : 'Chapter ${index + 1}',
                          style: TextStyle(
                            color: theme.textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        trailing: Icon(Icons.chevron_right_rounded, color: theme.secondaryTextColor, size: 20),
                        onTap: () {
                          Navigator.pop(ctx);
                          try {
                            _epubController.jumpToChapter(chapter.index);
                          } catch (_) {}
                        },
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
      },
    );
  }

  void _showFontAndThemeModal(BuildContext context, ReaderThemeData theme) {
    final isPdf = widget.book.format.toUpperCase() == 'PDF';

    showModalBottomSheet(
      context: context,
      backgroundColor: theme.toolbarColor,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isLandscape = MediaQuery.orientationOf(context) == Orientation.landscape;
            final screenHeight = MediaQuery.sizeOf(context).height;

            Widget buildThemesSection() {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Reading Themes',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _buildThemeOption(
                        label: 'Light',
                        color: const Color(0xFFFAF9F6),
                        borderColor: Colors.black26,
                        textColor: Colors.black87,
                        isSelected: _themeMode == ReaderThemeMode.light,
                        onTap: () {
                          setState(() => _themeMode = ReaderThemeMode.light);
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        label: 'Sepia',
                        color: const Color(0xFFFBF0D9),
                        borderColor: const Color(0xFFE5D2AD),
                        textColor: const Color(0xFF43301B),
                        isSelected: _themeMode == ReaderThemeMode.sepia,
                        onTap: () {
                          setState(() => _themeMode = ReaderThemeMode.sepia);
                          setModalState(() {});
                        },
                      ),
                      const SizedBox(width: 8),
                      _buildThemeOption(
                        label: 'Dark',
                        color: const Color(0xFF1E1E1E),
                        borderColor: Colors.white24,
                        textColor: Colors.white,
                        isSelected: _themeMode == ReaderThemeMode.dark,
                        onTap: () {
                          setState(() => _themeMode = ReaderThemeMode.dark);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                ],
              );
            }

            Widget buildTextOrZoomSection() {
              if (isPdf) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Page Zoom & Fit',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: theme.textColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.backgroundColor,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: theme.dividerColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: Icon(Icons.zoom_out_rounded, color: theme.toolbarIconColor),
                            tooltip: 'Zoom Out',
                            onPressed: () => _pdfController.zoomOut(),
                          ),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: AppTheme.primaryDark,
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            icon: const Icon(Icons.fit_screen_rounded, size: 16),
                            label: const Text(
                              'Fit Width',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () => _pdfController.fitWidth(),
                          ),
                          IconButton(
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                            icon: Icon(Icons.zoom_in_rounded, color: theme.toolbarIconColor),
                            tooltip: 'Zoom In',
                            onPressed: () => _pdfController.zoomIn(),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Font Size',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: theme.textColor,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: theme.backgroundColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: theme.dividerColor),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: Icon(Icons.remove_rounded, color: theme.toolbarIconColor),
                          onPressed: _fontSize > 12
                              ? () {
                                  setState(() => _fontSize -= 1);
                                  setModalState(() {});
                                }
                              : null,
                        ),
                        Text(
                          '${_fontSize.toInt()} pt',
                          style: TextStyle(
                            color: theme.textColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_rounded, color: theme.toolbarIconColor),
                          onPressed: _fontSize < 28
                              ? () {
                                  setState(() => _fontSize += 1);
                                  setModalState(() {});
                                }
                              : null,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }

            return SafeArea(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: screenHeight * (isLandscape ? 0.88 : 0.65),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      24,
                      12,
                      24,
                      isLandscape ? 16 : 24,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            margin: const EdgeInsets.only(bottom: 14),
                            decoration: BoxDecoration(
                              color: theme.dividerColor,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        if (isLandscape)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: buildThemesSection()),
                              const SizedBox(width: 20),
                              Expanded(child: buildTextOrZoomSection()),
                            ],
                          )
                        else ...[
                          buildThemesSection(),
                          const SizedBox(height: 18),
                          buildTextOrZoomSection(),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String label,
    required Color color,
    required Color borderColor,
    required Color textColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.primary : borderColor,
              width: isSelected ? 2.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Aa',
                style: TextStyle(
                  color: textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final readerTheme = ReaderThemeData.fromMode(_themeMode);
    final isPdf = widget.book.format.toUpperCase() == 'PDF';
    final isEpub = widget.book.format.toUpperCase() == 'EPUB';
    final ttsState = ref.watch(readingTtsProvider);

    return Scaffold(
      backgroundColor: readerTheme.backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Core Reader View (dedicated per eBook format)
            Positioned.fill(
              child: isPdf
                  ? PdfReaderView(
                      filePath: widget.book.filePath,
                      initialPage: widget.book.currentPage > 0 ? widget.book.currentPage : 1,
                      readerTheme: readerTheme,
                      controller: _pdfController,
                      onTap: _toggleToolbars,
                      onOutlinesLoaded: (outlines) {
                        if (mounted) {
                          setState(() {
                            _pdfOutlines = outlines;
                          });
                        }
                      },
                      onPageChanged: (curr, total, prog) {
                        if (_currentPage != curr || _totalPages != total) {
                          setState(() {
                            _currentPage = curr;
                            _totalPages = total;
                            _progress = prog;
                          });
                          _saveProgress();

                          final tts = ref.read(readingTtsProvider);
                          if (tts.isPlaying) {
                            _loadTtsForCurrentPage(autoPlay: true);
                          } else if (tts.isPlayerVisible) {
                            _ttsDebounceTimer?.cancel();
                            _ttsDebounceTimer = Timer(const Duration(milliseconds: 400), () {
                              if (mounted &&
                                  ref.read(readingTtsProvider).isPlayerVisible &&
                                  !ref.read(readingTtsProvider).isPlaying) {
                                _loadTtsForCurrentPage(autoPlay: false);
                              }
                            });
                          }
                        }
                      },
                      onDocumentLoaded: (total) {
                        setState(() {
                          _totalPages = total;
                        });
                        if (ref.read(readingTtsProvider).isPlayerVisible) {
                          _loadTtsForCurrentPage();
                        }
                      },
                    )
                  : isEpub
                      ? EpubReaderView(
                          filePath: widget.book.filePath,
                          initialProgress: _progress,
                          fontSize: _fontSize,
                          readerTheme: readerTheme,
                          controller: _epubController,
                          onTap: _toggleToolbars,
                          onChaptersLoaded: (chapters) {
                            setState(() {
                              _epubChapters = chapters;
                              if (chapters.isNotEmpty) {
                                _totalPages = chapters.length;
                              }
                            });
                            if (ref.read(readingTtsProvider).isPlayerVisible) {
                              _loadTtsForCurrentPage();
                            }
                          },
                          onChapterChanged: (chapterIdx, totalChapters) {
                            final prog = totalChapters > 1
                                ? (chapterIdx / (totalChapters - 1)).clamp(0.0, 1.0)
                                : 0.0;
                            setState(() {
                              _currentPage = chapterIdx + 1;
                              _totalPages = totalChapters;
                              _progress = prog;
                            });
                            _saveProgress();

                            final tts = ref.read(readingTtsProvider);
                            if (tts.isPlaying) {
                              _loadTtsForCurrentPage(autoPlay: true);
                            } else if (tts.isPlayerVisible) {
                              _loadTtsForCurrentPage(autoPlay: false);
                            }
                          },
                        )
                      : _buildFallbackReaderView(readerTheme),
            ),

            // Top Overlay Bar (Animated)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              top: _isToolbarVisible ? 0 : -110,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_isToolbarVisible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isToolbarVisible ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: readerTheme.toolbarColor.withValues(alpha: 0.96),
                      border: Border(bottom: BorderSide(color: readerTheme.dividerColor)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.arrow_back_rounded, color: readerTheme.toolbarIconColor),
                          tooltip: 'Back to Library',
                          onPressed: () => Navigator.pop(context),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                widget.book.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: readerTheme.textColor,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.book.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: readerTheme.secondaryTextColor,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            ttsState.isPlaying
                                ? Icons.volume_up_rounded
                                : (ttsState.isPlayerVisible ? Icons.headphones_rounded : Icons.headphones_outlined),
                            color: (ttsState.isPlaying || ttsState.isPlayerVisible)
                                ? AppTheme.primaryDark
                                : readerTheme.toolbarIconColor,
                          ),
                          tooltip: 'Read Aloud (Voice)',
                          onPressed: _toggleTtsPlayer,
                        ),
                        IconButton(
                          icon: Icon(Icons.format_size_rounded, color: readerTheme.toolbarIconColor),
                          tooltip: 'Appearance & Themes',
                          onPressed: () => _showFontAndThemeModal(context, readerTheme),
                        ),
                        IconButton(
                          icon: Icon(Icons.list_alt_rounded, color: readerTheme.toolbarIconColor),
                          tooltip: isPdf ? 'Table of Contents' : 'Chapters',
                          onPressed: () => _showChaptersModal(context, readerTheme),
                        ),
                        IconButton(
                          icon: Icon(
                            widget.book.isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: widget.book.isFavorite ? Colors.redAccent : readerTheme.toolbarIconColor,
                          ),
                          tooltip: 'Favorite',
                          onPressed: () {
                            ref.read(booksProvider.notifier).toggleFavorite(widget.book.id);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Progress & Navigation Bar (Animated)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              bottom: _isToolbarVisible ? 0 : -140,
              left: 0,
              right: 0,
              child: IgnorePointer(
                ignoring: !_isToolbarVisible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: _isToolbarVisible ? 1.0 : 0.0,
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    decoration: BoxDecoration(
                      color: readerTheme.toolbarColor.withValues(alpha: 0.96),
                      border: Border(top: BorderSide(color: readerTheme.dividerColor)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, -4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            IconButton(
                              icon: Icon(Icons.chevron_left_rounded, color: readerTheme.toolbarIconColor),
                              tooltip: 'Previous Page',
                              onPressed: () {
                                if (isPdf) {
                                  _pdfController.previousPage();
                                } else if (isEpub) {
                                  _epubController.previousPage();
                                }
                              },
                            ),
                            Expanded(
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppTheme.primary,
                                  inactiveTrackColor: readerTheme.dividerColor,
                                  thumbColor: AppTheme.primary,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  trackHeight: 3,
                                ),
                                child: Slider(
                                  value: _progress.clamp(0.0, 1.0),
                                  onChanged: (val) {
                                    setState(() {
                                      _progress = val;
                                    });
                                  },
                                  onChangeEnd: (val) {
                                    if (isPdf) {
                                      final targetPage = (val * _totalPages).clamp(1, _totalPages).toInt();
                                      _pdfController.jumpToPage(targetPage);
                                    } else if (isEpub && _epubChapters.isNotEmpty) {
                                      final targetIndex = (val * (_epubChapters.length - 1)).round().clamp(0, _epubChapters.length - 1);
                                      _epubController.jumpToChapter(targetIndex);
                                    }
                                  },
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.chevron_right_rounded, color: readerTheme.toolbarIconColor),
                              tooltip: 'Next Page',
                              onPressed: () {
                                if (isPdf) {
                                  _pdfController.nextPage();
                                } else if (isEpub) {
                                  _epubController.nextPage();
                                }
                              },
                            ),
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              isPdf
                                  ? 'Page $_currentPage of $_totalPages'
                                  : (_epubChapters.isNotEmpty
                                      ? 'Chapter $_currentPage of $_totalPages'
                                      : 'Location: ${(_progress * 100).toInt()}%'),
                              style: TextStyle(
                                color: readerTheme.secondaryTextColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              '${(_progress * 100).toInt()}% completed',
                              style: TextStyle(
                                color: AppTheme.primaryDark,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Floating TTS Player Bar (Animated)
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOutCubic,
              left: 0,
              right: 0,
              bottom: ttsState.isPlayerVisible ? (_isToolbarVisible ? 115 : 12) : -350,
              child: IgnorePointer(
                ignoring: !ttsState.isPlayerVisible,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: ttsState.isPlayerVisible ? 1.0 : 0.0,
                  child: ReaderTtsBar(
                    readerTheme: readerTheme,
                    isPdf: isPdf,
                    currentPage: _currentPage,
                    totalPages: _totalPages,
                    onClose: () => _ttsNotifier.setPlayerVisible(false),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackReaderView(ReaderThemeData theme) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _toggleToolbars,
      child: Center(
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
                child: Text('📖', style: TextStyle(fontSize: 36)),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.book.title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'by ${widget.book.author}',
              style: TextStyle(
                fontSize: 14,
                color: theme.secondaryTextColor,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.surfaceMuted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Format: ${widget.book.format}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.book.filePath != null && File(widget.book.filePath!).existsSync()
                  ? 'Ready to read. Format ${widget.book.format} viewer loaded.'
                  : 'Book file is not found on local storage. Please re-import this eBook.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.secondaryTextColor, fontSize: 13),
            ),
          ],
        ),
      ),
    ),
  );
}
}
