import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/models/library_book.dart';
import 'package:bee_reading/providers/books_provider.dart';
import 'package:bee_reading/screens/audiobook/widgets/audiobook_chapters_sheet.dart';
import 'package:bee_reading/services/book_content_service.dart';
import 'package:bee_reading/services/tts_service.dart';

enum VoiceGender { female, male }

class NarratorVoice {
  final String id;
  final String name;
  final VoiceGender gender;
  final String style;
  final double defaultPitch;
  final String sampleLocale;

  const NarratorVoice({
    required this.id,
    required this.name,
    required this.gender,
    required this.style,
    required this.defaultPitch,
    required this.sampleLocale,
  });

  static const List<NarratorVoice> curatedVoices = [
    NarratorVoice(
      id: 'emma',
      name: 'Emma',
      gender: VoiceGender.female,
      style: 'Warm & Natural',
      defaultPitch: 1.05,
      sampleLocale: 'en-US',
    ),
    NarratorVoice(
      id: 'sophia',
      name: 'Sophia',
      gender: VoiceGender.female,
      style: 'Expressive Storyteller',
      defaultPitch: 1.15,
      sampleLocale: 'en-GB',
    ),
    NarratorVoice(
      id: 'oliver',
      name: 'Oliver',
      gender: VoiceGender.male,
      style: 'Deep & Calm',
      defaultPitch: 0.90,
      sampleLocale: 'en-US',
    ),
    NarratorVoice(
      id: 'james',
      name: 'James',
      gender: VoiceGender.male,
      style: 'Classic Narrative',
      defaultPitch: 0.82,
      sampleLocale: 'en-GB',
    ),
  ];
}

class ReadingTtsState {
  final TtsPlaybackStatus status;
  final List<String> chunks;
  final int currentChunkIndex;
  final double speedMultiplier;
  final double pitch;
  final bool autoAdvance;
  final int currentChapterOrPage;
  final String? bookId;
  final bool isPlayerVisible;
  final Duration? sleepTimerDuration;
  final int? sleepTimerRemainingSeconds;
  final String? currentChapterTitle;
  final int totalPagesOrChapters;
  final NarratorVoice selectedNarratorVoice;
  final Map<String, String>? selectedVoice;
  final List<Map<String, String>> availableVoices;

  const ReadingTtsState({
    this.status = TtsPlaybackStatus.stopped,
    this.chunks = const [],
    this.currentChunkIndex = 0,
    this.speedMultiplier = 1.0,
    this.pitch = 1.0,
    this.autoAdvance = true,
    this.currentChapterOrPage = 1,
    this.bookId,
    this.isPlayerVisible = false,
    this.sleepTimerDuration,
    this.sleepTimerRemainingSeconds,
    this.currentChapterTitle,
    this.totalPagesOrChapters = 1,
    this.selectedNarratorVoice = const NarratorVoice(
      id: 'emma',
      name: 'Emma',
      gender: VoiceGender.female,
      style: 'Warm & Natural',
      defaultPitch: 1.05,
      sampleLocale: 'en-US',
    ),
    this.selectedVoice,
    this.availableVoices = const [],
  });

  bool get isPlaying => status == TtsPlaybackStatus.playing;
  bool get isPaused => status == TtsPlaybackStatus.paused;
  bool get isStopped => status == TtsPlaybackStatus.stopped;
  bool get hasContent => chunks.isNotEmpty;
  bool get hasActiveSleepTimer =>
      sleepTimerRemainingSeconds != null && sleepTimerRemainingSeconds! > 0;

  String? get currentChunk =>
      (currentChunkIndex >= 0 && currentChunkIndex < chunks.length)
          ? chunks[currentChunkIndex]
          : null;

  int get totalChunks => chunks.length;
  bool get canGoNextChapter => currentChapterOrPage < totalPagesOrChapters;
  bool get canGoPreviousChapter => currentChapterOrPage > 1;

