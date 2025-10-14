import 'package:flutter/material.dart';

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  // Kullanıcının girdisini tutacak controller
  final TextEditingController _promptController = TextEditingController();
  // Butonun basılabilirliğini kontrol edecek durum
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    // Metin değiştikçe buton durumunu kontrol et
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
      // Prompt en az 5 karakter içeriyorsa butonu aktif et
      _isButtonEnabled = _promptController.text.trim().length >= 5;
    });
  }

  void _createStory() {
    if (!_isButtonEnabled) return;

    final promptText = _promptController.text.trim();
    
    // Şimdilik sadece konsola yazdırıyoruz.
    // HAFTA 3'te: Bu noktadan AI servisini (Mock) çağıracağız
    // ve sonuç (hikaye) oluşturulurken Lottie animasyonlu yükleme ekranına geçeceğiz.
    print("Hikaye oluşturuluyor, Prompt: $promptText");

    // TODO: Hafta 3'te navigasyonu burada bir Yükleme/Sonuç ekranına çevireceğiz.
    // context.go(AppRoutes.loading, extra: promptText);
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
            
            // Çocuk dostu, çok satırlı metin giriş alanı
            TextField(
              controller: _promptController,
              maxLines: 4, // Daha fazla yazı yazma alanı sağla
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
              onPressed: _isButtonEnabled ? _createStory : null,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: _isButtonEnabled ? Colors.blueAccent : Colors.grey,
              ),
              child: const Text(
                "AI Yapsın! 🚀",
                style: TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            
            const SizedBox(height: 20),
            // Çocuklara ipucu
            Center(
              child: Text(
                "En az 5 harfli bir hayal kurmalısın.",
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
          ],
        ),
      ),
    );
  }
}