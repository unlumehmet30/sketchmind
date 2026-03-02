import '../dummy/stories.dart';
import 'story_generation_models.dart';

class StoryModerationService {
  static const List<String> _blockedWords = <String>[
    'oldur',
    'intihar',
    'silah',
    'tabanca',
    'bicak',
    'bomba',
    'kan',
    'vahset',
    'iskence',
    'saldiri',
  ];

  static const List<String> _warnWords = <String>[
    'korku',
    'karanlik',
    'canavar',
    'tehdit',
    'dehset',
    'hirsiz',
    'kavga',
    'aglama',
    'kaybol',
  ];

  static final List<RegExp> _blockedPatterns = _blockedWords
      .map((word) => _wordBoundaryPattern(word))
      .toList(growable: false);
  static final List<RegExp> _warnPatterns = _warnWords
      .map((word) => _wordBoundaryPattern(word))
      .toList(growable: false);

  PromptModerationReport moderatePrompt(String prompt) {
    final normalizedPrompt = _normalizeForScan(prompt);
    final blockedFound = _findMatches(
      normalizedPrompt,
      words: _blockedWords,
      patterns: _blockedPatterns,
    );

    if (blockedFound.isNotEmpty) {
      return PromptModerationReport(
        allowed: false,
        flags: <String>['prompt_blocked:${blockedFound.join(',')}'],
        sanitizedPrompt: prompt,
      );
    }

    final warnFound = _findMatches(
      normalizedPrompt,
      words: _warnWords,
      patterns: _warnPatterns,
    );

    final flags = <String>[];
    if (warnFound.isNotEmpty) {
      flags.add('prompt_tone_adjusted:${warnFound.join(',')}');
    }

    return PromptModerationReport(
      allowed: true,
      flags: flags,
      sanitizedPrompt: _sanitize(prompt),
    );
  }

  StoryModerationReport moderate(StoryGenerationDraft draft) {
    final flags = <String>{};
    final corpus = <String>[
      draft.title,
      draft.body,
      ...draft.scenes.map((scene) => '${scene.title} ${scene.text}'),
    ].join(' ');
    final normalizedCorpus = _normalizeForScan(corpus);

    final blockedFound = _findMatches(
      normalizedCorpus,
      words: _blockedWords,
      patterns: _blockedPatterns,
    );
    if (blockedFound.isNotEmpty) {
      flags.add('blocked_content:${blockedFound.join(',')}');
      return StoryModerationReport(
        allowed: false,
        flags: flags.toList(growable: false),
        moderatedBody: draft.body,
        moderatedScenes: draft.scenes,
      );
    }

    final warnFound = _findMatches(
      normalizedCorpus,
      words: _warnWords,
      patterns: _warnPatterns,
    );
    if (warnFound.isNotEmpty) {
      flags.add('tone_adjusted:${warnFound.join(',')}');
    }

    return StoryModerationReport(
      allowed: true,
      flags: flags.toList(growable: false),
      moderatedBody: _sanitize(draft.body),
      moderatedScenes: draft.scenes
          .map(
            (scene) => StoryScene(
              id: scene.id,
              order: scene.order,
              title: _sanitize(scene.title),
              text: _sanitize(scene.text),
              imageUrl: scene.imageUrl,
            ),
          )
          .toList(growable: false),
    );
  }

  static RegExp _wordBoundaryPattern(String word) {
    return RegExp(
      '(^|[^a-z0-9])${RegExp.escape(word)}(?=\$|[^a-z0-9])',
      caseSensitive: false,
    );
  }

  List<String> _findMatches(
    String normalizedInput, {
    required List<String> words,
    required List<RegExp> patterns,
  }) {
    final matches = <String>[];
    for (var i = 0; i < words.length; i++) {
      if (patterns[i].hasMatch(normalizedInput)) {
        matches.add(words[i]);
      }
    }
    return matches;
  }

  String _sanitize(String value) {
    var output = value;
    for (final warnWord in _warnWords) {
      final regex = _wordBoundaryPattern(warnWord);
      output = output.replaceAllMapped(regex, (match) {
        final prefix = match.group(1) ?? '';
        return '${prefix}heyecan';
      });
    }
    return output;
  }

  String _normalizeForScan(String value) {
    var normalized = value.toLowerCase();

    const replacementMap = <String, String>{
      'ı': 'i',
      'ğ': 'g',
      'ş': 's',
      'ö': 'o',
      'ü': 'u',
      'ç': 'c',
      '@': 'a',
      '\$': 's',
      '0': 'o',
      '1': 'i',
      '3': 'e',
      '4': 'a',
      '5': 's',
      '7': 't',
    };

    replacementMap.forEach((source, target) {
      normalized = normalized.replaceAll(source, target);
    });

    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9\s]'), ' ');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized;
  }
}
