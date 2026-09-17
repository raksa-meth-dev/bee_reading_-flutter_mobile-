import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bee_reading/database/app_database.dart';
import 'package:bee_reading/providers/database_provider.dart';
import 'package:bee_reading/providers/streak_provider.dart';

void main() {
  group('Real Reading Tracking & Streak Tests', () {
    late AppDatabase db;
    late ProviderContainer container;

    setUp(() async {
      db = AppDatabase(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
        ],
      );

      // Insert a test book for session attribution
      await db.insertOrUpdateBook(
        BooksCompanion.insert(
          id: 'test-book-streak',
          title: 'Test Reading Book',
          filePath: '/path/test.epub',
          format: 'epub',
        ),
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('Starts clean with 0 streak and 0 minutes when no sessions exist', () async {
      final streak = container.read(streakProvider);

      expect(streak.currentStreak, 0);
      expect(streak.longestStreak, 0);
      expect(streak.todayMinutesRead, 0);
      expect(streak.dailyGoalMinutes, 60);
      expect(streak.isTodayGoalReached, isFalse);
      expect(streak.weekActivity.every((d) => d == false), isTrue);
    });

    test('Recording reading seconds persists in SQLite and updates todayMinutesRead', () async {
      final notifier = container.read(streakProvider.notifier);

      // Record 10 minutes (600 seconds)
      await notifier.recordReadingSeconds(bookId: 'test-book-streak', seconds: 600);
      await Future.delayed(const Duration(milliseconds: 50));

      final sessions = await db.getAllReadingSessions();
      expect(sessions.length, 1);
      expect(sessions.first.durationSeconds, 600);
      expect(sessions.first.bookId, 'test-book-streak');

      final streak = container.read(streakProvider);
      expect(streak.todayMinutesRead, 10);
      expect(streak.progressPercentage, closeTo(10 / 60, 0.01));
    });

    test('Multiple sessions accumulate correctly within today', () async {
      final notifier = container.read(streakProvider.notifier);

      await notifier.addReadingMinutes(15, bookId: 'test-book-streak');
      await notifier.addReadingMinutes(20, bookId: 'test-book-streak');
      await Future.delayed(const Duration(milliseconds: 50));

      final sessions = await db.getAllReadingSessions();
      expect(sessions.length, 2);

      final streak = container.read(streakProvider);
      expect(streak.todayMinutesRead, 35);
      expect(streak.currentStreak, 1);
    });

    test('Reaching daily goal sets isTodayGoalReached to true', () async {
      final notifier = container.read(streakProvider.notifier);

      await notifier.addReadingMinutes(60, bookId: 'test-book-streak');
      await Future.delayed(const Duration(milliseconds: 50));

      final streak = container.read(streakProvider);
      expect(streak.todayMinutesRead, 60);
      expect(streak.isTodayGoalReached, isTrue);
      expect(streak.progressPercentage, 1.0);
    });

    test('Calculates multi-day consecutive streaks accurately', () async {
      final now = DateTime.now();

      // Seed sessions for yesterday and the day before yesterday
      await db.recordReadingSession(
        bookId: 'test-book-streak',
        durationSeconds: 1800,
        sessionDate: now.subtract(const Duration(days: 2)),
      );
      await db.recordReadingSession(
        bookId: 'test-book-streak',
        durationSeconds: 1800,
        sessionDate: now.subtract(const Duration(days: 1)),
      );

      // Record session today
      await container.read(streakProvider.notifier).recordReadingSeconds(
            bookId: 'test-book-streak',
            seconds: 1200,
          );
      await Future.delayed(const Duration(milliseconds: 50));

      final streak = container.read(streakProvider);
      // 3 consecutive days: day - 2, day - 1, today
      expect(streak.currentStreak, 3);
      expect(streak.longestStreak, 3);
    });

    test('Streak remains active if yesterday was read and today is pending', () async {
      final now = DateTime.now();

      // Read yesterday, but not yet read today
      await db.recordReadingSession(
        bookId: 'test-book-streak',
        durationSeconds: 1200,
        sessionDate: now.subtract(const Duration(days: 1)),
      );
      await Future.delayed(const Duration(milliseconds: 50));

      // Trigger provider reload
      final notifier = container.read(streakProvider.notifier);
      await notifier.recordReadingSeconds(seconds: 0); // No-op to pump watcher
      await Future.delayed(const Duration(milliseconds: 50));

      final streak = container.read(streakProvider);
      expect(streak.currentStreak, 1);
      expect(streak.todayMinutesRead, 0);
    });

    test('Streak resets to 0 if there was a gap of 2 or more days', () async {
      final now = DateTime.now();

      // Read 3 days ago, but missed 2 days ago and yesterday
      await db.recordReadingSession(
        bookId: 'test-book-streak',
        durationSeconds: 1200,
        sessionDate: now.subtract(const Duration(days: 3)),
      );

      final notifier = container.read(streakProvider.notifier);
      await notifier.recordReadingSeconds(seconds: 0);
      await Future.delayed(const Duration(milliseconds: 50));

      final streak = container.read(streakProvider);
      expect(streak.currentStreak, 0);
      expect(streak.longestStreak, 1);
    });

    test('completeTodayGoal logs remaining minutes to hit 60 mins', () async {
      final notifier = container.read(streakProvider.notifier);

      await notifier.addReadingMinutes(25, bookId: 'test-book-streak');
      await Future.delayed(const Duration(milliseconds: 50));
      expect(container.read(streakProvider).todayMinutesRead, 25);

      await notifier.completeTodayGoal(bookId: 'test-book-streak');
      await Future.delayed(const Duration(milliseconds: 50));

      final streak = container.read(streakProvider);
      expect(streak.todayMinutesRead, 60);
      expect(streak.isTodayGoalReached, isTrue);
    });
  });
}
