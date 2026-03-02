import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dart_openai/dart_openai.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../dummy/stories.dart';
import 'connectivity_service.dart';
import 'story_generation_models.dart';

class StoryAIOrchestrator {
  final Map<String, _CachedDraft> _cache = <String, _CachedDraft>{};
  final ConnectivityService _connectivity = ConnectivityService();
  static final Map<String, _RateLimitWindow> _rateWindows =
      <String, _RateLimitWindow>{};

  static const Duration _cacheTtl = Duration(minutes: 15);
  static const int _maxAttempts = 2;
  static const int _maxImagePromptLength = 900;
  static const int _maxStoryBodyLength = 2200;
  static const int _maxSceneTextLength = 600;
  static const String _imageCreateModel = 'dall-e-3';
  static const String _imageEditModel = 'dall-e-2';
  static const String _textCreateModel = 'gpt-4o-mini';
  static const int _referenceImageSize = 1024;
  static const Duration _rateLimitWindow = Duration(minutes: 1);
  static const int _maxImageRequestsPerWindow = 8;
  static const int _maxReferenceImageBytes = 2 * 1024 * 1024;
  static const Duration _networkTimeout = Duration(seconds: 8);
  static const Set<String> _allowedReferenceHosts = <String>{
    'firebasestorage.googleapis.com',
    'storage.googleapis.com',
    'lh3.googleusercontent.com',
  };

  Future<StoryGenerationDraft> generate({
    required StoryGenerationRequest request,
    required StoryPromptEnvelope prompt,
  }) async {
    _removeExpiredCacheEntries();

    final cacheKey = _buildCacheKey(request, prompt);
    final cached = _cache[cacheKey];
    if (cached != null) {
      return cached.draft;
    }

    Object? lastError;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      try {
        final mode = _resolveMode(request, prompt);
        final draft = await _generateTemplateDraft(
          request: request,
          generationMode: mode,
        );

        _cache[cacheKey] = _CachedDraft(
          draft: draft,
          createdAt: DateTime.now(),
        );
        return draft;
      } catch (error, stackTrace) {
        lastError = error;
        debugPrint(
          'Story generation attempt $attempt failed: $error\n$stackTrace',
        );
        await Future<void>.delayed(Duration(milliseconds: 150 * attempt));
      }
    }

