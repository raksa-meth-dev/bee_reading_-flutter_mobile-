import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:bee_reading/screens/reader/reader_theme.dart';
import 'package:bee_reading/theme/app_theme.dart';

/// Outline/chapter marker inside a PDF document.
class PdfOutlineItem {
  final String title;
  final int pageNumber;
  final PdfDest? dest;
  final int level;

  const PdfOutlineItem({
    required this.title,
    required this.pageNumber,
    this.dest,
    this.level = 0,
  });
}

/// Controller providing high-level PDF navigation and state access.
class PdfBookController {
  PdfBookController({PdfViewerController? rawController})
      : rawController = rawController ?? PdfViewerController();

  final PdfViewerController rawController;
  PdfDocument? document;

  bool get isReady => rawController.isReady;
  int get pageCount => isReady ? rawController.pageCount : 1;
  int get currentPage => isReady ? (rawController.pageNumber ?? 1) : 1;

  Future<String?> getPageText(int pageNumber) async {
    if (document == null || pageNumber < 1 || pageNumber > document!.pages.length) {
      return null;
    }
    try {
      final page = document!.pages[pageNumber - 1];
      final text = await page.loadText();
      return text?.fullText;
    } catch (e) {
      debugPrint('Error getting PDF page text: $e');
      return null;
    }
  }

  void jumpToPage(int page, {Duration duration = const Duration(milliseconds: 200)}) {
    if (isReady && pageCount > 0) {
      final target = page.clamp(1, pageCount);
      rawController.goToPage(pageNumber: target, duration: duration);
    }
  }

  void nextPage({Duration duration = const Duration(milliseconds: 200)}) {
    if (isReady && pageCount > 0) {
      final curr = rawController.pageNumber ?? 1;
      if (curr < pageCount) {
        rawController.goToPage(pageNumber: curr + 1, duration: duration);
      }
    }
  }

  void previousPage({Duration duration = const Duration(milliseconds: 200)}) {
    if (isReady && pageCount > 0) {
      final curr = rawController.pageNumber ?? 1;
      if (curr > 1) {
        rawController.goToPage(pageNumber: curr - 1, duration: duration);
      }
    }
  }

  void goToDest(PdfDest? dest, {Duration duration = const Duration(milliseconds: 200)}) {
    if (dest != null && isReady) {
      rawController.goToDest(dest, duration: duration);
    }
  }

  void zoomIn() {
    if (isReady) {
      rawController.zoomUp();
    }
  }

  void zoomOut() {
    if (isReady) {
      rawController.zoomDown();
    }
  }

  void fitWidth() {
    if (isReady) {
      final pageNum = rawController.pageNumber ?? 1;
      final m = rawController.calcMatrixFitWidthForPage(pageNumber: pageNum);
      if (m != null) {
        rawController.goTo(m);
      }
    }
  }

  void resetZoom() {
    if (isReady) {
      final pageNum = rawController.pageNumber ?? 1;
      final m = rawController.calcMatrixForFit(pageNumber: pageNum);
      if (m != null) {
        rawController.goTo(m);
      }
    }
  }

  void dispose() {
    document = null;
  }
}

class PdfReaderView extends StatefulWidget {
  const PdfReaderView({
    super.key,
    required this.filePath,
    this.initialPage = 1,
    required this.readerTheme,
    required this.controller,
    required this.onPageChanged,
    required this.onDocumentLoaded,
    this.onOutlinesLoaded,
    this.onTap,
  });

  final String? filePath;
  final int initialPage;
  final ReaderThemeData readerTheme;
  final PdfBookController controller;
  final void Function(int currentPage, int totalPages, double progress) onPageChanged;
  final void Function(int totalPages) onDocumentLoaded;
  final void Function(List<PdfOutlineItem> outlines)? onOutlinesLoaded;
  final VoidCallback? onTap;

  @override
  State<PdfReaderView> createState() => _PdfReaderViewState();
}

