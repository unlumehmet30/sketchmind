// lib/data/services/openai_story_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http; // HTTP istekleri için
// dart_openai ve flutter_dotenv artık kullanılmıyor, çünkü API anahtarı Flutter'da değil.

import '../i_story_service.dart';
import '../dummy/stories.dart';
import 'firestore_story_service.dart'; 
import 'auth_service.dart';
import 'storage_service.dart';

final _firestoreService = FirestoreStoryService();
final _authService = AuthService();
final _storageService = StorageService();

// ÖNEMLİ: Bu URL, sizin Firebase Cloud Function'ınızın HTTPS uç noktası olmalıdır.
// Örneğin: "https://us-central1-sketchmind-project.cloudfunctions.net/generateStory"
const String _cloudFunctionUrl = "[FIREBASE_CLOUD_FUNCTION_URL_BURAYA_GELECEK]"; 


class OpenAIStoryService implements IStoryService {
  OpenAIStoryService() {
    // API Anahtarını doğrudan yükleyen constructor kodu kaldırılmıştır.
  }

  @override
  Future<Story> createStory(String prompt) async {
    final currentUserId = await _authService.getCurrentUserId(); 

    // 1. Cloud Function'a Tek HTTPS İsteği Gönderme
    final storyData = await _callCloudFunction(prompt);

    // 2. Story nesnesini gelen verilerle oluşturma
    var newStory = Story(
      id: "", 
      title: "Yapay Zeka Macerası: ${prompt.substring(0, prompt.length > 15 ? 15 : prompt.length)}...",
      text: storyData['storyText']!,
      imageUrl: storyData['imageUrl']!, 
      audioUrl: storyData['audioUrl']!,
      createdAt: DateTime.now(),
      userId: currentUserId,
      isPublic: true,
    );

    // 3. Firestore'a Kayıt
    final firestoreId = await _firestoreService.saveStory(newStory);
    
    return newStory.copyWith(id: firestoreId); 
  }

  // Tüm AI işlemlerini (GPT, DALL·E, TTS Mock) tek bir Backend çağrısıyla halleder.
  Future<Map<String, String>> _callCloudFunction(String prompt) async {
    if (_cloudFunctionUrl.contains("[FIREBASE_CLOUD_FUNCTION_URL_BURAYA_GELECEK]")) {
        throw Exception("Cloud Function URL'si ayarlanmadı. Lütfen URL'yi doğru girin.");
    }
    
    final response = await http.post(
      Uri.parse(_cloudFunctionUrl),
      headers: {'Content-Type': 'application/json'},
      // Prompt verisini Cloud Function'a gönder
      body: jsonEncode({'prompt': prompt}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Cloud Function'ın doğru formatta veri döndürdüğünden emin olun
      if (data['storyText'] == null || data['imageUrl'] == null || data['audioUrl'] == null) {
          throw Exception("Backend'den eksik veri geldi (StoryText, ImageUrl, AudioUrl)");
      }

      return {
        'storyText': data['storyText'] as String,
        'imageUrl': data['imageUrl'] as String,
        'audioUrl': data['audioUrl'] as String,
      };

    } else {
      throw Exception('Backend (Cloud Function) çağrısı başarısız oldu. Durum Kodu: ${response.statusCode}. Yanıt: ${response.body}');
    }
  }

  // Diğer tüm eski _generate... metotları (GPT/DALL·E) bu yapıya devredildiği için kaldırılmıştır.
  // Bu metodun yerine _callCloudFunction geçmiştir.

  @override
  Future<void> saveStory(Story story) async {
    throw UnimplementedError('Kayıt createStory içinde yapılıyor.');
  }

  @override
  Future<List<Story>> getPublicStories() async {
    return _firestoreService.getPublicStories();
  }
}