    throw Exception('Story generation failed after retries: $lastError');
  }

  void _removeExpiredCacheEntries() {
    final now = DateTime.now();
    final expiredKeys = _cache.entries
        .where((entry) => now.difference(entry.value.createdAt) > _cacheTtl)
        .map((entry) => entry.key)
        .toList(growable: false);

    for (final key in expiredKeys) {
      _cache.remove(key);
    }
  }

  String _buildCacheKey(
    StoryGenerationRequest request,
    StoryPromptEnvelope prompt,
  ) {
    final parent = request.parentStory?.id ?? '';
    return [
      request.userId,
      request.prompt.trim().toLowerCase(),
      request.style.key,
      request.ageProfile.key,
      request.colorPalette.key,
      request.sceneMode.toString(),
      request.sceneCount.toString(),
      parent,
      prompt.promptVersion,
    ].join('|');
  }

  String _resolveMode(
      StoryGenerationRequest request, StoryPromptEnvelope prompt) {
    if (request.sceneMode ||
        request.isContinuation ||
        prompt.userPrompt.length > 180) {
      return 'full';
    }
    return 'lite';
  }

  Future<StoryGenerationDraft> _generateTemplateDraft({
    required StoryGenerationRequest request,
    required String generationMode,
  }) async {
    final aiNarrative = await _generateNarrativeWithAi(
      request: request,
      generationMode: generationMode,
    );

    final title = aiNarrative?.title ?? _buildTitle(request);
    final body = aiNarrative?.body ?? _buildBody(request, title: title);
    final draftScenes = _resolveDraftScenes(
      request: request,
      title: title,
      body: body,
      aiScenes: aiNarrative?.scenes ?? const <StoryScene>[],
    );
    final visuals = await _buildVisualBundle(
      request: request,
      title: title,
      body: body,
      scenes: draftScenes,
    );
    final modelBase = generationMode == 'full'
        ? 'sketchmind-story-full-v1'
        : 'sketchmind-story-lite-v1';
    final textModel = aiNarrative != null ? _textCreateModel : 'template';
    final visualModel = visuals.usedReferenceImage
        ? '$_imageEditModel toy-ref'
        : _imageCreateModel;

    return StoryGenerationDraft(
      title: title,
      body: body,
      imageUrl: visuals.coverImageUrl,
      scenes: visuals.scenes,
      questions: _buildQuizQuestions(
        request: request,
        title: title,
        body: body,
        scenes: draftScenes,
      ),
      modelUsed: visuals.usedAiImages
          ? '$modelBase + $textModel + $visualModel'
          : '$modelBase + $textModel + fallback',
      generationMode: generationMode,
    );
  }

  Future<_AiNarrativeDraft?> _generateNarrativeWithAi({
    required StoryGenerationRequest request,
    required String generationMode,
  }) async {
    final isConnected = await _connectivity.isConnected();
    if (!isConnected) return null;

    try {
      final response = await OpenAI.instance.chat.create(
        model: _textCreateModel,
        responseFormat: const <String, String>{'type': 'json_object'},
        temperature: generationMode == 'full' ? 0.9 : 0.7,
        maxTokens: request.sceneMode ? 900 : 650,
        user: request.userId.trim().isEmpty ? null : request.userId.trim(),
        messages: <OpenAIChatCompletionChoiceMessageModel>[
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.system,
            content: <OpenAIChatCompletionChoiceMessageContentItemModel>[
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                'You are a child-safe story generator. '
                'Respond strictly as JSON with keys: title (string), body (string), scenes (array). '
                'Each scene must include title and text. Avoid violence, fear, and unsafe content. '
                'No markdown, no extra keys.',
              ),
            ],
          ),
          OpenAIChatCompletionChoiceMessageModel(
            role: OpenAIChatMessageRole.user,
            content: <OpenAIChatCompletionChoiceMessageContentItemModel>[
              OpenAIChatCompletionChoiceMessageContentItemModel.text(
                _buildNarrativeUserPrompt(request),
              ),
            ],
          ),
        ],
      );

      final rawJson = _extractTextResponse(response);
      if (rawJson.isEmpty) return null;
      return _parseNarrativeDraft(rawJson, request);
    } catch (error, stackTrace) {
      debugPrint(
          'AI text generation fallback to template: $error\n$stackTrace');
      return null;
    }
  }

  String _buildNarrativeUserPrompt(StoryGenerationRequest request) {
    final safePrompt = request.prompt.trim().isEmpty
        ? 'Cocuk dostu bir iyilik macerasi'
        : request.prompt.trim();
    final sceneInstructions = request.sceneMode
        ? 'Produce ${request.sceneCount.clamp(2, 5)} scenes with clear progression.'
        : 'Return an empty scenes array.';
    final continuation = request.parentStory == null
        ? ''
        : 'This is a continuation of "${request.parentStory!.title}".';
    final character = request.characterProfile == null
        ? ''
        : 'Main character: ${request.characterProfile!.name}, '
            '${request.characterProfile!.personality}, '
            'power ${request.characterProfile!.power}, '
            'world ${request.characterProfile!.world}.';

    return [
      'Language: Turkish.',
      'Theme: $safePrompt.',
      'Age profile: ${request.ageProfile.key}.',
      'Style: ${request.style.key}.',
      'Color palette: ${request.colorPalette.key}.',
      continuation,
      character,
      sceneInstructions,
      'Body must be at most $_maxStoryBodyLength characters.',
      'Each scene text at most $_maxSceneTextLength characters.',
    ].where((part) => part.trim().isNotEmpty).join(' ');
  }

  String _extractTextResponse(OpenAIChatCompletionModel response) {
    if (response.choices.isEmpty) return '';
    final message = response.choices.first.message;
    final content = message.content;
    if (content == null || content.isEmpty) return '';
    return content
        .where((item) => item.type == 'text' && item.text != null)
        .map((item) => item.text!)
        .join(' ')
        .trim();
  }

  _AiNarrativeDraft? _parseNarrativeDraft(
    String rawJson,
    StoryGenerationRequest request,
  ) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map) return null;
      final map = decoded.map(
        (dynamic key, dynamic value) => MapEntry(key.toString(), value),
      );

      final title = _sanitizeNarrativeValue(
        map['title']?.toString() ?? '',
        maxLength: 96,
      );
      final body = _sanitizeNarrativeValue(
        map['body']?.toString() ?? '',
        maxLength: _maxStoryBodyLength,
      );
      if (title.isEmpty || body.isEmpty) return null;

      final desiredSceneCount = request.sceneCount.clamp(2, 5);
      final scenes = <StoryScene>[];
      final rawScenes = map['scenes'];
      if (request.sceneMode && rawScenes is List) {
        for (var i = 0;
            i < rawScenes.length && scenes.length < desiredSceneCount;
            i++) {
          final entry = rawScenes[i];
          if (entry is! Map) continue;
          final sceneMap = entry.map(
            (dynamic key, dynamic value) => MapEntry(key.toString(), value),
          );
          final sceneTitle = _sanitizeNarrativeValue(
            sceneMap['title']?.toString() ?? '',
            maxLength: 72,
          );
          final sceneText = _sanitizeNarrativeValue(
            sceneMap['text']?.toString() ?? '',
            maxLength: _maxSceneTextLength,
          );
          if (sceneTitle.isEmpty || sceneText.isEmpty) continue;
          final order = scenes.length + 1;
          scenes.add(
            StoryScene(
              id: '${DateTime.now().millisecondsSinceEpoch}_ai_$order',
              order: order,
              title: sceneTitle,
              text: sceneText,
              imageUrl: '',
            ),
          );
        }
      }

      return _AiNarrativeDraft(
        title: title,
        body: body,
        scenes: scenes,
      );
    } catch (_) {
      return null;
    }
  }

  String _sanitizeNarrativeValue(
    String value, {
    required int maxLength,
  }) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return '';
    if (compact.length <= maxLength) return compact;
    return compact.substring(0, maxLength).trimRight();
  }

  List<StoryScene> _resolveDraftScenes({
    required StoryGenerationRequest request,
    required String title,
    required String body,
    required List<StoryScene> aiScenes,
  }) {
    if (!request.sceneMode) return const <StoryScene>[];

    final desiredSceneCount = request.sceneCount.clamp(2, 5);
    final sanitizedAiScenes = aiScenes
        .where(
          (scene) =>
              scene.title.trim().isNotEmpty && scene.text.trim().isNotEmpty,
        )
        .take(desiredSceneCount)
        .toList(growable: true);

    if (sanitizedAiScenes.isEmpty) {
      return _buildScenes(
        request,
        title: title,
        fallbackBody: body,
      );
    }

    for (var i = 0; i < sanitizedAiScenes.length; i++) {
      final existing = sanitizedAiScenes[i];
      sanitizedAiScenes[i] = StoryScene(
        id: existing.id.trim().isEmpty
            ? '${DateTime.now().millisecondsSinceEpoch}_${i + 1}'
            : existing.id,
        order: i + 1,
        title: existing.title,
        text: existing.text,
        imageUrl: existing.imageUrl,
      );
    }

    while (sanitizedAiScenes.length < desiredSceneCount) {
      final fallbackIndex = sanitizedAiScenes.length + 1;
      sanitizedAiScenes.add(
        StoryScene(
          id: '${DateTime.now().millisecondsSinceEpoch}_fallback_$fallbackIndex',
          order: fallbackIndex,
          title: 'Sahne $fallbackIndex',
          text: _sceneNarrative(
            request,
            sceneOrder: fallbackIndex,
            total: desiredSceneCount,
            fallbackBody: body,
          ),
          imageUrl: '',
        ),
      );
    }

    return sanitizedAiScenes;
  }

  Future<_StoryVisualBundle> _buildVisualBundle({
    required StoryGenerationRequest request,
    required String title,
    required String body,
    required List<StoryScene> scenes,
  }) async {
    final toyImageUrl = request.characterProfile?.toyImageUrl.trim() ?? '';
    final referenceImageFile = await _prepareToyReferenceImage(toyImageUrl);
    final shouldUseReference = referenceImageFile != null;
    final aiAllowed = await _connectivity.isConnected();

    try {
      if (scenes.isEmpty) {
        final coverImage = await _generateImageUrl(
          prompt: _buildCoverImagePrompt(
            request: request,
            title: title,
            body: body,
          ),
          fallbackLabel: title,
          userId: request.userId,
          referenceImageFile: referenceImageFile,
          useToyReference: shouldUseReference,
          allowAi: aiAllowed,
        );
        return _StoryVisualBundle(
          coverImageUrl: coverImage.url,
          scenes: const <StoryScene>[],
          usedAiImages: coverImage.usedAiImage,
          usedReferenceImage: coverImage.usedReferenceImage,
        );
      }

      var usedAiImages = false;
      var usedReferenceImage = false;
      final sceneImageResults = await Future.wait(
        scenes.map(
          (scene) => _generateImageUrl(
            prompt: _buildSceneImagePrompt(
              request: request,
              title: title,
              scene: scene,
            ),
            fallbackLabel: '$title ${scene.title}',
            userId: request.userId,
            referenceImageFile: referenceImageFile,
            useToyReference: shouldUseReference,
            allowAi: aiAllowed,
          ),
        ),
      );

      final visualScenes = <StoryScene>[];
      for (var i = 0; i < scenes.length; i++) {
        final scene = scenes[i];
        final sceneImage = sceneImageResults[i];
        usedAiImages = usedAiImages || sceneImage.usedAiImage;
        usedReferenceImage =
            usedReferenceImage || sceneImage.usedReferenceImage;
        visualScenes.add(
          StoryScene(
            id: scene.id,
            order: scene.order,
            title: scene.title,
            text: scene.text,
            imageUrl: sceneImage.url,
          ),
        );
      }

      return _StoryVisualBundle(
        coverImageUrl: visualScenes.first.imageUrl,
        scenes: visualScenes,
        usedAiImages: usedAiImages,
        usedReferenceImage: usedReferenceImage,
      );
    } finally {
      if (referenceImageFile != null) {
        try {
          await referenceImageFile.delete();
        } catch (_) {}
      }
    }
  }

  Future<_GeneratedImageResult> _generateImageUrl({
    required String prompt,
    required String fallbackLabel,
    required String userId,
    required File? referenceImageFile,
    required bool useToyReference,
    required bool allowAi,
  }) async {
    if (!allowAi) {
      return _GeneratedImageResult(
        url: _buildImageUrl(fallbackLabel),
        usedAiImage: false,
        usedReferenceImage: false,
      );
    }

    if (useToyReference && referenceImageFile != null) {
      final edited = await _generateImageFromReference(
        prompt: prompt,
        referenceImageFile: referenceImageFile,
        userId: userId,
        allowAi: allowAi,
      );
      if (edited != null) return edited;
    }

    if (!_consumeRateLimitToken(userId)) {
      debugPrint('AI image generation rate limit exceeded for user: $userId');
      return _GeneratedImageResult(
        url: _buildImageUrl(fallbackLabel),
        usedAiImage: false,
        usedReferenceImage: false,
      );
    }

    try {
      final response = await OpenAI.instance.image.create(
        model: _imageCreateModel,
        prompt: _normalizeImagePrompt(prompt),
        n: 1,
        size: OpenAIImageSize.size1024,
        style: OpenAIImageStyle.vivid,
        responseFormat: OpenAIImageResponseFormat.url,
        user: userId.trim().isEmpty ? null : userId,
      );

      for (final image in response.data) {
        final url = (image.url ?? '').trim();
        if (url.isNotEmpty) {
          return _GeneratedImageResult(
            url: url,
            usedAiImage: true,
            usedReferenceImage: false,
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('AI image generation failed: $error\n$stackTrace');
    }

    return _GeneratedImageResult(
      url: _buildImageUrl(fallbackLabel),
      usedAiImage: false,
      usedReferenceImage: false,
    );
  }

  Future<_GeneratedImageResult?> _generateImageFromReference({
    required String prompt,
    required File referenceImageFile,
    required String userId,
    required bool allowAi,
  }) async {
    if (!allowAi) return null;
    if (!_consumeRateLimitToken(userId)) {
      debugPrint('AI image edit rate limit exceeded for user: $userId');
      return null;
    }

    try {
      final response = await OpenAI.instance.image.edit(
        model: _imageEditModel,
        image: referenceImageFile,
        prompt: _normalizeImagePrompt(
          '$prompt Keep the same toy identity and silhouette from the reference image. '
          'Make it a child-safe 2.5D layered story scene with gentle cinematic depth.',
        ),
        n: 1,
        size: OpenAIImageSize.size1024,
        responseFormat: OpenAIImageResponseFormat.url,
        user: userId.trim().isEmpty ? null : userId,
      );

      for (final image in response.data) {
        final url = (image.url ?? '').trim();
        if (url.isNotEmpty) {
          return _GeneratedImageResult(
            url: url,
            usedAiImage: true,
            usedReferenceImage: true,
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Reference image generation failed: $error\n$stackTrace');
    }

    return null;
  }

  Future<File?> _prepareToyReferenceImage(String toyImageUrl) async {
    if (toyImageUrl.isEmpty) return null;

    final uri = Uri.tryParse(toyImageUrl);
    if (uri == null || !_isAllowedReferenceUri(uri)) return null;

    try {
      final response = await http.get(
        uri,
        headers: const <String, String>{
          'Range': 'bytes=0-2097151',
        },
      ).timeout(_networkTimeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      if (response.bodyBytes.isEmpty ||
          response.bodyBytes.length > _maxReferenceImageBytes) {
        return null;
      }

      final contentTypeHeader = response.headers['content-type'] ?? '';
      if (!contentTypeHeader.toLowerCase().startsWith('image/')) {
        return null;
      }

      final contentLength =
          _readContentLength(response.headers['content-length']);
      if (contentLength != null && contentLength > _maxReferenceImageBytes) {
        return null;
      }

      final normalizedPng = await _convertToSquarePng(response.bodyBytes);
      final tempDir = await getTemporaryDirectory();
      final outputFile = File(
        '${tempDir.path}/toy_ref_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await outputFile.writeAsBytes(normalizedPng, flush: true);
      return outputFile;
    } catch (error, stackTrace) {
      debugPrint('Toy reference image prep failed: $error\n$stackTrace');
      return null;
    }
  }

  Future<Uint8List> _convertToSquarePng(Uint8List sourceBytes) async {
    final codec = await ui.instantiateImageCodec(sourceBytes);
    final frameInfo = await codec.getNextFrame();
    final sourceImage = frameInfo.image;

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final canvasSize = _referenceImageSize.toDouble();

    canvas.drawRect(
      ui.Rect.fromLTWH(0, 0, canvasSize, canvasSize),
      ui.Paint()..color = const ui.Color(0xFFFFFFFF),
    );

    final sourceRect = _coverCropRect(
      width: sourceImage.width.toDouble(),
      height: sourceImage.height.toDouble(),
    );
    final targetRect = ui.Rect.fromLTWH(0, 0, canvasSize, canvasSize);

    canvas.drawImageRect(
      sourceImage,
      sourceRect,
      targetRect,
      ui.Paint()
        ..isAntiAlias = true
        ..filterQuality = ui.FilterQuality.high,
    );

    final picture = recorder.endRecording();
    final squaredImage =
        await picture.toImage(_referenceImageSize, _referenceImageSize);
    final byteData = await squaredImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    if (byteData == null) return sourceBytes;
    return byteData.buffer.asUint8List();
  }

  int? _readContentLength(String? headerValue) {
    if (headerValue == null || headerValue.trim().isEmpty) return null;
    return int.tryParse(headerValue.trim());
  }

  bool _isAllowedReferenceUri(Uri uri) {
    if (!uri.isAbsolute || uri.scheme.toLowerCase() != 'https') {
      return false;
    }

    final host = uri.host.toLowerCase();
    if (host.isEmpty ||
        host == 'localhost' ||
        host.endsWith('.local') ||
        _isPrivateAddress(host)) {
      return false;
    }

    if (_allowedReferenceHosts.contains(host)) {
      return true;
    }

    return host.endsWith('.firebasestorage.app') ||
        host.endsWith('.googleusercontent.com');
  }

  bool _isPrivateAddress(String host) {
    final parsed = InternetAddress.tryParse(host);
    if (parsed == null) return false;

    if (parsed.isLoopback || parsed.isLinkLocal || parsed.isMulticast) {
      return true;
    }

    if (parsed.type == InternetAddressType.IPv4) {
      final bytes = parsed.rawAddress;
      final first = bytes[0];
      final second = bytes[1];
      final is10 = first == 10;
      final is172 = first == 172 && second >= 16 && second <= 31;
      final is192 = first == 192 && second == 168;
      final is127 = first == 127;
      return is10 || is172 || is192 || is127;
    }

    final normalized = host.toLowerCase();
    return normalized.startsWith('fc') || normalized.startsWith('fd');
  }

  bool _consumeRateLimitToken(String userId) {
    final normalizedUser =
        userId.trim().isEmpty ? 'guest' : userId.trim().toLowerCase();
    final now = DateTime.now();
    final window = _rateWindows[normalizedUser];

    if (window == null ||
        now.difference(window.windowStart) > _rateLimitWindow) {
      _rateWindows[normalizedUser] = _RateLimitWindow(
        windowStart: now,
        usedRequestCount: 1,
      );
      return true;
    }

    if (window.usedRequestCount >= _maxImageRequestsPerWindow) {
      return false;
    }

    _rateWindows[normalizedUser] = window.copyWith(
      usedRequestCount: window.usedRequestCount + 1,
    );
    return true;
  }

  ui.Rect _coverCropRect({
    required double width,
    required double height,
  }) {
    if (width <= 0 || height <= 0) {
      return const ui.Rect.fromLTWH(0, 0, 1, 1);
    }
    if (width == height) {
      return ui.Rect.fromLTWH(0, 0, width, height);
    }
    if (width > height) {
      final left = (width - height) / 2;
      return ui.Rect.fromLTWH(left, 0, height, height);
    }
    final top = (height - width) / 2;
    return ui.Rect.fromLTWH(0, top, width, width);
  }

  String _buildCoverImagePrompt({
    required StoryGenerationRequest request,
    required String title,
    required String body,
  }) {
    final hasToyReference =
        request.characterProfile?.toyImageUrl.trim().isNotEmpty ?? false;
    final parts = <String>[
      'Child-safe storybook illustration.',
      'No text, no letters, no watermark.',
      '2.5D layered parallax style, toy-like depth, cinematic composition.',
      'Vibrant but soft lighting.',
      'Main story title cue: $title.',
      'Theme: ${request.prompt}.',
      'Narrative mood: ${_styleVisualHint(request.style)}.',
      'Palette: ${_paletteVisualHint(request.colorPalette)}.',
      'Age range: ${request.ageProfile.key}.',
      'Story summary: ${_shortenForImagePrompt(body)}.',
    ];

    if (request.characterProfile != null) {
      parts.add(
        'Main character: ${request.characterProfile!.name}, ${request.characterProfile!.personality}, power ${request.characterProfile!.power}, world ${request.characterProfile!.world}.',
      );
    }
    if (hasToyReference) {
      parts.add(
        'Character must match the uploaded toy reference image identity.',
      );
    }

    return parts.join(' ');
  }

  String _buildSceneImagePrompt({
    required StoryGenerationRequest request,
    required String title,
    required StoryScene scene,
  }) {
    final hasToyReference =
        request.characterProfile?.toyImageUrl.trim().isNotEmpty ?? false;
    final parts = <String>[
      'Child-safe illustration for a story scene.',
      'No text, no watermark.',
      '2.5D layered parallax style with gentle depth.',
      'Consistent characters with previous scenes.',
      'Story: $title.',
      'Scene title: ${scene.title}.',
      'Scene narrative: ${_shortenForImagePrompt(scene.text)}.',
      'Style mood: ${_styleVisualHint(request.style)}.',
      'Palette: ${_paletteVisualHint(request.colorPalette)}.',
      'Theme: ${request.prompt}.',
    ];

    if (request.characterProfile != null) {
      parts.add(
        'Character look: ${request.characterProfile!.name}, ${request.characterProfile!.personality}, ${request.characterProfile!.power}.',
      );
    }
    if (hasToyReference) {
      parts.add(
        'Use the same toy character from uploaded reference photo in this scene.',
      );
    }

    return parts.join(' ');
  }

  String _styleVisualHint(StoryStyle style) {
    switch (style) {
      case StoryStyle.fairyTale:
        return 'magical fairy-tale fantasy';
      case StoryStyle.funny:
        return 'playful and humorous';
      case StoryStyle.adventure:
        return 'dynamic adventure';
      case StoryStyle.educational:
        return 'curious and discovery-driven';
      case StoryStyle.bedtime:
        return 'calm bedtime serenity';
    }
  }

  String _paletteVisualHint(StoryColorPalette palette) {
    switch (palette) {
      case StoryColorPalette.auto:
        return 'balanced child-friendly colors';
      case StoryColorPalette.vibrant:
        return 'vibrant blue pink yellow';
      case StoryColorPalette.pastel:
        return 'soft pastel tones';
      case StoryColorPalette.warmSunset:
        return 'warm sunset orange coral gold';
      case StoryColorPalette.forest:
        return 'forest greens and earthy tones';
      case StoryColorPalette.ocean:
        return 'ocean blue turquoise';
      case StoryColorPalette.candy:
        return 'candy pink mint lilac';
    }
  }

  String _shortenForImagePrompt(String text) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= 180) return compact;
    return compact.substring(0, 180).trimRight();
  }

  String _normalizeImagePrompt(String prompt) {
    final compact = prompt.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= _maxImagePromptLength) return compact;
    return compact.substring(0, _maxImagePromptLength).trimRight();
  }

  String _buildTitle(StoryGenerationRequest request) {
    final normalized = request.prompt.trim();
    final shortPrompt = normalized.length > 28
        ? normalized.substring(0, 28).trimRight()
        : normalized;

    if (request.parentStory == null) {
      return 'Hayal Hikayesi: $shortPrompt';
    }

    return '${request.parentStory!.title} - Bolum ${request.parentStory!.chapterIndex + 1}';
  }

  String _buildBody(StoryGenerationRequest request, {required String title}) {
    final intro = request.parentStory == null
        ? 'Bir varmis bir yokmus, "$title" adli hikaye baslamis.'
        : 'Onceki bolumun ardindan yeni bir sayfa acilmis.';

    final characterLine = request.characterProfile == null
        ? 'Kahramanimiz merakli ve cesur bir cocuktu.'
        : '${request.characterProfile!.name}, ${request.characterProfile!.personality.toLowerCase()} bir kahramandi. '
            'En guclu yani ${request.characterProfile!.power.toLowerCase()} idi.';

    final worldLine = request.characterProfile == null
        ? 'Etrafta kesfedilecek gizemli yerler vardi.'
        : 'Hikaye ${request.characterProfile!.world.toLowerCase()} dunyasinda geciyordu.';

    final styleLine = _styleLine(request.style);
    final ageLine = _ageLine(request.ageProfile);
    final paletteLine = _paletteLine(request.colorPalette);
    final toyReferenceLine = request.characterProfile?.toyImageUrl
                .trim()
                .isNotEmpty ==
            true
        ? 'Bu hikayede yuklenen oyuncak kahramanin gorunumu tum sahnelerde korunmustur.'
        : '';

    final closure = request.style == StoryStyle.educational
        ? 'Gun sonunda herkes paylasmanin ve birlikte dusunmenin gucunu ogrendi.'
        : 'Macera biterken kahramanimiz yeni bir hayal kurmayi ihmal etmedi.';

    return [
      intro,
      characterLine,
      worldLine,
      styleLine,
      'Bugunun gorevi: ${request.prompt}.',
      if (toyReferenceLine.isNotEmpty) toyReferenceLine,
      ageLine,
      paletteLine,
      closure,
    ].join(' ');
  }

  String _styleLine(StoryStyle style) {
    switch (style) {
      case StoryStyle.fairyTale:
        return 'Gokyuzunden yumusak bir isik inmis ve her sey masal gibi gorunmus.';
      case StoryStyle.funny:
        return 'Yolda minik ama cok komik surprizler cikmis, herkes gulmus.';
      case StoryStyle.adventure:
        return 'Haritanin kenarinda sakli bir yol bulunmus ve kesif hizlanmis.';
      case StoryStyle.educational:
        return 'Yolculukta hem eglence hem de yeni bir bilgi ogrenme firsati olmus.';
      case StoryStyle.bedtime:
        return 'Ruzgar sakinlesmis, hikaye yavas yavas huzurlu bir ritme donmus.';
    }
  }

  String _ageLine(StoryAgeProfile ageProfile) {
    switch (ageProfile) {
      case StoryAgeProfile.age4to6:
        return 'Cumleler kisa tutulmus. Her adim kolayca anlasilmis.';
      case StoryAgeProfile.age7to9:
        return 'Her bolumde minik bir gizem ve net bir cozum yer almis.';
      case StoryAgeProfile.age10to12:
        return 'Karakterler karar vermek zorunda kalmis ve secimlerinin sonucunu gormus.';
      case StoryAgeProfile.unknown:
        return 'Hikaye hem basit hem de merak uyandirici bir denge kurmus.';
    }
  }

  String _paletteLine(StoryColorPalette palette) {
    switch (palette) {
      case StoryColorPalette.auto:
        return 'Renkler hikayenin ruhuna gore dengeli secilmis.';
      case StoryColorPalette.vibrant:
        return 'Sahnelerde canli ve enerjik renkler dikkat cekmis.';
      case StoryColorPalette.pastel:
        return 'Pastel tonlar hikayeye yumusak bir sicaklik katmis.';
      case StoryColorPalette.warmSunset:
        return 'Sicak gun batimi tonlari ortama umutlu bir isik vermis.';
      case StoryColorPalette.forest:
        return 'Yesil ve toprak tonlari kesif duygusunu guclendirmis.';
      case StoryColorPalette.ocean:
        return 'Mavi ve turkuaz tonlar ferah bir atmosfer olusturmus.';
      case StoryColorPalette.candy:
        return 'Sekersi renkler hikayeyi neseli ve oyuncu hale getirmis.';
    }
  }

  List<StoryScene> _buildScenes(
    StoryGenerationRequest request, {
    required String title,
    required String fallbackBody,
  }) {
    if (!request.sceneMode) {
      return const <StoryScene>[];
    }

    final count = request.sceneCount.clamp(2, 5);
    return List<StoryScene>.generate(count, (index) {
      final sceneOrder = index + 1;
      final sceneTitle = 'Sahne $sceneOrder';
      final sceneText = _sceneNarrative(
        request,
        sceneOrder: sceneOrder,
        total: count,
        fallbackBody: fallbackBody,
      );

      return StoryScene(
        id: '${DateTime.now().millisecondsSinceEpoch}_$sceneOrder',
        order: sceneOrder,
        title: sceneTitle,
        text: sceneText,
        imageUrl: _buildImageUrl('$title $sceneTitle'),
      );
    });
  }

  String _sceneNarrative(
    StoryGenerationRequest request, {
    required int sceneOrder,
    required int total,
    required String fallbackBody,
  }) {
    final heroName = request.characterProfile?.name.trim().isNotEmpty == true
        ? request.characterProfile!.name.trim()
        : 'Kahraman';
    final hasToyReference =
        request.characterProfile?.toyImageUrl.trim().isNotEmpty ?? false;

    if (sceneOrder == 1) {
      final referenceLine = hasToyReference
          ? '$heroName, yuklenen oyuncak kimligiyle hikayeye can verdi.'
          : '$heroName yolculuga basladi.';
      return '$referenceLine Hedef: ${request.prompt}.';
    }

    if (sceneOrder == total) {
      return request.style == StoryStyle.bedtime
          ? 'Gun huzurla bitti. $heroName derin bir nefes alip dinlenmeye gecti.'
          : 'Son adimda gorev tamamlandi ve $heroName mutlu bir sekilde kutlama yapti.';
    }

    if (sceneOrder == 2) {
      return 'Yolda bir engel cikti; $heroName cesaretini kullanip cozum uretmeye calisti.';
    }

    if (sceneOrder == 3) {
      return 'Bir dost yardim etti ve $heroName ekip olarak yeni bir yol buldu.';
    }

    return fallbackBody;
  }

  String _buildImageUrl(String label) {
    final safeText = _sanitizeSvgText(label, maxLength: 42);
    final svg = '''
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="576" viewBox="0 0 1024 576">
  <defs>
    <linearGradient id="bg" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0%" stop-color="#9CC0FF"/>
      <stop offset="100%" stop-color="#F5B4D6"/>
    </linearGradient>
  </defs>
  <rect width="1024" height="576" fill="url(#bg)"/>
  <g transform="translate(512 288)">
    <rect x="-322" y="-82" rx="28" ry="28" width="644" height="164" fill="#FFFFFF" fill-opacity="0.84"/>
    <text x="0" y="-8" text-anchor="middle" fill="#31496B" font-size="44" font-family="Arial">$safeText</text>
    <text x="0" y="44" text-anchor="middle" fill="#4F6286" font-size="22" font-family="Arial">SketchMind fallback visual</text>
  </g>
</svg>
''';
    return 'data:image/svg+xml;utf8,${Uri.encodeComponent(svg)}';
  }

  String _sanitizeSvgText(String value, {required int maxLength}) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.isEmpty) return 'Hikaye Gorseli';
    final shortened = compact.length <= maxLength
        ? compact
        : compact.substring(0, maxLength).trimRight();
    return shortened
        .replaceAll('&', 've')
        .replaceAll('<', '')
        .replaceAll('>', '')
        .replaceAll('"', "'");
  }

  List<QuizQuestion> _buildQuizQuestions({
    required StoryGenerationRequest request,
    required String title,
    required String body,
    required List<StoryScene> scenes,
  }) {
    final heroName = request.characterProfile?.name.trim().isNotEmpty == true
        ? request.characterProfile!.name.trim()
        : 'Kahraman';
    final mission =
        request.prompt.trim().isEmpty ? title : request.prompt.trim();
    final endingTone = _resolveEndingTone(body, scenes);

    final missionOptions = _buildOptions(
      correct: mission,
      distractors: const <String>[
        'Hicbir sey yapmamak',
        'Yarisi hemen birakmak',
        'Eve donup uyumak',
      ],
    );
    final toneOptions = _buildOptions(
      correct: endingTone,
      distractors: const <String>[
        'Cok karamsar ve umutsuz',
        'Kavgayla biten bir son',
        'Belirsiz ve eksik kapanis',
      ],
    );

    final missionCorrectIndex = _placeCorrectAnswer(
      missionOptions,
      seed: '${title}_mission',
    );
    final toneCorrectIndex = _placeCorrectAnswer(
      toneOptions,
      seed: '${title}_tone',
    );

    return <QuizQuestion>[
      QuizQuestion(
        question: '$heroName bu hikayede hangi gorevi takip etti?',
        options: missionOptions,
        correctIndex: missionCorrectIndex,
      ),
      QuizQuestion(
        question:
            'Hikayenin sonundaki duygu tonu en iyi hangi secenekle anlatilir?',
        options: toneOptions,
        correctIndex: toneCorrectIndex,
      ),
    ];
  }

  String _resolveEndingTone(String body, List<StoryScene> scenes) {
    final corpus = <String>[
      body.toLowerCase(),
      if (scenes.isNotEmpty) scenes.last.text.toLowerCase(),
    ].join(' ');

    if (RegExp(r'huzur|sakin|dinlen').hasMatch(corpus)) {
      return 'Sakin ve huzurlu';
    }
    if (RegExp(r'kutla|mutlu|umut|sevinc').hasMatch(corpus)) {
      return 'Umutlu ve sicak';
    }
    return 'Pozitif ve ogrenmeye acik';
  }

  List<String> _buildOptions({
    required String correct,
    required List<String> distractors,
  }) {
    final normalizedCorrect =
        correct.trim().isEmpty ? 'Tema gorevi' : correct.trim();
    final options = <String>[normalizedCorrect];
    for (final distractor in distractors) {
      final trimmed = distractor.trim();
      if (trimmed.isEmpty || options.contains(trimmed)) continue;
      options.add(trimmed);
      if (options.length == 4) break;
    }
    while (options.length < 4) {
      options.add('Secenek ${options.length + 1}');
    }
    return options;
  }

  int _placeCorrectAnswer(List<String> options, {required String seed}) {
    if (options.isEmpty) return 0;
    final hash = seed.codeUnits.fold<int>(
      0,
      (acc, codeUnit) => (acc * 31 + codeUnit) & 0x7fffffff,
    );
    final targetIndex = hash % options.length;
    if (targetIndex == 0) return 0;
    final first = options[0];
    options[0] = options[targetIndex];
    options[targetIndex] = first;
    return targetIndex;
  }
}

class _CachedDraft {
  const _CachedDraft({
    required this.draft,
    required this.createdAt,
  });

  final StoryGenerationDraft draft;
  final DateTime createdAt;
}

class _StoryVisualBundle {
  const _StoryVisualBundle({
    required this.coverImageUrl,
    required this.scenes,
    required this.usedAiImages,
    required this.usedReferenceImage,
  });

  final String coverImageUrl;
  final List<StoryScene> scenes;
  final bool usedAiImages;
  final bool usedReferenceImage;
}

class _GeneratedImageResult {
  const _GeneratedImageResult({
    required this.url,
    required this.usedAiImage,
    required this.usedReferenceImage,
  });

  final String url;
  final bool usedAiImage;
  final bool usedReferenceImage;
}

class _AiNarrativeDraft {
  const _AiNarrativeDraft({
    required this.title,
    required this.body,
    required this.scenes,
  });

  final String title;
  final String body;
  final List<StoryScene> scenes;
}

class _RateLimitWindow {
  const _RateLimitWindow({
    required this.windowStart,
    required this.usedRequestCount,
  });

  final DateTime windowStart;
  final int usedRequestCount;

  _RateLimitWindow copyWith({
    DateTime? windowStart,
    int? usedRequestCount,
  }) {
    return _RateLimitWindow(
      windowStart: windowStart ?? this.windowStart,
      usedRequestCount: usedRequestCount ?? this.usedRequestCount,
    );
  }
}
