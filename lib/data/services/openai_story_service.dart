// lib/data/services/openai_story_service.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:dart_openai/dart_openai.dart'; // Yeni paket
import '../i_story_service.dart';
import '../dummy/stories.dart';
import 'firestore_story_service.dart';

final _firestoreService = FirestoreStoryService();

class OpenAIStoryService implements IStoryService {
  OpenAIStoryService() {
    // API anahtarı ayarı, artık constructor'da yapılıyor.
    OpenAI.apiKey = dotenv.env['OPENAI_API_KEY']!;
  }

  @override
  Future<Story> createStory(String prompt) async {
    final storyText = await _generateStoryText(prompt);
    final imageUrl = await _generateStoryImage(storyText);

    var newStory = Story(
      id: "",
      title:
          "Yapay Zeka Macerası: ${prompt.substring(0, prompt.length > 15 ? 15 : prompt.length)}...",
      text: storyText,
      imageUrl: imageUrl,
      createdAt: DateTime.now(),
    );

    final firestoreId = await _firestoreService.saveStory(newStory);

    return newStory.copyWith(id: firestoreId);
  }

  Future<String> _generateStoryText(String prompt) async {
    const systemPrompt =
        "Sen 3-10 yaş arası çocuklar için kısa, pozitif ve eğlenceli hikayeler yazan neşeli bir hikaye anlatıcısısın.";

    final response = await OpenAI.instance.chat.create(
      model: "gpt-3.5-turbo",
      messages: [
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.system,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(systemPrompt),
          ],
        ),
        OpenAIChatCompletionChoiceMessageModel(
          role: OpenAIChatMessageRole.user,
          content: [
            OpenAIChatCompletionChoiceMessageContentItemModel.text(
              "Şu konu hakkında 5-7 cümlelik bir hikaye yaz: $prompt",
            ),
          ],
        ),
      ],
    );

    final contentItems = response.choices?.first?.message?.content;
    final storyText = contentItems
        ?.map((c) => c.text)
        .whereType<String>()
        .join(' ')
        .trim();
    return (storyText != null && storyText.isNotEmpty)
        ? storyText
        : "Hikaye oluşturulamadı.";
  }

  Future<String> _generateStoryImage(String storyText) async {
    final imagePrompt =
        "Çocuk çizimi stilinde, pastel renklerde, pozitif ve sevimli bir atmosferde '${storyText.substring(0, storyText.length > 100 ? 100 : storyText.length)}' hikayesine uygun tek bir sahne çizimi.";

    // DÜZELTME: Model ve boyut parametreleri güncelleniyor
    final response = await OpenAI.instance.image.create(
      // DALL-E 3 modelini kullanıyoruz.
      model: "dall-e-3", 
      prompt: imagePrompt,
      n: 1,
      // Boyutu string olarak (veya paketin kendi enum'unu kontrol edin, genellikle 'v' ile başlar)
      size: OpenAIImageSize.size1024,// Eğer hata devam ederse, bunu '1024x1024' olarak deneyin.
      responseFormat: OpenAIImageResponseFormat.url,
    );

    return response.data.first.url!;
  }

  @override
  Future<void> saveStory(Story story) async {
    throw UnimplementedError('Kayıt createStory içinde yapılıyor.');
  }

  @override
  Future<List<Story>> getPublicStories() async {
    return _firestoreService.getPublicStories();
  }
}