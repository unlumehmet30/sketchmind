import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'local_user_service.dart';
import 'learning_progress_models.dart';

export 'learning_progress_models.dart';

class LearningProgressService {
  static const _rootKey = 'learning_progress_store_v1';
  static const bool _isTestEnvironment = bool.fromEnvironment('FLUTTER_TEST');
  final LocalUserService _userService;
  Future<SharedPreferences>? _prefsFuture;

  LearningProgressService({LocalUserService? userService})
      : _userService = userService ?? LocalUserService();

  Future<SharedPreferences> _getPrefs() async {
    if (_isTestEnvironment) {
      return SharedPreferences.getInstance();
    }
    return _prefsFuture ??= SharedPreferences.getInstance();
  }

  Future<LearningSnapshot> loadSnapshot() async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);
    final reviewQueue = _nestedMap(profile, 'reviewQueue');
    if (reviewQueue.isEmpty) {
      _seedReviewCards(
          profile, _readStringList(profile, 'vocabularyMasteredWords'));
    }
    _applyBadges(profile);
    await _saveProfile(userId, root, profile);

    final daily = _todayMap(profile);
    final weekly = _buildWeeklyReport(profile);
    final dueReviewCount = _countDueReviewCards(profile);
    final parentSettings = _readParentSettings(profile);
    final adaptivePlan = _buildAdaptiveTutorPlan(
      profile: profile,
      weekly: weekly,
      dueReviewCount: dueReviewCount,
    );
    final parentNudges = _buildParentNudges(
      profile: profile,
      weekly: weekly,
      settings: parentSettings,
      dueReviewCount: dueReviewCount,
      adaptivePlan: adaptivePlan,
    );
    final digitalSafetyStats = _readDigitalSafetyStats(profile);
    final missions = _buildMissions(daily);
    final recommendations = _buildRecommendations(
      mood: _readString(profile, 'mood', 'merakli'),
      weekly: weekly,
      quickMathLevel: _readInt(profile, 'quickMathLevel', 1),
      offlinePackEnabled: _readBool(profile, 'offlinePackEnabled', false),
      dueReviewCount: dueReviewCount,
      adaptiveFocus: adaptivePlan.focusArea,
    );

    return LearningSnapshot(
      userId: userId,
      streakDays: _readInt(profile, 'streakDays', 0),
      badges: _readStringList(profile, 'badges'),
      dailyMissions: missions,
      weeklyReport: weekly,
      mood: _readString(profile, 'mood', 'merakli'),
      quickMathLevel: _readInt(profile, 'quickMathLevel', 1),
      offlinePackEnabled: _readBool(profile, 'offlinePackEnabled', false),
      teacherModeEnabled: _readBool(profile, 'teacherModeEnabled', false),
      teacherAssignments: _readStringList(profile, 'teacherAssignments'),
      recommendations: recommendations,
      vocabularyMasteredCount:
          _readStringList(profile, 'vocabularyMasteredWords').length,
      tournamentWins: _readInt(profile, 'tournamentWins', 0),
      dueReviewCount: dueReviewCount,
      completedReviewToday: _readInt(daily, 'retrievalPracticed', 0),
      hintUsageToday: _readInt(daily, 'hintUsage', 0),
      parentSettings: parentSettings,
      parentNudges: parentNudges,
      adaptivePlan: adaptivePlan,
      digitalSafetyStats: digitalSafetyStats,
    );
  }

  Future<int> getQuickMathLevel() async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);
    return _readInt(profile, 'quickMathLevel', 1);
  }

  Future<List<ReviewCard>> getDueReviewCards({int limit = 12}) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);
    final queue = _nestedMap(profile, 'reviewQueue');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dueCards = <ReviewCard>[];
    for (final entry in queue.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;

      final dueDate = _parseDate(value['due']) ?? today;
      if (!_isDueDate(dueDate, today)) continue;

      final stage = _readInt(value, 'stage', 0).clamp(0, 6);
      dueCards.add(
        ReviewCard(
          id: key,
          word: _readString(value, 'word', key),
          dueDate: dueDate,
          stage: stage.toInt(),
        ),
      );
    }

    dueCards.sort((a, b) {
      final dateCompare = a.dueDate.compareTo(b.dueDate);
      if (dateCompare != 0) return dateCompare;
      return a.stage.compareTo(b.stage);
    });
    return dueCards.take(limit.clamp(1, 40).toInt()).toList();
  }

  Future<void> submitReviewResult({
    required String cardId,
    required bool correct,
  }) async {
    final normalizedId = cardId.trim().toLowerCase();
    if (normalizedId.isEmpty) return;

    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);
    final queue = _nestedMap(profile, 'reviewQueue');
    final rawCard = queue[normalizedId];
    final card =
        rawCard is Map<String, dynamic> ? rawCard : <String, dynamic>{};

    final currentStage = _readInt(card, 'stage', 0).clamp(0, 6).toInt();
    final nextStage = (correct ? (currentStage + 1).clamp(0, 6) : 0).toInt();
    final interval = _reviewIntervals[nextStage];
    final now = DateTime.now();
    final dueDate =
        DateTime(now.year, now.month, now.day).add(Duration(days: interval));

    card['word'] = _readString(card, 'word', normalizedId);
    card['stage'] = nextStage;
    card['due'] = _dateKey(dueDate);
    card['reviewCount'] = _readInt(card, 'reviewCount', 0) + 1;
    card['lastCorrect'] = correct;
    card['lastReviewed'] = now.toIso8601String();
    queue[normalizedId] = card;

    final daily = _todayMap(profile);
    daily['retrievalPracticed'] = _readInt(daily, 'retrievalPracticed', 0) + 1;
    daily['retrievalCorrect'] =
        _readInt(daily, 'retrievalCorrect', 0) + (correct ? 1 : 0);

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> updateParentInterventionSettings({
    int? dailyGoalMinutes,
    bool? breakReminderEnabled,
    int? breakEveryMinutes,
  }) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    if (dailyGoalMinutes != null) {
      profile['dailyGoalMinutes'] = dailyGoalMinutes.clamp(10, 120);
    }
    if (breakReminderEnabled != null) {
      profile['breakReminderEnabled'] = breakReminderEnabled;
    }
    if (breakEveryMinutes != null) {
      profile['breakEveryMinutes'] = breakEveryMinutes.clamp(10, 45);
    }

    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> recordHintUsage({
    String context = 'general',
  }) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    final daily = _todayMap(profile);
    daily['hintUsage'] = _readInt(daily, 'hintUsage', 0) + 1;

    final hintStats = _nestedMap(profile, 'hintStats');
    final contextKey = context.trim().isEmpty ? 'general' : context.trim();
    hintStats[contextKey] = _readInt(hintStats, contextKey, 0) + 1;

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> recordInterleavingSession({
    required int total,
    required int correct,
    int minutes = 6,
  }) async {
    final safeTotal = total.clamp(1, 1000).toInt();
    final safeCorrect = correct.clamp(0, safeTotal).toInt();
    final score = safeCorrect * 12;

    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    _increaseDaily(
      profile,
      gamesPlayed: 1,
      storiesRead: 0,
      vocabularyAnswered: 0,
      vocabularyCorrect: 0,
      minutes: minutes.clamp(2, 40),
    );

    final daily = _todayMap(profile);
    daily['interleavingAnswered'] =
        _readInt(daily, 'interleavingAnswered', 0) + safeTotal;
    daily['interleavingCorrect'] =
        _readInt(daily, 'interleavingCorrect', 0) + safeCorrect;

    final gameStats = _nestedMap(profile, 'gameStats');
    final current = gameStats['interleaving'];
    final currentMap =
        current is Map<String, dynamic> ? current : <String, dynamic>{};
    currentMap['played'] = _readInt(currentMap, 'played', 0) + 1;
    currentMap['wins'] = _readInt(currentMap, 'wins', 0) +
        (safeCorrect >= (safeTotal * 0.6) ? 1 : 0);
    currentMap['bestScore'] = score > _readInt(currentMap, 'bestScore', 0)
        ? score
        : _readInt(currentMap, 'bestScore', 0);
    gameStats['interleaving'] = currentMap;

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> recordDigitalSafetySession({
    required int score,
    required int total,
    int minutes = 4,
  }) async {
    final safeTotal = total.clamp(1, 1000).toInt();
    final safeScore = score.clamp(0, safeTotal).toInt();

    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    _increaseDaily(
      profile,
      gamesPlayed: 0,
      storiesRead: 0,
      vocabularyAnswered: 0,
      vocabularyCorrect: 0,
      minutes: minutes.clamp(1, 20),
    );

    final daily = _todayMap(profile);
    daily['safetySessions'] = _readInt(daily, 'safetySessions', 0) + 1;
    daily['safetyScore'] = _readInt(daily, 'safetyScore', 0) + safeScore;

    profile['digitalSafetyPlayed'] =
        _readInt(profile, 'digitalSafetyPlayed', 0) + 1;
    profile['digitalSafetyLast'] = safeScore;
    profile['digitalSafetyBest'] =
        safeScore > _readInt(profile, 'digitalSafetyBest', 0)
            ? safeScore
            : _readInt(profile, 'digitalSafetyBest', 0);

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> setMood(String mood) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);
    profile['mood'] = mood;
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> setOfflinePackEnabled(bool enabled) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);
    profile['offlinePackEnabled'] = enabled;
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> setTeacherMode(bool enabled) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);
    profile['teacherModeEnabled'] = enabled;
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> generateTeacherAssignments() async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);
    final today = _todayKey();

    final assignments = <String>[
      'Haftalik okuma: 3 hikaye tamamla',
      'Kelime calismasi: 12 dogru cevap',
      'Hizli matematik: en az 2 oturum oyna',
      'Oyun stratejisi: 1 mini turnuva bitir',
      'Raporlama: Pazar gunu haftalik raporu kontrol et',
    ];

    profile['teacherAssignments'] = assignments;
    profile['teacherAssignmentDate'] = today;
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> recordStoryRead({
    int minutes = 2,
  }) async {
    await _recordDailyActivity(
      gamesPlayed: 0,
      storiesRead: 1,
      vocabularyAnswered: 0,
      vocabularyCorrect: 0,
      minutes: minutes.clamp(1, 60),
    );
  }

  Future<void> recordGameSession({
    required String gameId,
    int score = 0,
    bool won = false,
    int minutes = 2,
  }) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    _increaseDaily(
      profile,
      gamesPlayed: 1,
      storiesRead: 0,
      vocabularyAnswered: 0,
      vocabularyCorrect: 0,
      minutes: minutes.clamp(1, 40),
    );

    final gameStats = _nestedMap(profile, 'gameStats');
    final current = gameStats[gameId];
    final currentMap =
        current is Map<String, dynamic> ? current : <String, dynamic>{};

    currentMap['played'] = _readInt(currentMap, 'played', 0) + 1;
    currentMap['wins'] = _readInt(currentMap, 'wins', 0) + (won ? 1 : 0);
    currentMap['bestScore'] = score > _readInt(currentMap, 'bestScore', 0)
        ? score
        : _readInt(currentMap, 'bestScore', 0);
    gameStats[gameId] = currentMap;

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> recordQuickMathResult({
    required int correct,
    required int total,
    required int score,
    required int minutes,
  }) async {
    final accuracy = total <= 0 ? 0 : correct / total;
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    final currentLevel = _readInt(profile, 'quickMathLevel', 1);
    var nextLevel = currentLevel;

    if (accuracy >= 0.8) {
      nextLevel += 1;
    } else if (accuracy < 0.45) {
      nextLevel -= 1;
    }

    profile['quickMathLevel'] = nextLevel.clamp(1, 5);
    _increaseDaily(
      profile,
      gamesPlayed: 1,
      storiesRead: 0,
      vocabularyAnswered: 0,
      vocabularyCorrect: 0,
      minutes: minutes.clamp(1, 40),
    );

    final daily = _todayMap(profile);
    daily['quickMathAnswered'] =
        _readInt(daily, 'quickMathAnswered', 0) + total;
    daily['quickMathCorrect'] =
        _readInt(daily, 'quickMathCorrect', 0) + correct;

    final gameStats = _nestedMap(profile, 'gameStats');
    final current = gameStats['quick_math'];
    final currentMap =
        current is Map<String, dynamic> ? current : <String, dynamic>{};
    currentMap['played'] = _readInt(currentMap, 'played', 0) + 1;
    currentMap['wins'] =
        _readInt(currentMap, 'wins', 0) + (accuracy >= 0.6 ? 1 : 0);
    currentMap['bestScore'] = score > _readInt(currentMap, 'bestScore', 0)
        ? score
        : _readInt(currentMap, 'bestScore', 0);
    gameStats['quick_math'] = currentMap;

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> recordVocabularyPractice({
    required int answered,
    required int correct,
    List<String> masteredWords = const [],
    int minutes = 3,
  }) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    _increaseDaily(
      profile,
      gamesPlayed: 0,
      storiesRead: 0,
      vocabularyAnswered: answered,
      vocabularyCorrect: correct,
      minutes: minutes.clamp(1, 20),
    );

    final wordSet = <String>{
      ..._readStringList(profile, 'vocabularyMasteredWords')
    };
    for (final word in masteredWords) {
      if (word.trim().isNotEmpty) {
        wordSet.add(word.toLowerCase());
      }
    }
    profile['vocabularyMasteredWords'] = wordSet.toList()..sort();
    _seedReviewCards(profile, masteredWords);

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> recordTournamentResult({
    required int totalScore,
    required bool won,
    int minutes = 6,
  }) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    _increaseDaily(
      profile,
      gamesPlayed: 1,
      storiesRead: 0,
      vocabularyAnswered: 0,
      vocabularyCorrect: 0,
      minutes: minutes.clamp(2, 45),
    );

    profile['tournamentPlayed'] = _readInt(profile, 'tournamentPlayed', 0) + 1;
    profile['tournamentWins'] =
        _readInt(profile, 'tournamentWins', 0) + (won ? 1 : 0);
    profile['tournamentBest'] =
        totalScore > _readInt(profile, 'tournamentBest', 0)
            ? totalScore
            : _readInt(profile, 'tournamentBest', 0);

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<void> _recordDailyActivity({
    required int gamesPlayed,
    required int storiesRead,
    required int vocabularyAnswered,
    required int vocabularyCorrect,
    required int minutes,
  }) async {
    final userId = await _resolveUserId();
    final root = await _readRoot();
    final profile = _profileFromRoot(root, userId);

    _increaseDaily(
      profile,
      gamesPlayed: gamesPlayed,
      storiesRead: storiesRead,
      vocabularyAnswered: vocabularyAnswered,
      vocabularyCorrect: vocabularyCorrect,
      minutes: minutes,
    );

    _refreshDailyStreak(profile);
    _applyBadges(profile);
    _markActive(profile);
    await _saveProfile(userId, root, profile);
  }

  Future<String> _resolveUserId() async {
    final selected = await _userService.getSelectedUserId();
    return selected.trim().isEmpty
        ? LocalUserService.defaultUserId
        : selected.trim();
  }

  Future<Map<String, dynamic>> _readRoot() async {
    final prefs = await _getPrefs();
    final raw = prefs.getString(_rootKey);
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return <String, dynamic>{};
    }
    return <String, dynamic>{};
  }

  Map<String, dynamic> _profileFromRoot(
    Map<String, dynamic> root,
    String userId,
  ) {
    final existing = root[userId];
    if (existing is Map<String, dynamic>) {
      return existing;
    }

    final created = <String, dynamic>{
      'streakDays': 0,
      'lastMissionDate': '',
      'lastActiveDate': '',
      'quickMathLevel': 1,
      'badges': <String>[],
      'mood': 'merakli',
      'offlinePackEnabled': false,
      'teacherModeEnabled': false,
      'teacherAssignments': <String>[],
      'vocabularyMasteredWords': <String>[],
      'reviewQueue': <String, dynamic>{},
      'gameStats': <String, dynamic>{},
      'hintStats': <String, dynamic>{},
      'dailyActivity': <String, dynamic>{},
      'dailyGoalMinutes': 25,
      'breakReminderEnabled': true,
      'breakEveryMinutes': 15,
      'digitalSafetyPlayed': 0,
      'digitalSafetyBest': 0,
      'digitalSafetyLast': 0,
      'tournamentPlayed': 0,
      'tournamentWins': 0,
      'tournamentBest': 0,
    };
    root[userId] = created;
    return created;
  }

  Future<void> _saveProfile(
    String userId,
    Map<String, dynamic> root,
    Map<String, dynamic> profile,
  ) async {
    root[userId] = profile;
    final prefs = await _getPrefs();
    await prefs.setString(_rootKey, jsonEncode(root));
  }

  WeeklyReport _buildWeeklyReport(Map<String, dynamic> profile) {
    final days = <WeeklyDaySummary>[];
    var totalMinutes = 0;
    var totalGames = 0;
    var totalStories = 0;
    var totalVocabularyCorrect = 0;

    final daily = _nestedMap(profile, 'dailyActivity');
    final now = DateTime.now();
    for (var i = 6; i >= 0; i--) {
      final date =
          DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final key = _dateKey(date);
      final entry = daily[key];
      final dayMap =
          entry is Map<String, dynamic> ? entry : <String, dynamic>{};

      final minutes = _readInt(dayMap, 'minutesSpent', 0);
      final games = _readInt(dayMap, 'gamesPlayed', 0);
      final stories = _readInt(dayMap, 'storiesRead', 0);
      final vocab = _readInt(dayMap, 'vocabularyCorrect', 0);

      totalMinutes += minutes;
      totalGames += games;
      totalStories += stories;
      totalVocabularyCorrect += vocab;

      days.add(
        WeeklyDaySummary(
          date: date,
          minutesSpent: minutes,
          gamesPlayed: games,
          storiesRead: stories,
          vocabularyCorrect: vocab,
        ),
      );
    }

    return WeeklyReport(
      days: days,
      totalMinutes: totalMinutes,
      totalGames: totalGames,
      totalStories: totalStories,
      totalVocabularyCorrect: totalVocabularyCorrect,
    );
  }

  List<DailyMissionStatus> _buildMissions(Map<String, dynamic> daily) {
    return [
      DailyMissionStatus(
        id: 'story_reader',
        title: 'Hikaye Gorevi',
        description: 'Bugun en az 1 hikaye oku',
        progress: _readInt(daily, 'storiesRead', 0),
        target: 1,
      ),
      DailyMissionStatus(
        id: 'game_runner',
        title: 'Oyun Gorevi',
        description: 'Bugun 2 oyun oturumu tamamla',
        progress: _readInt(daily, 'gamesPlayed', 0),
        target: 2,
      ),
      DailyMissionStatus(
        id: 'vocab_builder',
        title: 'Kelime Gorevi',
        description: 'Bugun 5 dogru kelime cevabi ver',
        progress: _readInt(daily, 'vocabularyCorrect', 0),
        target: 5,
      ),
      DailyMissionStatus(
        id: 'focus_time',
        title: 'Odak Gorevi',
        description: 'Bugun 15 dakika ogrenme zamani',
        progress: _readInt(daily, 'minutesSpent', 0),
        target: 15,
      ),
      DailyMissionStatus(
        id: 'retrieval_boost',
        title: 'Hatirlama Gorevi',
        description: 'Bugun 3 aralikli tekrar karti coz',
        progress: _readInt(daily, 'retrievalPracticed', 0),
        target: 3,
      ),
      DailyMissionStatus(
        id: 'safety_check',
        title: 'Guvenlik Gorevi',
        description: 'Bugun 1 dijital guvenlik senaryosu tamamla',
        progress: _readInt(daily, 'safetySessions', 0),
        target: 1,
      ),
    ];
  }

  List<String> _buildRecommendations({
    required String mood,
    required WeeklyReport weekly,
    required int quickMathLevel,
    required bool offlinePackEnabled,
    required int dueReviewCount,
    required String adaptiveFocus,
  }) {
    final items = <String>[];

    if (mood == 'enerjik') {
      items.add('Mini turnuva ve hizli matematik ile enerjini puana cevir.');
    } else if (mood == 'sakin') {
      items.add('Sesli takipli hikaye ve kelime modu ile sakin ilerle.');
    } else if (mood == 'merakli') {
      items.add('Hexapawn + kelime avcisi modu ile kesif odakli ilerle.');
    } else {
      items.add('Hafiza eslestirme ve kisa hikaye ile yumusak baslangic yap.');
    }

    if (weekly.totalGames < 5) {
      items.add('Haftalik oyun hedefi: en az 5 oturum.');
    }
    if (weekly.totalStories < 3) {
      items.add('Haftalik hikaye hedefi: 3 hikaye.');
    }
    if (quickMathLevel >= 4) {
      items.add('Matematik seviyen yuksek, zorlu sorular modunu ac.');
    } else {
      items.add('Temel matematikte tekrar ile seviye artisina odaklan.');
    }
    if (dueReviewCount > 0) {
      items.add('Bugun bekleyen $dueReviewCount tekrar kartini tamamla.');
    }
    if (adaptiveFocus.trim().isNotEmpty) {
      items.add('Adaptif odak: $adaptiveFocus.');
    }
    if (!offlinePackEnabled) {
      items.add(
          'Cevrimdisi ogrenme paketi acilirsa internet yokken de devam edebilirsin.');
    }

    return items.take(4).toList();
  }

  static const List<int> _reviewIntervals = [0, 1, 3, 7, 14, 30, 45];

  void _seedReviewCards(Map<String, dynamic> profile, List<String> words) {
    if (words.isEmpty) return;
    final queue = _nestedMap(profile, 'reviewQueue');
    final now = DateTime.now();
    final initialDue = DateTime(now.year, now.month, now.day)
        .add(Duration(days: _reviewIntervals.first));

    for (final raw in words) {
      final id = raw.trim().toLowerCase();
      if (id.isEmpty) continue;

      final existing = queue[id];
      if (existing is Map<String, dynamic>) {
        existing['word'] = _readString(existing, 'word', id);
        existing['due'] = _readString(existing, 'due', _dateKey(initialDue));
        existing['stage'] = _readInt(existing, 'stage', 0).clamp(0, 6);
        queue[id] = existing;
        continue;
      }

      queue[id] = <String, dynamic>{
        'word': id,
        'stage': 0,
        'due': _dateKey(initialDue),
        'reviewCount': 0,
      };
    }
  }

  int _countDueReviewCards(Map<String, dynamic> profile) {
    final queue = _nestedMap(profile, 'reviewQueue');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    var dueCount = 0;

    for (final value in queue.values) {
      if (value is! Map<String, dynamic>) continue;
      final dueDate = _parseDate(value['due']) ?? today;
      if (_isDueDate(dueDate, today)) {
        dueCount += 1;
      }
    }
    return dueCount;
  }

  ParentInterventionSettings _readParentSettings(Map<String, dynamic> profile) {
    return ParentInterventionSettings(
      dailyGoalMinutes:
          _readInt(profile, 'dailyGoalMinutes', 25).clamp(10, 120).toInt(),
      breakReminderEnabled: _readBool(profile, 'breakReminderEnabled', true),
      breakEveryMinutes:
          _readInt(profile, 'breakEveryMinutes', 15).clamp(10, 45).toInt(),
    );
  }

  AdaptiveTutorPlan _buildAdaptiveTutorPlan({
    required Map<String, dynamic> profile,
    required WeeklyReport weekly,
    required int dueReviewCount,
  }) {
    final daily = _todayMap(profile);
    final quickMathAnswered = _readInt(daily, 'quickMathAnswered', 0);
    final quickMathCorrect = _readInt(daily, 'quickMathCorrect', 0);
    final quickMathAccuracy = quickMathAnswered <= 0
        ? 0.0
        : (quickMathCorrect / quickMathAnswered).clamp(0.0, 1.0);

    final vocabAnswered = _readInt(daily, 'vocabularyAnswered', 0);
    final vocabCorrect = _readInt(daily, 'vocabularyCorrect', 0);
    final vocabAccuracy = vocabAnswered <= 0
        ? 0.0
        : (vocabCorrect / vocabAnswered).clamp(0.0, 1.0);

    if (dueReviewCount >= 4) {
      return const AdaptiveTutorPlan(
        focusArea: 'Aralikli tekrar',
        reason: 'Bekleyen kart sayisi yuksek oldugu icin unutma riski artiyor.',
        nextSteps: [
          '6 tekrar kartini tamamla',
          'Yanlis kartlari tekrar et',
          'Kelime modunda 1 tur daha oyna',
        ],
        confidence: 0.85,
      );
    }

    if (weekly.totalStories < 3 || vocabAccuracy < 0.55) {
      return const AdaptiveTutorPlan(
        focusArea: 'Okuma ve kelime',
        reason: 'Okuma sayisi veya kelime dogrulugu hedefin altinda.',
        nextSteps: [
          'Sesli takip ile 1 hikaye bitir',
          'Kelime modunda en az 8 soru coz',
          '3 yeni kelimeyi karta ekle',
        ],
        confidence: 0.78,
      );
    }

    if (quickMathAccuracy < 0.6 ||
        _readInt(profile, 'quickMathLevel', 1) <= 2) {
      return const AdaptiveTutorPlan(
        focusArea: 'Temel matematik',
        reason: 'Matematikte dogruluk ve seviye artisi icin tekrar gerekiyor.',
        nextSteps: [
          'Hizli matematikte 2 oturum oyna',
          'Ipuclu cozum modunu kullan',
          'Karma pratikte matematik turlarina odaklan',
        ],
        confidence: 0.74,
      );
    }

    return const AdaptiveTutorPlan(
      focusArea: 'Karma ustalik',
      reason: 'Temel metrikler dengeli, ust duzey karisik pratik uygun.',
      nextSteps: [
        'Karma pratik oturumunu tamamla',
        'Mini turnuvada kupa hedefle',
        'Dijital guvenlik senaryosunu bitir',
      ],
      confidence: 0.68,
    );
  }

  List<String> _buildParentNudges({
    required Map<String, dynamic> profile,
    required WeeklyReport weekly,
    required ParentInterventionSettings settings,
    required int dueReviewCount,
    required AdaptiveTutorPlan adaptivePlan,
  }) {
    final nudges = <String>[];

    final targetMinutesWeek = settings.dailyGoalMinutes * 7;
    if (weekly.totalMinutes < targetMinutesWeek) {
      nudges.add(
        'Haftalik sure hedefi geride. Gunluk hedefi ${settings.dailyGoalMinutes} dk olarak koruyun.',
      );
    }
    if (dueReviewCount >= 4) {
      nudges.add(
        'Hatirlama kartlari birikti. Kisa ama duzenli tekrar seansi planlayin.',
      );
    }
    if (_readInt(profile, 'digitalSafetyPlayed', 0) < 2) {
      nudges.add('Bu hafta en az 2 dijital guvenlik senaryosu tamamlatin.');
    }
    if (settings.breakReminderEnabled) {
      nudges.add(
        'Odak icin ${settings.breakEveryMinutes} dakikada bir kisa mola hatirlatmasi aktif.',
      );
    } else {
      nudges.add(
          'Uzun ekran suresinde mola hatirlatmasini acik tutmaniz onerilir.');
    }
    nudges.add('Bu haftanin odagi: ${adaptivePlan.focusArea}.');

    return nudges.take(4).toList();
  }

  DigitalSafetyStats _readDigitalSafetyStats(Map<String, dynamic> profile) {
    return DigitalSafetyStats(
      sessionsPlayed: _readInt(profile, 'digitalSafetyPlayed', 0),
      bestScore: _readInt(profile, 'digitalSafetyBest', 0),
      lastScore: _readInt(profile, 'digitalSafetyLast', 0),
    );
  }

  bool _isDueDate(DateTime dueDate, DateTime today) {
    final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final current = DateTime(today.year, today.month, today.day);
    return !due.isAfter(current);
  }

  DateTime? _parseDate(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return null;
    try {
      return DateTime.parse(raw.trim());
    } catch (_) {
      return null;
    }
  }

  void _increaseDaily(
    Map<String, dynamic> profile, {
    required int gamesPlayed,
    required int storiesRead,
    required int vocabularyAnswered,
    required int vocabularyCorrect,
    required int minutes,
  }) {
    final daily = _todayMap(profile);
    daily['gamesPlayed'] = _readInt(daily, 'gamesPlayed', 0) + gamesPlayed;
    daily['storiesRead'] = _readInt(daily, 'storiesRead', 0) + storiesRead;
    daily['vocabularyAnswered'] =
        _readInt(daily, 'vocabularyAnswered', 0) + vocabularyAnswered;
    daily['vocabularyCorrect'] =
        _readInt(daily, 'vocabularyCorrect', 0) + vocabularyCorrect;
    daily['minutesSpent'] = _readInt(daily, 'minutesSpent', 0) + minutes;
  }

  Map<String, dynamic> _todayMap(Map<String, dynamic> profile) {
    final allDaily = _nestedMap(profile, 'dailyActivity');
    final key = _todayKey();
    final current = allDaily[key];
    if (current is Map<String, dynamic>) {
      return current;
    }
    final created = <String, dynamic>{
      'gamesPlayed': 0,
      'storiesRead': 0,
      'vocabularyAnswered': 0,
      'vocabularyCorrect': 0,
      'minutesSpent': 0,
      'quickMathAnswered': 0,
      'quickMathCorrect': 0,
      'retrievalPracticed': 0,
      'retrievalCorrect': 0,
      'hintUsage': 0,
      'interleavingAnswered': 0,
      'interleavingCorrect': 0,
      'safetySessions': 0,
      'safetyScore': 0,
    };
    allDaily[key] = created;
    return created;
  }

  void _refreshDailyStreak(Map<String, dynamic> profile) {
    final currentDay = _todayKey();
    final lastDay = _readString(profile, 'lastMissionDate', '');
    final today = DateTime.now();

    if (lastDay == currentDay) return;

    if (lastDay.isEmpty) {
      profile['streakDays'] = 1;
      profile['lastMissionDate'] = currentDay;
      return;
    }

    DateTime? parsedLast;
    try {
      parsedLast = DateTime.parse(lastDay);
    } catch (_) {
      parsedLast = null;
    }

    if (parsedLast == null) {
      profile['streakDays'] = 1;
      profile['lastMissionDate'] = currentDay;
      return;
    }

    final difference = DateTime(today.year, today.month, today.day)
        .difference(DateTime(parsedLast.year, parsedLast.month, parsedLast.day))
        .inDays;

    if (difference == 1) {
      profile['streakDays'] = _readInt(profile, 'streakDays', 0) + 1;
    } else if (difference > 1) {
      profile['streakDays'] = 1;
    }
    profile['lastMissionDate'] = currentDay;
  }

  void _applyBadges(Map<String, dynamic> profile) {
    final badgeSet = <String>{..._readStringList(profile, 'badges')};
    final streak = _readInt(profile, 'streakDays', 0);
    final vocabCount =
        _readStringList(profile, 'vocabularyMasteredWords').length;
    final quickMathLevel = _readInt(profile, 'quickMathLevel', 1);
    final tournamentWins = _readInt(profile, 'tournamentWins', 0);
    final digitalSafetyPlayed = _readInt(profile, 'digitalSafetyPlayed', 0);

    final gameStats = _nestedMap(profile, 'gameStats');
    var totalPlayed = 0;
    for (final entry in gameStats.values) {
      if (entry is Map<String, dynamic>) {
        totalPlayed += _readInt(entry, 'played', 0);
      }
    }
    final interleavingStats = gameStats['interleaving'];
    final interleavingPlayed = interleavingStats is Map<String, dynamic>
        ? _readInt(interleavingStats, 'played', 0)
        : 0;

    final reviewQueue = _nestedMap(profile, 'reviewQueue');
    var stabilizedReviewCount = 0;
    for (final value in reviewQueue.values) {
      if (value is Map<String, dynamic>) {
        final stage = _readInt(value, 'stage', 0);
        if (stage >= 3) {
          stabilizedReviewCount += 1;
        }
      }
    }

    if (totalPlayed > 0 || vocabCount > 0 || streak > 0) {
      badgeSet.add('Ilk Adim');
    }
    if (streak >= 3) {
      badgeSet.add('3 Gun Seri');
    }
    if (streak >= 7) {
      badgeSet.add('Hafta Yildizi');
    }
    if (totalPlayed >= 20) {
      badgeSet.add('Oyun Ustasi');
    }
    if (vocabCount >= 25) {
      badgeSet.add('Kelime Kasifi');
    }
    if (quickMathLevel >= 4) {
      badgeSet.add('Matematik Ninja');
    }
    if (tournamentWins >= 3) {
      badgeSet.add('Turnuva Kupasi');
    }
    if (stabilizedReviewCount >= 10) {
      badgeSet.add('Hafiza Ustasi');
    }
    if (interleavingPlayed >= 5) {
      badgeSet.add('Karma Pratikci');
    }
    if (digitalSafetyPlayed >= 3) {
      badgeSet.add('Guvenli Gezgin');
    }

    profile['badges'] = badgeSet.toList()..sort();
  }

  void _markActive(Map<String, dynamic> profile) {
    profile['lastActiveDate'] = _todayKey();
  }

  Map<String, dynamic> _nestedMap(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is Map<String, dynamic>) return value;
    final created = <String, dynamic>{};
    source[key] = created;
    return created;
  }

  String _todayKey() {
    final now = DateTime.now();
    return _dateKey(now);
  }

  String _dateKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  int _readInt(Map<String, dynamic> source, String key, int fallback) {
    final value = source[key];
    if (value is num) return value.toInt();
    return fallback;
  }

  bool _readBool(Map<String, dynamic> source, String key, bool fallback) {
    final value = source[key];
    if (value is bool) return value;
    return fallback;
  }

  String _readString(Map<String, dynamic> source, String key, String fallback) {
    final value = source[key];
    if (value is String) return value;
    return fallback;
  }

  List<String> _readStringList(Map<String, dynamic> source, String key) {
    final value = source[key];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return <String>[];
  }
}
