import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bee_reading/services/tts_service.dart';

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
  });

  bool get isPlaying => status == TtsPlaybackStatus.playing;
  bool get isPaused => status == TtsPlaybackStatus.paused;
  bool get isStopped => status == TtsPlaybackStatus.stopped;
  bool get hasContent => chunks.isNotEmpty;

  String? get currentChunk =>
      (currentChunkIndex >= 0 && currentChunkIndex < chunks.length)
          ? chunks[currentChunkIndex]
          : null;

  int get totalChunks => chunks.length;

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
    );
  }
}

class ReadingTtsNotifier extends Notifier<ReadingTtsState> {
  late final TtsService _ttsService;

  /// Counter used to cancel pending inter-chunk pauses if user pauses, skips, or stops.
  int _playSessionId = 0;

  /// External callback to request next page/chapter when current page reaches the end
  VoidCallback? onAutoAdvanceRequested;

  @override
  ReadingTtsState build() {
    _ttsService = ref.watch(ttsServiceProvider);

    _ttsService.onStatusChanged = (status) {
      if (state.status != status) {
        state = state.copyWith(status: status);
      }
    };

    _ttsService.onCompleted = _handleChunkCompleted;

    return const ReadingTtsState();
  }

  /// Loads text chunks for the active chapter/page.
  /// If [autoStart] is true or currently playing, it will automatically begin speaking the first chunk.
  void loadContent({
    required String bookId,
    required int chapterOrPage,
    required List<String> chunks,
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
      if (state.autoAdvance && onAutoAdvanceRequested != null) {
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
    }
  }

  /// Cleans up TTS audio when exiting the reader.
  void cleanup() {
    _playSessionId++;
    _ttsService.stop();
  }
}

final readingTtsProvider =
    NotifierProvider<ReadingTtsNotifier, ReadingTtsState>(ReadingTtsNotifier.new);
