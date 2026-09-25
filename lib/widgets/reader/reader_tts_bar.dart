import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/screens/reader/reader_theme.dart';
import 'package:bee_reading/theme/app_theme.dart';

class ReaderTtsBar extends ConsumerWidget {
  const ReaderTtsBar({
    super.key,
    required this.readerTheme,
    required this.isPdf,
    required this.currentPage,
    required this.totalPages,
    required this.onClose,
    this.onExpand,
  });

  final ReaderThemeData readerTheme;
  final bool isPdf;
  final int currentPage;
  final int totalPages;
  final VoidCallback onClose;
  final VoidCallback? onExpand;

  static const List<double> _availableSpeeds = [0.75, 1.0, 1.25, 1.5, 2.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(readingTtsProvider);
    final ttsNotifier = ref.read(readingTtsProvider.notifier);

    final isDark = readerTheme.backgroundColor.computeLuminance() < 0.2;
    final cardBg = readerTheme.toolbarColor;
    final borderColor = readerTheme.dividerColor;
    final textColor = readerTheme.textColor;
    final secondaryText = readerTheme.secondaryTextColor;

    final currentChunkText = ttsState.currentChunk ?? 'No readable text on this page.';
    final currentChunkNum = ttsState.totalChunks > 0 ? (ttsState.currentChunkIndex + 1) : 0;
    final totalChunks = ttsState.totalChunks;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: cardBg.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header Row: Status, Page/Chapter, and Close
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: ttsState.isPlaying
                          ? AppTheme.primary.withValues(alpha: 0.2)
                          : borderColor.withValues(alpha: 0.4),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      ttsState.isPlaying
                          ? Icons.volume_up_rounded
                          : (ttsState.isPaused ? Icons.volume_down_rounded : Icons.volume_mute_rounded),
                      color: ttsState.isPlaying ? AppTheme.primaryDark : secondaryText,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ttsState.isPlaying
                              ? 'Reading Aloud...'
                              : (ttsState.isPaused ? 'Voice Paused' : 'Voice Reader'),
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          isPdf
                              ? 'Page $currentPage of $totalPages • Block $currentChunkNum of $totalChunks'
                              : 'Chapter $currentPage of $totalPages • Block $currentChunkNum of $totalChunks',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (onExpand != null)
                    IconButton(
                      icon: Icon(Icons.open_in_full_rounded, color: secondaryText, size: 18),
                      tooltip: 'Open Full Audiobook Screen',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      onPressed: onExpand,
                    ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, color: secondaryText, size: 20),
                    tooltip: 'Close Voice Player',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () {
                      ttsNotifier.stop();
                      onClose();
                    },
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Currently Spoken Chunk Snippet Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                constraints: const BoxConstraints(maxHeight: 65),
                decoration: BoxDecoration(
                  color: readerTheme.backgroundColor.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor.withValues(alpha: 0.6)),
                ),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    currentChunkText,
                    style: TextStyle(
                      color: textColor.withValues(alpha: 0.9),
                      fontSize: 12.5,
                      height: 1.35,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Controls Row (Previous, Play/Pause, Next, Stop)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Rewind / Previous Block
                  IconButton(
                    icon: Icon(Icons.skip_previous_rounded, color: textColor),
                    iconSize: 28,
                    tooltip: 'Previous Paragraph',
                    onPressed: ttsState.hasContent && ttsState.currentChunkIndex > 0
                        ? () => ttsNotifier.previousChunk()
                        : null,
                  ),
                  const SizedBox(width: 12),

                  // Main Play / Pause Button
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primary.withValues(alpha: 0.35),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: IconButton(
                      icon: Icon(
                        ttsState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        color: Colors.black87,
                      ),
                      iconSize: 32,
                      tooltip: ttsState.isPlaying ? 'Pause' : 'Play',
                      onPressed: () => ttsNotifier.togglePlayPause(),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Forward / Next Block
                  IconButton(
                    icon: Icon(Icons.skip_next_rounded, color: textColor),
                    iconSize: 28,
                    tooltip: 'Next Paragraph',
                    onPressed: ttsState.hasContent
                        ? () => ttsNotifier.nextChunk()
                        : null,
                  ),
                  const SizedBox(width: 8),

                  // Stop Button
                  IconButton(
                    icon: Icon(Icons.stop_rounded, color: secondaryText),
                    iconSize: 24,
                    tooltip: 'Stop Reading',
                    onPressed: !ttsState.isStopped ? () => ttsNotifier.stop() : null,
                  ),
                ],
              ),

              const SizedBox(height: 6),

              // Bottom Settings Row: Speed Selector & Auto Advance Toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Speed Selector Popup / Dropdown
                  PopupMenuButton<double>(
                    tooltip: 'Speech Rate',
                    initialValue: ttsState.speedMultiplier,
                    onSelected: (speed) => ttsNotifier.setSpeed(speed),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    color: cardBg,
                    itemBuilder: (context) => _availableSpeeds.map((rate) {
                      final isSelected = (rate - ttsState.speedMultiplier).abs() < 0.05;
                      return PopupMenuItem<double>(
                        value: rate,
                        child: Row(
                          children: [
                            Text(
                              '${rate}x',
                              style: TextStyle(
                                color: isSelected ? AppTheme.primaryDark : textColor,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            if (isSelected) ...[
                              const Spacer(),
                              const Icon(Icons.check_rounded, color: AppTheme.primaryDark, size: 18),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: readerTheme.backgroundColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.speed_rounded, size: 15, color: secondaryText),
                          const SizedBox(width: 4),
                          Text(
                            '${ttsState.speedMultiplier}x',
                            style: TextStyle(
                              color: textColor,
                              fontSize: 11.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down_rounded, size: 16, color: secondaryText),
                        ],
                      ),
                    ),
                  ),

                  // Auto-advance Toggle Button
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => ttsNotifier.toggleAutoAdvance(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ttsState.autoAdvance
                            ? AppTheme.primary.withValues(alpha: 0.15)
                            : readerTheme.backgroundColor.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: ttsState.autoAdvance ? AppTheme.primary.withValues(alpha: 0.4) : borderColor,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            ttsState.autoAdvance
                                ? Icons.autorenew_rounded
                                : Icons.stop_screen_share_outlined,
                            size: 14,
                            color: ttsState.autoAdvance ? AppTheme.primaryDark : secondaryText,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            ttsState.autoAdvance ? 'Auto-Flip: ON' : 'Auto-Flip: OFF',
                            style: TextStyle(
                              color: ttsState.autoAdvance ? AppTheme.primaryDark : secondaryText,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
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
}
