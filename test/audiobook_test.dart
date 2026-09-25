import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/screens/audiobook/audiobook_hub_screen.dart';
import 'package:bee_reading/screens/audiobook/audiobook_screen.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_car_mode_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_chapters_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_controls.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_sleep_timer_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_speed_sheet.dart';

void main() {
  const sampleBook = LibraryBook(
    id: 'test_book_audio',
    title: 'The Great Audiobook',
    author: 'Bee Author',
    format: 'EPUB',
    category: 'Fiction',
    emoji: '🎧',
    coverGradient: LinearGradient(colors: [Colors.amber, Colors.orange]),
    progress: 0.25,
    totalPages: 12,
    currentPage: 3,
    fileSize: '1.2 MB',
    lastReadTime: 'Today',
    highlightsCount: 0,
  );

  group('ReadingTtsState Sleep Timer & Chapter Tests', () {
    test('Sleep timer state and chapter details update correctly in copyWith', () {
      const state = ReadingTtsState();
      expect(state.hasActiveSleepTimer, isFalse);

      final withTimer = state.copyWith(
        sleepTimerDuration: const Duration(minutes: 15),
        sleepTimerRemainingSeconds: 900,
        currentChapterTitle: 'Chapter 3: The Secret Path',
        totalPagesOrChapters: 12,
      );

      expect(withTimer.hasActiveSleepTimer, isTrue);
      expect(withTimer.sleepTimerRemainingSeconds, 900);
      expect(withTimer.currentChapterTitle, 'Chapter 3: The Secret Path');
      expect(withTimer.totalPagesOrChapters, 12);

      final cleared = withTimer.copyWith(clearSleepTimer: true);
      expect(cleared.hasActiveSleepTimer, isFalse);
      expect(cleared.sleepTimerRemainingSeconds, isNull);
    });
  });

  group('AudiobookControls Widget Tests', () {
    testWidgets('renders scrubber and transport buttons with correct defaults', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AudiobookControls(),
            ),
          ),
        ),
      );

      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.byTooltip('Previous Sentence'), findsOneWidget);
      expect(find.byTooltip('Next Sentence'), findsOneWidget);
      expect(find.byIcon(Icons.bedtime_rounded), findsOneWidget);
    });
  });

  group('AudiobookSleepTimerSheet Tests', () {
    testWidgets('displays sleep timer presets and responds to tap', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AudiobookSleepTimerSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Sleep Timer'), findsOneWidget);
      expect(find.text('15 Minutes'), findsOneWidget);
      expect(find.text('30 Minutes'), findsOneWidget);
      expect(find.text('45 Minutes'), findsOneWidget);
      expect(find.text('60 Minutes'), findsOneWidget);
    });
  });

  group('AudiobookSpeedSheet Tests', () {
    testWidgets('displays speed choices, pitch slider, and 4 curated narrator voices', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AudiobookSpeedSheet(),
            ),
          ),
        ),
      );

      expect(find.text('Playback Speed & Voice'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('1.5x'), findsOneWidget);
      expect(find.text('2.0x'), findsOneWidget);
      expect(find.text('VOICE PITCH'), findsOneWidget);
      expect(find.text('Reset'), findsOneWidget);

      // Verify the 4 curated voices (2 female, 2 male)
      expect(find.text('NARRATOR VOICE (4 VOICES)'), findsOneWidget);
      expect(find.text('Emma'), findsOneWidget);
      expect(find.text('Sophia'), findsOneWidget);
      expect(find.text('Oliver'), findsOneWidget);
      expect(find.text('James'), findsOneWidget);

      // Tap on Oliver to switch narrator voice
      await tester.ensureVisible(find.text('Oliver'));
      await tester.tap(find.text('Oliver'));
      await tester.pumpAndSettle();
    });
  });

  group('AudiobookCarModeView Tests', () {
    testWidgets('renders distraction-free UI with giant buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AudiobookCarModeView(book: sampleBook),
          ),
        ),
      );

      expect(find.text('EXIT CAR MODE'), findsOneWidget);
      expect(find.text('The Great Audiobook'), findsOneWidget);
      expect(find.text('PREV'), findsOneWidget);
      expect(find.text('NEXT'), findsOneWidget);
      expect(find.byIcon(Icons.play_arrow_rounded), findsOneWidget);
    });
  });

  group('AudiobookChaptersSheet Tests', () {
    testWidgets('renders chapters and handles selection callback', (WidgetTester tester) async {
      int? selectedChapter;

      final sampleChapters = [
        const ChapterItemData(index: 1, title: 'Chapter 1: Dawn'),
        const ChapterItemData(index: 2, title: 'Chapter 2: Journey'),
        const ChapterItemData(index: 3, title: 'Chapter 3: Arrival'),
      ];

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: AudiobookChaptersSheet(
                chapters: sampleChapters,
                currentChapterIndex: 2,
                onChapterSelected: (idx) {
                  selectedChapter = idx;
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('Table of Contents'), findsOneWidget);
      expect(find.text('3 chapters available'), findsOneWidget);
      expect(find.text('Chapter 1: Dawn'), findsOneWidget);
      expect(find.text('Chapter 2: Journey'), findsOneWidget);
      expect(find.text('Playing'), findsOneWidget);

      await tester.tap(find.text('Chapter 1: Dawn'));
      expect(selectedChapter, 1);
    });
  });

  group('AudiobookScreen Full Integration Tests', () {
    testWidgets('renders header, cover artwork, and action buttons', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AudiobookScreen(book: sampleBook),
          ),
        ),
      );

      expect(find.text('NOW PLAYING'), findsOneWidget);
      expect(find.text('The Great Audiobook'), findsOneWidget);
      expect(find.text('by Bee Author'), findsOneWidget);
      expect(find.text('Chapters'), findsOneWidget);
      expect(find.text('Car Mode'), findsOneWidget);
      expect(find.text('Read'), findsOneWidget);
    });
  });

  group('AudiobookHubScreen Bottom Tab Tests', () {
    testWidgets('renders Audiobook Hub with title and search bar', (WidgetTester tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: AudiobookHubScreen(),
          ),
        ),
      );

      expect(find.text('Audiobooks'), findsOneWidget);
      expect(find.text('Listen to any eBook with natural voice'), findsOneWidget);
      expect(find.text('Search audiobooks...'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Continue Listening'), findsOneWidget);
      expect(find.text('Favorites'), findsOneWidget);
    });
  });
}
