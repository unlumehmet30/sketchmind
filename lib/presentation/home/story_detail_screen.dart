// lib/presentation/story_detail/story_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../data/dummy/stories.dart';
import '../../data/services/audio_service.dart'; // YENİ: Audio Servisi

final _audioService = AudioService(); // YENİ: Audio servisi başlatıldı

class StoryDetailScreen extends StatefulWidget {
  final Story story;

  const StoryDetailScreen({super.key, required this.story});
  
  // Widget'a dispose mantığı için State'e çeviriyoruz
  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  String? _localAudioPath;
  bool _isDownloading = true;
  
  @override
  void initState() {
    super.initState();
    // Audio URL'si Mock olduğu için, bu kısım Mock URL'yi indirmeye çalışacaktır.
    _cacheAudio(); 
  }

  @override
  void dispose() {
    // Ekran kapanınca oynatmayı durdur
    _audioService.stopAudio();
    // _audioService.dispose(); // Eğer AudioService tekil değilse çağrılır
    super.dispose();
  }

  // Audio dosyasını önbelleğe alır
  Future<void> _cacheAudio() async {
    if (widget.story.audioUrl.isEmpty) {
      setState(() => _isDownloading = false);
      return;
    }
    try {
      // Mock URL'den dosya indirmeyi simüle et
      final path = await _audioService.downloadAndCacheAudio(
        widget.story.audioUrl,
        widget.story.id,
      );
      setState(() {
        _localAudioPath = path;
        _isDownloading = false;
      });
    } catch (e) {
      print("Audio önbellekleme hatası: $e");
      setState(() => _isDownloading = false);
    }
  }

  void _startSpeaking() {
    if (_localAudioPath != null) {
      _audioService.playAudio(_localAudioPath!);
    } else {
      // Offline değilse bile hata mesajı göster
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ses dosyası henüz hazır değil.')),
      );
    }
  }

  void _stopSpeaking() {
    _audioService.stopAudio();
  }

  @override
  Widget build(BuildContext context) {
    // Oynatma butonu durumunu kontrol eder
    final isPlayable = !_isDownloading && _localAudioPath != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.story.title),
        actions: [
          // Dinleme Butonu (İndirme durumuna bağlı)
          IconButton(
            icon: _isDownloading
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.volume_up),
            onPressed: isPlayable ? _startSpeaking : null,
          ),
          // Durdurma Butonu
          IconButton(
            icon: const Icon(Icons.stop),
            onPressed: _stopSpeaking,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Görsel Önbellekleme
            CachedNetworkImage(
              imageUrl: widget.story.imageUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(width: double.infinity, height: 200, color: Colors.grey[200]),
              errorWidget: (context, url, error) => Container(width: double.infinity, height: 200, color: Colors.red[100], child: const Center(child: Icon(Icons.signal_wifi_off))),
            ),
            const SizedBox(height: 16),
            Text(
              widget.story.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              widget.story.text,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}