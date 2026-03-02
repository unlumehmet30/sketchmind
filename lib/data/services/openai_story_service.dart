// lib/data/services/openai_story_service.dart

import 'package:flutter/foundation.dart';
import 'package:dart_openai/dart_openai.dart';

import '../i_story_service.dart';
import '../dummy/stories.dart';
import 'auth_service.dart';
import 'firestore_story_service.dart';
import 'local_user_service.dart';
import 'story_generation_models.dart';
import 'story_generation_pipeline.dart';

class OpenAIStoryService implements IStoryService {
  OpenAIStoryService._internal({
    StoryGenerationPipeline? pipeline,
  }) : _pipeline = pipeline ??
            StoryGenerationPipeline(firestore: FirestoreStoryService()) {
    _configureOpenAi();
  }

  static final OpenAIStoryService _instance = OpenAIStoryService._internal();
  static bool _openAiConfigured = false;
  static const String _openAiApiKey = String.fromEnvironment('OPENAI_API_KEY');

  factory OpenAIStoryService({
    StoryGenerationPipeline? pipeline,
  }) {
    if (pipeline == null) {
      return _instance;
    }
    return OpenAIStoryService._internal(pipeline: pipeline);
  }

  final StoryGenerationPipeline _pipeline;
  final FirestoreStoryService _firestoreService = FirestoreStoryService();
  final LocalUserService _localUserService = LocalUserService();
  final AuthService _authService = AuthService();

  void _configureOpenAi() {
    if (_openAiConfigured) return;
    final key = _openAiApiKey.trim();
    if (key.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'OpenAI API key is missing. Provide it via --dart-define=OPENAI_API_KEY=...',
        );
      }
      return;
    }
    OpenAI.apiKey = key;
    _openAiConfigured = true;
    if (kDebugMode) {
      debugPrint('OpenAI client configured via dart-define.');
    }
  }

  @override
  Future<Story> createStory(
    String prompt, {
    StoryAgeProfile ageProfile = StoryAgeProfile.unknown,
    StoryStyle style = StoryStyle.adventure,
    StoryColorPalette colorPalette = StoryColorPalette.auto,
    bool sceneMode = false,
    int sceneCount = 3,
    StoryCharacterProfile? characterProfile,
    bool isPublic = true,
    bool dataMinimizationMode = true,
  }) async {
    final ownerUid = await _authService.getCurrentUserId();
    final currentLocalUserId = await _localUserService.getSelectedUserId();

    final request = StoryGenerationRequest(
      ownerUid: ownerUid,
      userId: currentLocalUserId,
      prompt: prompt,
      ageProfile: ageProfile,
      style: style,
      colorPalette: colorPalette,
      sceneMode: sceneMode,
      sceneCount: sceneCount,
      isPublic: isPublic,
      dataMinimizationMode: dataMinimizationMode,
      characterProfile: characterProfile,
    );

    return _pipeline.generateAndPublish(request);
  }

  @override
  Future<Story> continueStory({
    required Story parentStory,
    String continuationPrompt = 'Devamini yaz',
    StoryAgeProfile? ageProfile,
    StoryStyle? style,
    StoryColorPalette? colorPalette,
    bool sceneMode = true,
    int sceneCount = 3,
    bool dataMinimizationMode = true,
  }) async {
    final ownerUid = await _authService.getCurrentUserId();
    final currentLocalUserId = await _localUserService.getSelectedUserId();

    final request = StoryGenerationRequest(
      ownerUid: ownerUid,
      userId: currentLocalUserId,
      prompt: continuationPrompt,
      ageProfile: ageProfile ?? parentStory.ageProfile,
      style: style ?? parentStory.style,
      colorPalette: colorPalette ?? parentStory.colorPalette,
      sceneMode: sceneMode,
      sceneCount: sceneCount,
      isPublic: parentStory.isPublic,
      dataMinimizationMode: dataMinimizationMode,
      characterProfile: parentStory.characterProfile,
      parentStory: parentStory,
    );

    return _pipeline.generateAndPublish(request);
  }

  @override
  Future<List<Story>> getStoriesForUser(String userId) async {
    final ownerUid = await _authService.getCurrentUserId();

    try {
      if (userId == LocalUserService.defaultUserId) {
        return await _firestoreService.getPublicStories();
      }

      return await _firestoreService.getStoriesForUser(
        ownerUid: ownerUid,
        userId: userId,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('User-scoped fetch failed, falling back: $e\n$st');
      }

      try {
        if (userId == LocalUserService.defaultUserId) {
          return await _firestoreService.getPublicStories();
        }
        return <Story>[];
      } catch (fallbackError, fallbackStack) {
        if (kDebugMode) {
          debugPrint(
            'Fallback story fetch failed: $fallbackError\n$fallbackStack',
          );
        }
        return <Story>[];
      }
    }
  }

  @override
  Future<List<Story>> getPublicStories() async {
    try {
      return await _firestoreService.getPublicStories();
    } catch (e, st) {
      if (kDebugMode) debugPrint('Failed to fetch public stories: $e\n$st');
      return <Story>[];
    }
  }

  @override
  Future<void> saveStory(Story story) async {
    throw UnimplementedError('Kayit islemi createStory icinde yapiliyor.');
  }
}
