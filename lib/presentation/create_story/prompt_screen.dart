import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:lottie/lottie.dart';

import '../../data/dummy/stories.dart';
import '../../data/i_story_service.dart';
import '../../data/services/connectivity_service.dart';
import '../../data/services/family_settings_service.dart';
import '../../data/services/local_user_service.dart';
import '../../data/services/openai_story_service.dart';
import '../../data/services/screen_time_service.dart';
import '../../data/services/storage_service.dart';
import '../../data/services/story_generation_models.dart';
import '../../router/app_router.dart';
import '../theme/playful_theme.dart';
import 'widgets/live_toy_preview.dart';

class PromptScreen extends StatefulWidget {
  const PromptScreen({super.key});

  @override
  State<PromptScreen> createState() => _PromptScreenState();
}

class _PromptScreenState extends State<PromptScreen> {
  late final IStoryService _storyService;
  final _connectivityService = ConnectivityService();
  final _storageService = StorageService();
  final _localUserService = LocalUserService();
  final _familySettingsService = FamilySettingsService();
  final _screenTimeService = ScreenTimeService();
  final _imagePicker = ImagePicker();

  final TextEditingController _promptController = TextEditingController();
  final TextEditingController _characterNameController =
      TextEditingController();
  final TextEditingController _characterPowerController =
      TextEditingController();
  final TextEditingController _characterPersonalityController =
      TextEditingController();
  final TextEditingController _characterWorldController =
      TextEditingController();

  bool _isButtonEnabled = false;
  bool _isProcessing = false;
  bool _isUploadingToyImage = false;
  bool _isPickingToyImage = false;

  StoryAgeProfile _selectedAgeProfile = StoryAgeProfile.age7to9;
  StoryStyle _selectedStyle = StoryStyle.adventure;
  StoryColorPalette _selectedColorPalette = StoryColorPalette.auto;
  bool _sceneMode = true;
  int _sceneCount = 3;
  File? _toyImageFile;
  String? _toyImageUrl;
  UserPersonalization _personalization = const UserPersonalization();
  String _appliedDefaultsUserId = '';
  bool _isParentMode = false;
  bool _isDevModeBypass = false;
  bool _isSafetyLoading = true;
  FamilySafetySettings _familySettings = const FamilySafetySettings();
  ScreenTimeStatus _screenTimeStatus = const ScreenTimeStatus(
    usedSeconds: 0,
    usedMinutes: 0,
    limitEnabled: false,
    dailyLimitMinutes: 0,
  );

  @override
  void initState() {
    super.initState();
    _storyService = OpenAIStoryService();
    _promptController.addListener(_updateButtonState);
    _loadSafetyState();
  }

  @override
  void dispose() {
    _promptController.removeListener(_updateButtonState);
    _promptController.dispose();
    _characterNameController.dispose();
    _characterPowerController.dispose();
    _characterPersonalityController.dispose();
    _characterWorldController.dispose();
    super.dispose();
  }

  void _updateButtonState() {
    setState(() {
      _isButtonEnabled = _promptController.text.trim().length >= 5;
    });
  }

  bool get _isChildMode => !_isParentMode && !_isDevModeBypass;

  bool get _isScreenTimeLocked =>
      _isChildMode &&
      _familySettings.screenTimeLimitEnabled &&
      _screenTimeStatus.isLimitReached;

  bool get _isQuietHoursLocked =>
      _isChildMode && _familySettings.isWithinQuietHours(DateTime.now());

  bool get _isPromptBlocked => _isScreenTimeLocked || _isQuietHoursLocked;
  bool get _reducedStimulusMode =>
      _isChildMode && _familySettings.lowStimulusModeEnabled;
  bool get _requiresAiConsent =>
      _isChildMode && _familySettings.requireParentalConsentForAi;
  bool get _hasAiConsent =>
      !_requiresAiConsent || _familySettings.parentalConsentGranted;
  bool get _hasToyReferenceForStory =>
      _familySettings.allowToyPhotoUpload &&
      _hasAiConsent &&
      (_toyImageFile != null || (_toyImageUrl ?? '').trim().isNotEmpty);

