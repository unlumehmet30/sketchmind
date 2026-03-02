import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/services/learning_progress_service.dart';
import '../../data/services/local_user_service.dart';
import '../../router/app_router.dart';
import 'digital_safety_screen.dart';
import 'interleaved_practice_screen.dart';
import 'offline_pack_screen.dart';
import 'spaced_review_screen.dart';
import '../theme/playful_theme.dart';

class LearningHubScreen extends StatefulWidget {
  const LearningHubScreen({super.key});

  @override
  State<LearningHubScreen> createState() => _LearningHubScreenState();
}

class _LearningHubScreenState extends State<LearningHubScreen> {
  final LearningProgressService _progressService = LearningProgressService();
  final LocalUserService _localUserService = LocalUserService();

  bool _isLoadingMeta = true;
  bool _isParentMode = false;
  bool _isDevModeBypass = false;
  bool _isGuest = true;
  Future<LearningSnapshot>? _snapshotFuture;

  static const List<String> _moods = ['enerjik', 'sakin', 'merakli', 'yorgun'];

  bool get _hasParentAccess => _isParentMode || _isDevModeBypass;

  @override
  void initState() {
    super.initState();
    _reloadAll();
  }

  Future<void> _reloadAll() async {
    setState(() {
      _isLoadingMeta = true;
      _snapshotFuture = _progressService.loadSnapshot();
    });

    final userId = await _localUserService.getSelectedUserId();
    final parentMode = await _localUserService.getIsParentMode();
    final devModeBypass = await _localUserService.getDevModeBypass();
    if (!mounted) return;

    setState(() {
      _isGuest = userId == LocalUserService.defaultUserId;
      _isParentMode = parentMode;
      _isDevModeBypass = devModeBypass;
      _isLoadingMeta = false;
    });
  }

