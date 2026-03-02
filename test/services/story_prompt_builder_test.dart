import 'package:flutter_test/flutter_test.dart';

import 'package:sketchmind/data/dummy/stories.dart';
import 'package:sketchmind/data/services/story_generation_models.dart';
import 'package:sketchmind/data/services/story_prompt_builder.dart';

void main() {
  test('builds continuation prompt with scene and character hints', () {
    final parentStory = Story(
      id: 'parent_1',
      title: 'Ilk Bolum',
      text: 'Uzun bir ozet metni. ' * 40,
      imageUrl: 'https://example.com/parent.png',
      ownerUid: 'uid_1',
      userId: 'Cocuk_01',
      createdAt: DateTime(2026, 2, 23),
    );

    final request = StoryGenerationRequest(
      ownerUid: 'uid_1',
      userId: 'Cocuk_01',
      prompt: 'Yeni macerada gizli kapilar kesfedilsin',
      ageProfile: StoryAgeProfile.age7to9,
      style: StoryStyle.adventure,
      colorPalette: StoryColorPalette.vibrant,
      sceneMode: true,
      sceneCount: 4,
      isPublic: true,
      characterProfile: const StoryCharacterProfile(
        name: 'Mina',
        power: 'ruzgar hizi',
        personality: 'cesur',
        world: 'bulut adasi',
      ),
      parentStory: parentStory,
    );

    final envelope = StoryPromptBuilder().build(request);

    expect(envelope.promptVersion, 'story_prompt_v2');
    expect(envelope.systemHint, contains('4 sahneye ayir'));
    expect(envelope.systemHint, contains('Canli ve enerjik bir renk paleti'));
    expect(envelope.userPrompt, contains('Bu bir devam bolumu'));
    expect(envelope.userPrompt, contains('Karakter Profili: Isim=Mina'));
    expect(envelope.combinedPrompt, contains('Tema: Yeni macerada'));
  });
}
