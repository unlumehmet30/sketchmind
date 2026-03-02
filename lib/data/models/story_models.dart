import 'package:cloud_firestore/cloud_firestore.dart';

enum StoryAgeProfile {
  unknown,
  age4to6,
  age7to9,
  age10to12,
}

extension StoryAgeProfileX on StoryAgeProfile {
  String get key {
    switch (this) {
      case StoryAgeProfile.age4to6:
        return 'age_4_6';
      case StoryAgeProfile.age7to9:
        return 'age_7_9';
      case StoryAgeProfile.age10to12:
        return 'age_10_12';
      case StoryAgeProfile.unknown:
        return 'unknown';
    }
  }

  String get displayLabel {
    switch (this) {
      case StoryAgeProfile.age4to6:
        return '4-6';
      case StoryAgeProfile.age7to9:
        return '7-9';
      case StoryAgeProfile.age10to12:
        return '10-12';
      case StoryAgeProfile.unknown:
        return 'Otomatik';
    }
  }

  static StoryAgeProfile fromKey(String? key) {
    switch (key) {
      case 'age_4_6':
        return StoryAgeProfile.age4to6;
      case 'age_7_9':
        return StoryAgeProfile.age7to9;
      case 'age_10_12':
        return StoryAgeProfile.age10to12;
      default:
        return StoryAgeProfile.unknown;
    }
  }
}

enum StoryStyle {
  fairyTale,
  funny,
  adventure,
  educational,
  bedtime,
}

extension StoryStyleX on StoryStyle {
  String get key {
    switch (this) {
      case StoryStyle.fairyTale:
        return 'fairy_tale';
      case StoryStyle.funny:
        return 'funny';
      case StoryStyle.adventure:
        return 'adventure';
      case StoryStyle.educational:
        return 'educational';
      case StoryStyle.bedtime:
        return 'bedtime';
    }
  }

  String get displayLabel {
    switch (this) {
      case StoryStyle.fairyTale:
        return 'Masal';
      case StoryStyle.funny:
        return 'Komik';
      case StoryStyle.adventure:
        return 'Macera';
      case StoryStyle.educational:
        return 'Egitimsel';
      case StoryStyle.bedtime:
        return 'Uyku';
    }
  }

  static StoryStyle fromKey(String? key) {
    switch (key) {
      case 'fairy_tale':
        return StoryStyle.fairyTale;
      case 'funny':
        return StoryStyle.funny;
      case 'educational':
        return StoryStyle.educational;
      case 'bedtime':
        return StoryStyle.bedtime;
      case 'adventure':
      default:
        return StoryStyle.adventure;
    }
  }
}

enum StoryColorPalette {
  auto,
  vibrant,
  pastel,
  warmSunset,
  forest,
  ocean,
  candy,
}

extension StoryColorPaletteX on StoryColorPalette {
  String get key {
    switch (this) {
      case StoryColorPalette.auto:
        return 'auto';
      case StoryColorPalette.vibrant:
        return 'vibrant';
      case StoryColorPalette.pastel:
        return 'pastel';
      case StoryColorPalette.warmSunset:
        return 'warm_sunset';
      case StoryColorPalette.forest:
        return 'forest';
      case StoryColorPalette.ocean:
        return 'ocean';
      case StoryColorPalette.candy:
        return 'candy';
    }
  }

  String get displayLabel {
    switch (this) {
      case StoryColorPalette.auto:
        return 'Otomatik';
      case StoryColorPalette.vibrant:
        return 'Canli';
      case StoryColorPalette.pastel:
        return 'Pastel';
      case StoryColorPalette.warmSunset:
        return 'Gun Batimi';
      case StoryColorPalette.forest:
        return 'Orman';
      case StoryColorPalette.ocean:
        return 'Okyanus';
      case StoryColorPalette.candy:
        return 'Sekersi';
    }
  }

  static StoryColorPalette fromKey(String? key) {
    switch (key) {
      case 'vibrant':
        return StoryColorPalette.vibrant;
      case 'pastel':
        return StoryColorPalette.pastel;
      case 'warm_sunset':
        return StoryColorPalette.warmSunset;
      case 'forest':
        return StoryColorPalette.forest;
      case 'ocean':
        return StoryColorPalette.ocean;
      case 'candy':
        return StoryColorPalette.candy;
      case 'auto':
      default:
        return StoryColorPalette.auto;
    }
  }
}

class StoryCharacterProfile {
  final String name;
  final String power;
  final String personality;
  final String world;
  final String toyImageUrl;

