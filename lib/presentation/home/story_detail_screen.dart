// lib/presentation/story_detail/story_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart'; 
import '../../data/dummy/stories.dart';
import '../../data/services/tts_services.dart'; // YENİ: TTS Servisi
import '../../data/services/firestore_story_service.dart';
import '../../data/services/local_user_service.dart';
import '../../presentation/quiz/quiz_dialog.dart';
import 'package:go_router/go_router.dart';

final _ttsService = TTSService();
final _firestoreService = FirestoreStoryService();
final _localUserService = LocalUserService();

class StoryDetailScreen extends StatefulWidget {
  final Story story;

  const StoryDetailScreen({super.key, required this.story});
  
  // Widget'a dispose mantığı için State'e çeviriyoruz
  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  bool _isSpeaking = false;
  bool _canDelete = false;

  @override
  void initState() {
    super.initState();
    _checkDeletePermission();
  }

  @override
  void dispose() {
    _ttsService.stop();
    super.dispose();
  }

  Future<void> _checkDeletePermission() async {
    final currentUserId = await _localUserService.getSelectedUserId();
    final isParent = await _localUserService.getIsParentMode();
    
    if (mounted) {
      setState(() {
        // Silme yetkisi: Hikaye sahibi veya Ebeveyn Modu açıksa
        _canDelete = (currentUserId == widget.story.userId) || isParent;
      });
    }
  }

  void _toggleSpeaking() async {
    if (_isSpeaking) {
      await _ttsService.stop();
      setState(() => _isSpeaking = false);
    } else {
      setState(() => _isSpeaking = true);
      await _ttsService.speak(widget.story.text);
      setState(() => _isSpeaking = false); // Okuma bitince (basitçe)
    }
  }

  void _showQuiz() {
    if (widget.story.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu hikaye için test bulunamadı.')));
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => QuizDialog(questions: widget.story.questions),
    );
  }

  void _deleteStory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hikayeyi Sil'),
        content: const Text('Bu hikayeyi silmek istediğine emin misin?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _firestoreService.deleteStory(widget.story.id);
      if (mounted) {
        context.pop(); // Detaydan çık
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Hikaye silindi.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Oynatma butonu durumunu kontrol eder - ARTIK GEREK YOK
    
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.story.title),
        actions: [
          // Dinleme Butonu
          IconButton(
            icon: Icon(_isSpeaking ? Icons.stop_circle : Icons.volume_up),
            color: _isSpeaking ? Colors.red : null,
            onPressed: _toggleSpeaking,
          ),
          // Silme Butonu
          if (_canDelete)
            IconButton(
              icon: const Icon(Icons.delete),
              color: Colors.red,
              onPressed: _deleteStory,
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
            
            // Quiz Butonu
            if (widget.story.questions.isNotEmpty)
              Center(
                child: ElevatedButton.icon(
                  onPressed: _showQuiz,
                  icon: const Icon(Icons.quiz),
                  label: const Text("Eğlenceli Testi Çöz!"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}