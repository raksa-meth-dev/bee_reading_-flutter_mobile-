import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/reading_tts_provider.dart';

/// Full-screen high-contrast Car/Driving Mode view with oversized tap targets.
class AudiobookCarModeView extends ConsumerWidget {
  const AudiobookCarModeView({
    super.key,
    required this.book,
  });

  final LibraryBook book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsState = ref.watch(readingTtsProvider);
    final ttsNotifier = ref.read(readingTtsProvider.notifier);

    final currentChunkNum = ttsState.totalChunks > 0 ? (ttsState.currentChunkIndex + 1) : 0;
    final chapterTitle = ttsState.currentChapterTitle ?? 'Chapter ${ttsState.currentChapterOrPage}';

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Top Bar: Exit Car Mode & Speed
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    label: const Text(
                      'EXIT CAR MODE',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        fontSize: 14,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white38, width: 1.5),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white12,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.speed_rounded, color: Colors.amber, size: 20),
                        const SizedBox(width: 6),
                        Text(
                          '${ttsState.speedMultiplier}x',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Title and Chapter Display (Oversized, high contrast)
              Text(
                chapterTitle,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.amber,
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                book.title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Block $currentChunkNum of ${ttsState.totalChunks}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white38,
                  fontSize: 14,
                ),
              ),

              const Spacer(flex: 1),

              // Primary Driving Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Giant Rewind
                  Material(
                    color: Colors.white12,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: ttsState.hasContent && ttsState.currentChunkIndex > 0
                          ? () => ttsNotifier.previousChunk()
                          : null,
                      child: Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.replay_10_rounded, color: Colors.white, size: 36),
                            Text(
                              'PREV',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Giant Play / Pause Button
                  Material(
                    color: Colors.amber,
                    shape: const CircleBorder(),
                    elevation: 6,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => ttsNotifier.togglePlayPause(),
                      child: Container(
                        width: 104,
                        height: 104,
                        alignment: Alignment.center,
                        child: Icon(
                          ttsState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                          color: Colors.black87,
                          size: 64,
                        ),
                      ),
                    ),
                  ),

                  // Giant Forward
                  Material(
                    color: Colors.white12,
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: ttsState.hasContent ? () => ttsNotifier.nextChunk() : null,
                      child: Container(
                        width: 84,
                        height: 84,
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.forward_10_rounded, color: Colors.white, size: 36),
                            Text(
                              'NEXT',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.8),
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Quick Chapter Skip Row
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: ttsState.canGoPreviousChapter
                        ? () => ttsNotifier.previousChapter(book)
                        : null,
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      size: 22,
                      color: ttsState.canGoPreviousChapter ? Colors.amber : Colors.white24,
                    ),
                    label: Text(
                      'PREV CH.',
                      style: TextStyle(
                        color: ttsState.canGoPreviousChapter ? Colors.amber : Colors.white24,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: ttsState.canGoPreviousChapter ? Colors.amber.withValues(alpha: 0.5) : Colors.white12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                  const SizedBox(width: 16),
                  OutlinedButton.icon(
                    onPressed: ttsState.canGoNextChapter
                        ? () => ttsNotifier.nextChapter(book)
                        : null,
                    icon: Icon(
                      Icons.skip_next_rounded,
                      size: 22,
                      color: ttsState.canGoNextChapter ? Colors.amber : Colors.white24,
                    ),
                    label: Text(
                      'NEXT CH.',
                      style: TextStyle(
                        color: ttsState.canGoNextChapter ? Colors.amber : Colors.white24,
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: ttsState.canGoNextChapter ? Colors.amber.withValues(alpha: 0.5) : Colors.white12,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),

              const Spacer(flex: 1),

              // Bottom status bar
              Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      ttsState.isPlaying ? Icons.volume_up_rounded : Icons.pause_circle_filled_rounded,
                      color: ttsState.isPlaying ? Colors.amber : Colors.white38,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      ttsState.isPlaying ? 'Audiobook is Playing' : 'Playback Paused',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
