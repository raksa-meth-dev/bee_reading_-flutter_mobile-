import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_sleep_timer_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_speed_sheet.dart';
import 'package:bee_reading/theme/app_theme.dart';

/// Primary playback transport controls and scrubber for the Audiobook player.
class AudiobookControls extends ConsumerWidget {
  const AudiobookControls({super.key, this.book});

  final LibraryBook? book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(readingTtsProvider);
    final ttsNotifier = ref.read(readingTtsProvider.notifier);

    final totalChunks = ttsState.totalChunks;
    final currentIdx = ttsState.currentChunkIndex;
    final progress = totalChunks > 0 ? (currentIdx / totalChunks).clamp(0.0, 1.0) : 0.0;

    final allBooks = ref.watch(booksProvider);
    final activeBook = book ??
        ttsNotifier.currentBook ??
        allBooks.where((b) => b.id == ttsState.bookId).firstOrNull;

    final canGoPrevChapter = ttsState.canGoPreviousChapter && activeBook != null;
    final canGoNextChapter = ttsState.canGoNextChapter && activeBook != null;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Scrubber / Progress Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 4,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                  activeTrackColor: AppTheme.primary,
                  inactiveTrackColor: AppTheme.surfaceMuted,
                  thumbColor: AppTheme.primaryDark,
                ),
                child: Slider(
                  value: progress,
                  onChanged: totalChunks > 0
                      ? (val) {
                          final targetIdx = ((val * (totalChunks - 1)).round()).clamp(0, totalChunks - 1);
                          ttsNotifier.jumpToChunk(targetIdx);
                        }
                      : null,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Block ${totalChunks > 0 ? currentIdx + 1 : 0}',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% of chapter',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryDark,
                      ),
                    ),
                    Text(
                      'Total $totalChunks',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // Secondary Utility Bar (Speed Multiplier & Sleep Timer)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Speed Multiplier Button
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => AudiobookSpeedSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.surfaceMuted),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.speed_rounded, size: 15, color: AppTheme.primaryDark),
                      const SizedBox(width: 4),
                      Text(
                        '${ttsState.speedMultiplier}x',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Sleep Timer Button
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => AudiobookSleepTimerSheet.show(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: ttsState.hasActiveSleepTimer
                        ? AppTheme.primary.withValues(alpha: 0.15)
                        : AppTheme.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: ttsState.hasActiveSleepTimer
                          ? AppTheme.primary
                          : AppTheme.surfaceMuted,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bedtime_rounded,
                        size: 15,
                        color: ttsState.hasActiveSleepTimer
                            ? AppTheme.primaryDark
                            : AppTheme.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        ttsState.hasActiveSleepTimer
                            ? '${(ttsState.sleepTimerRemainingSeconds! ~/ 60) + 1}m'
                            : 'Timer',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: ttsState.hasActiveSleepTimer
                              ? AppTheme.primaryDark
                              : AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // Primary 5-Button Transport Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Previous Chapter Button
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.skip_previous_rounded),
                  iconSize: 34,
                  color: canGoPrevChapter ? AppTheme.textDark : AppTheme.textMuted.withValues(alpha: 0.35),
                  tooltip: 'Previous Chapter',
                  onPressed: canGoPrevChapter
                      ? () => ttsNotifier.previousChapter(activeBook)
                      : null,
                ),
              ),

              // Skip Backward (-10s / previous sentence chunk)
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.replay_10_rounded),
                  iconSize: 30,
                  color: AppTheme.textDark,
                  tooltip: 'Previous Sentence',
                  onPressed: ttsState.hasContent && currentIdx > 0
                      ? () => ttsNotifier.previousChunk()
                      : null,
                ),
              ),

              // Big Play / Pause Button
              RepaintBoundary(
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: 0.45),
                        blurRadius: 18,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: AppTheme.primary,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        if (!ttsState.hasContent && activeBook != null) {
                          ttsNotifier.changeChapterOrPage(
                            book: activeBook,
                            targetChapterOrPage: activeBook.currentPage > 0 ? activeBook.currentPage : 1,
                            autoPlay: true,
                          );
                        } else {
                          ttsNotifier.togglePlayPause();
                        }
                      },
                      child: Container(
                        width: 68,
                        height: 68,
                        alignment: Alignment.center,
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: Icon(
                            ttsState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            key: ValueKey<bool>(ttsState.isPlaying),
                            color: Colors.white,
                            size: 38,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Skip Forward (+10s / next sentence chunk)
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.forward_10_rounded),
                  iconSize: 30,
                  color: AppTheme.textDark,
                  tooltip: 'Next Sentence',
                  onPressed: ttsState.hasContent
                      ? () => ttsNotifier.nextChunk()
                      : null,
                ),
              ),

              // Next Chapter Button
              Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: IconButton(
                  icon: const Icon(Icons.skip_next_rounded),
                  iconSize: 34,
                  color: canGoNextChapter ? AppTheme.textDark : AppTheme.textMuted.withValues(alpha: 0.35),
                  tooltip: 'Next Chapter',
                  onPressed: canGoNextChapter
                      ? () => ttsNotifier.nextChapter(activeBook)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