  const StoryCharacterProfile({
    required this.name,
    required this.power,
    required this.personality,
    required this.world,
    this.toyImageUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'power': power,
      'personality': personality,
      'world': world,
      'toyImageUrl': toyImageUrl,
    };
  }

  factory StoryCharacterProfile.fromMap(Map<String, dynamic> map) {
    return StoryCharacterProfile(
      name: map['name'] as String? ?? '',
      power: map['power'] as String? ?? '',
      personality: map['personality'] as String? ?? '',
      world: map['world'] as String? ?? '',
      toyImageUrl: map['toyImageUrl'] as String? ?? '',
    );
  }
}

class StoryScene {
  final String id;
  final int order;
  final String title;
  final String text;
  final String imageUrl;

  const StoryScene({
    required this.id,
    required this.order,
    required this.title,
    required this.text,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'order': order,
      'title': title,
      'text': text,
      'imageUrl': imageUrl,
    };
  }

  factory StoryScene.fromMap(Map<String, dynamic> map) {
    return StoryScene(
      id: map['id'] as String? ?? '',
      order: (map['order'] as num?)?.toInt() ?? 0,
      title: map['title'] as String? ?? '',
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
    );
  }
}

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctIndex;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctIndex,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options,
      'correctIndex': correctIndex,
    };
  }

  factory QuizQuestion.fromMap(Map<String, dynamic> map) {
    final rawOptions = map['options'];
    final parsedOptions = rawOptions is List
        ? rawOptions
            .map((item) => item?.toString() ?? '')
            .where((item) => item.trim().isNotEmpty)
            .map((item) => item.trim())
            .toList(growable: false)
        : const <String>[];

    final options = parsedOptions.length >= 2
        ? parsedOptions
        : const <String>[
            'Secenek 1',
            'Secenek 2',
          ];

    final parsedCorrectIndex = (map['correctIndex'] as num?)?.toInt() ?? 0;
    final safeCorrectIndex =
        parsedCorrectIndex.clamp(0, options.length - 1).toInt();

    return QuizQuestion(
      question: map['question'] as String? ?? 'Soru bulunamadi.',
      options: options,
      correctIndex: safeCorrectIndex,
    );
  }
}

class Story {
  final String id;
  final String title;
  final String text;
  final String imageUrl;
  final String audioUrl;
  final String ownerUid;
  final String userId;
  final DateTime createdAt;
  final bool isPublic;
  final List<QuizQuestion> questions;
  final String? parentStoryId;
  final int chapterIndex;
  final String promptVersion;
  final String modelUsed;
  final String generationMode;
  final StoryAgeProfile ageProfile;
  final StoryStyle style;
  final StoryColorPalette colorPalette;
  final List<String> safetyFlags;
  final bool isModerated;
  final List<StoryScene> scenes;
  final StoryCharacterProfile? characterProfile;
  final String originalPrompt;
  final int schemaVersion;

  Story({
    required this.id,
    required this.title,
    required this.text,
    required this.imageUrl,
    this.audioUrl = '',
    this.ownerUid = '',
    this.userId = 'anonymous',
    required this.createdAt,
    this.isPublic = true,
    this.questions = const [],
    this.parentStoryId,
    this.chapterIndex = 1,
    this.promptVersion = 'story_prompt_v1',
    this.modelUsed = 'mock-model',
    this.generationMode = 'lite',
    this.ageProfile = StoryAgeProfile.unknown,
    this.style = StoryStyle.adventure,
    this.colorPalette = StoryColorPalette.auto,
    this.safetyFlags = const [],
    this.isModerated = true,
    this.scenes = const [],
    this.characterProfile,
    this.originalPrompt = '',
    this.schemaVersion = 2,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'text': text,
      'imageUrl': imageUrl,
      'audioUrl': audioUrl,
      'ownerUid': ownerUid,
      'userId': userId,
      'createdAt': Timestamp.fromDate(createdAt),
      'isPublic': isPublic,
      'questions': questions.map((q) => q.toMap()).toList(growable: false),
      'parentStoryId': parentStoryId,
      'chapterIndex': chapterIndex,
      'promptVersion': promptVersion,
      'modelUsed': modelUsed,
      'generationMode': generationMode,
      'ageProfile': ageProfile.key,
      'style': style.key,
      'colorPalette': colorPalette.key,
      'safetyFlags': safetyFlags,
      'isModerated': isModerated,
      'scenes': scenes.map((scene) => scene.toMap()).toList(growable: false),
      'characterProfile': characterProfile?.toMap(),
      'originalPrompt': originalPrompt,
      'schemaVersion': schemaVersion,
    };
  }

