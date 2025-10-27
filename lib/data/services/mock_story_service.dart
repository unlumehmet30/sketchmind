// lib/data/services/mock_story_service.dart

import 'dart:math';

import '../dummy/stories.dart'; // Story sınıfının yolu
import '../i_story_service.dart'; // Yeni oluşturduğumuz Arayüzün yolu

// Gerçek AI/Backend servisini taklit eden sınıf.
class MockStoryService implements IStoryService {
  
  // AI'ın hikaye oluşturma süresini simüle etmek için gecikme
  static const Duration _mockDelay = Duration(seconds: 3);

  @override
  Future<Story> createStory(String prompt) async {
    // 3 saniye bekle ki yükleme ekranını görelim (Hafta 7'de Lottie eklenecek)
    await Future.delayed(_mockDelay); 
    
    // Prompt'u kullanarak sahte bir hikaye oluştur
    return Story(
      id: 'mock_${Random().nextInt(1000)}',
      title: 'Yapay Zeka Macerası: ${prompt.substring(0, min(10, prompt.length))}...',
      text: 'Mock hikaye metni: Hayal ettiğin "$prompt" fikriyle başlayan harika bir macera yaşandı. Bu, Hafta 3 testiniz için yapay zeka tarafından üretilmiş geçici metindir. Akış başarılı!',
      imageUrl: 'assets/images/forest.png', // Farklı bir Mock görsel
      audioUrl: '', // TTS henüz başlamadı
      isPublic: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> saveStory(Story story) async {
    // Kaydetme işlemini simüle et
    await Future.delayed(const Duration(milliseconds: 500));
    print('Mock: Hikaye (ID: ${story.id}) başarıyla kaydedildi.');
    // Hafta 4'te buraya Firestore kaydı gelecek.
  }

  @override
  Future<List<Story>> getPublicStories() async {
    // Mevcut dummyStories'i döndürerek Hafta 5'e hazırlık yap
    return dummyStories.where((s) => s.isPublic).toList();
  }
}