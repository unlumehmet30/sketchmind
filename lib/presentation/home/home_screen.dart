import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/avatars.dart';
import '../../data/dummy/stories.dart';
import '../../data/i_story_service.dart';
import '../../data/services/family_settings_service.dart';
import '../../data/services/local_user_service.dart';
import '../../data/services/openai_story_service.dart';
import '../../data/services/screen_time_service.dart';
import '../../router/app_router.dart';
import '../games/game_hub_screen.dart';
import '../learning/learning_hub_screen.dart';
import '../theme/playful_theme.dart';
import 'widgets/reactive_mascot.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final IStoryService _storyService = OpenAIStoryService();
  final LocalUserService _localUserService = LocalUserService();
  final FamilySettingsService _familySettingsService = FamilySettingsService();
  final ScreenTimeService _screenTimeService = ScreenTimeService();

  int _selectedIndex = 0;

  List<Story> _stories = [];
  bool _isLoading = true;
  String _currentUsername = 'Misafir';
  String _lastLoadedUserId = '';
  String? _currentAvatarUrl;
  UserPersonalization _userPersonalization = const UserPersonalization();
  bool _isParentMode = false;
  bool _isDevModeBypass = false;
  FamilySafetySettings _familySettings = const FamilySafetySettings();
  ScreenTimeStatus _screenTimeStatus = const ScreenTimeStatus(
    usedSeconds: 0,
    usedMinutes: 0,
    limitEnabled: false,
    dailyLimitMinutes: 0,
  );
  bool _isScreenTimeLimitReached = false;
  bool _isQuietHoursActive = false;
  Timer? _safetyTicker;
  Timer? _mascotResetTimer;
  int _mascotTapCount = 0;
  MascotReaction _mascotReaction = const MascotReaction(
    mood: MascotMood.idle,
    message: 'Merhaba! Bir hikaye ya da oyun seç, birlikte başlayalım.',
  );

  @override
  void initState() {
    super.initState();
    _safetyTicker = Timer.periodic(
        const Duration(seconds: 35), (_) => _refreshSafetyState());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadInitialData();
      }
    });
  }

  @override
  void dispose() {
    _safetyTicker?.cancel();
    _mascotResetTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (mounted) {
      _checkAndReloadUser();
    }
  }

  bool get _isChildMode => !_isParentMode && !_isDevModeBypass;
  bool get _isPlayRestricted => _isChildMode && _isQuietHoursActive;
  bool get _isFullyLocked => _isChildMode && _isScreenTimeLimitReached;

  String get _visibleName {
    final custom = _userPersonalization.displayName.trim();
    if (custom.isNotEmpty) return custom;
    return _currentUsername;
  }

  String _favoriteGameLabel(String key) {
    switch (key) {
      case 'memory_match':
        return 'Hafıza Eşleştirme';
      case 'rps':
        return 'Taş Kağıt Makas';
      case 'game_2048':
        return '2048';
      case 'hexapawn':
        return 'Hexapawn';
      case 'mini_tournament':
        return 'Mini Turnuva';
      case 'quick_math':
      default:
        return 'Hızlı Matematik';
    }
  }

  String get _mascotName {
    final customName = _userPersonalization.mascotName.trim();
    return customName.isNotEmpty ? customName : 'Pofi';
  }

  MascotReaction _baselineMascotReaction() {
    if (_isFullyLocked) {
      return const MascotReaction(
        mood: MascotMood.warning,
        message: 'Süre bitti. Dinlenelim, yarın tekrar devam ederiz.',
      );
    }
    if (_isPlayRestricted) {
      return const MascotReaction(
        mood: MascotMood.sleepy,
        message: 'Sessiz saatteyiz. Şimdilik hikaye zamanı.',
      );
    }

    switch (_selectedIndex) {
      case 1:
        return const MascotReaction(
          mood: MascotMood.excited,
          message: 'Oyun zamanı! Bir oyun seç, sana destek olayım.',
        );
      case 2:
        return const MascotReaction(
          mood: MascotMood.thinking,
          message: 'Öğrenme görevleri hazır. Hadi birini seçelim.',
        );
      case 0:
      default:
        return const MascotReaction(
          mood: MascotMood.idle,
          message: 'Bir hikaye seç, beraber keşfe çıkalım.',
        );
    }
  }

  void _setMascotToBaseline() {
    _mascotResetTimer?.cancel();
    if (!mounted) return;
    setState(() => _mascotReaction = _baselineMascotReaction());
  }

  void _setMascotReaction(
    MascotMood mood,
    String message, {
    Duration duration = const Duration(seconds: 4),
    bool autoReset = true,
  }) {
    _mascotResetTimer?.cancel();
    if (!mounted) return;

    setState(() {
      _mascotReaction = MascotReaction(
        mood: mood,
        message: message,
      );
    });

    if (!autoReset) return;
    _mascotResetTimer = Timer(duration, () {
      if (!mounted) return;
      setState(() => _mascotReaction = _baselineMascotReaction());
    });
  }

  void _onStoryOpened() {
    _setMascotReaction(
      MascotMood.happy,
      'Süper seçim! Hikayeni açıyorum.',
      duration: const Duration(seconds: 3),
    );
  }

  void _onGameStarted(String gameTitle) {
    _setMascotReaction(
      MascotMood.celebrate,
      '$gameTitle başlıyor. Eğlenerek öğrenelim!',
      duration: const Duration(seconds: 3),
    );
  }

  void _onMascotTapped() {
    final messages = switch (_selectedIndex) {
      0 => const [
          'Bir kahraman seç, macerayı birlikte okuyalım.',
          'Bugün hayal gücüne puanım: 10/10!',
          'Yeni bir hikaye kartına dokunmayı dene.',
        ],
      1 => const [
          'Hadi refleks testi! Bir oyun başlat.',
          'Kazansan da kaybetsen de öğreniyorsun.',
          'Bu turda strateji kullanmayı unutma.',
        ],
      2 => const [
          'Kısa bir öğrenme görevi yapalım mı?',
          'Bugün hedef: az ama düzenli pratik.',
          'Hazırsan bir öğrenme kartı aç.',
        ],
      _ => const ['Buradayım, devam edelim!'],
    };

    final mood = switch (_selectedIndex) {
      1 => MascotMood.excited,
      2 => MascotMood.thinking,
      _ => MascotMood.happy,
    };

    final message = messages[_mascotTapCount % messages.length];
    _mascotTapCount++;
    _setMascotReaction(mood, message);
  }

  Future<void> _refreshSafetyState({bool allowBreakReminder = true}) async {
    final settings = await _familySettingsService.getSettings();
    final status = await _screenTimeService.getStatus(
      limitEnabled: settings.screenTimeLimitEnabled,
      dailyLimitMinutes: settings.dailyScreenTimeLimitMinutes,
    );
    final quietHours = settings.isWithinQuietHours(DateTime.now());
    final canApplyRestrictions = !_isParentMode && !_isDevModeBypass;
    final limitReached = canApplyRestrictions && status.isLimitReached;
    final quietActive = canApplyRestrictions && quietHours;
    final wasLimitReached = _isScreenTimeLimitReached;
    final wasQuietActive = _isQuietHoursActive;

    if (!mounted) return;
    setState(() {
      _familySettings = settings;
      _screenTimeStatus = status;
      _isScreenTimeLimitReached = limitReached;
      _isQuietHoursActive = quietActive;
      if ((limitReached || quietActive) && _selectedIndex != 0) {
        _selectedIndex = 0;
      }
    });

    if (!wasLimitReached && limitReached) {
      _setMascotReaction(
        MascotMood.warning,
        'Bugünlük süre tamamlandı. Biraz dinlenelim.',
        autoReset: false,
      );
    } else if (!wasQuietActive && quietActive) {
      _setMascotReaction(
        MascotMood.sleepy,
        'Sessiz saat başladı. Hikaye köşesinde sakin devam edelim.',
        autoReset: false,
      );
    } else if ((wasLimitReached && !limitReached) ||
        (wasQuietActive && !quietActive)) {
      _setMascotReaction(
        MascotMood.celebrate,
        'Harika, tekrar devam edebiliriz.',
        duration: const Duration(seconds: 3),
      );
    } else {
      _setMascotToBaseline();
    }

    if (!allowBreakReminder || !canApplyRestrictions || limitReached) return;

    final dueMinutes = await _screenTimeService.consumeDueBreakReminder(
      enabled: settings.breakReminderEnabled,
      intervalMinutes: settings.breakEveryMinutes,
    );

    if (!mounted || dueMinutes == null) return;
    _setMascotReaction(
      MascotMood.warning,
      '$dueMinutes dakika oldu, mini mola zamanı.',
      duration: const Duration(seconds: 3),
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$dueMinutes dakika oldu. Su içip 2-3 dakika mola verelim.',
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _loadInitialData() async {
    await _loadUserData(forceReloadStories: true);
  }

  Future<void> _checkAndReloadUser() async {
    final userId = await _localUserService.getSelectedUserId();
    final avatarUrl = await _localUserService.getSelectedUserAvatar(userId);
    final parentMode = await _localUserService.getIsParentMode();
    final devModeBypass = await _localUserService.getDevModeBypass();
    if (!mounted) return;

    final shouldReload = userId != _lastLoadedUserId ||
        avatarUrl != _currentAvatarUrl ||
        parentMode != _isParentMode ||
        devModeBypass != _isDevModeBypass;

    if (shouldReload) {
      await _loadUserData(forceReloadStories: true);
      return;
    }

    await _refreshSafetyState(allowBreakReminder: false);
  }

  Future<void> _loadUserData({required bool forceReloadStories}) async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    final userId = await _localUserService.getSelectedUserId();
    final fetchedAvatarUrl =
        await _localUserService.getSelectedUserAvatar(userId);
    final personalization = userId == LocalUserService.defaultUserId
        ? const UserPersonalization()
        : await _localUserService.getUserPersonalization(userId);
    final parentMode = await _localUserService.getIsParentMode();
    final devModeBypass = await _localUserService.getDevModeBypass();
    if (!mounted) return;

    setState(() {
      _currentUsername =
          userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
      _lastLoadedUserId = userId;
      _currentAvatarUrl = fetchedAvatarUrl ?? defaultAvatarUrl;
      _userPersonalization = personalization;
      _isParentMode = parentMode;
      _isDevModeBypass = devModeBypass;
    });
    await _familySettingsService.syncFromCloudAndMerge();
    await _refreshSafetyState(allowBreakReminder: false);

    if (forceReloadStories || _stories.isEmpty) {
      await _fetchStories(userId: userId);
    } else if (mounted) {
      setState(() => _isLoading = false);
    }

    if (!mounted) return;
    _setMascotToBaseline();
  }

  Future<void> _fetchStories({String? userId}) async {
    final resolvedUserId =
        userId ?? await _localUserService.getSelectedUserId();

    try {
      final stories = await _storyService.getStoriesForUser(resolvedUserId);
      if (!mounted) return;

      setState(() {
        _stories = stories;
        _isLoading = false;
      });
    } catch (error, stackTrace) {
      debugPrint('Hikayeler çekilemedi: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _logoutAndRedirect() async {
    await _localUserService.logoutUser();
    if (!mounted) return;
    context.go(AppRoutes.auth);
  }

  Future<void> _forceSwitchProfile(String username) async {
    await _localUserService.setSelectedUserId(username);
    if (!mounted) return;
    await _loadUserData(forceReloadStories: true);
  }

  Future<bool> _showPasswordVerificationDialog(
    String targetUsername, {
    bool isStrict = false,
  }) async {
    String typedPassword = '';
    String? localError;

    final password = await showDialog<String>(
      context: context,
      barrierDismissible: !isStrict,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return PopScope(
              canPop: !isStrict,
              child: AlertDialog(
                title: Text(
                  isStrict ? 'Giriş Yap: $targetUsername' : 'Şifre Doğrulama',
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isStrict)
                      const Text('Devam etmek için şifrenizi doğrulayın.'),
                    TextField(
                      obscureText: true,
                      autofocus: true,
                      onChanged: (value) => typedPassword = value,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        errorText: localError,
                      ),
                      onSubmitted: (_) {
                        final value = typedPassword.trim();
                        if (value.isEmpty) {
                          setDialogState(
                            () => localError = 'Şifre boş olamaz.',
                          );
                          return;
                        }
                        Navigator.of(dialogContext).pop(value);
                      },
                    ),
                  ],
                ),
                actions: [
                  if (!isStrict)
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      child: const Text('İptal'),
                    ),
                  ElevatedButton(
                    onPressed: () {
                      final value = typedPassword.trim();
                      if (value.isEmpty) {
                        setDialogState(
                          () => localError = 'Şifre boş olamaz.',
                        );
                        return;
                      }
                      Navigator.of(dialogContext).pop(value);
                    },
                    child: const Text('Doğrula'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (password == null) return false;

    final result = await _localUserService.verifyPasswordDetailed(
      targetUsername,
      password,
    );
    if (!mounted) return false;

    if (!result.success) {
      final message = result.isLockedOut
          ? 'Çok fazla deneme. ${result.remainingLockSeconds} sn bekleyin.'
          : 'Yanlış şifre.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return false;
    }

    return true;
  }

  Future<void> _showProfileOptions(Offset anchorPosition) async {
    final allUsernames = await _localUserService.getAllRegisteredUsernames();
    final personalizations =
        await _localUserService.getUserPersonalizations(allUsernames);
    final displayNames = <String, String>{};
    for (final username in allUsernames) {
      final personalization = personalizations[username];
      if (personalization == null) continue;
      final displayName = personalization.displayName.trim();
      if (displayName.isNotEmpty) {
        displayNames[username] = displayName;
      }
    }
    if (!mounted) return;

    final switchableUsers =
        allUsernames.where((name) => name != _currentUsername);
    final isGuest = _currentUsername == 'Misafir';

    final menuItems = <PopupMenuEntry<String>>[
      ...switchableUsers.map(
        (username) => PopupMenuItem<String>(
          value: username,
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: const Color(0xFFE2E9FF),
                child: Text(
                  username[0].toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6A6CC1),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  displayNames[username]?.isNotEmpty == true
                      ? 'Geçiş Yap: ${displayNames[username]} (@$username)'
                      : 'Geçiş Yap: $username',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
      ),
      if (switchableUsers.isNotEmpty) const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'logout',
        child: Row(
          children: [
            Icon(
              isGuest ? Icons.login : Icons.logout,
              color:
                  isGuest ? const Color(0xFF8EA5E7) : const Color(0xFFC88BAD),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isGuest ? 'Giriş Yap / Kayıt Ol' : 'Başka Biriyle Giriş Yap',
                style: TextStyle(
                  color: isGuest
                      ? const Color(0xFF8EA5E7)
                      : const Color(0xFFC88BAD),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    ];

    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;

    final selectedValue = await showMenu<String>(
      context: context,
      elevation: 8,
      shadowColor: Colors.black26,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 240),
      position: RelativeRect.fromLTRB(
        anchorPosition.dx,
        anchorPosition.dy,
        overlay.size.width - anchorPosition.dx,
        overlay.size.height - anchorPosition.dy,
      ),
      items: menuItems,
    );

    if (!mounted || selectedValue == null) return;

    if (selectedValue == 'logout') {
      await _logoutAndRedirect();
      return;
    }

    final isVerified = await _showPasswordVerificationDialog(
      selectedValue,
      isStrict: false,
    );
    if (!mounted || !isVerified) return;

    await _forceSwitchProfile(selectedValue);
  }

  Widget _buildStoriesTab() {
    return RefreshIndicator(
      onRefresh: () => _fetchStories(userId: _lastLoadedUserId),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 120),
        children: [
          _buildStoryHero(),
          const SizedBox(height: 14),
          if (_stories.isEmpty) _buildEmptyStoriesState(),
          ...List.generate(
            _stories.length,
            (index) => _buildAnimatedStoryCard(_stories[index], index),
          ),
        ],
      ),
    );
  }

  Widget _buildStoryHero() {
    final modeLabel = _isParentMode ? 'Ebeveyn Modu' : 'Keşif Modu';
    final headline = _currentUsername == 'Misafir'
        ? 'Bugün hangi maceraya çıkıyoruz?'
        : 'Hoş geldin $_visibleName, yeni hikaye seni bekliyor!';
    final showLimitInfo =
        _isChildMode && _familySettings.screenTimeLimitEnabled;
    final limitInfoText = showLimitInfo
        ? 'Süre: ${_screenTimeStatus.usedMinutes}/${_familySettings.dailyScreenTimeLimitMinutes} dk'
        : 'Hikayeleri aç, dinle, test çöz ve rozet topla.';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF92BCFF), Color(0xFFAD9DFF), Color(0xFFFFB1DE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2A2C4B8F),
            blurRadius: 22,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.24),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.auto_stories,
                        size: 16, color: Colors.white),
                    const SizedBox(width: 6),
                    Text(
                      modeLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_isDevModeBypass)
                const Icon(Icons.science, color: Colors.white, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            headline,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            limitInfoText,
            style: const TextStyle(color: Colors.white70),
          ),
          if (showLimitInfo) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: _screenTimeStatus.usageRatio,
                minHeight: 8,
                backgroundColor: Colors.white24,
                valueColor:
                    const AlwaysStoppedAnimation<Color>(Color(0xFFFFFFFF)),
              ),
            ),
          ],
          if (_isQuietHoursActive) ...[
            const SizedBox(height: 8),
            const Text(
              'Sessiz saat aktif: oyun ve öğrenme geçici olarak kapalı.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          if (_currentUsername != 'Misafir') ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    'Favori oyun: ${_favoriteGameLabel(_userPersonalization.favoriteGameKey)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_userPersonalization.interestTags.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      'İlgi: ${_userPersonalization.interestTags.take(2).join(', ')}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyStoriesState() {
    final canCreate = _isParentMode || _isDevModeBypass;
    final emptyText = _currentUsername == 'Misafir'
        ? 'Giriş yaparsan kendi kahramanlarını oluşturup hikaye yazabilirsin.'
        : (canCreate
            ? 'İlk hikayeni yazmak için yukarıdaki (+) butonunu kullan.'
            : 'Hikaye oluşturmak için önce Ebeveyn Modunu açmalısın.');

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: const Color(0xFFEFE9FF),
                borderRadius: BorderRadius.circular(28),
              ),
              child: const Icon(Icons.menu_book_rounded,
                  color: Color(0xFF7D6FCB), size: 44),
            ),
            const SizedBox(height: 12),
            const Text(
              'Hikaye Rafında Şimdilik Boşluk Var',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              emptyText,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnimatedStoryCard(Story story, int index) {
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 260 + (index * 60)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0.0, end: 1.0),
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: child,
          ),
        );
      },
      child: _StoryTileCard(
        story: story,
        onTap: _onStoryOpened,
      ),
    );
  }

  Widget _buildScreenTimeLockOverlay() {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: false,
        child: Container(
          color: Colors.white.withValues(alpha: 0.92),
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDEAFF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: const Icon(
                          Icons.hourglass_top_rounded,
                          size: 34,
                          color: Color(0xFF7B6BC9),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Günlük süre limiti doldu',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Bugün ${_screenTimeStatus.usedMinutes} dakika kullandın. Dinlenip yarın devam edebilirsin.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                context.push(AppRoutes.profile);
                              },
                              icon: const Icon(Icons.settings_outlined),
                              label: const Text('Ayarlar'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _refreshSafetyState(allowBreakReminder: false);
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Kontrol Et'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final initialLetter =
        _currentUsername.isNotEmpty ? _currentUsername[0].toUpperCase() : 'M';

    final profileAvatarWidget = CircleAvatar(
      radius: 18,
      backgroundColor: const Color(0xFFDDE7FF),
      backgroundImage:
          _currentAvatarUrl != null && _currentUsername != 'Misafir'
              ? CachedNetworkImageProvider(_currentAvatarUrl!)
              : null,
      child: _currentAvatarUrl == null || _currentUsername == 'Misafir'
          ? Text(
              initialLetter,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B70C4),
              ),
            )
          : null,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: PlayfulPalette.tabBackground(_selectedIndex),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: GestureDetector(
            onTap: () async {
              await context.push(AppRoutes.profile);
              if (!mounted) return;
              await _loadUserData(forceReloadStories: false);
            },
            onLongPressStart: (details) {
              _showProfileOptions(details.globalPosition);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                profileAvatarWidget,
                const SizedBox(width: 8),
                Text(
                  _selectedIndex == 0
                      ? 'Hikaye Kulubu ($_visibleName)'
                      : '($_visibleName)',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          automaticallyImplyLeading: false,
          actions: [
            if (_selectedIndex == 0 && _isParentMode)
              IconButton(
                icon: const Icon(Icons.add_box_outlined),
                onPressed: () => context.push(AppRoutes.create),
              ),
            if (_selectedIndex == 0 && _isDevModeBypass && !_isParentMode)
              IconButton(
                icon: const Icon(Icons.add_box_outlined),
                tooltip: 'Dev mode ile oluşturma',
                onPressed: () => context.push(AppRoutes.create),
              ),
            if (_isDevModeBypass)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Icon(Icons.science, color: Color(0xFFAD85D9)),
              ),
            if (_selectedIndex == 0)
              IconButton(
                icon: const Icon(Icons.refresh),
                onPressed: () {
                  _setMascotReaction(
                    MascotMood.thinking,
                    'Yeni hikayeleri kontrol ediyorum...',
                  );
                  setState(() {
                    _stories = [];
                    _isLoading = true;
                  });
                  _fetchStories(userId: _lastLoadedUserId);
                },
              ),
            const SizedBox(width: 8),
          ],
        ),
        body: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: [
                _buildStoriesTab(),
                GameHubScreen(onGameStarted: _onGameStarted),
                const LearningHubScreen(),
              ],
            ),
            if (_isFullyLocked) _buildScreenTimeLockOverlay(),
            Positioned(
              right: 14,
              bottom: 98,
              child: ReactiveMascot(
                name: _mascotName,
                reaction: _mascotReaction,
                onTap: _onMascotTapped,
              ),
            ),
          ],
        ),
        bottomNavigationBar: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x22416685),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: NavigationBar(
            backgroundColor: Colors.transparent,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              if (index != 0 && (_isFullyLocked || _isPlayRestricted)) {
                final message = _isFullyLocked
                    ? 'Günlük süre limiti doldu. Yarın devam edebilirsin.'
                    : 'Sessiz saat aktif. Oyun ve öğrenme sonra açılacak.';
                _setMascotReaction(
                  MascotMood.warning,
                  _isFullyLocked
                      ? 'Bugünlük oyun bitti, yarın devam ederiz.'
                      : 'Sessiz saatteyiz. Şimdilik hikayeler açık.',
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(message)),
                );
                return;
              }
              setState(() => _selectedIndex = index);

              if (index == 0) {
                _setMascotReaction(
                  MascotMood.happy,
                  'Hikaye sekmesi hazır. Bir macera seç!',
                );
              } else if (index == 1) {
                _setMascotReaction(
                  MascotMood.excited,
                  'Süper, oyun sekmesine geçtik!',
                );
              } else {
                _setMascotReaction(
                  MascotMood.thinking,
                  'Öğrenme görevleri seni bekliyor.',
                );
              }
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.book_outlined),
                selectedIcon: Icon(Icons.book_rounded),
                label: 'Hikayeler',
              ),
              NavigationDestination(
                icon: Icon(Icons.sports_esports_outlined),
                selectedIcon: Icon(Icons.sports_esports),
                label: 'Oyun',
              ),
              NavigationDestination(
                icon: Icon(Icons.school_outlined),
                selectedIcon: Icon(Icons.school),
                label: 'Öğrenme',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryTileCard extends StatelessWidget {
  const _StoryTileCard({
    required this.story,
    this.onTap,
  });

  final Story story;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final previewText = story.text.length > 96
        ? '${story.text.substring(0, 96)}...'
        : story.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: () {
          onTap?.call();
          context.push(AppRoutes.storyDetail.replaceFirst(':id', story.id));
        },
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F34558E),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(color: const Color(0xFFD9E8FA), width: 1.2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: story.imageUrl,
                    width: 86,
                    height: 86,
                    fit: BoxFit.cover,
                    placeholder: (context, _) => Container(
                      width: 86,
                      height: 86,
                      color: const Color(0xFFE8EEF6),
                    ),
                    errorWidget: (context, _, __) => Container(
                      width: 86,
                      height: 86,
                      color: const Color(0xFFFFE4E1),
                      child: const Icon(Icons.broken_image_outlined),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        story.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        previewText,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _MiniBadge(text: 'Bölüm ${story.chapterIndex}'),
                          _MiniBadge(text: 'Yaş ${story.ageProfile.key}'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(
                  Icons.arrow_circle_right_outlined,
                  color: Color(0xFF7B73C9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniBadge extends StatelessWidget {
  const _MiniBadge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFFF1EDFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF625AA8),
        ),
      ),
    );
  }
}
