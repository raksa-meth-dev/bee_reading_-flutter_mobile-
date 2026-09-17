import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:epub_pro/epub_pro.dart' hide Image;
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';

import 'package:bee_reading/screens/reader/reader_theme.dart';
import 'package:bee_reading/theme/app_theme.dart';

class ReaderChapter {
  final String title;
  final int index;
  final String htmlContent;

  const ReaderChapter({
    required this.title,
    required this.index,
    required this.htmlContent,
  });
}

class EpubBookController {
  PageController? pageController;
  void Function(int index)? _jumpCallback;

  void jumpToChapter(int index) {
    if (_jumpCallback != null) {
      _jumpCallback!(index);
    } else if (pageController?.hasClients == true) {
      pageController?.jumpToPage(index);
    }
  }

  void nextPage() {
    if (pageController?.hasClients == true) {
      pageController?.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void previousPage() {
    if (pageController?.hasClients == true) {
      pageController?.previousPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  void dispose() {
    pageController = null;
    _jumpCallback = null;
  }
}

class EpubReaderView extends StatefulWidget {
  const EpubReaderView({
    super.key,
    required this.filePath,
    this.initialProgress = 0.0,
    required this.readerTheme,
    this.fontSize = 16.0,
    required this.controller,
    required this.onChapterChanged,
    required this.onChaptersLoaded,
    this.onTap,
  });

  final String? filePath;
  final double initialProgress;
  final ReaderThemeData readerTheme;
  final double fontSize;
  final EpubBookController controller;
  final void Function(int chapterIndex, int totalChapters) onChapterChanged;
  final void Function(List<ReaderChapter> chapters) onChaptersLoaded;
  final VoidCallback? onTap;

  @override
  State<EpubReaderView> createState() => _EpubReaderViewState();
}

class _EpubReaderViewState extends State<EpubReaderView> {
  bool _isLoading = true;
  String? _errorMessage;
  List<ReaderChapter> _chapters = [];
  final Map<String, Uint8List> _imageCache = {};
  late final PageController _pageController;
  Offset? _pointerDownPos;
  DateTime? _pointerDownTime;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    widget.controller.pageController = _pageController;
    widget.controller._jumpCallback = (index) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    };
    _loadEpub();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  static Future<EpubBook> _parseEpubBytes(List<int> bytes) async {
    return await EpubReader.readBook(bytes);
  }

  Future<void> _loadEpub() async {
    if (widget.filePath == null || widget.filePath!.isEmpty) {
      if (mounted) {
        setState(() {
          _errorMessage = 'No file path provided for this EPUB.';
          _isLoading = false;
        });
      }
      return;
    }

    final file = File(widget.filePath!);
    if (!file.existsSync()) {
      if (mounted) {
        setState(() {
          _errorMessage = 'EPUB file was not found on device storage:\n${widget.filePath}';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      final bytes = await file.readAsBytes();

      // Offload ZIP decompression and XML parsing to background isolate
      final book = kIsWeb
          ? await EpubReader.readBook(bytes)
          : await compute(_parseEpubBytes, bytes);

      _populateImageCache(book.content);
      final extractedChapters = _flattenChapters(book.chapters, book.content);

      if (mounted) {
        setState(() {
          _chapters = extractedChapters;
          _isLoading = false;
        });

        widget.onChaptersLoaded(extractedChapters);

        // Jump to initial progress if provided
        if (extractedChapters.isNotEmpty && widget.initialProgress > 0.0) {
          final targetPage = (widget.initialProgress * (extractedChapters.length - 1))
              .round()
              .clamp(0, extractedChapters.length - 1);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (_pageController.hasClients) {
              _pageController.jumpToPage(targetPage);
            }
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load EPUB: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _populateImageCache(EpubContent? content) {
    _imageCache.clear();
    if (content == null || content.images.isEmpty) return;

    for (final entry in content.images.entries) {
      final bytes = entry.value.content;
      if (bytes != null && bytes.isNotEmpty) {
        final u8 = Uint8List.fromList(bytes);
        _imageCache[entry.key] = u8;

        final norm = entry.key.replaceAll('../', '').replaceAll('./', '');
        _imageCache[norm] = u8;

        final base = entry.key.split('/').last.split('\\').last.toLowerCase();
        _imageCache.putIfAbsent(base, () => u8);
      }
    }
  }

  List<ReaderChapter> _flattenChapters(List<EpubChapter> chapters, EpubContent? content) {
    final List<ReaderChapter> result = [];
    int index = 0;

    void processChapter(EpubChapter ch) {
      final title = ch.title?.trim() ?? '';
      final chapterHtml = ch.htmlContent ?? '';

      if (chapterHtml.trim().isNotEmpty) {
        result.add(ReaderChapter(
          title: title.isNotEmpty ? title : 'Chapter ${index + 1}',
          index: index,
          htmlContent: chapterHtml,
        ));
        index++;
      }

      for (final sub in ch.subChapters) {
        processChapter(sub);
      }
    }

    for (final ch in chapters) {
      processChapter(ch);
    }

    // Fallback: If no chapters had HTML content directly, read from content.html
    if (result.isEmpty && content?.html != null) {
      for (final entry in content!.html.entries) {
        final html = entry.value.content ?? '';
        if (html.trim().isNotEmpty) {
          result.add(ReaderChapter(
            title: 'Section ${index + 1}',
            index: index,
            htmlContent: html,
          ));
          index++;
        }
      }
    }

    return result;
  }

  Uint8List? _findImageBytes(String src) {
    if (_imageCache.containsKey(src)) return _imageCache[src];
    final norm = src.replaceAll('../', '').replaceAll('./', '');
    if (_imageCache.containsKey(norm)) return _imageCache[norm];
    final base = src.split('/').last.split('\\').last.toLowerCase();
    return _imageCache[base];
  }

  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorView(_errorMessage!);
    }

    if (_isLoading) {
      return Container(
        color: widget.readerTheme.backgroundColor,
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: widget.readerTheme.toolbarColor.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 10,
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(color: AppTheme.primary),
                SizedBox(height: 12),
                Text(
                  'Rendering eBook...',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_chapters.isEmpty) {
      return _buildErrorView('No readable chapters found in this EPUB document.');
    }

    return Container(
      color: widget.readerTheme.backgroundColor,
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          _pointerDownPos = event.position;
          _pointerDownTime = DateTime.now();
        },
        onPointerUp: (event) {
          if (_pointerDownPos != null && _pointerDownTime != null) {
            final delta = (event.position - _pointerDownPos!).distance;
            final duration = DateTime.now().difference(_pointerDownTime!);
            _pointerDownPos = null;
            _pointerDownTime = null;
            if (delta < 20.0 && duration.inMilliseconds < 400) {
              widget.onTap?.call();
            }
          }
        },
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: widget.onTap,
          child: PageView.builder(
          controller: _pageController,
          itemCount: _chapters.length,
          onPageChanged: (pageIndex) {
            widget.onChapterChanged(pageIndex, _chapters.length);
          },
          itemBuilder: (context, index) {
            final chapter = _chapters[index];
            return SelectionArea(
              child: RepaintBoundary(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (chapter.title.isNotEmpty) ...[
                        Text(
                          chapter.title,
                          style: TextStyle(
                            color: widget.readerTheme.textColor,
                            fontSize: widget.fontSize * 1.3,
                            fontWeight: FontWeight.bold,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Divider(color: widget.readerTheme.dividerColor, height: 1),
                        const SizedBox(height: 20),
                      ],
                      RepaintBoundary(
                        child: HtmlWidget(
                          chapter.htmlContent,
                          textStyle: TextStyle(
                            color: widget.readerTheme.textColor,
                            fontSize: widget.fontSize,
                            height: 1.6,
                            letterSpacing: 0.2,
                          ),
                          customWidgetBuilder: (element) {
                            if (element.localName == 'img') {
                              final src = element.attributes['src'];
                              if (src != null) {
                                final bytes = _findImageBytes(src);
                                if (bytes != null) {
                                  final mediaQuery = MediaQuery.maybeOf(context);
                                  final targetWidth = mediaQuery != null
                                      ? (mediaQuery.size.width * mediaQuery.devicePixelRatio).toInt()
                                      : null;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                    child: Center(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.memory(
                                          bytes,
                                          fit: BoxFit.contain,
                                          cacheWidth: (targetWidth != null && targetWidth > 0)
                                              ? targetWidth
                                              : null,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                              }
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
}

  Widget _buildErrorView(String message) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: widget.onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 36),
              ),
              const SizedBox(height: 16),
              const Text(
                'Could Not Open EPUB',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: Colors.grey, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
