// lib/presentation/create_story/prompt_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../data/services/openai_story_service.dart'; // Gerçek Servis
import '../../router/app_router.dart'; 

final _storyService = OpenAIStoryService(); 

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  final TextEditingController _promptController = TextEditingController();
  bool _isButtonEnabled = false;
  bool _isProcessing = false; 

  @override
  void initState() {
    super.initState();
    _promptController.addListener(_updateButtonState);
  }

  @override
  void dispose() {
    _promptController.removeListener(_updateButtonState);
    _promptController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _promptController.text.trim().length >= 5;
    });
  }

  Future<void> _createStory() async {
    if (!_isButtonEnabled || _isProcessing) return;

    final promptText = _promptController.text.trim();
    
    setState(() {
      _isProcessing = true; 
    });

    try {
      // Hikaye üretiliyor, görsel alınıyor ve Firestore'a kaydediliyor!
      final newStory = await _storyService.createStory(promptText);

      // Başarılı: Detay Ekranına yönlendir (Firestore ID kullanılıyor)
      if (mounted && newStory.id.isNotEmpty) {
         context.go(
          AppRoutes.storyDetail.replaceFirst(':id', newStory.id),
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: Hikaye oluşturulamadı. ($e)')),
        );
      }
      print("Hikaye oluşturulurken hata: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ... (UI Kodu aynı kalır, _createStory metodu artık gerçek servisi çağırır)
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hayalini Anlat"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Hangi konuda bir hikaye hayal ediyorsun?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              maxLines: 4, 
              decoration: InputDecoration(
                hintText: "Örn: Uçan bir dinozor ve konuşan bir bulut...",
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: (_isButtonEnabled && !_isProcessing) ? _createStory : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: (_isButtonEnabled && !_isProcessing) ? Colors.blueAccent : Colors.grey,
              ),
              child: _isProcessing
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3,))
                  : const Text("AI Yapsın! 🚀", style: TextStyle(fontSize: 18, color: Colors.white)),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                _isProcessing 
                    ? "Yapay zeka hayalini dinliyor ve görselini çiziyor..." 
                    : "En az 5 harfli bir hayal kurmalısın.",
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          ],
        ),
      ),
    );
  }
}