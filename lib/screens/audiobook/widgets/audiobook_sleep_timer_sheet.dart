import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/theme/app_theme.dart';

/// Bottom sheet for configuring the audiobook sleep timer.
class AudiobookSleepTimerSheet extends ConsumerWidget {
  const AudiobookSleepTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AudiobookSleepTimerSheet(),
    );
  }

  static String _formatDuration(int totalSeconds) {
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ttsNotifier = ref.read(readingTtsProvider.notifier);
    final remainingSeconds = ref.watch(
      readingTtsProvider.select((s) => s.sleepTimerRemainingSeconds),
    );
    final isTimerActive = remainingSeconds != null && remainingSeconds > 0;

    final timerPresets = [
      {'label': '15 Minutes', 'duration': const Duration(minutes: 15)},
      {'label': '30 Minutes', 'duration': const Duration(minutes: 30)},
      {'label': '45 Minutes', 'duration': const Duration(minutes: 45)},
      {'label': '60 Minutes', 'duration': const Duration(minutes: 60)},
    ];

    return Material(
      color: AppTheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: SafeArea(
          top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle
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

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bedtime_rounded,
                    color: AppTheme.primaryDark,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sleep Timer',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Audio will automatically pause smoothly',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isTimerActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryDark,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _formatDuration(remainingSeconds),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // Presets
            ...timerPresets.map((preset) {
              final duration = preset['duration'] as Duration;
              final label = preset['label'] as String;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () {
                      ttsNotifier.setSleepTimer(duration);
                      Navigator.pop(context);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      decoration: BoxDecoration(
                        color: AppTheme.background,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.surfaceMuted,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.timer_outlined, size: 20, color: AppTheme.textMuted),
                          const SizedBox(width: 12),
                          Text(
                            label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textDark,
                            ),
                          ),
                          const Spacer(),
                          const Icon(Icons.chevron_right_rounded, size: 20, color: AppTheme.textMuted),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 6),

            // Turn off timer if active
            if (isTimerActive)
              OutlinedButton.icon(
                onPressed: () {
                  ttsNotifier.cancelSleepTimer();
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.timer_off_outlined, color: Colors.redAccent, size: 18),
                label: const Text(
                  'Cancel Active Timer',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Colors.redAccent),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              )
            else
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close', style: TextStyle(color: AppTheme.textMuted)),
              ),
          ],
        ),
      ),
    ),
  );
}
}
