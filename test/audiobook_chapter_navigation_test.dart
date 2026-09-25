import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_car_mode_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_chapters_sheet.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_controls.dart';
import 'package:bee_reading/services/tts_service.dart';

class FakeTtsService extends TtsService {
  @override
  Future<void> speak(String text) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> pause() async {}

  @override
  void dispose() {}
}

void main() {
  const sampleBook = LibraryBook(
    id: 'test_nav_book',
    title: 'Pride and Prejudice',
    author: 'Jane Austen',
    format: 'EPUB',
    category: 'Classics',
    emoji: '🎩',
    coverGradient: LinearGradient(colors: [Colors.purple, Colors.pink]),
    progress: 0.2,
    totalPages: 5,
    currentPage: 2,
    fileSize: '800 KB',
    lastReadTime: 'Today',
    highlightsCount: 0,
  );

  group('ReadingTtsState & Notifier Chapter Navigation Tests', () {
    test('ReadingTtsState chapter boundary getters work accurately', () {
      const state1 = ReadingTtsState(
        currentChapterOrPage: 1,
        totalPagesOrChapters: 5,
      );
      expect(state1.canGoPreviousChapter, isFalse);
      expect(state1.canGoNextChapter, isTrue);

      const stateMiddle = ReadingTtsState(
        currentChapterOrPage: 3,
        totalPagesOrChapters: 5,
      );
      expect(stateMiddle.canGoPreviousChapter, isTrue);
      expect(stateMiddle.canGoNextChapter, isTrue);

      const stateLast = ReadingTtsState(
        currentChapterOrPage: 5,
        totalPagesOrChapters: 5,
      );
      expect(stateLast.canGoPreviousChapter, isTrue);
      expect(stateLast.canGoNextChapter, isFalse);
    });

    test('changeChapterOrPage updates chapter title, page, and chunk state', () async {
      final container = ProviderContainer(
        overrides: [
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(readingTtsProvider.notifier);

      await notifier.changeChapterOrPage(
        book: sampleBook,
        targetChapterOrPage: 3,
        autoPlay: false,
      );

      final state = container.read(readingTtsProvider);
      expect(state.currentChapterOrPage, 3);
      expect(state.bookId, sampleBook.id);
      expect(state.hasContent, isTrue);
      expect(state.currentChunkIndex, 0);

      // Next chapter
      await notifier.nextChapter(sampleBook, autoPlay: false);
      final nextState = container.read(readingTtsProvider);
      expect(nextState.currentChapterOrPage, 4);

      // Previous chapter
      await notifier.previousChapter(sampleBook, autoPlay: false);
      final prevState = container.read(readingTtsProvider);
      expect(prevState.currentChapterOrPage, 3);
    });
  });

  group('AudiobookControls Chapter Transport Tests', () {
    testWidgets('renders Previous Chapter and Next Chapter buttons with tooltips', (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AudiobookControls(book: sampleBook),
            ),
          ),
        ),
      );

      expect(find.byTooltip('Previous Chapter'), findsOneWidget);
      expect(find.byTooltip('Next Chapter'), findsOneWidget);
      expect(find.byTooltip('Previous Sentence'), findsOneWidget);
      expect(find.byTooltip('Next Sentence'), findsOneWidget);
    });

    testWidgets('tapping Next Chapter and Previous Chapter calls notifier methods', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(readingTtsProvider.notifier);
      await notifier.changeChapterOrPage(
        book: sampleBook,
        targetChapterOrPage: 2,
        autoPlay: false,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AudiobookControls(book: sampleBook),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap Next Chapter
      await tester.tap(find.byTooltip('Next Chapter'));
      await tester.pumpAndSettle();
      expect(container.read(readingTtsProvider).currentChapterOrPage, 3);

      // Tap Previous Chapter
      await tester.tap(find.byTooltip('Previous Chapter'));
      await tester.pumpAndSettle();
      expect(container.read(readingTtsProvider).currentChapterOrPage, 2);
    });
  });

  group('AudiobookChaptersSheet Tests', () {
    testWidgets('renders chapters and passes selected index on tap', (WidgetTester tester) async {
      int? selectedIndex;

      final testChapters = List.generate(
        5,
        (i) => ChapterItemData(index: i + 1, title: 'Chapter ${i + 1}'),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AudiobookChaptersSheet(
              chapters: testChapters,
              currentChapterIndex: 2,
              onChapterSelected: (idx) => selectedIndex = idx,
            ),
          ),
        ),
      );

      expect(find.text('Chapter 1'), findsOneWidget);
      expect(find.text('Chapter 2'), findsOneWidget);
      expect(find.text('Playing'), findsOneWidget);

      await tester.tap(find.text('Chapter 4'));
      await tester.pumpAndSettle();

      expect(selectedIndex, 4);
    });
  });

  group('AudiobookCarModeView Chapter Skip Tests', () {
    testWidgets('renders PREV CH. and NEXT CH. buttons in Car Mode', (WidgetTester tester) async {
      final container = ProviderContainer(
        overrides: [
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(readingTtsProvider.notifier);
      await notifier.changeChapterOrPage(
        book: sampleBook,
        targetChapterOrPage: 2,
        autoPlay: false,
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(
              body: AudiobookCarModeView(book: sampleBook),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('PREV CH.'), findsOneWidget);
      expect(find.text('NEXT CH.'), findsOneWidget);

      // Tap NEXT CH.
      await tester.tap(find.text('NEXT CH.'));
      await tester.pumpAndSettle();
      expect(container.read(readingTtsProvider).currentChapterOrPage, 3);
    });
  });
}
