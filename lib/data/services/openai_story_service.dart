// lib/data/services/openai_story_service.dart

import 'package:flutter/foundation.dart';
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
    try {
      final apiKey = dotenv.env['OPENAI_API_KEY'];
      if (apiKey != null && apiKey.isNotEmpty) {
        OpenAI.apiKey = apiKey;
        if (kDebugMode) print('✅ OpenAI API key yüklendi.');
      } else {
        if (kDebugMode) print('⚠️ OpenAI API key bulunamadı, AI çağrıları çalışmayacak.');
      }
    } catch (e, st) {
      // dotenv yüklenmemiş olsa da uygulama çökmesin
      if (kDebugMode) {
        print('⚠️ dotenv erişimi sırasında hata: $e\n$st');
      }
    }
  }

  @override
  Future<Story> createStory(String prompt) async {
    final currentUserId = await _authService.getCurrentUserId();

    // TODO: Gerçek GPT, DALL·E, TTS çağrıları burada yapılacak
    var newStory = Story(
      id: "",
      title: "Yapay Zeka Macerası: ${prompt.substring(0, prompt.length > 15 ? 15 : prompt.length)}...",
      text: "Bir zamanlar, $prompt ile ilgili harika bir macera yaşandı. Kahramanımız çok cesurdu ve zorlukların üstesinden geldi. Sonunda herkes mutlu oldu.", // Placeholder
      imageUrl: "https://via.placeholder.com/400x300.png?text=Mock+Image",
      audioUrl: "",
      createdAt: DateTime.now(),
      userId: currentUserId,
      isPublic: true,
      questions: [
        QuizQuestion(
          question: "Hikayenin kahramanı nasıldı?",
          options: ["Korkak", "Cesur", "Üzgün", "Yorgun"],
          correctIndex: 1,
        ),
        QuizQuestion(
          question: "Hikaye nasıl bitti?",
          options: ["Kötü", "Belirsiz", "Mutlu", "Sıkıcı"],
          correctIndex: 2,
        ),
      ],
    );

    final firestoreId = await _firestoreService.saveStory(newStory);
    return newStory.copyWith(id: firestoreId);
  }

  Future<List<Story>> getStoriesForUser(String userId) async {
    try {
      final allStories = await _firestoreService.getPublicStories();

      if (userId == LocalUserService.defaultUserId) {
        return allStories;
      }

      return allStories.where((story) => story.userId == userId).toList();
    } catch (e, st) {
      if (kDebugMode) print('Hikayeler çekilemedi: $e\n$st');
      return <Story>[]; // hata olsa bile boş liste döner, UI çökmez
    }
  }

  @override
  Future<List<Story>> getPublicStories() async {
    try {
      return await _firestoreService.getPublicStories();
    } catch (e, st) {
      if (kDebugMode) print('Public hikayeler çekilemedi: $e\n$st');
      return <Story>[];
    }
  }

  @override
  Future<void> saveStory(Story story) async {
    throw UnimplementedError('Kayıt işlemi createStory içinde yapılıyor.');
  }
}
