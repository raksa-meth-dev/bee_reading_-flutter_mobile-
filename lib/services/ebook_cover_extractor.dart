import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class EbookMetadata {
  final String? coverPath;
  final String? title;
  final String? author;

  const EbookMetadata({
    this.coverPath,
    this.title,
    this.author,
  });
}

class EbookCoverExtractor {
  /// Extracts the cover image and metadata from an eBook file ([fileBytes] or [filePath]).
  /// Saves the extracted cover to disk and returns an [EbookMetadata] with the file path.
  static Future<EbookMetadata> extractMetadataAndCover({
    required String bookId,
    required String format,
    List<int>? fileBytes,
    String? filePath,
  }) async {
    try {
      List<int>? bytes = fileBytes;
      if (bytes == null || bytes.isEmpty) {
        if (filePath != null && File(filePath).existsSync()) {
          bytes = await File(filePath).readAsBytes();
        }
      }

      if (bytes == null || bytes.isEmpty) {
        return const EbookMetadata();
      }

      final fmt = format.toUpperCase();
      if (fmt == 'EPUB') {
        return await _extractFromEpub(bookId, bytes);
      } else if (fmt == 'PDF') {
        return await _extractFromPdf(bookId, bytes);
      }
    } catch (e) {
      debugPrint('Error extracting cover for book $bookId: $e');
    }

    return const EbookMetadata();
  }

