import 'dart:math';

import 'package:sketchmind/data/i_story_service.dart';
import 'package:sketchmind/data/models/story_models.dart';

class MockStoryService implements IStoryService {
  static const Duration _mockDelay = Duration(milliseconds: 250);

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
    await Future<void>.delayed(_mockDelay);

    return Story(
      id: 'mock_${Random().nextInt(100000)}',
      title: 'Mock Hikaye: ${prompt.trim().isEmpty ? "Baslik" : prompt.trim()}',
      text: 'Bu test odakli bir mock hikaye icerigidir.',
      imageUrl: _mockImageUrl('Mock Hikaye'),
      createdAt: DateTime.now(),
      isPublic: isPublic,
      ageProfile: ageProfile,
      style: style,
      colorPalette: colorPalette,
      scenes: sceneMode
          ? List<StoryScene>.generate(
              sceneCount.clamp(2, 5),
              (index) => StoryScene(
                id: 'scene_$index',
                order: index + 1,
                title: 'Sahne ${index + 1}',
                text: 'Mock sahne ${index + 1}',
                imageUrl: _mockImageUrl('Sahne ${index + 1}'),
              ),
              growable: false,
            )
          : const <StoryScene>[],
      characterProfile: characterProfile,
    );
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
    final story = await createStory(
      continuationPrompt,
      ageProfile: ageProfile ?? parentStory.ageProfile,
      style: style ?? parentStory.style,
      colorPalette: colorPalette ?? parentStory.colorPalette,
      sceneMode: sceneMode,
      sceneCount: sceneCount,
      characterProfile: parentStory.characterProfile,
      isPublic: parentStory.isPublic,
      dataMinimizationMode: dataMinimizationMode,
    );
    return story.copyWith(
      parentStoryId: parentStory.id,
      chapterIndex: parentStory.chapterIndex + 1,
    );
  }

  @override
  Future<List<Story>> getPublicStories() async {
    await Future<void>.delayed(_mockDelay);
    return <Story>[
      Story(
        id: 'mock_public_1',
        title: 'Mock Public Story',
        text: 'Public mock story body',
        imageUrl: _mockImageUrl('Public'),
        createdAt: DateTime.now(),
        isPublic: true,
      ),
    ];
  }

  @override
  Future<List<Story>> getStoriesForUser(String userId) async {
    await Future<void>.delayed(_mockDelay);
    return <Story>[
      Story(
        id: 'mock_user_${userId.trim().isEmpty ? "guest" : userId.trim()}',
        title: 'Mock User Story',
        text: 'User-scoped mock story body',
        imageUrl: _mockImageUrl('User'),
        createdAt: DateTime.now(),
        userId: userId,
      ),
    ];
  }

  @override
  Future<void> saveStory(Story story) async {
    await Future<void>.delayed(const Duration(milliseconds: 60));
  }

  String _mockImageUrl(String label) {
    final safeText = label.replaceAll('&', 've');
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="576" viewBox="0 0 1024 576">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#9CC0FF"/>
      <stop offset="100%" stop-color="#F5B4D6"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="576" fill="url(#g)"/>
  <text x="512" y="300" text-anchor="middle" fill="#1F2D4D" font-size="52" font-family="Arial">$safeText</text>
</svg>
''';
    return 'data:image/svg+xml;utf8,${Uri.encodeComponent(svg)}';
  }
}
