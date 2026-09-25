import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/theme/app_theme.dart';

class ChapterItemData {
  final int index;
  final String title;
  final String? subtitle;

  const ChapterItemData({
    required this.index,
    required this.title,
    this.subtitle,
  });
}

/// Bottom sheet displaying the Audiobook Table of Contents / Chapters list.
class AudiobookChaptersSheet extends ConsumerStatefulWidget {
  const AudiobookChaptersSheet({
    super.key,
    required this.chapters,
    required this.currentChapterIndex,
    required this.onChapterSelected,
  });

  final List<ChapterItemData> chapters;
  final int currentChapterIndex;
  final ValueChanged<int> onChapterSelected;

  static Future<void> show({
    required BuildContext context,
    required List<ChapterItemData> chapters,
    required int currentChapterIndex,
    required ValueChanged<int> onChapterSelected,
  }) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => AudiobookChaptersSheet(
        chapters: chapters,
        currentChapterIndex: currentChapterIndex,
        onChapterSelected: onChapterSelected,
      ),
    );
  }

  @override
  ConsumerState<AudiobookChaptersSheet> createState() => _AudiobookChaptersSheetState();
}

class _AudiobookChaptersSheetState extends ConsumerState<AudiobookChaptersSheet> {
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    final activeIdx = widget.chapters.indexWhere((c) => c.index == widget.currentChapterIndex);
    final initialOffset = activeIdx > 2 ? ((activeIdx - 1) * 58.0) : 0.0;
    _scrollController = ScrollController(initialScrollOffset: initialOffset);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;

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
              // Drag Handle
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

              // Title Row
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
                        Icons.format_list_bulleted_rounded,
                        color: AppTheme.primaryDark,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Table of Contents',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                          Text(
                            '${widget.chapters.length} chapters available',
                            style: const TextStyle(
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
              const SizedBox(height: 12),
              const Divider(color: AppTheme.surfaceMuted, height: 1),

              // Chapters List
              Expanded(
                child: widget.chapters.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.menu_book_rounded, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            const Text(
                              'No Chapters Detected',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textDark),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Use the forward/backward controls to navigate blocks',
                              style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        itemCount: widget.chapters.length,
                        separatorBuilder: (_, _) => const Divider(
                          color: AppTheme.surfaceMuted,
                          height: 1,
                          indent: 64,
                        ),
                        itemBuilder: (context, index) {
                          final item = widget.chapters[index];
                          final isCurrent = item.index == widget.currentChapterIndex;

                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
                            leading: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? AppTheme.primary
                                    : AppTheme.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: isCurrent ? AppTheme.primary : AppTheme.surfaceMuted,
                                ),
                              ),
                              child: Center(
                                child: isCurrent
                                    ? const Icon(Icons.volume_up_rounded, color: Colors.white, size: 18)
                                    : Text(
                                        '${item.index}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.textDark,
                                        ),
                                      ),
                              ),
                            ),
                            title: Text(
                              item.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                                color: isCurrent ? AppTheme.primaryDark : AppTheme.textDark,
                              ),
                            ),
                            subtitle: item.subtitle != null
                                ? Text(
                                    item.subtitle!,
                                    style: const TextStyle(fontSize: 11.5, color: AppTheme.textMuted),
                                  )
                                : null,
                            trailing: isCurrent
                                ? Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: AppTheme.primary.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Playing',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryDark,
                                      ),
                                    ),
                                  )
                                : const Icon(Icons.chevron_right_rounded, size: 18, color: AppTheme.textMuted),
                            onTap: () {
                              Navigator.pop(context);
                              widget.onChapterSelected(item.index);
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