  static DateTime _readDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.now();
  }

  static Map<String, dynamic>? _asStringDynamicMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (dynamic key, dynamic mapValue) => MapEntry(
          key.toString(),
          mapValue,
        ),
      );
    }
    return null;
  }

  static List<QuizQuestion> _readQuestions(dynamic value) {
    if (value is! List) return const <QuizQuestion>[];
    return value
        .map(
          (item) => _asStringDynamicMap(item),
        )
        .whereType<Map<String, dynamic>>()
        .map(QuizQuestion.fromMap)
        .toList(growable: false);
  }

  static List<StoryScene> _readScenes(dynamic value) {
    if (value is! List) return const <StoryScene>[];
    return value
        .map(_asStringDynamicMap)
        .whereType<Map<String, dynamic>>()
        .map(StoryScene.fromMap)
        .toList(growable: false);
  }

  factory Story.fromMap(Map<String, dynamic> map, String id) {
    final characterMap = _asStringDynamicMap(map['characterProfile']);
    return Story(
      id: id,
      title: map['title'] as String? ?? 'Adsiz Hikaye',
      text: map['text'] as String? ?? '',
      imageUrl: map['imageUrl'] as String? ?? '',
      audioUrl: map['audioUrl'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      userId: map['userId'] as String? ?? 'anonymous',
      createdAt: _readDate(map['createdAt']),
      isPublic: map['isPublic'] as bool? ?? true,
      questions: _readQuestions(map['questions']),
      parentStoryId: map['parentStoryId'] as String?,
      chapterIndex: (map['chapterIndex'] as num?)?.toInt() ?? 1,
      promptVersion: map['promptVersion'] as String? ?? 'story_prompt_v1',
      modelUsed: map['modelUsed'] as String? ?? 'legacy',
      generationMode: map['generationMode'] as String? ?? 'legacy',
      ageProfile: StoryAgeProfileX.fromKey(map['ageProfile'] as String?),
      style: StoryStyleX.fromKey(map['style'] as String?),
      colorPalette: StoryColorPaletteX.fromKey(
        map['colorPalette'] as String?,
      ),
      safetyFlags: (map['safetyFlags'] as List<dynamic>?)
              ?.map((flag) => flag.toString())
              .toList(growable: false) ??
          const <String>[],
      isModerated: map['isModerated'] as bool? ?? true,
      scenes: _readScenes(map['scenes']),
      characterProfile: characterMap == null
          ? null
          : StoryCharacterProfile.fromMap(characterMap),
      originalPrompt: map['originalPrompt'] as String? ?? '',
      schemaVersion: (map['schemaVersion'] as num?)?.toInt() ?? 1,
    );
  }

  Story copyWith({
    String? id,
    String? title,
    String? text,
    String? imageUrl,
    String? audioUrl,
    String? ownerUid,
    String? userId,
    DateTime? createdAt,
    bool? isPublic,
    List<QuizQuestion>? questions,
    String? parentStoryId,
    int? chapterIndex,
    String? promptVersion,
    String? modelUsed,
    String? generationMode,
    StoryAgeProfile? ageProfile,
    StoryStyle? style,
    StoryColorPalette? colorPalette,
    List<String>? safetyFlags,
    bool? isModerated,
    List<StoryScene>? scenes,
    StoryCharacterProfile? characterProfile,
    String? originalPrompt,
    int? schemaVersion,
  }) {
    return Story(
      id: id ?? this.id,
      title: title ?? this.title,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      audioUrl: audioUrl ?? this.audioUrl,
      ownerUid: ownerUid ?? this.ownerUid,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      isPublic: isPublic ?? this.isPublic,
      questions: questions ?? this.questions,
      parentStoryId: parentStoryId ?? this.parentStoryId,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      promptVersion: promptVersion ?? this.promptVersion,
      modelUsed: modelUsed ?? this.modelUsed,
      generationMode: generationMode ?? this.generationMode,
      ageProfile: ageProfile ?? this.ageProfile,
      style: style ?? this.style,
      colorPalette: colorPalette ?? this.colorPalette,
      safetyFlags: safetyFlags ?? this.safetyFlags,
      isModerated: isModerated ?? this.isModerated,
      scenes: scenes ?? this.scenes,
      characterProfile: characterProfile ?? this.characterProfile,
      originalPrompt: originalPrompt ?? this.originalPrompt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
    );
  }
}