  Future<void> _loadSafetyState() async {
    final selectedUserId = await _localUserService.getSelectedUserId();
    final parentMode = await _localUserService.getIsParentMode();
    final devModeBypass = await _localUserService.getDevModeBypass();
    final personalization = selectedUserId == LocalUserService.defaultUserId
        ? const UserPersonalization()
        : await _localUserService.getUserPersonalization(selectedUserId);
    await _familySettingsService.syncFromCloudAndMerge();
    final familySettings = await _familySettingsService.getSettings();
    final screenTimeStatus = await _screenTimeService.getStatus(
      limitEnabled: familySettings.screenTimeLimitEnabled,
      dailyLimitMinutes: familySettings.dailyScreenTimeLimitMinutes,
    );

    if (!mounted) return;
    setState(() {
      _isParentMode = parentMode;
      _isDevModeBypass = devModeBypass;
      _familySettings = familySettings;
      _screenTimeStatus = screenTimeStatus;
      _personalization = personalization;
      if (_appliedDefaultsUserId != selectedUserId &&
          selectedUserId != LocalUserService.defaultUserId) {
        _selectedAgeProfile =
            StoryAgeProfileX.fromKey(personalization.ageBandKey);
        _selectedStyle =
            StoryStyleX.fromKey(personalization.favoriteStoryStyleKey);
        if (personalization.mascotName.trim().isNotEmpty &&
            _characterNameController.text.trim().isEmpty) {
          _characterNameController.text = personalization.mascotName.trim();
        }
        _appliedDefaultsUserId = selectedUserId;
      }
      if (familySettings.storySafetyLevel == StorySafetyLevel.strict &&
          _selectedAgeProfile == StoryAgeProfile.age10to12) {
        _selectedAgeProfile = StoryAgeProfile.age7to9;
      }
      if (familySettings.storySafetyLevel == StorySafetyLevel.strict &&
          _sceneCount > 3) {
        _sceneCount = 3;
      }
      _isSafetyLoading = false;
      if (!familySettings.allowToyPhotoUpload) {
        _toyImageFile = null;
        _toyImageUrl = null;
      }
    });
  }

  String _safetyModeHelperText() {
    final mode = _familySettings.storySafetyLevel;
    if (mode == StorySafetyLevel.strict) {
      return 'Sıkı güvenlik açık: daha yumuşak, sade ve sakin hikaye tonu uygulanır.';
    }
    if (mode == StorySafetyLevel.creative) {
      return 'Yaratıcı mod açık: hayal gücü daha geniş tutulur.';
    }
    return 'Dengeli mod açık: çocuk dostu varsayılan güvenlik uygulanır.';
  }

  String _safetyPrefixForPrompt() {
    switch (_familySettings.storySafetyLevel) {
      case StorySafetyLevel.strict:
        return 'Yumusak ve guvenli ton. Sade, sakin ve destekleyici anlatim. ';
      case StorySafetyLevel.creative:
        return 'Yaratici ama cocuk dostu ton. ';
      case StorySafetyLevel.balanced:
        return '';
    }
  }

  StoryCharacterProfile? _buildCharacterProfile({String? toyImageUrl}) {
    final name = _characterNameController.text.trim();
    final power = _characterPowerController.text.trim();
    final personality = _characterPersonalityController.text.trim();
    final world = _characterWorldController.text.trim();
    final resolvedToyImageUrl = _familySettings.allowToyPhotoUpload
        ? (toyImageUrl ?? _toyImageUrl ?? '').trim()
        : '';

    if (name.isEmpty &&
        power.isEmpty &&
        personality.isEmpty &&
        world.isEmpty &&
        resolvedToyImageUrl.isEmpty &&
        (_toyImageFile == null || !_familySettings.allowToyPhotoUpload)) {
      return null;
    }

    return StoryCharacterProfile(
      name: name.isEmpty
          ? (_personalization.mascotName.trim().isEmpty
              ? 'Kahraman'
              : _personalization.mascotName.trim())
          : name,
      power: power.isEmpty ? 'hayal gucu' : power,
      personality: personality.isEmpty ? 'yardimsever' : personality,
      world: world.isEmpty ? 'renkli bir diyar' : world,
      toyImageUrl: resolvedToyImageUrl,
    );
  }

