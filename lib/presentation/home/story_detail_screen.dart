import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/stories.dart';
import '../../data/i_story_service.dart';
import '../../data/services/auth_service.dart';
import '../../data/services/family_settings_service.dart';
import '../../data/services/firestore_story_service.dart';
import '../../data/services/learning_progress_service.dart';
import '../../data/services/local_user_service.dart';
import '../../data/services/openai_story_service.dart';
import '../../data/services/story_companion_service.dart';
import '../../data/services/story_generation_models.dart';
import '../../data/services/tts_services.dart';
import '../../presentation/learning/vocabulary_trainer_screen.dart';
import '../../presentation/quiz/quiz_dialog.dart';
import '../../router/app_router.dart';
import '../theme/playful_theme.dart';
import 'widgets/parallax_story_image.dart';

class StoryDetailScreen extends StatefulWidget {
  const StoryDetailScreen({super.key, required this.story});

  final Story story;

  @override
  State<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends State<StoryDetailScreen> {
  final TTSService _ttsService = TTSService();
  final FirestoreStoryService _firestoreService = FirestoreStoryService();
  final AuthService _authService = AuthService();
  final LocalUserService _localUserService = LocalUserService();
  final FamilySettingsService _familySettingsService = FamilySettingsService();
  final IStoryService _storyService = OpenAIStoryService();
  final LearningProgressService _learningProgressService =
      LearningProgressService();
  final StoryCompanionService _storyCompanionService = StoryCompanionService();

  bool _isSpeaking = false;
  bool _canDelete = false;
  bool _isContinuing = false;
  int _highlightStart = -1;
  int _highlightEnd = -1;
  late DateTime _openedAt;
  ReadingAccessibilityProfile _readingProfile =
      const ReadingAccessibilityProfile();
  FamilySafetySettings _familySettings = const FamilySafetySettings();
  bool _isExperienceReady = false;
  bool _autoplayHandled = false;
  final Map<String, String> _dialogicAnswers = <String, String>{};
  Set<String> _completedFamilyTasks = <String>{};
  final Map<String, int> _sceneQuizSelections = <String, int>{};
  late final List<DialogicPrompt> _dialogicPrompts;
  late final List<FamilyStoryTask> _familyTasks;
  bool _exitMetricsFlushed = false;

  @override
  void initState() {
    super.initState();
    _openedAt = DateTime.now();
    _dialogicPrompts =
        _storyCompanionService.buildDialogicPrompts(widget.story);
    _familyTasks = _storyCompanionService.buildFamilyTasks(widget.story);
    _ttsService.progressNotifier.addListener(_onTtsProgressChanged);
    _ttsService.speakingNotifier.addListener(_onSpeakingStateChanged);
    _checkDeletePermission();
    _loadExperienceSettings();
    _loadFamilyTaskState();
  }

  @override
  void dispose() {
    _ttsService.progressNotifier.removeListener(_onTtsProgressChanged);
    _ttsService.speakingNotifier.removeListener(_onSpeakingStateChanged);
    _flushExitMetrics();
    super.dispose();
  }

  void _flushExitMetrics() {
    if (_exitMetricsFlushed) return;
    _exitMetricsFlushed = true;

    unawaited(
      _ttsService.stop().catchError((Object error, StackTrace stackTrace) {
        debugPrint('TTS stop on dispose failed: $error\n$stackTrace');
      }),
    );

    final readSeconds = DateTime.now().difference(_openedAt).inSeconds;
    if (readSeconds < 20) return;

    final readMinutes = ((readSeconds / 60).ceil()).clamp(1, 60).toInt();
    unawaited(
      _learningProgressService
          .recordStoryRead(minutes: readMinutes)
          .catchError((Object error, StackTrace stackTrace) {
        debugPrint(
          'Story read progress save failed on dispose: $error\n$stackTrace',
        );
      }),
    );
  }

  Future<void> _loadExperienceSettings() async {
    final userId = await _localUserService.getSelectedUserId();
    final readingProfile =
        await _localUserService.getReadingAccessibilityProfile(userId);
    await _familySettingsService.syncFromCloudAndMerge();
    final familySettings = await _familySettingsService.getSettings();
    await _ttsService.applyVoiceSettings(
      rate: readingProfile.ttsRate,
      pitch: readingProfile.ttsPitch,
    );

    if (!mounted) return;
    setState(() {
      _readingProfile = readingProfile;
      _familySettings = familySettings;
      _isExperienceReady = true;
    });
    _attemptAutoplayNarration();
  }

  Future<void> _loadFamilyTaskState() async {
    final completed =
        await _storyCompanionService.getCompletedTaskIds(widget.story.id);
    if (!mounted) return;
    setState(() => _completedFamilyTasks = completed);
  }

  Future<void> _toggleFamilyTask(FamilyStoryTask task, bool value) async {
    await _storyCompanionService.setTaskCompleted(
      storyId: widget.story.id,
      taskId: task.id,
      completed: value,
    );
    if (!mounted) return;
    setState(() {
      final next = <String>{..._completedFamilyTasks};
      if (value) {
        next.add(task.id);
      } else {
        next.remove(task.id);
      }
      _completedFamilyTasks = next;
    });

    if (value) {
      unawaited(
          _learningProgressService.recordHintUsage(context: 'family_task'));
    }
  }

  void _attemptAutoplayNarration() {
    if (_autoplayHandled) return;
    if (!_isExperienceReady) return;
    if (!_familySettings.allowAutoplayNarration) return;
    if (_isSpeaking) return;
    _autoplayHandled = true;
    unawaited(_toggleSpeaking());
  }

  IconData _taskIcon(String token) {
    switch (token) {
      case 'draw':
        return Icons.brush_outlined;
      case 'retell':
        return Icons.record_voice_over_outlined;
      case 'roleplay':
        return Icons.theater_comedy_outlined;
      case 'discover':
        return Icons.search_outlined;
      case 'calm':
        return Icons.self_improvement_outlined;
      default:
        return Icons.checklist_rtl_outlined;
    }
  }

  Widget _buildDialogicReadingSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dialogik Okuma Modu',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hikaye uzerinden acik uclu sorularla dusunme ve anlatimi guclendir.',
            ),
            const SizedBox(height: 8),
            ..._dialogicPrompts.map((prompt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F9FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFD9E1F5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prompt.question,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ebeveyn ipucu: ${prompt.coachTip}',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _dialogicAnswers[prompt.id] ?? '',
                        onChanged: (value) =>
                            _dialogicAnswers[prompt.id] = value.trim(),
                        decoration: const InputDecoration(
                          hintText: 'Cocugun cevabini buraya yaz...',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFamilyTasksSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aile Etkinlik Gorevleri',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Hikaye sonrasinda 5 dakikalik aile etkinlikleri ile ogrenmeyi pekistir.',
            ),
            const SizedBox(height: 8),
            ..._familyTasks.map((task) {
              final checked = _completedFamilyTasks.contains(task.id);
              return CheckboxListTile(
                value: checked,
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                secondary: Icon(
                  _taskIcon(task.icon),
                  color: const Color(0xFF6E78C6),
                ),
                title: Text(
                  task.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(task.description),
                onChanged: (value) {
                  if (value == null) return;
                  _toggleFamilyTask(task, value);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildTransparencyPanel(Story story) {
    if (!_familySettings.transparencyModeEnabled) {
      return const SizedBox.shrink();
    }

    final hasToyReference = story.modelUsed.contains('toy-ref') ||
        (story.characterProfile?.toyImageUrl.trim().isNotEmpty ?? false);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'AI Seffaflik ve Gizlilik',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(label: Text('Model: ${story.modelUsed}')),
                Chip(label: Text('Prompt surumu: ${story.promptVersion}')),
                Chip(label: Text('Uretim: ${story.generationMode}')),
                Chip(
                  label: Text(
                    "Moderasyon: ${story.isModerated ? 'Acik' : 'Kapali'}",
                  ),
                ),
                Chip(
                  label: Text(
                    hasToyReference
                        ? 'Oyuncak referansi: Acik'
                        : 'Oyuncak referansi: Yok',
                  ),
                ),
                Chip(
                  label: Text(
                    _familySettings.dataMinimizationMode
                        ? 'Veri minimizasyonu: Acik'
                        : 'Veri minimizasyonu: Kapali',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Saklanan alanlar: baslik, hikaye metni, sahne gorselleri, karakter profili, sinirli prompt ozeti.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkDeletePermission() async {
    final currentUid = await _authService.getCurrentUserId();
    final currentUserId = await _localUserService.getSelectedUserId();
    final isParent = await _localUserService.getIsParentMode();

    if (!mounted) return;

    final ownsStory =
        widget.story.ownerUid.isNotEmpty && widget.story.ownerUid == currentUid;
    final hasRolePermission =
        (currentUserId == widget.story.userId) || isParent;

    setState(() {
      _canDelete = ownsStory && hasRolePermission;
    });
  }

  void _onTtsProgressChanged() {
    final progress = _ttsService.progressNotifier.value;
    if (!mounted || progress == null) return;
    setState(() {
      _highlightStart = progress.start;
      _highlightEnd = progress.end;
    });
  }

  void _onSpeakingStateChanged() {
    if (!mounted) return;
    final speaking = _ttsService.speakingNotifier.value;
    if (!speaking) {
      setState(() {
        _isSpeaking = false;
        _highlightStart = -1;
        _highlightEnd = -1;
      });
      return;
    }
    if (!_isSpeaking) {
      setState(() => _isSpeaking = true);
    }
  }

  Future<void> _toggleSpeaking() async {
    if (_isSpeaking) {
      await _ttsService.stop();
      return;
    }

    await _ttsService.speak(widget.story.text);
  }

  void _openVocabularyMode() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VocabularyTrainerScreen(
          storyTitle: widget.story.title,
          storyText: widget.story.text,
        ),
      ),
    );
  }

  void _showQuiz() {
    if (widget.story.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu hikaye icin test bulunamadi.')),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) => QuizDialog(questions: widget.story.questions),
    );
  }

  void _showReadingScaffold() {
    final sentences = widget.story.text
        .split(RegExp(r'[.!?]'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final firstSentence =
        sentences.isNotEmpty ? sentences.first : widget.story.text;
    final lastSentence = sentences.length > 1 ? sentences.last : firstSentence;

    unawaited(
      _learningProgressService.recordHintUsage(context: 'reading_scaffold'),
    );

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Okuma Iskeleleme Ipuclari'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('1) Kim, nerede, ne zaman?'),
              const SizedBox(height: 6),
              const Text('2) Karakterin sorunu ne?'),
              const SizedBox(height: 6),
              const Text('3) Cozum icin hangi ipuclari var?'),
              const SizedBox(height: 10),
              Text('Baslangic ipucu: $firstSentence'),
              const SizedBox(height: 6),
              Text('Bitis ipucu: $lastSentence'),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Tamam'),
          ),
        ],
      ),
    );
  }

  Future<void> _continueStory() async {
    if (_isContinuing) return;

    final controller = TextEditingController();
    final continuationPrompt = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hikayeyi Devam Ettir'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Yeni bolumde neler olsun?',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () {
              final value = controller.text.trim();
              Navigator.of(dialogContext).pop(
                  value.isEmpty ? 'Devaminda yeni bir kesif olsun.' : value);
            },
            child: const Text('Yaz'),
          ),
        ],
      ),
    );

    controller.dispose();

    if (!mounted || continuationPrompt == null) return;

    final isParentMode = await _localUserService.getIsParentMode();
    final isDevModeBypass = await _localUserService.getDevModeBypass();
    final isChildMode = !isParentMode && !isDevModeBypass;
    if (isChildMode &&
        _familySettings.requireParentalConsentForAi &&
        !_familySettings.parentalConsentGranted) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Devam bolumu icin ebeveyn AI onayi gerekli.',
          ),
        ),
      );
      return;
    }

    setState(() => _isContinuing = true);

    try {
      final continuedStory = await _storyService.continueStory(
        parentStory: widget.story,
        continuationPrompt: continuationPrompt,
        sceneMode: widget.story.scenes.isNotEmpty,
        sceneCount: widget.story.scenes.isEmpty
            ? 3
            : widget.story.scenes.length.clamp(2, 5),
        dataMinimizationMode: _familySettings.dataMinimizationMode,
      );

      if (!mounted) return;
      context
          .push(AppRoutes.storyDetail.replaceFirst(':id', continuedStory.id));
    } catch (error) {
      final message = error is StoryPolicyException
          ? error.message
          : 'Devam hikayesi olusturulamadi. Lutfen tekrar deneyin.';

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (mounted) {
        setState(() => _isContinuing = false);
      }
    }
  }

  Future<void> _deleteStory() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hikayeyi Sil'),
        content: const Text('Bu hikayeyi silmek istedigine emin misin?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Iptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final requesterUid = await _authService.getCurrentUserId();
      await _firestoreService.deleteStory(
        widget.story.id,
        requesterUid: requesterUid,
      );
      if (!mounted) return;

      context.pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Hikaye silindi.')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bu hikayeyi silme izniniz yok veya oturum gecersiz.'),
        ),
      );
    }
  }

  Widget _buildSceneCard(StoryScene scene) {
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              scene.title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ParallaxStoryImage(
              imageUrl: scene.imageUrl,
              height: 170,
              borderRadius: 12,
              reducedMotion: _familySettings.lowStimulusModeEnabled,
            ),
            const SizedBox(height: 8),
            Text(scene.text),
            const SizedBox(height: 10),
            _buildSceneQuiz(scene),
          ],
        ),
      ),
    );
  }

  Widget _buildSceneQuiz(StoryScene scene) {
    final quiz = _storyCompanionService.buildSceneQuiz(
      story: widget.story,
      scene: scene,
    );
    final selected = _sceneQuizSelections[quiz.id];
    final answered = selected != null;
    final correct = answered && selected == quiz.correctIndex;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD9DFF2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Mini Sahne Quiz',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(quiz.question),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List<Widget>.generate(quiz.options.length, (index) {
              final option = quiz.options[index];
              final isSelected = selected == index;
              return ChoiceChip(
                label: Text(option),
                selected: isSelected,
                onSelected: (_) {
                  setState(() => _sceneQuizSelections[quiz.id] = index);
                  unawaited(
                    _learningProgressService.submitReviewResult(
                      cardId: 'scene_quiz_${scene.id}',
                      correct: index == quiz.correctIndex,
                    ),
                  );
                },
              );
            }),
          ),
          if (answered) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color:
                    correct ? const Color(0xFFE9F8EF) : const Color(0xFFFFF3EC),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                correct ? 'Dogru! ${quiz.explanation}' : 'Tekrar dene.',
                style: TextStyle(
                  color: correct
                      ? const Color(0xFF2D7B4D)
                      : const Color(0xFF9A5A36),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHighlightedStoryText(String text) {
    final baseStyle = TextStyle(
      fontSize: (18 * _readingProfile.fontScale).clamp(14.0, 30.0),
      height: 1.45,
      letterSpacing: _readingProfile.letterSpacing,
    );
    if (!_isSpeaking ||
        !_readingProfile.lineHighlightEnabled ||
        _highlightStart < 0 ||
        _highlightEnd <= _highlightStart ||
        _highlightStart >= text.length) {
      return Text(text, style: baseStyle);
    }

    final safeStart = _highlightStart.clamp(0, text.length).toInt();
    final safeEnd = _highlightEnd.clamp(safeStart, text.length).toInt();

    return RichText(
      text: TextSpan(
        style: baseStyle.copyWith(color: Colors.black87),
        children: [
          TextSpan(text: text.substring(0, safeStart)),
          TextSpan(
            text: text.substring(safeStart, safeEnd),
            style: baseStyle.copyWith(
              backgroundColor: Colors.yellow.withValues(alpha: 0.45),
              fontWeight: FontWeight.bold,
            ),
          ),
          TextSpan(text: text.substring(safeEnd)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: PlayfulPalette.storiesBackground),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: Text(story.title),
          actions: [
            IconButton(
              icon: Icon(_isSpeaking ? Icons.stop_circle : Icons.volume_up),
              color: _isSpeaking ? const Color(0xFFB175CC) : null,
              onPressed: _toggleSpeaking,
            ),
            if (_canDelete)
              IconButton(
                icon: const Icon(Icons.delete),
                color: const Color(0xFFC885B1),
                onPressed: _deleteStory,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ParallaxStoryImage(
                imageUrl: story.imageUrl,
                height: 210,
                borderRadius: 16,
                reducedMotion: _familySettings.lowStimulusModeEnabled,
              ),
              if (story.modelUsed.contains('dall-e')) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF5FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome,
                          size: 14, color: Color(0xFF3E6AA8)),
                      SizedBox(width: 6),
                      Text(
                        'AI kapak gorseli',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF3E6AA8),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(label: Text('Bolum ${story.chapterIndex}')),
                  Chip(label: Text('Yas ${story.ageProfile.key}')),
                  Chip(label: Text('Stil ${story.style.key}')),
                  Chip(label: Text('Palet ${story.colorPalette.displayLabel}')),
                  Chip(label: Text(story.generationMode)),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                story.title,
                style:
                    const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_isSpeaking) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFE6FF),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.record_voice_over,
                          size: 16, color: Color(0xFF6E63B5)),
                      SizedBox(width: 6),
                      Text(
                        'Sesli takip aktif',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6E63B5),
                        ),
                      ),
                    ],
                  ),
                ),
                _buildHighlightedStoryText(story.text),
              ] else
                Text(
                  story.text,
                  style: TextStyle(
                    fontSize:
                        (18 * _readingProfile.fontScale).clamp(14.0, 30.0),
                    height: 1.45,
                    letterSpacing: _readingProfile.letterSpacing,
                  ),
                ),
              if (story.characterProfile != null) ...[
                const SizedBox(height: 18),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Karakter Profili',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text('Isim: ${story.characterProfile!.name}'),
                        Text('Guc: ${story.characterProfile!.power}'),
                        Text('Kisilik: ${story.characterProfile!.personality}'),
                        Text('Dunya: ${story.characterProfile!.world}'),
                        if (story.characterProfile!.toyImageUrl.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: CachedNetworkImage(
                              imageUrl: story.characterProfile!.toyImageUrl,
                              width: double.infinity,
                              height: 170,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                width: double.infinity,
                                height: 170,
                                color: Colors.grey[200],
                              ),
                              errorWidget: (context, url, error) => Container(
                                width: double.infinity,
                                height: 170,
                                color: Colors.red[100],
                                child: const Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
              if (story.scenes.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text(
                  'AI Gorsel Sahneler',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                ...story.scenes.map(_buildSceneCard),
              ],
              const SizedBox(height: 16),
              _buildDialogicReadingSection(),
              const SizedBox(height: 12),
              _buildFamilyTasksSection(),
              const SizedBox(height: 12),
              _buildTransparencyPanel(story),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: _isContinuing ? null : _continueStory,
                  icon: const Icon(Icons.auto_stories),
                  label: Text(
                    _isContinuing
                        ? 'Devam bolumu olusturuluyor...'
                        : 'Devamini Yaz',
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _openVocabularyMode,
                  icon: const Icon(Icons.spellcheck),
                  label: const Text('Kelime Modu'),
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: OutlinedButton.icon(
                  onPressed: _showReadingScaffold,
                  icon: const Icon(Icons.tips_and_updates_outlined),
                  label: const Text('Okuma Ipuclari'),
                ),
              ),
              const SizedBox(height: 18),
              if (story.questions.isNotEmpty)
                Center(
                  child: ElevatedButton.icon(
                    onPressed: _showQuiz,
                    icon: const Icon(Icons.quiz),
                    label: const Text('Eglenceli Testi Coz!'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFAB91FF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
