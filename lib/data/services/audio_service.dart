// lib/data/services/audio_service.dart

import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';

class AudioService {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Oynatma durumunu takip eder (örneğin: isPlaying)
  PlayerState get playerState => _audioPlayer.state;

  AudioService() {
    // Uygulama kapatıldığında ses çalmayı durdurmak için
    _audioPlayer.onPlayerComplete.listen((event) {
      print('Oynatma tamamlandı.');
    });
  }

  // URL'den ses dosyasını indirir ve yerel yolunu döndürür.
  Future<String> downloadAndCacheAudio(String audioUrl, String storyId) async {
    // Uygulamanın geçici depolama dizinini al
    final directory = await getTemporaryDirectory();
    final localPath = '${directory.path}/audio_$storyId.mp3';
    final file = File(localPath);

    // Dosya zaten yerel olarak inmiş mi kontrol et (Offline Mod)
    if (await file.exists()) {
      print('Audio zaten önbellekte: $localPath');
      return localPath;
    }

    try {
      print('Audio indiriliyor: $audioUrl');
      final response = await http.get(Uri.parse(audioUrl));
      
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
        print('Audio başarıyla indirildi: $localPath');
        return localPath;
      } else {
        throw Exception('Ses dosyası indirilemedi, Durum Kodu: ${response.statusCode}');
      }
    } catch (e) {
      print('İndirme sırasında hata: $e');
      throw Exception('Ses dosyası önbelleğe alınamadı.');
    }
  }

  // Ses çalmayı başlatır (URL veya yerel yol ile)
  Future<void> playAudio(String audioPath) async {
    await _audioPlayer.stop(); // Önceki çalmayı durdur
    
    // Ses dosyasını yerel olarak oynatmak için Source.file kullanılır
    await _audioPlayer.play(DeviceFileSource(audioPath));
  }

  // Ses çalmayı durdurur
  Future<void> stopAudio() async {
    await _audioPlayer.stop();
  }

  // Kaynakları temizler (dispose)
  void dispose() {
    _audioPlayer.dispose();
  }
}