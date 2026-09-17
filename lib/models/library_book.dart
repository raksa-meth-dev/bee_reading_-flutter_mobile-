import 'package:flutter/material.dart';

enum LibraryFilter { all, reading, completed, downloaded, favorites }
enum LibrarySort { recent, title, author, progress }

class LibraryBook {
  final String id;
  final String title;
  final String author;
  final String? filePath;
  final String format; // 'EPUB' | 'PDF' | 'MOBI'
  final String category;
  final String emoji;
  final LinearGradient coverGradient;
  final String? coverUrl;
  final double progress;
  final int totalPages;
  final int currentPage;
  final String fileSize;
  final String lastReadTime;
  final int highlightsCount;
  final bool isFavorite;
  final bool isDownloaded;

  const LibraryBook({
    required this.id,
    required this.title,
    required this.author,
    this.filePath,
    required this.format,
    required this.category,
    required this.emoji,
    required this.coverGradient,
    this.coverUrl,
    required this.progress,
    required this.totalPages,
    required this.currentPage,
    required this.fileSize,
    required this.lastReadTime,
    required this.highlightsCount,
    this.isFavorite = false,
    this.isDownloaded = true,
  });

  bool get isCompleted => progress >= 1.0;
  bool get isReading => progress > 0.0 && progress < 1.0;

  LibraryBook copyWith({
    String? id,
    String? title,
    String? author,
    String? filePath,
    String? format,
    String? category,
    String? emoji,
    LinearGradient? coverGradient,
    String? coverUrl,
    double? progress,
    int? totalPages,
    int? currentPage,
    String? fileSize,
    String? lastReadTime,
    int? highlightsCount,
    bool? isFavorite,
    bool? isDownloaded,
  }) {
    return LibraryBook(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      filePath: filePath ?? this.filePath,
      format: format ?? this.format,
      category: category ?? this.category,
      emoji: emoji ?? this.emoji,
      coverGradient: coverGradient ?? this.coverGradient,
      coverUrl: coverUrl ?? this.coverUrl,
      progress: progress ?? this.progress,
      totalPages: totalPages ?? this.totalPages,
      currentPage: currentPage ?? this.currentPage,
      fileSize: fileSize ?? this.fileSize,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      highlightsCount: highlightsCount ?? this.highlightsCount,
      isFavorite: isFavorite ?? this.isFavorite,
      isDownloaded: isDownloaded ?? this.isDownloaded,
    );
  }
}
