// lib/presentation/story_detail/story_detail_screen.dart

import 'package:flutter/material.dart';
import '../../data/dummy/stories.dart';
import '../../data/services/tts_services.dart'; // TTS Servisi (Hafta 3)

final _ttsService = TTSService(); // TTS servisi Hafta 3'ten geliyor

class StoryDetailScreen extends StatelessWidget {
  final Story story;

  const StoryDetailScreen({super.key, required this.story});

  void _startSpeaking() {
    _ttsService.speak(story.text);
  }

  void _stopSpeaking() {
    _ttsService.stop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(story.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up),
            onPressed: _startSpeaking, 
          ),
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
            // ARTIK Image.network KULLANILIYOR
            Image.network(
              story.imageUrl,
              width: double.infinity,
              height: 200,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Container(
                  width: double.infinity,
                  height: 200,
                  color: Colors.grey[200],
                  child: const Center(child: CircularProgressIndicator()),
                );
              },
              errorBuilder: (context, error, stackTrace) => Container(
                width: double.infinity,
                height: 200,
                color: Colors.red[100],
                child: const Center(child: Icon(Icons.error, color: Colors.red)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              story.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              story.text,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}