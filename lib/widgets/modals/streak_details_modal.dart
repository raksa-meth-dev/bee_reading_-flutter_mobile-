import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/providers/streak_provider.dart';
import 'package:bee_reading/theme/app_theme.dart';

/// Displays the reading streak details modal sheet with weekly calendar and stats.
void showStreakDetailsModal(BuildContext context, WidgetRef ref, StreakState streak) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) {
      final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
      return SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
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
              const SizedBox(height: 18),
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primary.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('🔥', style: TextStyle(fontSize: 36)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${streak.currentStreak} Day Reading Streak!',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                streak.isTodayGoalReached
                    ? 'You hit your reading goal for today! Keep the flame alive.'
                    : 'Read ${(streak.dailyGoalMinutes - streak.todayMinutesRead).clamp(0, 999)} more mins today to maintain your streak.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Weekly tracker row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.surfaceMuted),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(7, (index) {
                    final isActive = streak.weekActivity[index];
                    final isToday = (DateTime.now().weekday - 1) == index;
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          days[index],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isToday ? AppTheme.primaryDark : AppTheme.textMuted,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isActive
                                ? AppTheme.primary
                                : (isToday
                                    ? AppTheme.accentLight
                                    : AppTheme.surfaceMuted),
                            border: isToday && !isActive
                                ? Border.all(color: AppTheme.primary, width: 1.5)
                                : null,
                          ),
                          child: Center(
                            child: isActive
                                ? const Text('🔥', style: TextStyle(fontSize: 14))
                                : (isToday
                                    ? const Text('⏳', style: TextStyle(fontSize: 12))
                                    : const Icon(Icons.circle, size: 6, color: AppTheme.textMuted)),
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 18),

              // Streak Stats Row
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Longest Streak',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🏆 ${streak.longestStreak} days',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceMuted.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Streak Freezes',
                            style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '🛡️ ${streak.streakFreezes} left',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.textDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Action Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    if (!streak.isTodayGoalReached) {
                      ref.read(streakProvider.notifier).addReadingMinutes(15);
                    }
                    Navigator.pop(sheetContext);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    streak.isTodayGoalReached
                        ? 'Streak Protected Today 🎉'
                        : 'Log 15 Mins Reading 📖',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