  Future<void> _pickToyImage() async {
    if (_isPickingToyImage || _isProcessing) return;
    if (!_familySettings.allowToyPhotoUpload) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fotograf yukleme ebeveyn ayarlarinda kapali.'),
        ),
      );
      return;
    }
    if (!_hasAiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'AI icin ebeveyn onayi gereklidir. Once ayarlardan onay verin.',
          ),
        ),
      );
      return;
    }

    setState(() => _isPickingToyImage = true);
    try {
      final pickedImage = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1400,
      );

      if (pickedImage == null || !mounted) return;

      setState(() {
        _toyImageFile = File(pickedImage.path);
        _toyImageUrl = null;
        _sceneMode = true;
        if (_sceneCount < 3) {
          _sceneCount = 3;
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto secilemedi: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPickingToyImage = false);
      }
    }
  }

  Future<String?> _uploadToyImageIfNeeded() async {
    if (!_familySettings.allowToyPhotoUpload) return null;
    if (!_hasAiConsent) return null;
    if ((_toyImageUrl ?? '').isNotEmpty) return _toyImageUrl;
    if (_toyImageFile == null) return null;

    final userId = await _localUserService.getSelectedUserId();

    setState(() => _isUploadingToyImage = true);
    try {
      final uploadedUrl = await _storageService.uploadCharacterImage(
        file: _toyImageFile!,
        userId: userId,
      );

      if (mounted) {
        setState(() => _toyImageUrl = uploadedUrl);
      }
      return uploadedUrl;
    } finally {
      if (mounted) {
        setState(() => _isUploadingToyImage = false);
      }
    }
  }

  Future<void> _createStory() async {
    if (!_isButtonEnabled || _isProcessing) return;
    await _loadSafetyState();
    if (!mounted) return;

    if (_isPromptBlocked) {
      final message = _isScreenTimeLocked
          ? 'Günlük süre limiti doldu. Yarın tekrar deneyebilirsin.'
          : 'Sessiz saat aktif. Bu saatte yeni hikaye oluşturulamiyor.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }
    if (!_hasAiConsent) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Bu profilde AI hikaye için ebeveyn onayı gerekiyor.',
          ),
        ),
      );
      return;
    }

    final isConnected = await _connectivityService.isConnected();
    if (!isConnected) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.wifi_off, color: Colors.white),
                SizedBox(width: 10),
                Expanded(
                  child: Text('İnternet bağlantısı yok! Lütfen kontrol edin.'),
                ),
              ],
            ),
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final promptText = _promptController.text.trim();
    final strictMode =
        _familySettings.storySafetyLevel == StorySafetyLevel.strict;
    final enforceSceneMode = _sceneMode || _hasToyReferenceForStory;
    final effectiveAgeProfile =
        strictMode && _selectedAgeProfile == StoryAgeProfile.age10to12
            ? StoryAgeProfile.age7to9
            : _selectedAgeProfile;
    var effectiveSceneCount = strictMode && _sceneCount > 3 ? 3 : _sceneCount;
    if (_hasToyReferenceForStory && effectiveSceneCount < 3) {
      effectiveSceneCount = 3;
    }
    final effectivePrompt = '${_safetyPrefixForPrompt()}$promptText'.trim();

    setState(() {
      _isProcessing = true;
    });

    try {
      final toyImageUrl = await _uploadToyImageIfNeeded();
      final characterProfile = _buildCharacterProfile(toyImageUrl: toyImageUrl);

      final newStory = await _storyService.createStory(
        effectivePrompt,
        ageProfile: effectiveAgeProfile,
        style: _selectedStyle,
        colorPalette: _selectedColorPalette,
        sceneMode: enforceSceneMode,
        sceneCount: effectiveSceneCount,
        characterProfile: characterProfile,
        dataMinimizationMode: _familySettings.dataMinimizationMode,
      );

      if (mounted && newStory.id.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 10),
                Expanded(child: Text('Hikaye başarıyla oluşturuldu!')),
              ],
            ),
            duration: Duration(seconds: 2),
          ),
        );

        context.go(AppRoutes.storyDetail.replaceFirst(':id', newStory.id));
      }
    } catch (error) {
      final message = error is StoryPolicyException
          ? error.message
          : 'Hata oluştu: Hikaye oluşturulamadı. (API anahtarı/Konsol)';

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text(message)),
              ],
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }
      debugPrint('Hikaye oluşturulurken hata: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _ageLabel(StoryAgeProfile ageProfile) {
    return ageProfile.displayLabel;
  }

  String _styleLabel(StoryStyle style) {
    return style.displayLabel;
  }

  List<Color> _paletteColors(StoryColorPalette palette) {
    switch (palette) {
      case StoryColorPalette.auto:
        return const [Color(0xFF93A3B8), Color(0xFFD4DDE7), Color(0xFFF2F5F9)];
      case StoryColorPalette.vibrant:
        return const [Color(0xFF5A67FF), Color(0xFFFF6CA6), Color(0xFFFFD166)];
      case StoryColorPalette.pastel:
        return const [Color(0xFFAEC6FF), Color(0xFFFFC8DD), Color(0xFFCDEAC0)];
      case StoryColorPalette.warmSunset:
        return const [Color(0xFFFF7B54), Color(0xFFFFB26B), Color(0xFFFFD56F)];
      case StoryColorPalette.forest:
        return const [Color(0xFF2F855A), Color(0xFF68D391), Color(0xFFA3D9A5)];
      case StoryColorPalette.ocean:
        return const [Color(0xFF0EA5E9), Color(0xFF2DD4BF), Color(0xFF60A5FA)];
      case StoryColorPalette.candy:
        return const [Color(0xFFFF7BC7), Color(0xFFFFA7D1), Color(0xFFC7A6FF)];
    }
  }

  Widget _buildPaletteSwatches(StoryColorPalette palette) {
    final colors = _paletteColors(palette);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: colors
          .map(
            (color) => Container(
              width: 12,
              height: 12,
              margin: const EdgeInsets.only(right: 4),
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 0.8),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    IconData? icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withValues(alpha: 0.92),
      prefixIcon: icon == null ? null : Icon(icon),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD4DDF1), width: 1.2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD4DDF1), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(
          color: PlayfulPalette.grape,
          width: 1.6,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  Widget _buildSectionCard({
    required Widget child,
    List<Color>? colors,
    EdgeInsetsGeometry padding = const EdgeInsets.all(14),
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors ??
              [
                Colors.white.withValues(alpha: 0.98),
                const Color(0xFFF8F7FF).withValues(alpha: 0.96),
              ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDCE5F5), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22406188),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }

  Widget _buildAnimatedSection({
    required int index,
    required Widget child,
  }) {
    if (_reducedStimulusMode) return child;
    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 320 + (index * 90)),
      curve: Curves.easeOutCubic,
      tween: Tween(begin: 0, end: 1),
      child: child,
      builder: (context, value, sectionChild) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1 - value)),
            child: sectionChild,
          ),
        );
      },
    );
  }

  Widget _buildBackgroundOrb({
    required double size,
    required Alignment alignment,
    required List<Color> colors,
  }) {
    return IgnorePointer(
      child: Align(
        alignment: alignment,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: colors),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroBanner({
    required String? blockedInfo,
    required bool hasPersonalSignals,
  }) {
    final lineOne = blockedInfo ??
        '${_safetyModeHelperText()} Bugün ${_screenTimeStatus.usedMinutes} dk kullanıldı.';

    return _buildSectionCard(
      colors: const [Color(0xFF90B8FF), Color(0xFFA69BFF), Color(0xFFFFB0DB)],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.26),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  blockedInfo == null ? 'Hayal Motoru Açık' : 'Kilitli Mod',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            lineOne,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          if (hasPersonalSignals) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Stil: ${_styleLabel(_selectedStyle)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Yaş: ${_ageLabel(_selectedAgeProfile)}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (_personalization.interestTags.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _personalization.interestTags.take(2).join(', '),
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

  Widget _buildPaletteSelector() {
    return _buildSectionCard(
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 4),
          childrenPadding: const EdgeInsets.only(bottom: 6),
          leading: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFEFF3FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: _buildPaletteSwatches(_selectedColorPalette),
          ),
          title: const Text(
            'Sahne Renk Paleti',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          subtitle: Text('Secili: ${_selectedColorPalette.displayLabel}'),
          children: StoryColorPalette.values.map((palette) {
            final selected = _selectedColorPalette == palette;
            return Padding(
              padding: const EdgeInsets.fromLTRB(2, 3, 2, 3),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => setState(() => _selectedColorPalette = palette),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context)
                            .colorScheme
                            .primary
                            .withValues(alpha: 0.1)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected
                          ? Theme.of(context).colorScheme.primary
                          : const Color(0xFFDCE4F4),
                      width: selected ? 1.4 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      _buildPaletteSwatches(palette),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          palette.displayLabel,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Icon(
                        selected ? Icons.check_circle : Icons.circle_outlined,
                        size: 20,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : const Color(0xFF8893AD),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(growable: false),
        ),
      ),
    );
  }

  Widget _buildCreateButton() {
    final enabled = _isButtonEnabled && !_isProcessing && !_isPromptBlocked;

    return AnimatedScale(
      duration: const Duration(milliseconds: 180),
      scale: enabled ? 1 : 0.985,
      child: Container(
        decoration: BoxDecoration(
          gradient: enabled
              ? const LinearGradient(
                  colors: [
                    Color(0xFF6D8EFF),
                    Color(0xFF9B79FF),
                    Color(0xFFFF8BCB)
                  ],
                )
              : const LinearGradient(
                  colors: [Color(0xFFB6BDCF), Color(0xFFAAB3C8)],
                ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color:
                  enabled ? const Color(0x44626DC3) : const Color(0x223D4558),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: enabled ? _createStory : null,
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(double.infinity, 54),
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          child: _isProcessing
              ? SizedBox(
                  width: 110,
                  height: 48,
                  child: Lottie.asset(
                    'assets/lottie/loading_rocket.json',
                    repeat: true,
                  ),
                )
              : const Text(
                  'AI ile Hikaye Uret',
                  style: TextStyle(
                    fontSize: 17,
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isSafetyLoading) {
      return DecoratedBox(
        decoration: BoxDecoration(gradient: PlayfulPalette.appBackground),
        child: const Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final strictMode =
        _familySettings.storySafetyLevel == StorySafetyLevel.strict;
    final availableAgeProfiles = strictMode
        ? StoryAgeProfile.values
            .where((profile) => profile != StoryAgeProfile.age10to12)
            .toList(growable: false)
        : StoryAgeProfile.values;
    final blockedInfo = _isScreenTimeLocked
        ? 'Günlük süre limiti doldu. Yarın tekrar deneyebilirsin.'
        : _isQuietHoursLocked
            ? 'Sessiz saat aktif. Bu saatte yeni hikaye oluşturulamiyor.'
            : null;
    final hasPersonalSignals = _personalization.displayName.trim().isNotEmpty ||
        _personalization.mascotName.trim().isNotEmpty ||
        _personalization.interestTags.isNotEmpty;

    return DecoratedBox(
      decoration: BoxDecoration(gradient: PlayfulPalette.appBackground),
      child: Stack(
        children: [
          if (!_reducedStimulusMode) ...[
            _buildBackgroundOrb(
              size: 240,
              alignment: const Alignment(1.2, -0.9),
              colors: const [Color(0x44FFFFFF), Color(0x00FFFFFF)],
            ),
            _buildBackgroundOrb(
              size: 220,
              alignment: const Alignment(-1.2, -0.25),
              colors: const [Color(0x33A2C7FF), Color(0x00FFFFFF)],
            ),
            _buildBackgroundOrb(
              size: 260,
              alignment: const Alignment(0.9, 1.0),
              colors: const [Color(0x33FFB1D5), Color(0x00FFFFFF)],
            ),
          ],
          Scaffold(
            backgroundColor: Colors.transparent,
            appBar: AppBar(
              title: const Text('Hayalini Anlat'),
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
            ),
            body: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 30),
              child: AbsorbPointer(
                absorbing: _isPromptBlocked || _isProcessing,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildAnimatedSection(
                      index: 0,
                      child: _buildHeroBanner(
                        blockedInfo: blockedInfo,
                        hasPersonalSignals: hasPersonalSignals,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildAnimatedSection(
                      index: 1,
                      child: _buildSectionCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Hikaye Fikri',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _promptController,
                              maxLines: 4,
                              decoration: _fieldDecoration(
                                label: 'Hayalini anlat',
                                hint:
                                    'Orn: Ucan bir dinozor ve konusan bir bulut...',
                                icon: Icons.lightbulb_outline,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAnimatedSection(
                      index: 2,
                      child: _buildSectionCard(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isCompact = constraints.maxWidth < 520;

                            final ageField =
                                DropdownButtonFormField<StoryAgeProfile>(
                              isExpanded: true,
                              initialValue: _selectedAgeProfile,
                              decoration: _fieldDecoration(
                                label: 'Yaş Profili',
                                icon: isCompact ? null : Icons.cake_outlined,
                              ),
                              items: availableAgeProfiles
                                  .map(
                                    (value) =>
                                        DropdownMenuItem<StoryAgeProfile>(
                                      value: value,
                                      child: Text(
                                        _ageLabel(value),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedAgeProfile = value);
                              },
                            );

                            final styleField =
                                DropdownButtonFormField<StoryStyle>(
                              isExpanded: true,
                              initialValue: _selectedStyle,
                              decoration: _fieldDecoration(
                                label: 'Stil',
                                icon: isCompact
                                    ? null
                                    : Icons.auto_stories_outlined,
                              ),
                              items: StoryStyle.values
                                  .map(
                                    (value) => DropdownMenuItem<StoryStyle>(
                                      value: value,
                                      child: Text(
                                        _styleLabel(value),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  )
                                  .toList(growable: false),
                              onChanged: (value) {
                                if (value == null) return;
                                setState(() => _selectedStyle = value);
                              },
                            );

                            if (isCompact) {
                              return Column(
                                children: [
                                  ageField,
                                  const SizedBox(height: 10),
                                  styleField,
                                ],
                              );
                            }

                            return Row(
                              children: [
                                Expanded(child: ageField),
                                const SizedBox(width: 10),
                                Expanded(child: styleField),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAnimatedSection(
                        index: 3, child: _buildPaletteSelector()),
                    const SizedBox(height: 12),
                    _buildAnimatedSection(
                      index: 4,
                      child: _buildSectionCard(
                        child: Column(
                          children: [
                            SwitchListTile.adaptive(
                              title: const Text('Sahne bazli hikaye'),
                              subtitle: Text(
                                _hasToyReferenceForStory
                                    ? 'Oyuncak referansi secili oldugu icin sahne modu zorunlu.'
                                    : 'Mini cizgi film hissi icin sahnelere bol.',
                              ),
                              value:
                                  _hasToyReferenceForStory ? true : _sceneMode,
                              contentPadding: EdgeInsets.zero,
                              onChanged: _hasToyReferenceForStory
                                  ? null
                                  : (value) {
                                      setState(() => _sceneMode = value);
                                    },
                            ),
                            if (_sceneMode || _hasToyReferenceForStory)
                              DropdownButtonFormField<int>(
                                initialValue: _sceneCount,
                                decoration: _fieldDecoration(
                                  label: 'Sahne sayisi',
                                  icon: Icons.movie_creation_outlined,
                                ),
                                items: (strictMode ? [2, 3] : [2, 3, 4, 5])
                                    .map(
                                      (count) => DropdownMenuItem<int>(
                                        value: count,
                                        child: Text('$count sahne'),
                                      ),
                                    )
                                    .toList(growable: false),
                                onChanged: (value) {
                                  if (value == null) return;
                                  setState(() => _sceneCount = value);
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _buildAnimatedSection(
                      index: 5,
                      child: _buildSectionCard(
                        child: Theme(
                          data: Theme.of(context)
                              .copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            childrenPadding: const EdgeInsets.only(bottom: 8),
                            title: const Text(
                              'Karakter Oluşturucu',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                            subtitle:
                                const Text('İsim, güç, kişilik ve dünya seç.'),
                            children: [
                              TextField(
                                controller: _characterNameController,
                                decoration: _fieldDecoration(
                                  label: 'Karakter ismi',
                                  icon: Icons.face_retouching_natural,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _characterPowerController,
                                decoration: _fieldDecoration(
                                  label: 'Ozel guc',
                                  icon: Icons.bolt_outlined,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _characterPersonalityController,
                                decoration: _fieldDecoration(
                                  label: 'Kisilik',
                                  icon: Icons.favorite_outline,
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _characterWorldController,
                                decoration: _fieldDecoration(
                                  label: 'Yaşadığı dünya',
                                  icon: Icons.public_outlined,
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_familySettings.allowToyPhotoUpload) ...[
                                if (!_hasAiConsent)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(10),
                                    margin: const EdgeInsets.only(bottom: 8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF2E9),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFFF0C8A8),
                                      ),
                                    ),
                                    child: const Text(
                                      'Oyuncak fotografi icin ebeveyn AI onayi gerekli.',
                                      style: TextStyle(
                                        color: Color(0xFF8A5D3B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: (!_hasAiConsent ||
                                                _isPickingToyImage)
                                            ? null
                                            : _pickToyImage,
                                        icon: const Icon(
                                          Icons.photo_library_outlined,
                                        ),
                                        label: Text(
                                          _toyImageFile == null
                                              ? 'Oyuncak fotografi sec'
                                              : 'Fotografi degistir',
                                        ),
                                      ),
                                    ),
                                    if (_toyImageFile != null ||
                                        (_toyImageUrl ?? '').isNotEmpty)
                                      IconButton(
                                        tooltip: 'Fotografi kaldir',
                                        onPressed: () {
                                          setState(() {
                                            _toyImageFile = null;
                                            _toyImageUrl = null;
                                          });
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                  ],
                                ),
                                if (_isUploadingToyImage)
                                  const Padding(
                                    padding: EdgeInsets.only(top: 8),
                                    child:
                                        LinearProgressIndicator(minHeight: 3),
                                  ),
                                if (_toyImageFile != null) ...[
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.threed_rotation,
                                        size: 16,
                                        color: Color(0xFF6A77C2),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        _reducedStimulusMode
                                            ? 'Sade onizleme'
                                            : 'Canli 3D onizleme (surukleyebilirsin)',
                                        style: const TextStyle(
                                          color: Color(0xFF5D6AAE),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  if (_reducedStimulusMode)
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: Image.file(
                                        _toyImageFile!,
                                        height: 170,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                      ),
                                    )
                                  else
                                    LiveToyPreview(
                                      imageFile: _toyImageFile!,
                                      height: 170,
                                      borderRadius: 12,
                                    ),
                                ],
                              ] else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF4F6FB),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Text(
                                    'Fotograf yukleme ebeveyn ayarinda kapali.',
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildAnimatedSection(
                        index: 6, child: _buildCreateButton()),
                    const SizedBox(height: 12),
                    _buildAnimatedSection(
                      index: 7,
                      child: Center(
                        child: Text(
                          _isProcessing
                              ? 'Yapay zeka hikayeyi uretiyor...'
                              : _isPromptBlocked
                                  ? 'Kilitli mod aktif.'
                                  : 'En az 5 harfli bir hayal kurmalisin.',
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
