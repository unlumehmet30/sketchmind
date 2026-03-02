import '../dummy/stories.dart';
import 'connectivity_service.dart';
import 'firestore_story_service.dart';
import 'story_ai_orchestrator.dart';
import 'story_generation_models.dart';
import 'story_moderation_service.dart';
import 'story_prompt_builder.dart';

class StoryGenerationPipeline {
  StoryGenerationPipeline({
    FirestoreStoryService? firestore,
    StoryPromptBuilder? promptBuilder,
    StoryAIOrchestrator? orchestrator,
    StoryModerationService? moderation,
    ConnectivityService? connectivity,
  })  : _firestore = firestore ?? FirestoreStoryService(),
        _promptBuilder = promptBuilder ?? StoryPromptBuilder(),
        _orchestrator = orchestrator ?? StoryAIOrchestrator(),
        _moderation = moderation ?? StoryModerationService(),
        _connectivity = connectivity ?? ConnectivityService();

  final FirestoreStoryService _firestore;
  final StoryPromptBuilder _promptBuilder;
  final StoryAIOrchestrator _orchestrator;
  final StoryModerationService _moderation;
  final ConnectivityService _connectivity;

  Future<Story> generateAndPublish(StoryGenerationRequest request) async {
    if (request.ownerUid.trim().isEmpty) {
      throw const StoryPolicyException(
        'Guvenli oturum bulunamadi. Lutfen tekrar giris yapin.',
      );
    }

    final isConnected = await _connectivity.isConnected();
    if (!isConnected) {
      throw const StoryPolicyException(
        'Hikaye uretmek icin internet baglantisi gerekli.',
      );
    }

    final promptModeration = _moderation.moderatePrompt(request.prompt);
    if (!promptModeration.allowed) {
      throw const StoryPolicyException(
        'Istek metni guvenlik politikasina uymuyor. Lutfen daha yumusak bir tema deneyin.',
      );
    }

    final sanitizedRequest = request.copyWith(
      prompt: promptModeration.sanitizedPrompt,
    );
    final prompt = _promptBuilder.build(sanitizedRequest);

    final draft = await _orchestrator.generate(
      request: sanitizedRequest,
      prompt: prompt,
    );

    final moderationReport = _moderation.moderate(draft);
    if (!moderationReport.allowed) {
      throw const StoryPolicyException(
        'Icerik guvenlik politikasina takildi. Lutfen daha yumusak bir tema deneyin.',
      );
    }

    final chapterIndex =
        request.parentStory == null ? 1 : request.parentStory!.chapterIndex + 1;

    final story = Story(
      id: '',
      title: draft.title,
      text: moderationReport.moderatedBody,
      imageUrl: draft.imageUrl,
      audioUrl: '',
      ownerUid: request.ownerUid,
      userId: request.userId,
      createdAt: DateTime.now(),
      isPublic: request.isPublic,
      questions: draft.questions,
      parentStoryId: request.parentStory?.id,
      chapterIndex: chapterIndex,
      promptVersion: prompt.promptVersion,
      modelUsed: draft.modelUsed,
      generationMode: draft.generationMode,
      ageProfile: sanitizedRequest.ageProfile,
      style: sanitizedRequest.style,
      colorPalette: sanitizedRequest.colorPalette,
      safetyFlags: <String>[
        ...promptModeration.flags,
        ...moderationReport.flags,
      ],
      isModerated: true,
      scenes: moderationReport.moderatedScenes,
      characterProfile: sanitizedRequest.characterProfile,
      originalPrompt: _storedPromptValue(sanitizedRequest),
      schemaVersion: 2,
    );

    final id = await _firestore.saveStory(story);
    return story.copyWith(id: id);
  }

  String _storedPromptValue(StoryGenerationRequest request) {
    final source = request.prompt.trim();
    if (source.isEmpty) return '';
    if (!request.dataMinimizationMode) return source;

    var cleaned = source
        .replaceAll(RegExp(r'https?:\/\/\S+'), '[url]')
        .replaceAll(RegExp(r'\b[\w\.-]+@[\w\.-]+\.\w+\b'), '[email]')
        .replaceAll(RegExp(r'\+?\d[\d\s-]{5,}\d'), '[number]')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.length > 140) {
      cleaned = '${cleaned.substring(0, 140).trimRight()}...';
    }
    return cleaned;
  }
}
