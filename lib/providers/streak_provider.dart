import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/database/app_database.dart';
import 'package:bee_reading/providers/database_provider.dart';

class StreakState {
  final int currentStreak;
  final int longestStreak;
  final int todayMinutesRead;
  final int dailyGoalMinutes;
  final List<bool> weekActivity; // Mon to Sun
  final int streakFreezes;

  const StreakState({
    required this.currentStreak,
    required this.longestStreak,
    required this.todayMinutesRead,
    required this.dailyGoalMinutes,
    required this.weekActivity,
    this.streakFreezes = 2,
  });

  bool get isTodayGoalReached => todayMinutesRead >= dailyGoalMinutes;
  double get progressPercentage =>
      dailyGoalMinutes > 0 ? (todayMinutesRead / dailyGoalMinutes).clamp(0.0, 1.0) : 0.0;

  StreakState copyWith({
    int? currentStreak,
    int? longestStreak,
    int? todayMinutesRead,
    int? dailyGoalMinutes,
    List<bool>? weekActivity,
    int? streakFreezes,
  }) {
    return StreakState(
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      todayMinutesRead: todayMinutesRead ?? this.todayMinutesRead,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      weekActivity: weekActivity ?? this.weekActivity,
      streakFreezes: streakFreezes ?? this.streakFreezes,
    );
  }
}

class StreakNotifier extends Notifier<StreakState> {
  @override
  StreakState build() {
    _loadFromDatabase();
    return _computeStreakState([]);
  }

  Future<void> _loadFromDatabase() async {
    try {
      final db = ref.read(databaseProvider);
      final sessions = await db.getAllReadingSessions();
      state = _computeStreakState(sessions);
    } catch (e) {
      debugPrint('Error loading reading sessions: $e');
    }
  }

  /// Calculates real streak, today's minutes, and weekly activity from database session records.
  static StreakState _computeStreakState(List<ReadingSession> sessions, {int dailyGoalMinutes = 60}) {
    final now = DateTime.now();
    final todayDate = DateTime(now.year, now.month, now.day);

    int todaySeconds = 0;
    final activeDates = <DateTime>{};

    for (final s in sessions) {
      final sDate = DateTime(s.sessionDate.year, s.sessionDate.month, s.sessionDate.day);
      if (s.durationSeconds > 0) {
        activeDates.add(sDate);
      }
      if (sDate == todayDate) {
        todaySeconds += s.durationSeconds;
      }
    }

    final todayMinutes = (todaySeconds / 60).floor();

    // Compute weekActivity (Monday = 0 ... Sunday = 6)
    // In Dart: Monday = 1 ... Sunday = 7
    final monday = todayDate.subtract(Duration(days: now.weekday - 1));
    final weekActivity = List<bool>.generate(7, (index) {
      final dayDate = monday.add(Duration(days: index));
      return activeDates.contains(dayDate);
    });

    if (activeDates.isEmpty) {
      return StreakState(
        currentStreak: 0,
        longestStreak: 0,
        todayMinutesRead: todayMinutes,
        dailyGoalMinutes: dailyGoalMinutes,
        weekActivity: weekActivity,
        streakFreezes: 2,
      );
    }

    // Compute current streak:
    // If today has activity, count backwards starting from today.
    // If today does not have activity yet, check yesterday (streak is preserved until today ends).
    int currentStreak = 0;
    DateTime checkDate;
    if (activeDates.contains(todayDate)) {
      checkDate = todayDate;
    } else {
      final yesterday = todayDate.subtract(const Duration(days: 1));
      if (activeDates.contains(yesterday)) {
        checkDate = yesterday;
      } else {
        checkDate = todayDate; // Neither today nor yesterday active -> streak is 0
      }
    }

    if (activeDates.contains(checkDate)) {
      currentStreak = 1;
      var prevDate = checkDate.subtract(const Duration(days: 1));
      while (activeDates.contains(prevDate)) {
        currentStreak++;
        prevDate = prevDate.subtract(const Duration(days: 1));
      }
    }

    // Compute all-time longest streak
    final ascendingDates = activeDates.toList()..sort((a, b) => a.compareTo(b));
    int longestStreak = 0;
    int currentRun = 0;
    DateTime? lastDate;

    for (final d in ascendingDates) {
      if (lastDate == null) {
        currentRun = 1;
      } else if (d.difference(lastDate).inDays == 1) {
        currentRun++;
      } else {
        currentRun = 1;
      }
      if (currentRun > longestStreak) {
        longestStreak = currentRun;
      }
      lastDate = d;
    }
    if (currentStreak > longestStreak) {
      longestStreak = currentStreak;
    }

    return StreakState(
      currentStreak: currentStreak,
      longestStreak: longestStreak,
      todayMinutesRead: todayMinutes,
      dailyGoalMinutes: dailyGoalMinutes,
      weekActivity: weekActivity,
      streakFreezes: 2,
    );
  }

  /// Records active reading time in seconds into the persistent SQLite database.
  Future<void> recordReadingSeconds({String? bookId, required int seconds}) async {
    if (seconds <= 0) return;
    try {
      final db = ref.read(databaseProvider);
      await db.recordReadingSession(
        bookId: bookId,
        durationSeconds: seconds,
        sessionDate: DateTime.now(),
      );
      final sessions = await db.getAllReadingSessions();
      state = _computeStreakState(sessions);
    } catch (e) {
      debugPrint('Error recording reading session in SQLite: $e');
    }
  }

  /// Convenience method to record minutes read.
  Future<void> addReadingMinutes(int minutes, {String? bookId}) async {
    if (minutes <= 0) return;
    await recordReadingSeconds(
      bookId: bookId,
      seconds: minutes * 60,
    );
  }

  /// Completes today's remaining minutes to hit the daily goal.
  Future<void> completeTodayGoal({String? bookId}) async {
    final remaining = (state.dailyGoalMinutes - state.todayMinutesRead).clamp(0, 999);
    if (remaining > 0) {
      await addReadingMinutes(remaining, bookId: bookId);
    }
  }
}

final streakProvider =
    NotifierProvider<StreakNotifier, StreakState>(StreakNotifier.new);
