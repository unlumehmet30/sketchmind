// lib/data/services/openai_story_service.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_openai/dart_openai.dart'; 
import '../i_story_service.dart';
import '../dummy/stories.dart';
import 'firestore_story_service.dart';
import 'auth_service.dart'; 
import 'local_user_service.dart'; 
import 'storage_service.dart';

final _firestoreService = FirestoreStoryService(); 
final _authService = AuthService(); 
final _storageService = StorageService();

class OpenAIStoryService implements IStoryService {
  OpenAIStoryService() {
    final apiKey = dotenv.env['OPENAI_API_KEY'];
    if (apiKey != null && apiKey.isNotEmpty) {
      OpenAI.apiKey = apiKey;
    }
  }

  @override
  Future<Story> createStory(String prompt) async {
    final currentUserId = await _authService.getCurrentUserId(); 

    // TODO: Gerçek GPT, DALL·E, TTS çağrıları burada yapılacak
    var newStory = Story(
      id: "", 
      title: "Yapay Zeka Macerası: ${prompt.substring(0, prompt.length > 15 ? 15 : prompt.length)}...",
      text: "Simüle Edilmiş Hikaye Metni", // Placeholder
      imageUrl: "https://via.placeholder.com/400x300.png?text=Mock+Image", 
      audioUrl: "", 
      createdAt: DateTime.now(),
      userId: currentUserId, 
      isPublic: true,
    );

    final firestoreId = await _firestoreService.saveStory(newStory); 
    return newStory.copyWith(id: firestoreId); 
  }

  // Kullanıcı ID'sine göre filtrelenmiş hikayeleri çeker
  Future<List<Story>> getStoriesForUser(String userId) async {
    // Firestore'dan tüm public hikayeleri çek
    final allStories = await _firestoreService.getPublicStories();

    // Misafir kullanıcı ise tüm hikayeleri göster
    if (userId == LocalUserService.defaultUserId) {
      return allStories;
    }
    
    // Giriş yapmış kullanıcı ise sadece kendi hikayelerini göster
    final filteredStories = allStories
        .where((story) => story.userId == userId)
        .toList();

    return filteredStories;
  }
  
  @override
  Future<List<Story>> getPublicStories() async {
    return await _firestoreService.getPublicStories();
  }
  
  @override
  Future<void> saveStory(Story story) async {
    throw UnimplementedError('Kayıt işlemi createStory içinde yapılıyor.');
  }
}