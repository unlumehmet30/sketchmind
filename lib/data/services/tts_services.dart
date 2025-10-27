// lib/data/services/tts_service.dart

import 'package:flutter_tts/flutter_tts.dart';

class TTSService {
  final FlutterTts flutterTts = FlutterTts();

  TTSService() {
    _initializeTts();
  }

  void _initializeTts() async {
    // Platforma göre varsayılan ayarları yap
    await flutterTts.setLanguage("tr-TR"); // Türkçe dilini ayarla
    await flutterTts.setSpeechRate(0.5); // Okuma hızını ayarla (çocuklar için biraz yavaş)
    await flutterTts.setVolume(1.0); // Ses seviyesi
    await flutterTts.setPitch(1.0); // Ses perdesi
    
    // (Opsiyonel) Seslerin yüklenip yüklenmediğini kontrol etme
    // flutterTts.getVoices.then((voices) => print(voices));
  }

  // Metni sesli okumayı başlatır
  Future<void> speak(String text) async {
    await flutterTts.stop(); // Önceki okumayı durdur
    await flutterTts.speak(text); // Yeni okumayı başlat
  }

  // Okumayı durdurur
  Future<void> stop() async {
    await flutterTts.stop();
  }
}