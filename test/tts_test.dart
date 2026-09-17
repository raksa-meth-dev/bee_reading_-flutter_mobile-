import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bee_reading/providers/reading_tts_provider.dart';
import 'package:bee_reading/screens/reader/reader_theme.dart';
import 'package:bee_reading/services/book_text_extractor.dart';
import 'package:bee_reading/services/tts_service.dart';
import 'package:bee_reading/widgets/reader/reader_tts_bar.dart';

void main() {
  group('BookTextExtractor Tests', () {
    test('extractFromHtml strips tags, decodes entities, and chunks paragraphs', () {
      const sampleHtml = '''
        <!DOCTYPE html>
        <html>
          <head>
            <title>Test Chapter</title>
            <style>body { color: red; }</style>
          </head>
          <body>
            <h1>Chapter 1: The Beginning</h1>
            <p>It was a bright cold day in April, and the clocks were striking thirteen.</p>
            <p>Winston Smith, his chin nuzzled into his breast in an effort to escape the vile wind, slipped quickly through the glass doors of Victory Mansions.&nbsp;Though not quickly enough to prevent a swirl of gritty dust from entering along with him.</p>
          </body>
        </html>
      ''';

      final chunks = BookTextExtractor.extractFromHtml(sampleHtml);

      expect(chunks.isNotEmpty, isTrue);
      expect(chunks.any((c) => c.contains('<style>')), isFalse);
      expect(chunks.any((c) => c.contains('body {')), isFalse);
      expect(chunks.first, 'Chapter 1: The Beginning');
      expect(chunks[1], 'It was a bright cold day in April, and the clocks were striking thirteen.');
      // Verify &nbsp; was decoded to standard whitespace
      expect(chunks.any((c) => c.contains('&nbsp;')), isFalse);
    });

    test('extractFromHtml decodes numeric and named HTML entities', () {
      const htmlWithEntities = '<p>&ldquo;Hello World&rdquo; &mdash; It&#39;s an &#x27;eBook&#x27; &amp; more!</p>';
      final chunks = BookTextExtractor.extractFromHtml(htmlWithEntities);

      expect(chunks.length, 1);
      expect(chunks.first, '"Hello World" — It\'s an \'eBook\' & more!');
    });

    test('extractFromPdfText fixes hyphenated words and combines soft wraps', () {
      const rawPdf = '''
This is an exam-
ple of a continuous sentence that was bro-
ken across multiple lines in the document.

Here is a second paragraph that follows immediately.
''';

      final chunks = BookTextExtractor.extractFromPdfText(rawPdf);

      expect(chunks.length, 2);
      expect(chunks.first, contains('example'));
      expect(chunks.first, contains('broken across'));
      expect(chunks[1], 'Here is a second paragraph that follows immediately.');
    });

    test('extractFromHtml gracefully handles empty or whitespace input', () {
      expect(BookTextExtractor.extractFromHtml(''), isEmpty);
      expect(BookTextExtractor.extractFromHtml('    \n\t   '), isEmpty);
      expect(BookTextExtractor.extractFromHtml('<div></div><p></p>'), isEmpty);
    });

    test('extractFromHtml skips decorative divider symbols and isolated line noise', () {
      const htmlWithDividers = '''
        <p>Before the break.</p>
        <p>* * *</p>
        <p>---</p>
        <p>After the break.</p>
      ''';
      final chunks = BookTextExtractor.extractFromHtml(htmlWithDividers);
      expect(chunks.length, 2);
      expect(chunks[0], 'Before the break.');
      expect(chunks[1], 'After the break.');
    });
  });

  group('TtsService Sanitization Tests', () {
    test('sanitizeForSpeech expands ligatures, cleans dashes, soft hyphens, and footnote brackets', () {
      const input = 'The af\uFB02iction was re\uFB01ned\u00ad, and\u2014strangely enough\u2014clear[1]...';
      final sanitized = TtsService.sanitizeForSpeech(input);

      expect(sanitized.contains('affliction'), isTrue);
      expect(sanitized.contains('refined'), isTrue);
      expect(sanitized.contains('\u00ad'), isFalse);
      expect(sanitized.contains('[1]'), isFalse);
      expect(sanitized.contains(', and, strangely enough, clear.'), isTrue);
    });
  });

  group('ReadingTtsState & Provider Tests', () {
    test('ReadingTtsState defaults and copyWith', () {
      const state = ReadingTtsState();
      expect(state.status, TtsPlaybackStatus.stopped);
      expect(state.isPlaying, isFalse);
      expect(state.isPaused, isFalse);
      expect(state.isStopped, isTrue);
      expect(state.speedMultiplier, 1.0);
      expect(state.autoAdvance, isTrue);
      expect(state.chunks, isEmpty);

      final updated = state.copyWith(
        status: TtsPlaybackStatus.playing,
        chunks: ['First paragraph', 'Second paragraph'],
        currentChunkIndex: 0,
        speedMultiplier: 1.5,
      );

      expect(updated.isPlaying, isTrue);
      expect(updated.totalChunks, 2);
      expect(updated.currentChunk, 'First paragraph');
      expect(updated.speedMultiplier, 1.5);
    });
  });

  group('ReaderTtsBar Widget Tests', () {
    testWidgets('renders player controls and responds to callbacks', (WidgetTester tester) async {
      bool closed = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Scaffold(
              body: ReaderTtsBar(
                readerTheme: ReaderThemeData.light,
                isPdf: false,
                currentPage: 2,
                totalPages: 10,
                onClose: () {
                  closed = true;
                },
              ),
            ),
          ),
        ),
      );

      // Verify UI elements are present
      expect(find.text('Voice Reader'), findsOneWidget);
      expect(find.textContaining('Chapter 2 of 10'), findsOneWidget);
      expect(find.byTooltip('Play'), findsOneWidget);
      expect(find.byTooltip('Previous Paragraph'), findsOneWidget);
      expect(find.byTooltip('Next Paragraph'), findsOneWidget);
      expect(find.text('1.0x'), findsOneWidget);
      expect(find.text('Auto-Flip: ON'), findsOneWidget);

      // Test close button
      await tester.tap(find.byTooltip('Close Voice Player'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });
  });
}
