import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/theme/app_theme.dart';

/// Bottom sheet for adjusting playback speed, pitch, and voice settings.
class AudiobookSpeedSheet extends ConsumerStatefulWidget {
  const AudiobookSpeedSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const AudiobookSpeedSheet(),
    );
  }

  @override
  ConsumerState<AudiobookSpeedSheet> createState() => _AudiobookSpeedSheetState();
}

class _AudiobookSpeedSheetState extends ConsumerState<AudiobookSpeedSheet> {
  static const List<double> _speeds = [0.75, 1.0, 1.25, 1.5, 1.75, 2.0, 2.5];

  @override
  void initState() {
    super.initState();
    // Pre-fetch voices if not yet cached
    Future.microtask(() {
      ref.read(readingTtsProvider.notifier).fetchVoices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final ttsState = ref.watch(readingTtsProvider);
    final ttsNotifier = ref.read(readingTtsProvider.notifier);

    final screenHeight = MediaQuery.sizeOf(context).height;

    return Material(
      color: AppTheme.surface,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenHeight * 0.85),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
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
                    Icons.speed_rounded,
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
                        'Playback Speed & Voice',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textDark,
                        ),
                      ),
                      Text(
                        'Fine-tune narrator tempo and voice tone',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Speed Presets Grid
            const Text(
              'SPEED MULTIPLIER',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
                color: AppTheme.textMuted,
              ),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _speeds.map((rate) {
                final isSelected = (rate - ttsState.speedMultiplier).abs() < 0.05;
                return ChoiceChip(
                  label: Text('${rate}x'),
                  selected: isSelected,
                  onSelected: (selected) {
                    if (selected) {
                      ttsNotifier.setSpeed(rate);
                    }
                  },
                  selectedColor: AppTheme.primary,
                  backgroundColor: AppTheme.background,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textDark,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: isSelected ? AppTheme.primary : AppTheme.surfaceMuted,
                    ),
                  ),
                  showCheckmark: false,
                );
              }).toList(),
            ),

            const SizedBox(height: 22),

            // Voice Pitch Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'VOICE PITCH',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.textMuted,
                  ),
                ),
                TextButton(
                  onPressed: () => ttsNotifier.setPitch(1.0),
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(50, 24),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Reset', style: TextStyle(fontSize: 12, color: AppTheme.primaryDark)),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.arrow_downward_rounded, size: 16, color: AppTheme.textMuted),
                Expanded(
                  child: Slider(
                    value: ttsState.pitch.clamp(0.8, 1.4),
                    min: 0.8,
                    max: 1.4,
                    divisions: 6,
                    activeColor: AppTheme.primary,
                    inactiveColor: AppTheme.surfaceMuted,
                    label: '${ttsState.pitch.toStringAsFixed(1)}x',
                    onChanged: (value) => ttsNotifier.setPitch(value),
                  ),
                ),
                const Icon(Icons.arrow_upward_rounded, size: 16, color: AppTheme.textMuted),
              ],
            ),

            // Curated 4 Narrator Voices (2 Female, 2 Male)
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'NARRATOR VOICE (4 VOICES)',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: AppTheme.textMuted,
                  ),
                ),
                Text(
                  '2 Female • 2 Male',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryDark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 2.0,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: NarratorVoice.curatedVoices.map((voice) {
                final isSelected = ttsState.selectedNarratorVoice.id == voice.id;
                final isFemale = voice.gender == VoiceGender.female;

                return Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => ttsNotifier.setNarratorVoice(voice),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppTheme.primary.withValues(alpha: 0.12)
                            : AppTheme.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? AppTheme.primary : AppTheme.surfaceMuted,
                          width: isSelected ? 2.0 : 1.0,
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : (isFemale
                                      ? Colors.pink.withValues(alpha: 0.12)
                                      : Colors.blue.withValues(alpha: 0.12)),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              isFemale ? Icons.face_3_rounded : Icons.face_6_rounded,
                              size: 20,
                              color: isSelected
                                  ? Colors.white
                                  : (isFemale ? Colors.pink[700] : Colors.blue[700]),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        voice.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          color: isSelected ? AppTheme.primaryDark : AppTheme.textDark,
                                        ),
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 4),
                                      const Icon(Icons.check_circle_rounded, size: 14, color: AppTheme.primaryDark),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isFemale ? 'Female' : 'Male',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: isFemale ? Colors.pink[700] : Colors.blue[700],
                                  ),
                                ),
                                Text(
                                  voice.style,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 9.5,
                                    color: AppTheme.textMuted,
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
              }).toList(),
            ),

            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(vertical: 13),
              ),
              child: const Text('Apply Settings', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    ),
  ),
);
}
}
