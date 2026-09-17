import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bee_reading/main.dart';
import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/screens/home_screen.dart';
import 'package:bee_reading/screens/reader_screen.dart';
import 'package:bee_reading/screens/welcome_screen.dart';

LibraryBook createTestBook({
  String id = 'test-book-1',
  String title = 'Test eBook',
  String author = 'Test Author',
  String category = 'Technology',
  double progress = 0.5,
  int currentPage = 50,
  int totalPages = 100,
}) {
  return LibraryBook(
    id: id,
    title: title,
    author: author,
    format: 'EPUB',
    category: category,
    emoji: '📖',
    coverGradient: const LinearGradient(
      colors: [Color(0xFF2B5876), Color(0xFF4E4376)],
    ),
    progress: progress,
    totalPages: totalPages,
    currentPage: currentPage,
    fileSize: '2.5 MB',
    lastReadTime: 'Just now',
    highlightsCount: 0,
    isFavorite: false,
  );
}

void main() {
  testWidgets('Welcome screen renders and navigates to HomeScreen', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Verify WelcomeScreen is displayed
    expect(find.byType(WelcomeScreen), findsOneWidget);
    expect(find.text('Bee Reading'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Distraction-Free Reading'), findsOneWidget);

    // Tap Skip to navigate to HomeScreen
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Verify HomeScreen is now visible with empty state
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Bee Reading'), findsOneWidget);
    expect(find.text('Start Reading'), findsOneWidget);
  });

  testWidgets('Top bar search opens, shows empty state when library is empty, and closes cleanly', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Skip to HomeScreen
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Verify search icon exists in top bar
    final searchIconFinder = find.byTooltip('Search books');
    expect(searchIconFinder, findsOneWidget);

    // Tap search icon to open top bar search
    await tester.tap(searchIconFinder);
    await tester.pumpAndSettle();

    // Search bar should now be visible at top bar
    expect(find.text('Search books, authors, genres...'), findsOneWidget);
    expect(find.text('Library is empty'), findsOneWidget);
    expect(find.byTooltip('Close search'), findsOneWidget);

    // Close search via back button
    await tester.tap(find.byTooltip('Close search'));
    await tester.pumpAndSettle();

    // Back to normal top bar
    expect(find.text('Bee Reading'), findsOneWidget);
  });

  testWidgets('Top bar has import button and opens import modal', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Skip to HomeScreen
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Verify notifications button is removed
    expect(find.byTooltip('Notifications'), findsNothing);

    // Verify import button is present
    final importButtonFinder = find.byTooltip('Import book');
    expect(importButtonFinder, findsOneWidget);
    expect(find.byIcon(Icons.file_upload_outlined), findsOneWidget);

    // Tap import button to open modal
    await tester.tap(importButtonFinder);
    await tester.pumpAndSettle();

    // Verify modal content
    expect(find.text('Import eBook'), findsOneWidget);
    expect(find.text('Choose from Device'), findsOneWidget);
    expect(find.text('Import from Cloud Drive'), findsOneWidget);
  });

  testWidgets('Streak Counter renders in top bar and opens streak details modal', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Skip to HomeScreen
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Verify streak counter badge in top bar starts clean
    final streakBadgeFinder = find.byKey(const ValueKey('streak_counter_badge'));
    expect(streakBadgeFinder, findsOneWidget);
    expect(find.text('0'), findsOneWidget);

    // Verify streak in Daily Goal card
    expect(find.text('Daily Goal 🔥 0 Day Streak'), findsOneWidget);
    expect(find.text('0 of 60 mins read'), findsOneWidget);

    // Tap top bar streak badge to open modal
    await tester.tap(streakBadgeFinder);
    await tester.pumpAndSettle();

    // Verify modal details
    expect(find.text('0 Day Reading Streak!'), findsOneWidget);
    expect(find.text('🏆 0 days'), findsOneWidget);
    expect(find.text('🛡️ 2 left'), findsOneWidget);

    final buttonFinder = find.text('Log 15 Mins Reading 📖');
    await tester.ensureVisible(buttonFinder);
    await tester.pumpAndSettle();
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    // Verify streak and minutes updated with real logged session
    expect(find.text('1'), findsOneWidget);
    expect(find.text('Daily Goal 🔥 1 Day Streak'), findsOneWidget);
    expect(find.text('15 of 60 mins read'), findsOneWidget);
  });

  testWidgets('Library Screen starts clean with 0 books and empty state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Skip to HomeScreen
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Tap Library tab in NavigationBar
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    // Verify Library Screen header has 0 books
    expect(find.text('My Library'), findsOneWidget);
    expect(find.text('0'), findsWidgets);
    expect(find.text('Add Book'), findsOneWidget);
    expect(find.text('No Books Found'), findsOneWidget);
  });

  testWidgets('Manage book in library: favorite, options modal, and delete book', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testBook = createTestBook(id: 'actual-book-1', title: 'Actual Test Book');

    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // Add a real test book
    final element = tester.element(find.byType(MyApp));
    final container = ProviderScope.containerOf(element);
    container.read(booksProvider.notifier).addBook(testBook);
    await tester.pumpAndSettle();

    // Skip to HomeScreen
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Tap Library tab in NavigationBar
    await tester.tap(find.byIcon(Icons.menu_book_outlined));
    await tester.pumpAndSettle();

    // Verify 1 book exists
    expect(find.text('1'), findsWidgets);
    expect(find.text('Actual Test Book'), findsOneWidget);

    // Tap options button on book in library
    await tester.tap(find.byIcon(Icons.more_vert_rounded));
    await tester.pumpAndSettle();

    // Verify modal options include Continue Reading, Share, and Delete Book
    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('Delete Book'), findsOneWidget);

    // Tap Delete Book
    await tester.tap(find.text('Delete Book'));
    await tester.pumpAndSettle();

    // Verify confirmation dialog is shown
    expect(find.text('Are you sure you want to remove "Actual Test Book" from your library? This action cannot be undone.'), findsOneWidget);

    // Tap Delete in confirmation dialog
    await tester.tap(find.widgetWithText(ElevatedButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // Verify snackbar is shown
    expect(find.text('Removed "Actual Test Book" from library'), findsOneWidget);

    // Let snackbar dismiss and settle
    await tester.pumpAndSettle();

    // Verify book count decreased to 0
    expect(find.text('0'), findsWidgets);
    expect(find.text('Actual Test Book'), findsNothing);
  });

  testWidgets('HomeScreen displays book in Continue Reading and Category Grid when present', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testBook = createTestBook(
      id: 'actual-book-2',
      title: 'Real EBook File',
      author: 'Real Author',
      category: 'Technology',
      progress: 0.4,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    final element = tester.element(find.byType(MyApp));
    final container = ProviderScope.containerOf(element);
    container.read(booksProvider.notifier).addBook(testBook);
    await tester.pumpAndSettle();

    // Skip to HomeScreen
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Verify Continue Reading section displays Real EBook File
    expect(find.text('Continue Reading'), findsOneWidget);
    expect(find.text('Real EBook File'), findsWidgets);
    expect(find.text('40% completed • 50 / 100 pages'), findsOneWidget);

    // Tap 'See all' navigates to Library
    final seeAllFinder = find.widgetWithText(TextButton, 'See all');
    expect(seeAllFinder, findsOneWidget);
    await tester.tap(seeAllFinder);
    await tester.pumpAndSettle();

    // Verify Library Screen shows book
    expect(find.text('My Library'), findsOneWidget);
    expect(find.text('Real EBook File'), findsOneWidget);
  });

  testWidgets('Clicking book item opens Reading Screen', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final testBook = createTestBook(
      id: 'actual-reader-book-1',
      title: 'Mastering Flutter Architecture',
      author: 'Senior Engineer',
      category: 'Tech & Coding',
      progress: 0.25,
      currentPage: 25,
      totalPages: 100,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    final element = tester.element(find.byType(MyApp));
    final container = ProviderScope.containerOf(element);
    container.read(booksProvider.notifier).addBook(testBook);
    await tester.pumpAndSettle();

    // Skip welcome
    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    // Verify book is on HomeScreen
    expect(find.text('Mastering Flutter Architecture'), findsWidgets);

    // Click on the book item
    await tester.tap(find.text('Mastering Flutter Architecture').first);
    await tester.pumpAndSettle();

    // Verify Reading Screen opens
    expect(find.byType(ReaderScreen), findsOneWidget);
    expect(find.text('Mastering Flutter Architecture'), findsOneWidget);

    // Verify reader UI elements exist (back button, appearance settings icon, favorite icon)
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.byIcon(Icons.format_size_rounded), findsOneWidget);
    expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

    // Pop back to HomeScreen
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();

    // Verify back on HomeScreen
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('Tapping reading screen toggles controls visibility', (WidgetTester tester) async {
    const book = LibraryBook(
      id: 'test-tap-book',
      title: 'Tap Toggle Test Book',
      author: 'Author',
      format: 'EPUB',
      category: 'Tech',
      emoji: '📘',
      coverGradient: LinearGradient(colors: [Colors.blue, Colors.indigo]),
      progress: 0.1,
      totalPages: 10,
      currentPage: 1,
      fileSize: '1 MB',
      lastReadTime: 'Today',
      highlightsCount: 0,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Initially controls are visible
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    final initialIgnorePointer = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byType(AnimatedPositioned).first,
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(initialIgnorePointer.ignoring, isFalse);

    // Tap in the middle of the screen to hide controls
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    // Controls should now be hidden (IgnorePointer ignoring: true)
    final hiddenIgnorePointer = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byType(AnimatedPositioned).first,
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(hiddenIgnorePointer.ignoring, isTrue);

    // Tap again to show controls
    await tester.tapAt(const Offset(400, 300));
    await tester.pumpAndSettle();

    // Controls should reappear (IgnorePointer ignoring: false)
    final visibleIgnorePointer = tester.widget<IgnorePointer>(
      find.descendant(
        of: find.byType(AnimatedPositioned).first,
        matching: find.byType(IgnorePointer),
      ),
    );
    expect(visibleIgnorePointer.ignoring, isFalse);
  });

  testWidgets('Appearance modal opens cleanly without overflow in landscape orientation', (WidgetTester tester) async {
    // Set landscape screen dimensions (e.g. 800x360)
    tester.view.physicalSize = const Size(800, 360);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    const book = LibraryBook(
      id: 'book_landscape_test',
      title: 'Landscape Reading Test',
      author: 'Test Author',
      format: 'PDF',
      category: 'Tech',
      emoji: '📘',
      coverGradient: LinearGradient(colors: [Colors.blue, Colors.indigo]),
      progress: 0.1,
      totalPages: 10,
      currentPage: 1,
      fileSize: '1 MB',
      lastReadTime: 'Today',
      highlightsCount: 0,
    );

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ReaderScreen(book: book),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap Appearance & Themes button
    final themeButton = find.byIcon(Icons.format_size_rounded);
    expect(themeButton, findsOneWidget);
    await tester.tap(themeButton);
    await tester.pumpAndSettle();

    // Verify modal contents rendered without overflow
    expect(find.text('Reading Themes'), findsOneWidget);
    expect(find.text('Page Zoom & Fit'), findsOneWidget);
    expect(find.text('Fit Width'), findsOneWidget);
    expect(find.text('Light'), findsOneWidget);
    expect(find.text('Sepia'), findsOneWidget);
    expect(find.text('Dark'), findsOneWidget);
  });
}