  Future<void> _onMoodSelect(String mood) async {
    await _progressService.setMood(mood);
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _onOfflineToggle(bool value) async {
    await _progressService.setOfflinePackEnabled(value);
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _onTeacherModeToggle(bool value) async {
    await _progressService.setTeacherMode(value);
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _generateAssignments() async {
    await _progressService.generateTeacherAssignments();
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _openSpacedReview() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SpacedReviewScreen()),
    );
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _openInterleavedPractice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const InterleavedPracticeScreen()),
    );
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _openDigitalSafety() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const DigitalSafetyScreen()),
    );
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _startAdaptiveAction(LearningSnapshot data) async {
    final focus = data.adaptivePlan.focusArea.toLowerCase();
    if (focus.contains('tekrar')) {
      await _openSpacedReview();
      return;
    }
    if (focus.contains('guvenlik')) {
      await _openDigitalSafety();
      return;
    }
    await _openInterleavedPractice();
  }

  Future<void> _onGoalMinutesChanged(double value) async {
    await _progressService.updateParentInterventionSettings(
      dailyGoalMinutes: value.round(),
    );
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _onBreakReminderToggle(bool value) async {
    await _progressService.updateParentInterventionSettings(
      breakReminderEnabled: value,
    );
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _onBreakEveryMinutesChanged(double value) async {
    await _progressService.updateParentInterventionSettings(
      breakEveryMinutes: value.round(),
    );
    if (!mounted) return;
    setState(() => _snapshotFuture = _progressService.loadSnapshot());
  }

  Future<void> _lockAndSwitchProfile() async {
    await _localUserService.logoutUser();
    if (!mounted) return;
    context.go(AppRoutes.profileSelection);
  }

  void _showOfflinePackDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cevrimdisi Ogrenme Paketi'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  'Pakette internet olmadan kullanabilecegin etkinlikler var:'),
              SizedBox(height: 8),
              Text('- 5 kisa okuma metni'),
              Text('- 30 kelime yazim alistirmasi'),
              Text('- 40 hizli matematik sorusu'),
              Text('- 12 hafiza karti seviyesi'),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Tamam'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingMeta || _snapshotFuture == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<LearningSnapshot>(
      future: _snapshotFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData) {
          return const Center(child: Text('Ogrenme verisi yuklenemedi.'));
        }

        final data = snapshot.data!;

        final sections = <Widget>[
          _buildHeader(data),
          _buildMoodCard(data),
          _buildAdaptivePlanCard(data),
          _buildMissionCard(data),
          _buildSpacedReviewCard(data),
          _buildInterleavingCard(),
          _buildBadgesCard(data),
          _buildParentPanel(data),
          _buildParentInterventionCard(data),
          _buildTeacherModeCard(data),
          _buildOfflinePackCard(data),
          _buildDigitalSafetyCard(data),
          _buildRecommendationCard(data),
          _buildSecureProfileCard(),
        ];

        return DecoratedBox(
          decoration:
              BoxDecoration(gradient: PlayfulPalette.learningBackground),
          child: RefreshIndicator(
            onRefresh: _reloadAll,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: [
                _buildHubHero(data),
                const SizedBox(height: 12),
                for (var i = 0; i < sections.length; i++)
                  _buildAnimatedSection(i, sections[i]),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHubHero(LearningSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF97BCFF), Color(0xFFAA9EFF), Color(0xFFFFB6E0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x242A4B85),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(18),
            ),
            child:
                const Icon(Icons.school_rounded, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ogrenme Macerasi',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bugun ${data.dailyMissions.where((m) => m.isCompleted).length} gorev tamamlandi.',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedSection(int index, Widget section) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 220 + (index * 45)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: section,
      ),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - value)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildHeader(LearningSnapshot data) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF9BB9FF), Color(0xFFAB9BFF), Color(0xFFFFB4DD)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.school, color: Colors.white, size: 30),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ogrenme Merkezi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                Text(
                  'Seri: ${data.streakDays} gun | Rozet: ${data.badges.length} | Seviye: ${data.quickMathLevel}',
                  style: const TextStyle(color: Colors.white70),
                ),
                if (_isDevModeBypass)
                  const Text(
                    'Dev Test Modu acik: kilitler gevsetildi',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodCard(LearningSnapshot data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ruh Hali ve Oneriler',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _moods
                  .map(
                    (mood) => ChoiceChip(
                      label: Text(mood),
                      selected: data.mood == mood,
                      onSelected: (_) => _onMoodSelect(mood),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdaptivePlanCard(LearningSnapshot data) {
    final plan = data.adaptivePlan;
    final confidencePercent = (plan.confidence * 100).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Adaptif Tutor Plani',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Odak: ${plan.focusArea}  |  Guven: %$confidencePercent',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(plan.reason),
            const SizedBox(height: 8),
            ...plan.nextSteps.map(
              (step) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 16),
                    const SizedBox(width: 6),
                    Expanded(child: Text(step)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () => _startAdaptiveAction(data),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Plani Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpacedReviewCard(LearningSnapshot data) {
    final due = data.dueReviewCount;
    final completed = data.completedReviewToday;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aralikli Tekrar ve Hatirlama',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Bugun bekleyen kart: $due'),
            Text('Bugun tamamlanan tekrar: $completed'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _openSpacedReview,
              icon: const Icon(Icons.style),
              label: Text(due > 0 ? 'Tekrari Baslat' : 'Kartlari Kontrol Et'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInterleavingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Interleaving Lab (Karma Pratik)',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Matematik, kelime ve hafiza turlarini karisik vererek transfer becerisini guclendirir.',
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _openInterleavedPractice,
              icon: const Icon(Icons.shuffle),
              label: const Text('Karma Oturumu Ac'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentInterventionCard(LearningSnapshot data) {
    if (!_hasParentAccess) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.lock, color: Color(0xFF8A77C4)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ebeveyn mudahale ayarlari sadece Ebeveyn Modunda acilir.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    final settings = data.parentSettings;
    final weeklyGoal = settings.dailyGoalMinutes * 7;
    final ratio = (data.weeklyReport.totalMinutes / weeklyGoal).clamp(0.0, 1.0);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ebeveyn Mudahale Ayarlari',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Gunluk hedef: ${settings.dailyGoalMinutes} dk'),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: Colors.grey.shade200,
              ),
            ),
            const SizedBox(height: 8),
            Slider(
              value: settings.dailyGoalMinutes.toDouble(),
              min: 10,
              max: 120,
              divisions: 22,
              label: '${settings.dailyGoalMinutes} dk',
              onChanged: _onGoalMinutesChanged,
            ),
            Row(
              children: [
                const Expanded(child: Text('Mola hatirlatmasi')),
                Switch(
                  value: settings.breakReminderEnabled,
                  onChanged: _onBreakReminderToggle,
                ),
              ],
            ),
            Text('Mola araligi: ${settings.breakEveryMinutes} dk'),
            Slider(
              value: settings.breakEveryMinutes.toDouble(),
              min: 10,
              max: 45,
              divisions: 7,
              label: '${settings.breakEveryMinutes} dk',
              onChanged: settings.breakReminderEnabled
                  ? _onBreakEveryMinutesChanged
                  : null,
            ),
            const SizedBox(height: 8),
            const Text(
              'Ebeveyn nudge onerileri:',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            ...data.parentNudges.map((item) => Text('- $item')),
          ],
        ),
      ),
    );
  }

  Widget _buildDigitalSafetyCard(LearningSnapshot data) {
    final stats = data.digitalSafetyStats;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dijital Guvenlik Senaryolari',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Tamamlanan oturum: ${stats.sessionsPlayed}'),
            Text(
                'Son skor: ${stats.lastScore} | En iyi skor: ${stats.bestScore}'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _openDigitalSafety,
              icon: const Icon(Icons.security),
              label: const Text('Guvenlik Modulunu Ac'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissionCard(LearningSnapshot data) {
    final completedCount =
        data.dailyMissions.where((item) => item.isCompleted).length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Gunluk Gorevler ($completedCount/${data.dailyMissions.length})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...data.dailyMissions.map(
              (mission) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            mission.title,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text('${mission.progress}/${mission.target}'),
                      ],
                    ),
                    Text(
                      mission.description,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        minHeight: 8,
                        value: mission.completionRatio,
                        backgroundColor: Colors.grey.shade200,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadgesCard(LearningSnapshot data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Rozetler',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            if (data.badges.isEmpty)
              const Text('Henuz rozet yok. Gunluk gorevleri tamamlamaya basla.')
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: data.badges
                    .map((badge) => Chip(label: Text(badge)))
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentPanel(LearningSnapshot data) {
    final weekly = data.weeklyReport;

    if (!_hasParentAccess) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.lock, color: Color(0xFF8A77C4)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ebeveyn paneli kapali. Haftalik rapor icin Ebeveyn Modunu ac.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ebeveyn Paneli - Haftalik Rapor',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Text('Toplam sure: ${weekly.totalMinutes} dk'),
            Text('Toplam oyun: ${weekly.totalGames}'),
            Text('Okunan hikaye: ${weekly.totalStories}'),
            Text('Dogru kelime: ${weekly.totalVocabularyCorrect}'),
            const SizedBox(height: 12),
            ...weekly.days.map(
              (day) {
                final maxRef =
                    weekly.totalMinutes > 0 ? weekly.totalMinutes : 1;
                final dayRatio = (day.minutesSpent / maxRef).clamp(0.0, 1.0);
                final label =
                    '${day.date.day.toString().padLeft(2, '0')}/${day.date.month.toString().padLeft(2, '0')}';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(width: 46, child: Text(label)),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: dayRatio,
                            minHeight: 8,
                            backgroundColor: Colors.grey.shade200,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('${day.minutesSpent} dk'),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherModeCard(LearningSnapshot data) {
    if (!_hasParentAccess) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(Icons.lock, color: Color(0xFF8A77C4)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Ogretmen modu ebeveyn yetkisi gerektirir.',
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Ogretmen Modu',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: data.teacherModeEnabled,
                  onChanged: _onTeacherModeToggle,
                ),
              ],
            ),
            const Text(
              'Sinif odakli haftalik gorev setleri olusturur.',
              style: TextStyle(fontSize: 12),
            ),
            if (data.teacherModeEnabled) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton.icon(
                  onPressed: _generateAssignments,
                  icon: const Icon(Icons.assignment),
                  label: const Text('Haftalik Gorev Uret'),
                ),
              ),
              const SizedBox(height: 8),
              if (data.teacherAssignments.isEmpty)
                const Text('Henuz gorev seti yok.')
              else
                ...data.teacherAssignments
                    .map((assignment) => Text('- $assignment')),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOfflinePackCard(LearningSnapshot data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Cevrimdisi Ogrenme Paketi',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Switch(
                  value: data.offlinePackEnabled,
                  onChanged: _onOfflineToggle,
                ),
              ],
            ),
            const Text(
              'Internet olmadan da mini ogrenme aktivitelerine devam et.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _showOfflinePackDialog,
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Paket Icerigini Goster'),
                ),
                ElevatedButton.icon(
                  onPressed: data.offlinePackEnabled
                      ? () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const OfflinePackScreen(),
                            ),
                          );
                        }
                      : null,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Paketi Baslat'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecommendationCard(LearningSnapshot data) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Akilli Oneriler',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...data.recommendations.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Icon(Icons.circle, size: 8),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(item)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecureProfileCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Guvenli Coklu Profil',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Profil secim ekranina donup sifre dogrulamasi ile farkli profile gecis yapabilirsin.',
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: _isGuest ? null : _lockAndSwitchProfile,
              icon: const Icon(Icons.lock),
              label: const Text('Profili Kilitle ve Profil Sec'),
            ),
          ],
        ),
      ),
    );
  }
}
