// lib/data/services/tts_service.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TTSProgress {
  const TTSProgress({
    required this.start,
    required this.end,
    required this.word,
  });

  final int start;
  final int end;
  final String word;
}

class TTSService {
  final FlutterTts flutterTts = FlutterTts();
  final ValueNotifier<TTSProgress?> progressNotifier =
      ValueNotifier<TTSProgress?>(null);
  final ValueNotifier<bool> speakingNotifier = ValueNotifier<bool>(false);

  TTSService() {
    _initializeTts();
  }

  void _initializeTts() async {
    await flutterTts.setLanguage('tr-TR');
    await flutterTts.setSpeechRate(0.5);
    await flutterTts.setVolume(1.0);
    await flutterTts.setPitch(1.0);

    flutterTts.setStartHandler(() {
      speakingNotifier.value = true;
    });

    flutterTts.setCompletionHandler(() {
      speakingNotifier.value = false;
      progressNotifier.value = null;
    });

    flutterTts.setCancelHandler(() {
      speakingNotifier.value = false;
      progressNotifier.value = null;
    });

    flutterTts.setProgressHandler((text, start, end, word) {
      progressNotifier.value = TTSProgress(start: start, end: end, word: word);
    });
  }

  Future<void> speak(String text) async {
    progressNotifier.value = null;
    await flutterTts.stop();
    await flutterTts.speak(text);
  }

  Future<void> applyVoiceSettings({
    required double rate,
    required double pitch,
  }) async {
    await flutterTts.setSpeechRate(rate.clamp(0.3, 0.75));
    await flutterTts.setPitch(pitch.clamp(0.75, 1.3));
  }

  Future<void> stop() async {
    await flutterTts.stop();
    speakingNotifier.value = false;
    progressNotifier.value = null;
  }

  void dispose() {
    speakingNotifier.dispose();
    progressNotifier.dispose();
    flutterTts.stop();
  }
}
