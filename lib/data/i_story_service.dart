// lib/data/i_story_service.dart

import 'models/story_models.dart';

abstract class IStoryService {
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
  });

  Future<Story> continueStory({
    required Story parentStory,
    String continuationPrompt = 'Devamini yaz',
    StoryAgeProfile? ageProfile,
    StoryStyle? style,
    StoryColorPalette? colorPalette,
    bool sceneMode = true,
    int sceneCount = 3,
    bool dataMinimizationMode = true,
  });

  Future<void> saveStory(
      Story story); // Artık kullanılmayacak ama kontratta kalmalı
  Future<List<Story>> getPublicStories();
  Future<List<Story>> getStoriesForUser(String userId);
}
