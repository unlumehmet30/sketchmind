import '../dummy/stories.dart';

class StoryGenerationRequest {
  const StoryGenerationRequest({
    required this.ownerUid,
    required this.userId,
    required this.prompt,
    required this.ageProfile,
    required this.style,
    required this.colorPalette,
    required this.sceneMode,
    required this.sceneCount,
    required this.isPublic,
    this.dataMinimizationMode = true,
    this.characterProfile,
    this.parentStory,
  });

  final String ownerUid;
  final String userId;
  final String prompt;
  final StoryAgeProfile ageProfile;
  final StoryStyle style;
  final StoryColorPalette colorPalette;
  final bool sceneMode;
  final int sceneCount;
  final bool isPublic;
  final bool dataMinimizationMode;
  final StoryCharacterProfile? characterProfile;
  final Story? parentStory;

  bool get isContinuation => parentStory != null;

  StoryGenerationRequest copyWith({
    String? ownerUid,
    String? userId,
    String? prompt,
    StoryAgeProfile? ageProfile,
    StoryStyle? style,
    StoryColorPalette? colorPalette,
    bool? sceneMode,
    int? sceneCount,
    bool? isPublic,
    bool? dataMinimizationMode,
    StoryCharacterProfile? characterProfile,
    Story? parentStory,
  }) {
    return StoryGenerationRequest(
      ownerUid: ownerUid ?? this.ownerUid,
      userId: userId ?? this.userId,
      prompt: prompt ?? this.prompt,
      ageProfile: ageProfile ?? this.ageProfile,
      style: style ?? this.style,
      colorPalette: colorPalette ?? this.colorPalette,
      sceneMode: sceneMode ?? this.sceneMode,
      sceneCount: sceneCount ?? this.sceneCount,
      isPublic: isPublic ?? this.isPublic,
      dataMinimizationMode: dataMinimizationMode ?? this.dataMinimizationMode,
      characterProfile: characterProfile ?? this.characterProfile,
      parentStory: parentStory ?? this.parentStory,
    );
  }
}

class StoryPromptEnvelope {
  const StoryPromptEnvelope({
    required this.promptVersion,
    required this.systemHint,
    required this.userPrompt,
    required this.combinedPrompt,
  });

  final String promptVersion;
  final String systemHint;
  final String userPrompt;
  final String combinedPrompt;
}

class StoryGenerationDraft {
  const StoryGenerationDraft({
    required this.title,
    required this.body,
    required this.imageUrl,
    required this.scenes,
    required this.questions,
    required this.modelUsed,
    required this.generationMode,
  });

  final String title;
  final String body;
  final String imageUrl;
  final List<StoryScene> scenes;
  final List<QuizQuestion> questions;
  final String modelUsed;
  final String generationMode;
}

class StoryModerationReport {
  const StoryModerationReport({
    required this.allowed,
    required this.flags,
    required this.moderatedBody,
    required this.moderatedScenes,
  });

  final bool allowed;
  final List<String> flags;
  final String moderatedBody;
  final List<StoryScene> moderatedScenes;
}

class PromptModerationReport {
  const PromptModerationReport({
    required this.allowed,
    required this.flags,
    required this.sanitizedPrompt,
  });

  final bool allowed;
  final List<String> flags;
  final String sanitizedPrompt;
}

class StoryPolicyException implements Exception {
  const StoryPolicyException(this.message);

  final String message;

  @override
  String toString() => 'StoryPolicyException: $message';
}
