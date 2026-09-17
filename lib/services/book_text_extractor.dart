/// Utility service for extracting and chunking readable text from
/// EPUB HTML chapters and PDF pages for Text-to-Speech (TTS).
class BookTextExtractor {
  static final RegExp _scriptStyleHeadRegExp = RegExp(
    r'<(?:script|style|head)[^>]*>[\s\S]*?<\/(?:script|style|head)>',
    caseSensitive: false,
  );

  static final RegExp _blockTagsRegExp = RegExp(
    r'<\/(?:p|div|h[1-6]|li|tr|blockquote|section|article)>\s*|<br\s*\/?>',
    caseSensitive: false,
  );

  static final RegExp _allTagsRegExp = RegExp(r'<[^>]+>');

  static final RegExp _multiWhitespaceRegExp = RegExp(r'[ \t\f\r]+');
  static final RegExp _multiNewlineRegExp = RegExp(r'\n{2,}');

  static final RegExp _sentenceSplitRegExp = RegExp(r'(?<=[.!?])\s+(?=[A-Z0-9"\u201C\u2018])');

  /// Extracts structured, clean speech chunks from EPUB HTML content.
  static List<String> extractFromHtml(String htmlContent) {
    if (htmlContent.trim().isEmpty) return const [];

    // 1. Strip script, style, and head blocks
    var text = htmlContent.replaceAll(_scriptStyleHeadRegExp, ' ');

    // 2. Turn block boundaries into newlines
    text = text.replaceAll(_blockTagsRegExp, '\n\n');

    // 3. Strip all remaining HTML tags
    text = text.replaceAll(_allTagsRegExp, ' ');

    // 4. Decode HTML entities
    text = _decodeHtmlEntities(text);

    // 5. Clean whitespace per line
    final rawLines = text.split('\n');
    final cleanedParagraphs = <String>[];

    for (final rawLine in rawLines) {
      final line = rawLine.replaceAll(_multiWhitespaceRegExp, ' ').trim();
      if (line.isNotEmpty && !_isSkippableGarbage(line)) {
        cleanedParagraphs.add(line);
      }
    }

    // 6. Break down any paragraph that is too long into sentences for better TTS fluidity
    return _chunkParagraphs(cleanedParagraphs, maxChunkLength: 350);
  }

  /// Extracts structured, clean speech chunks from raw text (e.g. from PDF).
  static List<String> extractFromPdfText(String rawText) {
    if (rawText.trim().isEmpty) return const [];

    var text = rawText;

    // 1. Fix hyphenation at line breaks (e.g. "instruc-\ntion" -> "instruction")
    text = text.replaceAllMapped(RegExp(r'(\w+)-\s*\n\s*(\w+)'), (m) => '${m[1]}${m[2]}');

    // 2. Join soft-wrapped lines inside paragraphs
    // A newline not preceded by a sentence terminator (.!?:) is usually a soft wrap
    final lines = text.split('\n');
    final sb = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) {
        sb.write('\n\n');
        continue;
      }

      sb.write(line);

      // If the line ends with a period, question mark, exclamation, or quotes, add paragraph separator
      if (line.endsWith('.') || line.endsWith('!') || line.endsWith('?') || line.endsWith(':') || line.endsWith('”') || line.endsWith('"')) {
        sb.write('\n\n');
      } else {
        sb.write(' ');
      }
    }

    final rawParagraphs = sb.toString().split(_multiNewlineRegExp);
    final cleaned = <String>[];

    for (final p in rawParagraphs) {
      final trimmed = p.replaceAll(_multiWhitespaceRegExp, ' ').trim();
      if (trimmed.isNotEmpty && !_isSkippableGarbage(trimmed)) {
        cleaned.add(trimmed);
      }
    }

    return _chunkParagraphs(cleaned, maxChunkLength: 350);
  }

  /// Splits long paragraphs into sentence-sized chunks to ensure optimal TTS responsiveness
  /// and allow instant forward/rewind scrubbing.
  static List<String> _chunkParagraphs(List<String> paragraphs, {int maxChunkLength = 350}) {
    final result = <String>[];

    for (final para in paragraphs) {
      if (para.length <= maxChunkLength) {
        result.add(para);
      } else {
        // Split by sentence terminators
        final sentences = para.split(_sentenceSplitRegExp);
        String currentAccum = '';

        for (final s in sentences) {
          final sTrimmed = s.trim();
          if (sTrimmed.isEmpty) continue;

          if (currentAccum.isEmpty) {
            currentAccum = sTrimmed;
          } else if ((currentAccum.length + sTrimmed.length + 1) <= maxChunkLength) {
            currentAccum = '$currentAccum $sTrimmed';
          } else {
            result.add(currentAccum);
            currentAccum = sTrimmed;
          }
        }

        if (currentAccum.isNotEmpty) {
          result.add(currentAccum);
        }
      }
    }

    return result;
  }

  /// Filters out isolated page numbers, CSS snippets, decorative dividers, or empty symbols.
  static bool _isSkippableGarbage(String line) {
    if (line.length <= 1) return true;
    // Pure numbers (like page footers)
    if (RegExp(r'^\d+$').hasMatch(line)) return true;
    // Pure punctuation/symbols without any letters or numbers (e.g. "* * *", "---", "###")
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(line)) return true;
    return false;
  }

  /// Decodes standard HTML entities without requiring heavyweight third-party libraries.
  static String _decodeHtmlEntities(String text) {
    var s = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '...')
        .replaceAll('&lsquo;', "'")
        .replaceAll('&rsquo;', "'")
        .replaceAll('&ldquo;', '"')
        .replaceAll('&rdquo;', '"');

    // Decode decimal numeric entities &#123;
    s = s.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '');
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });

    // Decode hex numeric entities &#x1F4DA;
    s = s.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.tryParse(match.group(1) ?? '', radix: 16);
      return code != null ? String.fromCharCode(code) : match.group(0)!;
    });

    return s;
  }
}
