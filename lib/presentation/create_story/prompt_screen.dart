// lib/presentation/create_story/prompt_screen.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart'; 
import '../../data/services/openai_story_service.dart'; 
import '../../data/services/connectivity_service.dart'; 
import '../../router/app_router.dart'; 

final _storyService = OpenAIStoryService(); 
final _connectivityService = ConnectivityService();

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

    // Bağlantı Kontrolü
    final isConnected = await _connectivityService.isConnected();
    if (!isConnected) {
      if (mounted) {
        // HATA 1 DÜZELTİLDİ: Text Expanded ile sarıldı
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 30, height: 30, child: Lottie.asset('assets/lottie/error_sad.json', repeat: false)), 
                const SizedBox(width: 10),
                const Expanded( 
                  child: Text('İnternet bağlantısı yok! Lütfen kontrol edin.'),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    
    final promptText = _promptController.text.trim();
    
    setState(() {
      _isProcessing = true; 
    });

    try {
      final newStory = await _storyService.createStory(promptText);

      if (mounted && newStory.id.isNotEmpty) {
        // HATA 2 DÜZELTİLDİ: Text Expanded ile sarıldı (Başarı)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 30, height: 30, child: Lottie.asset('assets/lottie/success_star.json', repeat: false)), 
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Hikaye başarıyla oluşturuldu!'),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        
        context.go(
          AppRoutes.storyDetail.replaceFirst(':id', newStory.id),
        );
      }

    } catch (e) {
      if (mounted) {
        // HATA 3 DÜZELTİLDİ: Text Expanded ile sarıldı (API Hatası)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                SizedBox(width: 30, height: 30, child: Lottie.asset('assets/lottie/error_sad.json', repeat: false)), 
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Hata oluştu: Hikaye oluşturulamadı. (API Anahtarını/Konsolu kontrol edin)'),
                ),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text("Hayalini Anlat"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "Hangi konuda bir hikaye hayal ediyorsun?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _promptController,
              maxLines: 4, 
              decoration: InputDecoration(
                hintText: "Örn: Uçan bir dinozor ve konuşan bir bulut...",
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
            const SizedBox(height: 32),
            
            // Hikaye Oluşturma Butonu
            ElevatedButton(
              onPressed: (_isButtonEnabled && !_isProcessing) ? _createStory : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: (_isButtonEnabled && !_isProcessing) ? Colors.blueAccent : Colors.grey,
              ),
              child: _isProcessing
                  ? SizedBox( // Lottie animasyonu
                      width: 100, 
                      height: 50, 
                      child: Lottie.asset(
                        'assets/lottie/loading_rocket.json', 
                        repeat: true,
                      ),
                    )
                  : const Text(
                      "AI Yapsın! 🚀",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
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