class _PdfReaderViewState extends State<PdfReaderView> {
  @override
  Widget build(BuildContext context) {
    if (widget.filePath == null || widget.filePath!.isEmpty) {
      return _buildErrorView('No file path provided for this PDF.');
    }

    final file = File(widget.filePath!);
    if (!file.existsSync()) {
      return _buildErrorView('PDF file was not found on device storage:\n${widget.filePath}');
    }

    return Container(
      color: widget.readerTheme.backgroundColor,
      child: PdfViewer.file(
        widget.filePath!,
        controller: widget.controller.rawController,
        initialPageNumber: widget.initialPage > 0 ? widget.initialPage : 1,
        params: PdfViewerParams(
          backgroundColor: widget.readerTheme.backgroundColor,
          margin: 8.0,
          limitRenderingCache: true,
          maxImageBytesCachedOnMemory: 128 * 1024 * 1024,
          scrollPhysics: const ClampingScrollPhysics(),
          interactionDelegateProvider: const PdfViewerScrollInteractionDelegateProviderInstant(),
          verticalCacheExtent: 2.0,
          onePassRenderingSizeThreshold: 2048,
          enableKeyboardNavigation: true,
          pageDropShadow: const BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 3,
            offset: Offset(0, 1),
          ),
          viewerOverlayBuilder: (context, size, handleLinkTap) => [
            PdfViewerScrollThumb(
              controller: widget.controller.rawController,
              orientation: ScrollbarOrientation.right,
              thumbSize: const Size(42, 28),
              thumbBuilder: (context, thumbSize, pageNumber, controller) {
                return Container(
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: widget.readerTheme.toolbarColor.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: widget.readerTheme.dividerColor, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${pageNumber ?? 1}',
                      style: TextStyle(
                        color: widget.readerTheme.textColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
          onGeneralTap: (context, controller, details) {
            if (details.type == PdfViewerGeneralTapType.tap) {
              widget.onTap?.call();
            }
            return false;
          },
          onViewerReady: (document, controller) {
            widget.controller.document = document;
            if (mounted) {
              final totalPages = document.pages.length;
              widget.onDocumentLoaded(totalPages);

              // Asynchronously extract table of contents (outline) without blocking render
              document.loadOutline().then((nodes) {
                if (mounted && nodes.isNotEmpty) {
                  final items = <PdfOutlineItem>[];
                  void addNodes(List<PdfOutlineNode> list, int level) {
                    for (final node in list) {
                      final pageNum = node.dest?.pageNumber ?? 1;
                      items.add(
                        PdfOutlineItem(
                          title: node.title,
                          pageNumber: pageNum,
                          dest: node.dest,
                          level: level,
                        ),
                      );
                      if (node.children.isNotEmpty) {
                        addNodes(node.children, level + 1);
                      }
                    }
                  }

                  addNodes(nodes, 0);
                  widget.onOutlinesLoaded?.call(items);
                }
              }).catchError((e) {
                debugPrint('Error loading PDF outline: $e');
              });
            }
          },
          onPageChanged: (pageNumber) {
            if (pageNumber != null) {
              final totalPages = widget.controller.pageCount;
              final progress = totalPages > 0 ? (pageNumber / totalPages).clamp(0.0, 1.0) : 0.0;
              widget.onPageChanged(pageNumber, totalPages, progress);
            }
          },
          loadingBannerBuilder: (context, bytesDownloaded, totalBytes) => Center(
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  CircularProgressIndicator(color: AppTheme.primary),
                  SizedBox(height: 12),
                  Text(
                    'Loading PDF...',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          errorBannerBuilder: (context, error, stackTrace, documentRef) =>
              _buildErrorView(error.toString()),
        ),
      ),
    );
  }

  Widget _buildErrorView(String message) {
    return Center(
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
              'Could Not Open PDF',
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
    );
  }
}
