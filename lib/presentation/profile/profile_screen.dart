import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/dummy/avatars.dart';
import '../../data/services/family_settings_service.dart';
import '../../data/services/local_user_service.dart';
import '../../data/services/screen_time_service.dart';
import '../../router/app_router.dart';
import '../theme/app_theme_controller.dart';
import '../theme/playful_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final LocalUserService _localUserService = LocalUserService();
  final AppThemeController _themeController = AppThemeController.instance;
  final FamilySettingsService _familySettingsService = FamilySettingsService();
  final ScreenTimeService _screenTimeService = ScreenTimeService();

  String _currentUsername = 'Misafir';
  String? _currentAvatarUrl;
  bool _isParentMode = false;
  bool _isDevModeBypass = false;
  bool _isLoading = true;
  AppThemePalette _selectedThemePalette = AppThemePalette.candySky;
  FamilySafetySettings _familySettings = const FamilySafetySettings();
  int _todayUsedMinutes = 0;
  UserPersonalization _personalization = const UserPersonalization();
  ReadingAccessibilityProfile _readingAccessibility =
      const ReadingAccessibilityProfile();

  static const List<_PersonalOption> _ageBandOptions = [
    _PersonalOption('age_4_6', '4-6'),
    _PersonalOption('age_7_9', '7-9'),
    _PersonalOption('age_10_12', '10-12'),
  ];

  static const List<_PersonalOption> _storyStyleOptions = [
    _PersonalOption('fairy_tale', 'Masal'),
    _PersonalOption('funny', 'Komik'),
    _PersonalOption('adventure', 'Macera'),
    _PersonalOption('educational', 'Eğitim'),
    _PersonalOption('bedtime', 'Uyku'),
  ];

  static const List<_PersonalOption> _gameOptions = [
    _PersonalOption('quick_math', 'Hızlı Matematik'),
    _PersonalOption('memory_match', 'Hafıza Eşleştirme'),
    _PersonalOption('rps', 'Taş Kağıt Makas'),
    _PersonalOption('game_2048', '2048'),
    _PersonalOption('hexapawn', 'Hexapawn'),
    _PersonalOption('mini_tournament', 'Mini Turnuva'),
  ];

  static const List<String> _interestOptions = [
    'Uzay',
    'Dinozor',
    'Prenses',
    'Robot',
    'Hayvanlar',
    'Deniz',
    'Bilim',
    'Müzik',
    'Çizim',
    'Spor',
    'Bulmaca',
    'Arkadaşlık',
  ];

  bool get _isGuest => _currentUsername == 'Misafir';
  bool get _canEditSafetySettings =>
      !_isGuest && (_isParentMode || _isDevModeBypass);

  @override
  void initState() {
    super.initState();
    _themeController.addListener(_onThemeChanged);
    _loadUserData();
  }

  @override
  void dispose() {
    _themeController.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    if (!mounted) return;
    setState(() {
      _selectedThemePalette = _themeController.value;
    });
  }

  Future<void> _loadUserData() async {
    final userId = await _localUserService.getSelectedUserId();
    final avatarUrl = userId != LocalUserService.defaultUserId
        ? await _localUserService.getSelectedUserAvatar(userId)
        : defaultAvatarUrl;
    final parentMode = await _localUserService.getIsParentMode();
    final devModeBypass = await _localUserService.getDevModeBypass();
    await _familySettingsService.syncFromCloudAndMerge();
    final familySettings = await _familySettingsService.getSettings();
    final todayUsedMinutes = await _screenTimeService.getTodayUsedMinutes();
    final personalization = userId == LocalUserService.defaultUserId
        ? const UserPersonalization()
        : await _localUserService.getUserPersonalization(userId);
    final readingAccessibility =
        await _localUserService.getReadingAccessibilityProfile(userId);

    if (!mounted) return;
    setState(() {
      _currentUsername =
          userId == LocalUserService.defaultUserId ? 'Misafir' : userId;
      _currentAvatarUrl = avatarUrl;
      _isParentMode = parentMode;
      _isDevModeBypass = devModeBypass;
      _selectedThemePalette = _themeController.value;
      _familySettings = familySettings;
      _todayUsedMinutes = todayUsedMinutes;
      _personalization = personalization;
      _readingAccessibility = readingAccessibility;
      _isLoading = false;
    });
  }

  Future<void> _logoutAndRedirect() async {
    await _localUserService.logoutUser();
    if (!mounted) return;
    context.go(AppRoutes.auth);
  }

  Future<void> _switchProfile() async {
    await _localUserService.logoutUser();
    if (!mounted) return;
    context.go(AppRoutes.profileSelection);
  }

  Future<String?> _askPasswordDialog() async {
    String typedPassword = '';
    String? localError;

    final password = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Ebeveyn Doğrulaması'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Modu değiştirmek için şifrenizi girin: ($_currentUsername)',
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    autofocus: true,
                    obscureText: true,
                    onChanged: (value) => typedPassword = value,
                    decoration: InputDecoration(
                      labelText: 'Şifre',
                      errorText: localError,
                    ),
                    onSubmitted: (_) {
                      final value = typedPassword.trim();
                      if (value.isEmpty) {
                        setDialogState(() => localError = 'Şifre boş olamaz.');
                        return;
                      }
                      Navigator.of(dialogContext).pop(value);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final value = typedPassword.trim();
                    if (value.isEmpty) {
                      setDialogState(() => localError = 'Şifre boş olamaz.');
                      return;
                    }
                    Navigator.of(dialogContext).pop(value);
                  },
                  child: const Text('Doğrula'),
                ),
              ],
            );
          },
        );
      },
    );

    return password;
  }

  Future<void> _toggleParentMode(bool requestedValue) async {
    if (_isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Giriş yapmadan ayarları değiştiremezsiniz.'),
        ),
      );
      return;
    }

    final password = await _askPasswordDialog();
    if (!mounted || password == null) return;

    final verification = await _localUserService.verifyPasswordDetailed(
      _currentUsername,
      password,
    );
    if (!mounted) return;

    if (!verification.success) {
      final message = verification.isLockedOut
          ? 'Çok fazla deneme. ${verification.remainingLockSeconds} sn bekleyin.'
          : 'Yanlış şifre.';
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
      return;
    }

    await _localUserService.setIsParentMode(requestedValue);
    if (!mounted) return;

    setState(() => _isParentMode = requestedValue);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          requestedValue
              ? 'Ebeveyn modu açıldı (10 dakika sonra otomatik kapanır).'
              : 'Ebeveyn modu kapatıldı.',
        ),
      ),
    );
    context.go(AppRoutes.home);
  }

  Future<void> _toggleDevModeBypass(bool value) async {
    await _localUserService.setDevModeBypass(value);
    if (!mounted) return;

    setState(() => _isDevModeBypass = value);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          value
              ? 'Dev Test Modu açıldı. Ebeveyn kilitleri test için gevşetildi.'
              : 'Dev Test Modu kapatıldı.',
        ),
      ),
    );
  }

  Future<void> _applyThemePalette(AppThemePalette palette) async {
    await _themeController.setThemePalette(palette);
    if (!mounted) return;

    setState(() => _selectedThemePalette = palette);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Uygulama paleti: ${palette.label}')),
    );
  }

  void _showParentPermissionInfo() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
           'Bu ayarı değiştirmek için Ebeveyn Modu veya Dev Test Modu gerekli.',
        ),
      ),
    );
  }

  Future<void> _updateFamilySettings(FamilySafetySettings updated) async {
    if (!_canEditSafetySettings) {
      _showParentPermissionInfo();
      return;
    }

    await _familySettingsService.saveSettings(updated);
    if (!mounted) return;

    setState(() => _familySettings = updated);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aile güvenlik ayarları güncellendi.')),
    );
  }

  Future<void> _refreshScreenTimeUsage() async {
    final minutes = await _screenTimeService.getTodayUsedMinutes();
    if (!mounted) return;
    setState(() => _todayUsedMinutes = minutes);
  }

  Future<void> _updateReadingAccessibility(
    ReadingAccessibilityProfile updated,
  ) async {
    final userId = await _localUserService.getSelectedUserId();
    await _localUserService.saveReadingAccessibilityProfile(userId, updated);
    if (!mounted) return;
    setState(() => _readingAccessibility = updated);
    ScaffoldMessenger.of(context).showSnackBar(
       const SnackBar(
           content: Text('Okuma erişilebilirlik ayarları kaydedildi.')),
    );
  }

  String _hourLabel(int hour) => _familySettingsService.hourLabel(hour);

  String _quietHoursSummary(FamilySafetySettings settings) {
     if (!settings.quietHoursEnabled) return 'Kapalı';
    return '${_hourLabel(settings.quietHoursStartHour)} - ${_hourLabel(settings.quietHoursEndHour)}';
  }

  String _optionLabel(List<_PersonalOption> options, String key) {
    for (final option in options) {
      if (option.key == key) return option.label;
    }
    return options.isNotEmpty ? options.first.label : '-';
  }

  InputDecoration _dropdownDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      border: const OutlineInputBorder(),
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
    );
  }

  String _effectiveDisplayName() {
    final displayName = _personalization.displayName.trim();
    if (displayName.isNotEmpty) return displayName;
    return _currentUsername;
  }

  Future<void> _openPersonalizationEditor() async {
    if (_isGuest) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
           content: Text('Misafir profilde kişiselleştirme kapalı.')),
      );
      return;
    }

    final displayNameController = TextEditingController(
      text: _personalization.displayName,
    );
    final aboutController = TextEditingController(text: _personalization.about);
    final mascotController = TextEditingController(
      text: _personalization.mascotName,
    );

    var ageBandKey = _personalization.ageBandKey;
    var storyStyleKey = _personalization.favoriteStoryStyleKey;
    var gameKey = _personalization.favoriteGameKey;
    final selectedInterests = <String>{..._personalization.interestTags};

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 18,
                right: 18,
                top: 16,
                bottom: 16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                       'Kişisel Profil Kartı',
                      style:
                          TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: displayNameController,
                      maxLength: 24,
                      decoration: const InputDecoration(
                         labelText: 'Görünen isim',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: aboutController,
                      maxLength: 80,
                      maxLines: 2,
                      decoration: const InputDecoration(
                         labelText: 'Kısa tanıtım',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: mascotController,
                      maxLength: 20,
                      decoration: const InputDecoration(
                         labelText: 'Favori kahraman/oyuncak adı',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: ageBandKey,
                            decoration: _dropdownDecoration('Yaş grubu'),
                            items: _ageBandOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option.key,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() => ageBandKey = value);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: storyStyleKey,
                            decoration:
                                _dropdownDecoration('Favori hikaye stili'),
                            items: _storyStyleOptions
                                .map(
                                  (option) => DropdownMenuItem<String>(
                                    value: option.key,
                                    child: Text(option.label),
                                  ),
                                )
                                .toList(growable: false),
                            onChanged: (value) {
                              if (value == null) return;
                              setSheetState(() => storyStyleKey = value);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      isExpanded: true,
                      initialValue: gameKey,
                      decoration: _dropdownDecoration('Favori oyun'),
                      items: _gameOptions
                          .map(
                            (option) => DropdownMenuItem<String>(
                              value: option.key,
                              child: Text(option.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: (value) {
                        if (value == null) return;
                        setSheetState(() => gameKey = value);
                      },
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'İlgi alanları (en fazla 6)',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _interestOptions.map((tag) {
                        final isSelected = selectedInterests.contains(tag);
                        return FilterChip(
                          selected: isSelected,
                          label: Text(tag),
                          onSelected: (value) {
                            setSheetState(() {
                              if (value) {
                                if (selectedInterests.length < 6) {
                                  selectedInterests.add(tag);
                                }
                              } else {
                                selectedInterests.remove(tag);
                              }
                            });
                          },
                        );
                      }).toList(growable: false),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            child: const Text('İptal'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              final cleanDisplayName =
                                  displayNameController.text.trim();
                              if (cleanDisplayName.length > 24) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                     content: Text(
                                         'Görünen isim 24 karakteri geçemez.'),
                                  ),
                                );
                                return;
                              }

                              final updated = UserPersonalization(
                                displayName: cleanDisplayName,
                                about: aboutController.text.trim(),
                                ageBandKey: ageBandKey,
                                favoriteStoryStyleKey: storyStyleKey,
                                favoriteGameKey: gameKey,
                                interestTags:
                                    selectedInterests.toList(growable: false),
                                mascotName: mascotController.text.trim(),
                              );

                              await _localUserService.saveUserPersonalization(
                                _currentUsername,
                                updated,
                              );
                              if (!mounted) return;

                              // Pop the sheet BEFORE triggering setState so the
                              // sheet's TextFields are removed from the tree
                              // before the parent rebuilds.
                              if (sheetContext.mounted) {
                                Navigator.of(sheetContext).pop();
                              }
                              setState(() => _personalization = updated);
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                 const SnackBar(
                                   content: Text('Kişisel profil güncellendi.'),
                                ),
                              );
                            },
                            child: const Text('Kaydet'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    // Dispose after the sheet is fully removed from the widget tree.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      displayNameController.dispose();
      aboutController.dispose();
      mascotController.dispose();
    });
  }

  void _showAvatarSelectionMenu() {
    if (_isGuest) return;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.9,
          expand: true,
          builder: (context, scrollController) {
            return Material(
              color: Colors.white,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(20)),
              child: DefaultTabController(
                length: predefinedAvatars.length,
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                       'Yeni Avatarını Seç',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    TabBar(
                      isScrollable: true,
                      labelColor: const Color(0xFF7D6CC4),
                      unselectedLabelColor: const Color(0xFF8F92A7),
                      tabs: predefinedAvatars
                          .map((category) => Tab(text: category.name))
                          .toList(),
                    ),
                    Expanded(
                      child: TabBarView(
                        children: predefinedAvatars.map((category) {
                          return GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                            ),
                            itemCount: category.imageUrls.length,
                            itemBuilder: (context, index) {
                              final url = category.imageUrls[index];
                              return GestureDetector(
                                onTap: () async {
                                  await _localUserService.setSelectedUserAvatar(
                                    _currentUsername,
                                    url,
                                  );
                                  if (!mounted) return;

                                  setState(() => _currentAvatarUrl = url);
                                  if (sheetContext.mounted) {
                                    Navigator.of(sheetContext).pop();
                                  }
                                  ScaffoldMessenger.of(this.context)
                                      .showSnackBar(
                                    const SnackBar(
                                      content: Text('Avatar güncellendi.'),
                                    ),
                                  );
                                },
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border:
                                        Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: ClipOval(
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      placeholder: (context, _) => const Center(
                                        child: SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, _, __) =>
                                          const Icon(Icons.error),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatusChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniPalettePreview(AppThemePalette palette) {
    final previewColors = PlayfulPalette.previewColors(palette);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: previewColors
          .map(
            (color) => Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildThemeOption(AppThemePalette palette) {
    final isSelected = _selectedThemePalette == palette;
    final previewColors = PlayfulPalette.previewColors(palette);
    final borderColor = isSelected
        ? Theme.of(context).colorScheme.primary
        : const Color(0xFFDCE4F4);

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => _applyThemePalette(palette),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: isSelected ? 1.6 : 1),
        ),
        child: Row(
          children: [
            ...previewColors.map(
              (color) => Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    palette.label,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    palette.description,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalSummaryCard() {
    final displayName = _effectiveDisplayName();
    final about = _personalization.about.trim();
    final ageBandLabel =
        _optionLabel(_ageBandOptions, _personalization.ageBandKey);
    final storyStyleLabel = _optionLabel(
      _storyStyleOptions,
      _personalization.favoriteStoryStyleKey,
    );
    final favoriteGameLabel = _optionLabel(
      _gameOptions,
      _personalization.favoriteGameKey,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.badge_outlined, color: Color(0xFF6A73C8)),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Kişisel Profil Kartı',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                TextButton.icon(
                  onPressed: _openPersonalizationEditor,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Düzenle'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildStatusChip(
                  icon: Icons.person_outline,
                  label: displayName,
                  color: const Color(0xFF6D86D8),
                ),
                _buildStatusChip(
                  icon: Icons.cake_outlined,
                  label: 'Yaş: $ageBandLabel',
                  color: const Color(0xFF7D6CC4),
                ),
                _buildStatusChip(
                  icon: Icons.auto_stories_outlined,
                  label: storyStyleLabel,
                  color: const Color(0xFF5F9DE0),
                ),
                _buildStatusChip(
                  icon: Icons.sports_esports_outlined,
                  label: favoriteGameLabel,
                  color: const Color(0xFFAA78C9),
                ),
              ],
            ),
            if (about.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                about,
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (_personalization.mascotName.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Favori kahraman: ${_personalization.mascotName.trim()}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _personalization.interestTags.isEmpty
                  ? const [
                      Chip(
                        label: Text('İlgi alanı ekle'),
                        avatar: Icon(Icons.add_reaction_outlined, size: 18),
                      ),
                    ]
                  : _personalization.interestTags
                      .map(
                        (tag) => Chip(
                          label: Text(tag),
                          avatar: const Icon(Icons.star_outline, size: 16),
                        ),
                      )
                      .toList(growable: false),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab(Widget avatarWidget) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  PlayfulPalette.sky,
                  PlayfulPalette.grape,
                  PlayfulPalette.coral,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: PlayfulPalette.grape.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: const Text(
              'Profil merkezinden hesabını yönet, avatarını güncelle ve ayarlara hızlı geçiş yap.',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      avatarWidget,
                      if (!_isGuest)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: _showAvatarSelectionMenu,
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFAA95FF),
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: Colors.white,
                                  size: 24,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _effectiveDisplayName(),
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                     _isGuest ? 'Lütfen giriş yapın.' : '@$_currentUsername',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildStatusChip(
                        icon: _isParentMode ? Icons.lock_open : Icons.lock,
                         label: _isParentMode ? 'Ebeveyn Açık' : 'Çocuk Modu',
                        color: _isParentMode
                            ? const Color(0xFF7D5FD6)
                            : const Color(0xFF5F9DE0),
                      ),
                      _buildStatusChip(
                        icon: Icons.science_outlined,
                        label: _isDevModeBypass
                             ? 'Dev Test Açık'
                             : 'Dev Test Kapalı',
                        color: _isDevModeBypass
                            ? const Color(0xFFB184D8)
                            : const Color(0xFF8B97B6),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          if (!_isGuest) _buildPersonalSummaryCard(),
          if (!_isGuest) const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _logoutAndRedirect,
              icon: Icon(_isGuest ? Icons.login : Icons.logout),
              label: Text(_isGuest ? 'Giriş Yap / Kayıt Ol' : 'Oturumu Kapat'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                backgroundColor: _isGuest
                    ? const Color(0xFF98A8FF)
                    : const Color(0xFFD28EB6),
                foregroundColor: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => context.go(AppRoutes.auth),
              icon: const Icon(Icons.person_add),
              label: const Text('Yeni Profil Olustur'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
                foregroundColor: const Color(0xFF6671C4),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsTab() {
    final canEditSafety = _canEditSafetySettings;
    final safeLimit = _familySettings.dailyScreenTimeLimitMinutes;
    final usageRatio =
        safeLimit <= 0 ? 0.0 : (_todayUsedMinutes / safeLimit).clamp(0.0, 1.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 14, 24, 28),
      child: Column(
        children: [
          Card(
            child: Theme(
              data:
                  Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
                childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                leading: const Icon(Icons.palette_outlined),
                title: const Text(
                  'Genel Uygulama Renk Paleti',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    children: [
                      _buildMiniPalettePreview(_selectedThemePalette),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Secili: ${_selectedThemePalette.label}',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Bu secim tum ekranlarda tema tonunu degistirir.',
                      style: TextStyle(color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Column(
                    children: AppThemePalette.values
                        .map(
                          (palette) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _buildThemeOption(palette),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.accessibility_new_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Okuma Erisilebilirligi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Yazi, satir vurgusu ve TTS sesi her profil icin kisisellesir.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Yazi boyutu: ${_readingAccessibility.fontScale.toStringAsFixed(2)}x',
                  ),
                  Slider(
                    value: _readingAccessibility.fontScale,
                    min: 0.9,
                    max: 1.4,
                    divisions: 10,
                    onChanged: (value) {
                      setState(
                        () => _readingAccessibility =
                            _readingAccessibility.copyWith(fontScale: value),
                      );
                    },
                    onChangeEnd: (value) {
                      _updateReadingAccessibility(
                        _readingAccessibility.copyWith(fontScale: value),
                      );
                    },
                  ),
                  Text(
                    'Harf araligi: ${_readingAccessibility.letterSpacing.toStringAsFixed(1)}',
                  ),
                  Slider(
                    value: _readingAccessibility.letterSpacing,
                    min: 0.0,
                    max: 1.5,
                    divisions: 15,
                    onChanged: (value) {
                      setState(
                        () => _readingAccessibility = _readingAccessibility
                            .copyWith(letterSpacing: value),
                      );
                    },
                    onChangeEnd: (value) {
                      _updateReadingAccessibility(
                        _readingAccessibility.copyWith(letterSpacing: value),
                      );
                    },
                  ),
                  Text(
                    'TTS hizi: ${_readingAccessibility.ttsRate.toStringAsFixed(2)}',
                  ),
                  Slider(
                    value: _readingAccessibility.ttsRate,
                    min: 0.3,
                    max: 0.75,
                    divisions: 9,
                    onChanged: (value) {
                      setState(
                        () => _readingAccessibility =
                            _readingAccessibility.copyWith(ttsRate: value),
                      );
                    },
                    onChangeEnd: (value) {
                      _updateReadingAccessibility(
                        _readingAccessibility.copyWith(ttsRate: value),
                      );
                    },
                  ),
                  Text(
                    'TTS tonu: ${_readingAccessibility.ttsPitch.toStringAsFixed(2)}',
                  ),
                  Slider(
                    value: _readingAccessibility.ttsPitch,
                    min: 0.8,
                    max: 1.2,
                    divisions: 8,
                    onChanged: (value) {
                      setState(
                        () => _readingAccessibility =
                            _readingAccessibility.copyWith(ttsPitch: value),
                      );
                    },
                    onChangeEnd: (value) {
                      _updateReadingAccessibility(
                        _readingAccessibility.copyWith(ttsPitch: value),
                      );
                    },
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Satir vurgulama',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    subtitle: const Text(
                      'Sesli okumada aktif satiri renkle takip eder.',
                    ),
                    value: _readingAccessibility.lineHighlightEnabled,
                    onChanged: (value) {
                      final updated = _readingAccessibility.copyWith(
                        lineHighlightEnabled: value,
                      );
                      setState(() => _readingAccessibility = updated);
                      _updateReadingAccessibility(updated);
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.family_restroom_outlined),
                      SizedBox(width: 8),
                      Text(
                        'Çocuk Güvenlik Merkezi',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    canEditSafety
                        ? 'Ayarlar aktif. Bu ayarlar tum sayfalara uygulanir.'
                        : 'Bu bolumu duzenlemek icin Ebeveyn Modu acik olmali.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildStatusChip(
                        icon: Icons.shield_outlined,
                        label: _familySettings.storySafetyLevel.label,
                        color: const Color(0xFF6D86D8),
                      ),
                      _buildStatusChip(
                        icon: Icons.schedule_outlined,
                        label: _familySettings.screenTimeLimitEnabled
                            ? '$safeLimit dk limit'
                            : 'Sure limiti kapali',
                        color: const Color(0xFF8097D9),
                      ),
                      _buildStatusChip(
                        icon: Icons.nightlight_outlined,
                        label: _quietHoursSummary(_familySettings),
                        color: const Color(0xFF8663B7),
                      ),
                    ],
                  ),
                  if (_familySettings.screenTimeLimitEnabled) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Bugun: $_todayUsedMinutes / $safeLimit dk',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _refreshScreenTimeUsage,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Yenile'),
                        ),
                      ],
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        minHeight: 10,
                        value: usageRatio,
                        backgroundColor: const Color(0xFFEAEFF8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Gunluk Ekran Suresi Limiti',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Limit dolunca cocuk modunda etkinlikler kilitlenir.',
                    ),
                    value: _familySettings.screenTimeLimitEnabled,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(
                          screenTimeLimitEnabled: value,
                        ),
                      );
                    },
                    secondary: const Icon(Icons.timer_outlined),
                  ),
                  if (_familySettings.screenTimeLimitEnabled) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Row(
                        children: [
                          const Text('15 dk'),
                          Expanded(
                            child: Slider(
                              value: _familySettings.dailyScreenTimeLimitMinutes
                                  .toDouble(),
                              min: 15,
                              max: 180,
                              divisions: 33,
                              label:
                                  '${_familySettings.dailyScreenTimeLimitMinutes} dk',
                              onChanged: canEditSafety
                                  ? (value) {
                                      _updateFamilySettings(
                                        _familySettings.copyWith(
                                          dailyScreenTimeLimitMinutes:
                                              value.round(),
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                          const Text('180 dk'),
                        ],
                      ),
                    ),
                  ],
                  const Divider(),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Mola Hatirlatmasi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${_familySettings.breakEveryMinutes} dakikada bir mola onerir.',
                    ),
                    value: _familySettings.breakReminderEnabled,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(breakReminderEnabled: value),
                      );
                    },
                    secondary: const Icon(Icons.self_improvement_outlined),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    child: Row(
                      children: [
                        const Text('10 dk'),
                        Expanded(
                          child: Slider(
                            value: _familySettings.breakEveryMinutes.toDouble(),
                            min: 10,
                            max: 60,
                            divisions: 10,
                            label: '${_familySettings.breakEveryMinutes} dk',
                            onChanged: canEditSafety &&
                                    _familySettings.breakReminderEnabled
                                ? (value) {
                                    _updateFamilySettings(
                                      _familySettings.copyWith(
                                        breakEveryMinutes: value.round(),
                                      ),
                                    );
                                  }
                                : null,
                          ),
                        ),
                        const Text('60 dk'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
              child: Column(
                children: [
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Sessiz Saatler',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Bu saatlerde hikaye olusturma kilitlenir.',
                    ),
                    value: _familySettings.quietHoursEnabled,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(quietHoursEnabled: value),
                      );
                    },
                    secondary: const Icon(Icons.bedtime_outlined),
                  ),
                  if (_familySettings.quietHoursEnabled)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      child: Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _familySettings.quietHoursStartHour,
                              decoration: _dropdownDecoration('Baslangic'),
                              items: List.generate(
                                24,
                                (index) => DropdownMenuItem<int>(
                                  value: index,
                                  child: Text(_hourLabel(index)),
                                ),
                              ),
                              onChanged: canEditSafety
                                  ? (value) {
                                      if (value == null) return;
                                      _updateFamilySettings(
                                        _familySettings.copyWith(
                                          quietHoursStartHour: value,
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              isExpanded: true,
                              initialValue: _familySettings.quietHoursEndHour,
                              decoration: _dropdownDecoration('Bitis'),
                              items: List.generate(
                                24,
                                (index) => DropdownMenuItem<int>(
                                  value: index,
                                  child: Text(_hourLabel(index)),
                                ),
                              ),
                              onChanged: canEditSafety
                                  ? (value) {
                                      if (value == null) return;
                                      _updateFamilySettings(
                                        _familySettings.copyWith(
                                          quietHoursEndHour: value,
                                        ),
                                      );
                                    }
                                  : null,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
              child: Column(
                children: [
                  const ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 4),
                    leading: Icon(Icons.shield_moon_outlined),
                    title: Text(
                      'Hikaye Güvenlik Seviyesi',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      'Prompt ekranindaki icerik tonunu belirler.',
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: DropdownButtonFormField<StorySafetyLevel>(
                      isExpanded: true,
                      initialValue: _familySettings.storySafetyLevel,
                      decoration: _dropdownDecoration('Güvenlik seviyesi'),
                      items: StorySafetyLevel.values
                          .map(
                            (level) => DropdownMenuItem<StorySafetyLevel>(
                              value: level,
                              child: Text(level.label),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: canEditSafety
                          ? (value) {
                              if (value == null) return;
                              _updateFamilySettings(
                                _familySettings.copyWith(
                                  storySafetyLevel: value,
                                ),
                              );
                            }
                          : null,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                    child: Text(
                      _familySettings.storySafetyLevel.description,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                  const Divider(height: 4),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Oyuncak Fotograf Yukleme Izni',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Kapaliyken prompt ekraninda fotograf secimi gizlenir.',
                    ),
                    value: _familySettings.allowToyPhotoUpload,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(allowToyPhotoUpload: value),
                      );
                    },
                    secondary: const Icon(Icons.photo_camera_back_outlined),
                  ),
                  const Divider(height: 4),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Dusuk Uyarimli Gorunum',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Hikaye ekraninda 2.5D hareketleri azaltir.',
                    ),
                    value: _familySettings.lowStimulusModeEnabled,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(
                          lowStimulusModeEnabled: value,
                        ),
                      );
                    },
                    secondary: const Icon(Icons.motion_photos_off_outlined),
                  ),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Otomatik Sesli Okuma',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Hikaye acildiginda TTS otomatik baslasin.',
                    ),
                    value: _familySettings.allowAutoplayNarration,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(
                          allowAutoplayNarration: value,
                        ),
                      );
                    },
                    secondary: const Icon(Icons.record_voice_over_outlined),
                  ),
                  const Divider(height: 4),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'AI Icin Ebeveyn Onayi Zorunlu',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Aciksa cocuk modunda onay olmadan AI hikaye uretilmez.',
                    ),
                    value: _familySettings.requireParentalConsentForAi,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(
                          requireParentalConsentForAi: value,
                        ),
                      );
                    },
                    secondary: const Icon(Icons.verified_user_outlined),
                  ),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'AI Onayi Verildi',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Ebeveyn tarafindan AI hikaye/foto onayi verildi.',
                    ),
                    value: _familySettings.parentalConsentGranted,
                    onChanged: canEditSafety
                        ? (value) {
                            _updateFamilySettings(
                              _familySettings.copyWith(
                                parentalConsentGranted: value,
                              ),
                            );
                          }
                        : null,
                    secondary: const Icon(Icons.fact_check_outlined),
                  ),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'Veri Minimizasyonu',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Prompt kaydini kisaltip hassas kaliplari maskeler.',
                    ),
                    value: _familySettings.dataMinimizationMode,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(
                          dataMinimizationMode: value,
                        ),
                      );
                    },
                    secondary: const Icon(Icons.lock_clock_outlined),
                  ),
                  SwitchListTile.adaptive(
                    title: const Text(
                      'AI Seffaflik Paneli',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text(
                      'Hikaye ekraninda model ve veri ozetini gosterir.',
                    ),
                    value: _familySettings.transparencyModeEnabled,
                    onChanged: (value) {
                      _updateFamilySettings(
                        _familySettings.copyWith(
                          transparencyModeEnabled: value,
                        ),
                      );
                    },
                    secondary: const Icon(Icons.policy_outlined),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'COPPA Uyum Notlari',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1) Cocuk modunda AI icin ebeveyn onayi zorunlu tutulabilir.',
                  ),
                  Text(
                    '2) Veri minimizasyonu acikken prompt ozeti kisaltilarak saklanir.',
                  ),
                  Text(
                    '3) Seffaflik paneli ile model ve veri ozeti hikayede gorunur.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile.adaptive(
              title: const Text(
                'Ebeveyn Modu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                _isGuest
                    ? 'Misafir hesapta ebeveyn ayarlari kullanilamaz.'
                    : 'Hikaye olusturma gibi yetkili alanlari ac/kapat.',
              ),
              value: _isParentMode,
              onChanged: _isGuest ? null : _toggleParentMode,
              secondary: Icon(
                _isParentMode ? Icons.lock_open : Icons.lock,
                color: _isParentMode ? const Color(0xFF8E6CDA) : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: SwitchListTile.adaptive(
              title: const Text(
                'Dev Test Modu',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Simulator testi icin ebeveyn kilitlerini gecici olarak ac.',
              ),
              value: _isDevModeBypass,
              onChanged: _toggleDevModeBypass,
              secondary: Icon(
                _isDevModeBypass ? Icons.science : Icons.science_outlined,
                color: _isDevModeBypass ? const Color(0xFFB184D8) : null,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Profil Yonetimi',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _switchProfile,
                    icon: const Icon(Icons.switch_account),
                    label: const Text('Profil Degistir'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => context.go(AppRoutes.auth),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Yeni Profil Oluştur'),
                  ),
                ],
              ),
            ),
          ),
        ],
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

    final avatarWidget = CircleAvatar(
      radius: 60,
      backgroundColor: PlayfulPalette.sky.withValues(alpha: 0.85),
      backgroundImage: _currentAvatarUrl != null && !_isGuest
          ? CachedNetworkImageProvider(_currentAvatarUrl!)
          : null,
      child: _currentAvatarUrl == null || _isGuest
          ? Text(
              initialLetter,
              style: const TextStyle(
                fontSize: 50,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            )
          : null,
    );

    return DecoratedBox(
      decoration: BoxDecoration(gradient: PlayfulPalette.appBackground),
      child: DefaultTabController(
        length: 2,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: const Text('Profilim'),
            bottom: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.account_circle_outlined), text: 'Profil'),
                Tab(icon: Icon(Icons.settings_outlined), text: 'Ayarlar'),
              ],
            ),
          ),
          body: TabBarView(
            children: [
              _buildProfileTab(avatarWidget),
              _buildSettingsTab(),
            ],
          ),
        ),
      ),
    );
  }
}

class _PersonalOption {
  const _PersonalOption(this.key, this.label);

  final String key;
  final String label;
}
