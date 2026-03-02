import 'package:flutter_test/flutter_test.dart';

import 'package:sketchmind/data/dummy/stories.dart';
import 'package:sketchmind/data/services/story_generation_models.dart';
import 'package:sketchmind/data/services/story_moderation_service.dart';

void main() {
  final moderation = StoryModerationService();

  StoryGenerationDraft draftWithBody(String body) {
    return StoryGenerationDraft(
      title: 'Test',
      body: body,
      imageUrl: 'https://example.com/img.png',
      scenes: const <StoryScene>[],
      questions: const <QuizQuestion>[],
      modelUsed: 'test-model',
      generationMode: 'lite',
    );
  }

  test('blocks story when blocked keywords exist', () {
    final report = moderation.moderate(
      draftWithBody('Kahraman gizli bir silah buldu.'),
    );

    expect(report.allowed, isFalse);
    expect(report.flags.join(','), contains('blocked_content'));
  });

  test('replaces warning words with neutral language', () {
    const draft = StoryGenerationDraft(
      title: 'Warn',
      body: 'Karanlik gecede canavar cikti ama herkes sakindi.',
      imageUrl: 'https://example.com/img.png',
      scenes: <StoryScene>[
        StoryScene(
          id: '1',
          order: 1,
          title: 'Korku An',
          text: 'Tehdit gibi duran bir ses geldi.',
          imageUrl: 'https://example.com/scene.png',
        ),
      ],
      questions: <QuizQuestion>[],
      modelUsed: 'test-model',
      generationMode: 'full',
    );

    final report = moderation.moderate(draft);

    expect(report.allowed, isTrue);
    expect(report.moderatedBody.toLowerCase(), isNot(contains('karanlik')));
    expect(report.moderatedBody.toLowerCase(), isNot(contains('canavar')));
    expect(report.moderatedBody.toLowerCase(), contains('heyecan'));
    expect(report.moderatedScenes.first.title.toLowerCase(),
        isNot(contains('korku')));
    expect(
      report.moderatedScenes.first.text.toLowerCase(),
      isNot(contains('tehdit')),
    );
  });
}