  ReadingTtsState copyWith({
    TtsPlaybackStatus? status,
    List<String>? chunks,
    int? currentChunkIndex,
    double? speedMultiplier,
    double? pitch,
    bool? autoAdvance,
    int? currentChapterOrPage,
    String? bookId,
    bool? isPlayerVisible,
    Duration? sleepTimerDuration,
    int? sleepTimerRemainingSeconds,
    bool clearSleepTimer = false,
    String? currentChapterTitle,
    int? totalPagesOrChapters,
    NarratorVoice? selectedNarratorVoice,
    Map<String, String>? selectedVoice,
    List<Map<String, String>>? availableVoices,
  }) {
    return ReadingTtsState(
      status: status ?? this.status,
      chunks: chunks ?? this.chunks,
      currentChunkIndex: currentChunkIndex ?? this.currentChunkIndex,
      speedMultiplier: speedMultiplier ?? this.speedMultiplier,
      pitch: pitch ?? this.pitch,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      currentChapterOrPage: currentChapterOrPage ?? this.currentChapterOrPage,
      bookId: bookId ?? this.bookId,
      isPlayerVisible: isPlayerVisible ?? this.isPlayerVisible,
      sleepTimerDuration: clearSleepTimer
          ? null
          : (sleepTimerDuration ?? this.sleepTimerDuration),
      sleepTimerRemainingSeconds: clearSleepTimer
          ? null
          : (sleepTimerRemainingSeconds ?? this.sleepTimerRemainingSeconds),
      currentChapterTitle: currentChapterTitle ?? this.currentChapterTitle,
      totalPagesOrChapters: totalPagesOrChapters ?? this.totalPagesOrChapters,
      selectedNarratorVoice: selectedNarratorVoice ?? this.selectedNarratorVoice,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      availableVoices: availableVoices ?? this.availableVoices,
    );
  }
}

class ReadingTtsNotifier extends Notifier<ReadingTtsState> {
  late final TtsService _ttsService;
  late final BookContentService _contentService;

  /// Current active book associated with playback session.
  LibraryBook? _currentBook;
  LibraryBook? get currentBook => _currentBook;

  void setCurrentBook(LibraryBook? book) {
    _currentBook = book;
  }

  /// Counter used to cancel pending inter-chunk pauses if user pauses, skips, or stops.
  int _playSessionId = 0;

  /// Periodic timer for counting down the sleep timer
  Timer? _sleepCountdownTimer;

  /// External callback to request next page/chapter when current page reaches the end
  VoidCallback? onAutoAdvanceRequested;

  /// External callback to request jumping to a specific chapter or page
  void Function(int chapterOrPage)? onChapterJumpRequested;

  @override
  ReadingTtsState build() {
    _ttsService = ref.watch(ttsServiceProvider);
    _contentService = ref.watch(bookContentServiceProvider);

    _ttsService.onStatusChanged = (status) {
      if (state.status != status) {
        state = state.copyWith(status: status);
      }
    };

    _ttsService.onCompleted = _handleChunkCompleted;

    ref.onDispose(() {
      _sleepCountdownTimer?.cancel();
    });

    return const ReadingTtsState();
  }

