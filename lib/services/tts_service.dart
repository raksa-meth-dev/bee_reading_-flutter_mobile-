import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum TtsPlaybackStatus { stopped, playing, paused }

final ttsServiceProvider = Provider<TtsService>((ref) {
  final service = TtsService();
  ref.onDispose(() => service.dispose());
  return service;
});

class TtsService {
  TtsService() {
    _initTts();
  }

  final FlutterTts _flutterTts = FlutterTts();
  TtsPlaybackStatus _status = TtsPlaybackStatus.stopped;
  TtsPlaybackStatus get status => _status;

  void Function(TtsPlaybackStatus status)? onStatusChanged;
  void Function()? onCompleted;
  void Function(String word, int start, int end)? onProgress;
  void Function(String error)? onError;

  double? _lastSpeechRate;
  double? _lastPitch;
  double? _lastVolume;
  String? _lastLanguage;

  Future<void> _initTts() async {
    try {
      if (!kIsWeb && Platform.isIOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
            IosTextToSpeechAudioCategoryOptions.allowBluetooth,
            IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          ],
          IosTextToSpeechAudioMode.spokenAudio,
        );
      } else if (!kIsWeb && Platform.isAndroid) {
        await _flutterTts.setQueueMode(0); // QUEUE_FLUSH
      }

      // Avoid awaitSpeakCompletion(true) because setCompletionHandler handles chunk
      // progression asynchronously. Combining both creates race conditions & clipping.
      await _flutterTts.awaitSpeakCompletion(false);

      _flutterTts.setStartHandler(() {
        _status = TtsPlaybackStatus.playing;
        onStatusChanged?.call(_status);
      });

      _flutterTts.setCompletionHandler(() {
        _status = TtsPlaybackStatus.stopped;
        onStatusChanged?.call(_status);
        onCompleted?.call();
      });

      _flutterTts.setPauseHandler(() {
        _status = TtsPlaybackStatus.paused;
        onStatusChanged?.call(_status);
      });

      _flutterTts.setContinueHandler(() {
        _status = TtsPlaybackStatus.playing;
        onStatusChanged?.call(_status);
      });

      _flutterTts.setCancelHandler(() {
        _status = TtsPlaybackStatus.stopped;
        onStatusChanged?.call(_status);
      });

      _flutterTts.setErrorHandler((dynamic message) {
        _status = TtsPlaybackStatus.stopped;
        onStatusChanged?.call(_status);
        onError?.call(message.toString());
      });

      _flutterTts.setProgressHandler((String text, int start, int end, String word) {
        onProgress?.call(word, start, end);
      });
    } catch (e) {
      debugPrint('Error initializing TTS: $e');
    }
  }

  Future<void> setLanguage(String languageCode) async {
    if (_lastLanguage == languageCode) return;
    try {
      await _flutterTts.setLanguage(languageCode);
      _lastLanguage = languageCode;
    } catch (e) {
      debugPrint('Error setting language: $e');
    }
  }

  /// Sets speech rate where 1.0 represents standard conversational pace.
  /// FlutterTts internally maps rates depending on platform.
  /// Caches the value to avoid redundant platform channel traffic and audio hardware reset.
  Future<void> setSpeechRate(double speedMultiplier) async {
    final double normalized = (0.5 * speedMultiplier).clamp(0.1, 1.0);
    if (_lastSpeechRate == normalized) return;
    try {
      await _flutterTts.setSpeechRate(normalized);
      _lastSpeechRate = normalized;
    } catch (e) {
      debugPrint('Error setting speech rate: $e');
    }
  }

  Future<void> setPitch(double pitch) async {
    final double clamped = pitch.clamp(0.5, 2.0);
    if (_lastPitch == clamped) return;
    try {
      await _flutterTts.setPitch(clamped);
      _lastPitch = clamped;
    } catch (e) {
      debugPrint('Error setting pitch: $e');
    }
  }

  Future<void> setVolume(double volume) async {
    final double clamped = volume.clamp(0.0, 1.0);
    if (_lastVolume == clamped) return;
    try {
      await _flutterTts.setVolume(clamped);
      _lastVolume = clamped;
    } catch (e) {
      debugPrint('Error setting volume: $e');
    }
  }

  /// Sanitizes text to remove artifacts that cause TTS voice cracking,
  /// clicks, and robotic glitch sounds.
  static String sanitizeForSpeech(String text) {
    if (text.isEmpty) return text;

    var s = text;

    // 1. Remove soft hyphens, zero-width spaces, and control characters
    s = s.replaceAll(RegExp(r'[\u00AD\u200B\uFEFF\u200E\u200F]'), '');

    // 2. Expand common typographic ligatures that trip up synthesizers
    s = s
        .replaceAll('ﬁ', 'fi')
        .replaceAll('ﬂ', 'fl')
        .replaceAll('ﬀ', 'ff')
        .replaceAll('ﬃ', 'ffi')
        .replaceAll('ﬄ', 'ffl')
        .replaceAll('æ', 'ae')
        .replaceAll('Æ', 'Ae')
        .replaceAll('œ', 'oe')
        .replaceAll('Œ', 'Oe');

    // 3. Normalize em-dashes and en-dashes to a natural speech pause (comma)
    // Avoids synthetic "dash dash" recitation and audio pop
    s = s.replaceAll(RegExp(r'[\u2014\u2013]|--+'), ', ');

    // 4. Normalize ellipses and repeated periods to a single pause
    s = s.replaceAll(RegExp(r'\.{2,}|\u2026'), '. ');

    // 5. Clean up bracketed footnote citations like [1], [12], [note]
    s = s.replaceAll(RegExp(r'\[\d+\]|\(\d+\)'), '');

    // 6. Remove stray bullet/symbol characters at beginning or end
    s = s.replaceAll(RegExp(r'^[•▪►◆*#~-]+\s*|\s*[•▪►◆*#~-]+$'), '');

    // 7. Collapse multiple spaces and trim
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    return s;
  }

  Future<void> speak(String text) async {
    final cleanText = sanitizeForSpeech(text);
    if (cleanText.isEmpty) {
      onCompleted?.call();
      return;
    }
    try {
      _status = TtsPlaybackStatus.playing;
      onStatusChanged?.call(_status);
      await _flutterTts.speak(cleanText, focus: true);
    } catch (e) {
      debugPrint('Error in TTS speak: $e');
      _status = TtsPlaybackStatus.stopped;
      onStatusChanged?.call(_status);
      onError?.call(e.toString());
    }
  }

  Future<void> pause() async {
    try {
      await _flutterTts.pause();
      _status = TtsPlaybackStatus.paused;
      onStatusChanged?.call(_status);
    } catch (e) {
      debugPrint('Error pausing TTS: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _flutterTts.stop();
      _status = TtsPlaybackStatus.stopped;
      onStatusChanged?.call(_status);
    } catch (e) {
      debugPrint('Error stopping TTS: $e');
    }
  }

  void dispose() {
    _flutterTts.stop();
  }
}