  static Future<Directory> _getCoversDirectory() async {
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      final tempDir = Directory('${Directory.systemTemp.path}/bee_reading_test_covers');
      if (!tempDir.existsSync()) {
        tempDir.createSync(recursive: true);
      }
      return tempDir;
    }
    try {
      final docDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory('${docDir.path}/covers');
      if (!coversDir.existsSync()) {
        await coversDir.create(recursive: true);
      }
      return coversDir;
    } catch (e) {
      debugPrint('Error accessing documents directory for covers: $e');
      final fallbackDir = Directory('${Directory.systemTemp.path}/bee_reading_covers');
      if (!fallbackDir.existsSync()) {
        fallbackDir.createSync(recursive: true);
      }
      return fallbackDir;
    }
  }

  static Future<EbookMetadata> _extractFromEpub(String bookId, List<int> bytes) async {
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      String? title;
      String? author;
      List<int>? coverBytes;
      String coverExt = 'jpg';

      // 1. Locate container.xml to find the root OPF file path
      String? opfPath;
      final containerEntry = archive.findFile('META-INF/container.xml');
      if (containerEntry != null) {
        final containerXml = utf8.decode(containerEntry.content as List<int>, allowMalformed: true);
        final fullPathMatch = RegExp(r'''full-path\s*=\s*["']([^"']+\.opf)["']''', caseSensitive: false)
            .firstMatch(containerXml);
        if (fullPathMatch != null) {
          opfPath = fullPathMatch.group(1);
        }
      }

      // If container.xml was missing or didn't point to an OPF, search for any .opf file in archive
      if (opfPath == null) {
        for (final f in archive.files) {
          if (f.name.toLowerCase().endsWith('.opf')) {
            opfPath = f.name;
            break;
          }
        }
      }

      if (opfPath != null) {
        var opfDir = p.posix.dirname(opfPath);
        if (opfDir == '.') opfDir = '';

        final opfEntry = archive.findFile(opfPath);
        if (opfEntry != null) {
          final opfContent = utf8.decode(opfEntry.content as List<int>, allowMalformed: true);

          // Extract title if present
          final titleMatch = RegExp(r'<dc:title[^>]*>([^<]+)</dc:title>', caseSensitive: false)
              .firstMatch(opfContent);
          if (titleMatch != null) {
            title = titleMatch.group(1)?.trim();
          }

          // Extract author if present
          final authorMatch = RegExp(r'<dc:creator[^>]*>([^<]+)</dc:creator>', caseSensitive: false)
              .firstMatch(opfContent);
          if (authorMatch != null) {
            author = authorMatch.group(1)?.trim();
          }

          // A. Check for EPUB 3 cover: item with properties="cover-image"
          final epub3Match = RegExp(
            r'''<item[^>]+properties\s*=\s*["'][^"']*cover-image[^"']*["'][^>]+href\s*=\s*["']([^"']+)["']''',
            caseSensitive: false,
          ).firstMatch(opfContent) ??
          RegExp(
            r'''<item[^>]+href\s*=\s*["']([^"']+)["'][^>]+properties\s*=\s*["'][^"']*cover-image[^"']*["']''',
            caseSensitive: false,
          ).firstMatch(opfContent);

          String? coverHref;
          if (epub3Match != null) {
            coverHref = epub3Match.group(1);
          }

          // B. Check for EPUB 2 cover: <meta name="cover" content="cover-id" />
          if (coverHref == null) {
            final epub2MetaMatch = RegExp(
              r'''<meta\s+[^>]*name\s*=\s*["']cover["']\s+content\s*=\s*["']([^"']+)["']''',
              caseSensitive: false,
            ).firstMatch(opfContent) ??
            RegExp(
              r'''<meta\s+[^>]*content\s*=\s*["']([^"']+)["']\s+name\s*=\s*["']cover["']''',
              caseSensitive: false,
            ).firstMatch(opfContent);

            if (epub2MetaMatch != null) {
              final coverId = RegExp.escape(epub2MetaMatch.group(1)!);
              final itemMatch = RegExp(
                '''<item[^>]+id\\s*=\\s*["']$coverId["'][^>]+href\\s*=\\s*["']([^"']+)["']''',
                caseSensitive: false,
              ).firstMatch(opfContent) ??
              RegExp(
                '''<item[^>]+href\\s*=\\s*["']([^"']+)["'][^>]+id\\s*=\\s*["']$coverId["']''',
                caseSensitive: false,
              ).firstMatch(opfContent);

              if (itemMatch != null) {
                coverHref = itemMatch.group(1);
              }
            }
          }

          // If coverHref found, locate file in archive
          if (coverHref != null) {
            final decodedHref = Uri.decodeComponent(coverHref);
            final resolvedPath = opfDir.isNotEmpty
                ? p.posix.normalize('$opfDir/$decodedHref')
                : p.posix.normalize(decodedHref);

            ArchiveFile? targetEntry = archive.findFile(resolvedPath);
            if (targetEntry == null) {
              final base = p.posix.basename(resolvedPath).toLowerCase();
              for (final f in archive.files) {
                if (p.posix.basename(f.name).toLowerCase() == base) {
                  targetEntry = f;
                  break;
                }
              }
            }

            if (targetEntry != null) {
              coverBytes = targetEntry.content as List<int>;
              coverExt = _getExtensionForBytes(coverBytes, resolvedPath);
            }
          }
        }
      }

      // 2. Fallback: Search archive directly for cover images
      if (coverBytes == null || coverBytes.isEmpty) {
        ArchiveFile? candidate;

        // Priority 1: Exact cover.jpg, cover.png, cover.jpeg, cover.webp
        for (final f in archive.files) {
          final name = p.posix.basename(f.name).toLowerCase();
          if (name == 'cover.jpg' || name == 'cover.jpeg' || name == 'cover.png' || name == 'cover.webp') {
            candidate = f;
            break;
          }
        }

        // Priority 2: File containing 'cover' and image extension
        if (candidate == null) {
          for (final f in archive.files) {
            final name = p.posix.basename(f.name).toLowerCase();
            if (name.contains('cover') &&
                (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp'))) {
              candidate = f;
              break;
            }
          }
        }

        // Priority 3: First image in images/ or img/ folder
        if (candidate == null) {
          for (final f in archive.files) {
            final name = f.name.toLowerCase();
            if ((name.contains('images/') || name.contains('img/')) &&
                (name.endsWith('.jpg') || name.endsWith('.jpeg') || name.endsWith('.png') || name.endsWith('.webp'))) {
              candidate = f;
              break;
            }
          }
        }

        if (candidate != null) {
          coverBytes = candidate.content as List<int>;
          coverExt = _getExtensionForBytes(coverBytes, candidate.name);
        }
      }

      // If cover bytes were extracted, write them to disk
      String? savedPath;
      if (coverBytes != null && coverBytes.isNotEmpty) {
        final coversDir = await _getCoversDirectory();
        final file = File('${coversDir.path}/${bookId}_cover.$coverExt');
        await file.writeAsBytes(coverBytes);
        savedPath = file.path;
      }

      return EbookMetadata(
        coverPath: savedPath,
        title: title,
        author: author,
      );
    } catch (e) {
      debugPrint('Error in _extractFromEpub: $e');
      return const EbookMetadata();
    }
  }

  static Future<EbookMetadata> _extractFromPdf(String bookId, List<int> bytes) async {
    try {
      final coverBytes = _findFirstJpegInBytes(bytes);
      if (coverBytes != null && coverBytes.length > 5000) {
        final coversDir = await _getCoversDirectory();
        final file = File('${coversDir.path}/${bookId}_cover.jpg');
        await file.writeAsBytes(coverBytes);
        return EbookMetadata(coverPath: file.path);
      }
    } catch (e) {
      debugPrint('Error in _extractFromPdf: $e');
    }
    return const EbookMetadata();
  }

  static List<int>? _findFirstJpegInBytes(List<int> bytes) {
    final len = bytes.length;
    final maxScan = len > 5 * 1024 * 1024 ? 5 * 1024 * 1024 : len;
    int start = -1;

    for (int i = 0; i < maxScan - 3; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8 && bytes[i + 2] == 0xFF) {
        start = i;
        break;
      }
    }

    if (start == -1) return null;

    for (int i = start + 3; i < maxScan - 1; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD9) {
        final jpegBytes = bytes.sublist(start, i + 2);
        return jpegBytes;
      }
    }

    return null;
  }

  static String _getExtensionForBytes(List<int> bytes, String fallbackPath) {
    if (bytes.length >= 4) {
      if (bytes[0] == 0xFF && bytes[1] == 0xD8) return 'jpg';
      if (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) return 'png';
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46 &&
          bytes[8] == 0x57 &&
          bytes[9] == 0x45 &&
          bytes[10] == 0x42 &&
          bytes[11] == 0x50) {
        return 'webp';
      }
    }
    final ext = p.extension(fallbackPath).replaceFirst('.', '').toLowerCase();
    if (ext == 'jpeg') return 'jpg';
    if (ext.isNotEmpty) return ext;
    return 'jpg';
  }
}