  /// Sets up sleep timer countdown. Passing null cancels any active sleep timer.
  void setSleepTimer(Duration? duration) {
    _sleepCountdownTimer?.cancel();

    if (duration == null) {
      state = state.copyWith(clearSleepTimer: true);
      return;
    }

    state = state.copyWith(
      sleepTimerDuration: duration,
      sleepTimerRemainingSeconds: duration.inSeconds,
    );

    _sleepCountdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = state.sleepTimerRemainingSeconds;
      if (remaining == null || remaining <= 1) {
        timer.cancel();
        state = state.copyWith(clearSleepTimer: true);
        pause();
      } else {
        state = state.copyWith(sleepTimerRemainingSeconds: remaining - 1);
      }
    });
  }

  /// Cancels any currently active sleep timer.
  void cancelSleepTimer() {
    _sleepCountdownTimer?.cancel();
    state = state.copyWith(clearSleepTimer: true);
  }

  /// Fetches platform voices and populates the availableVoices list.
  Future<void> fetchVoices() async {
    final voices = await _ttsService.getVoices();
    if (voices.isNotEmpty) {
      state = state.copyWith(availableVoices: voices);
    }
  }

  /// Sets the active platform voice.
  Future<void> setVoice(Map<String, String> voice) async {
    state = state.copyWith(selectedVoice: voice);
    await _ttsService.setVoice(voice);
  }

  /// Sets one of the 4 curated narrator voices (2 female: Emma, Sophia; 2 male: Oliver, James)
  Future<void> setNarratorVoice(NarratorVoice voice) async {
    state = state.copyWith(
      selectedNarratorVoice: voice,
      pitch: voice.defaultPitch,
    );
    await _ttsService.setPitch(voice.defaultPitch);

    if (state.availableVoices.isNotEmpty) {
      final isFemale = voice.gender == VoiceGender.female;
      Map<String, String>? matched;

      for (final v in state.availableVoices) {
        final name = (v['name'] ?? '').toLowerCase();
        final matchesGender = isFemale
            ? (name.contains('female') ||
                name.contains('woman') ||
                name.contains('samantha') ||
                name.contains('karen') ||
                name.contains('zira') ||
                name.contains('sfg') ||
                name.contains('victoria'))
            : (name.contains('male') ||
                name.contains('man') ||
                name.contains('david') ||
                name.contains('daniel') ||
                name.contains('alex') ||
                name.contains('george') ||
                name.contains('iol'));

        if (matchesGender) {
          matched = v;
          break;
        }
      }

      matched ??= state.availableVoices.firstWhere(
        (v) {
          final name = (v['name'] ?? '').toLowerCase();
          return isFemale ? name.contains('female') : name.contains('male');
        },
        orElse: () => state.availableVoices.first,
      );

      state = state.copyWith(selectedVoice: matched);
      await _ttsService.setVoice(matched);
    }
  }

  /// Adjusts pitch (0.5 to 2.0).
  Future<void> setPitch(double pitch) async {
    state = state.copyWith(pitch: pitch);
    await _ttsService.setPitch(pitch);
  }

  /// Updates chapter information displayed in the audio player.
  void setChapterInfo({
    String? title,
    int? total,
    int? current,
  }) {
    state = state.copyWith(
      currentChapterTitle: title,
      totalPagesOrChapters: total,
      currentChapterOrPage: current,
    );
  }

  /// Requests navigation to a specific chapter/page.
  void requestChapterJump(int chapterOrPage) {
    onChapterJumpRequested?.call(chapterOrPage);
  }

  /// Changes to a specific chapter or page for the given [book].
  /// Loads real speech chunks via [BookContentService], updates reading progress in database,
  /// and begins recitation if [autoPlay] is true or currently playing.
  Future<void> changeChapterOrPage({
    required LibraryBook book,
    required int targetChapterOrPage,
    bool autoPlay = true,
  }) async {
    _playSessionId++;
    _currentBook = book;
    final wasPlaying = state.isPlaying;

    await _ttsService.stop();

    final chapters = await _contentService.loadChapters(book);
    final total = chapters.isNotEmpty
        ? chapters.length
        : (book.totalPages > 0 ? book.totalPages : 1);
    final clampedTarget = targetChapterOrPage.clamp(1, total);

    final matched = chapters.firstWhere(
      (c) => c.index == clampedTarget,
      orElse: () => ChapterItemData(
        index: clampedTarget,
        title: book.format.toUpperCase() == 'PDF'
            ? 'Page $clampedTarget'
            : 'Chapter $clampedTarget',
      ),
    );

    final chunks = await _contentService.loadChunksForChapterOrPage(
      book: book,
      chapterOrPage: clampedTarget,
    );

    state = state.copyWith(
      bookId: book.id,
      currentChapterOrPage: clampedTarget,
      currentChapterTitle: matched.title,
      totalPagesOrChapters: total,
      chunks: chunks,
      currentChunkIndex: 0,
      status: TtsPlaybackStatus.stopped,
    );

    // Persist progress to database
    final progress = total > 1
        ? ((clampedTarget - 1) / (total - 1)).clamp(0.0, 1.0)
        : 0.0;

    try {
      await ref.read(booksProvider.notifier).updateReadingProgress(
        bookId: book.id,
        progress: progress,
        currentPage: clampedTarget,
        totalPages: total,
      );
    } catch (_) {}

    onChapterJumpRequested?.call(clampedTarget);

    if ((wasPlaying || autoPlay) && chunks.isNotEmpty) {
      await play();
    }
  }

  /// Skips to the next chapter or page.
  Future<void> nextChapter(LibraryBook book, {bool autoPlay = true}) async {
    if (state.currentChapterOrPage < state.totalPagesOrChapters) {
      await changeChapterOrPage(
        book: book,
        targetChapterOrPage: state.currentChapterOrPage + 1,
        autoPlay: autoPlay,
      );
    }
  }

  /// Skips to the previous chapter or page.
  Future<void> previousChapter(LibraryBook book, {bool autoPlay = true}) async {
    if (state.currentChapterOrPage > 1) {
      await changeChapterOrPage(
        book: book,
        targetChapterOrPage: state.currentChapterOrPage - 1,
        autoPlay: autoPlay,
      );
    }
  }

  /// Loads text chunks for the active chapter/page.
  /// If [autoStart] is true or currently playing, it will automatically begin speaking the first chunk.
  void loadContent({
    required String bookId,
    required int chapterOrPage,
    required List<String> chunks,
    String? chapterTitle,
    int? totalChaptersOrPages,
    bool autoStart = false,
  }) {
    _playSessionId++;
    final wasPlaying = state.isPlaying;

    state = state.copyWith(
      bookId: bookId,
      currentChapterOrPage: chapterOrPage,
      chunks: chunks,
      currentChunkIndex: 0,
      status: TtsPlaybackStatus.stopped,
      currentChapterTitle: chapterTitle ?? state.currentChapterTitle,
      totalPagesOrChapters: totalChaptersOrPages ?? state.totalPagesOrChapters,
    );

    if ((wasPlaying || autoStart) && chunks.isNotEmpty) {
      // Ensure previous audio is stopped before starting new chapter/page
      _ttsService.stop().then((_) {
        if (state.chunks.isNotEmpty) {
          play();
        }
      });
    }
  }

  /// Sets the TTS panel visibility in the Reader view.
  void setPlayerVisible(bool visible) {
    state = state.copyWith(isPlayerVisible: visible);
  }

  /// Toggles TTS panel visibility.
  void togglePlayerVisible() {
    state = state.copyWith(isPlayerVisible: !state.isPlayerVisible);
  }

  /// Begins or resumes reading the current chunk.
  Future<void> play() async {
    if (state.chunks.isEmpty) return;

    if (state.currentChunkIndex >= state.chunks.length) {
      state = state.copyWith(currentChunkIndex: 0);
    }

    final chunk = state.currentChunk;
    if (chunk != null) {
      await _ttsService.setSpeechRate(state.speedMultiplier);
      await _ttsService.setPitch(state.pitch);
      await _ttsService.speak(chunk);
    }
  }

  /// Pauses speaking.
  Future<void> pause() async {
    _playSessionId++;
    await _ttsService.pause();
  }

  /// Stops speaking and resets to the beginning of the current page.
  Future<void> stop() async {
    _playSessionId++;
    await _ttsService.stop();
    state = state.copyWith(
      status: TtsPlaybackStatus.stopped,
      currentChunkIndex: 0,
    );
  }

  /// Toggle play/pause.
  Future<void> togglePlayPause() async {
    if (state.isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  /// Skips to the next sentence/paragraph chunk.
  Future<void> nextChunk() async {
    _playSessionId++;
    if (state.currentChunkIndex + 1 < state.chunks.length) {
      final nextIdx = state.currentChunkIndex + 1;
      state = state.copyWith(currentChunkIndex: nextIdx);
      if (state.isPlaying) {
        await _ttsService.stop();
        await play();
      }
    } else if (state.autoAdvance) {
      onAutoAdvanceRequested?.call();
    }
  }

  /// Skips to the previous sentence/paragraph chunk.
  Future<void> previousChunk() async {
    _playSessionId++;
    if (state.currentChunkIndex > 0) {
      final prevIdx = state.currentChunkIndex - 1;
      state = state.copyWith(currentChunkIndex: prevIdx);
      if (state.isPlaying) {
        await _ttsService.stop();
        await play();
      }
    }
  }

  /// Jumps to a specific chunk index.
  Future<void> jumpToChunk(int index) async {
    _playSessionId++;
    if (index >= 0 && index < state.chunks.length) {
      state = state.copyWith(currentChunkIndex: index);
      if (state.isPlaying) {
        await _ttsService.stop();
        await play();
      }
    }
  }

  /// Adjusts reading speed multiplier (e.g. 0.75x, 1.0x, 1.25x, 1.5x, 2.0x).
  Future<void> setSpeed(double multiplier) async {
    state = state.copyWith(speedMultiplier: multiplier);
    await _ttsService.setSpeechRate(multiplier);
  }

  /// Toggles auto-advancing to the next page/chapter when the current page finishes.
  void toggleAutoAdvance() {
    state = state.copyWith(autoAdvance: !state.autoAdvance);
  }

  /// Called automatically by the TTS engine whenever a chunk finishes speaking.
  Future<void> _handleChunkCompleted() async {
    if (state.status != TtsPlaybackStatus.playing && state.status != TtsPlaybackStatus.stopped) {
      return;
    }

    final currentSession = ++_playSessionId;

    if (state.currentChunkIndex + 1 < state.chunks.length) {
      final nextIdx = state.currentChunkIndex + 1;
      state = state.copyWith(
        currentChunkIndex: nextIdx,
        status: TtsPlaybackStatus.playing,
      );

      // Brief inter-chunk pause (120ms) allows audio buffer to flush and settle,
      // eliminating audio crackles/pops and mimicking natural sentence cadence.
      await Future.delayed(const Duration(milliseconds: 120));

      if (currentSession == _playSessionId && state.isPlaying) {
        await play();
      }
    } else {
      // Finished all chunks on current page/chapter
      if (state.autoAdvance) {
        if (_currentBook != null && state.currentChapterOrPage < state.totalPagesOrChapters) {
          await Future.delayed(const Duration(milliseconds: 250));
          if (currentSession == _playSessionId) {
            await nextChapter(_currentBook!, autoPlay: true);
          }
        } else if (onAutoAdvanceRequested != null) {
          await Future.delayed(const Duration(milliseconds: 200));
          if (currentSession == _playSessionId) {
            onAutoAdvanceRequested?.call();
          }
        } else {
          state = state.copyWith(
            status: TtsPlaybackStatus.stopped,
            currentChunkIndex: 0,
          );
        }
      } else {
        state = state.copyWith(
          status: TtsPlaybackStatus.stopped,
          currentChunkIndex: 0,
        );
      }
    }
  }

  /// Cleans up TTS audio when exiting the reader.
  void cleanup() {
    _playSessionId++;
    _sleepCountdownTimer?.cancel();
    _currentBook = null;
    _ttsService.stop();
  }
}

final readingTtsProvider =
    NotifierProvider<ReadingTtsNotifier, ReadingTtsState>(ReadingTtsNotifier.new);
