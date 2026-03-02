import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'auth_service.dart';
import 'firestore_family_settings_service.dart';
import 'local_user_service.dart';

enum StorySafetyLevel {
  strict,
  balanced,
  creative,
}

extension StorySafetyLevelX on StorySafetyLevel {
  String get key {
    switch (this) {
      case StorySafetyLevel.strict:
        return 'strict';
      case StorySafetyLevel.balanced:
        return 'balanced';
      case StorySafetyLevel.creative:
        return 'creative';
    }
  }

  String get label {
    switch (this) {
      case StorySafetyLevel.strict:
        return 'Sıkı';
      case StorySafetyLevel.balanced:
        return 'Dengeli';
      case StorySafetyLevel.creative:
        return 'Yaratici';
    }
  }

  String get description {
    switch (this) {
      case StorySafetyLevel.strict:
        return 'Daha sade ve güvenli tema, yumuşak ton.';
      case StorySafetyLevel.balanced:
        return 'Varsayılan çocuk dostu güvenlik dengesi.';
      case StorySafetyLevel.creative:
        return 'Hayal gücüne daha açık ama filtreli ton.';
    }
  }

  static StorySafetyLevel fromKey(String? value) {
    switch (value) {
      case 'strict':
        return StorySafetyLevel.strict;
      case 'creative':
        return StorySafetyLevel.creative;
      case 'balanced':
      default:
        return StorySafetyLevel.balanced;
    }
  }
}

class FamilySafetySettings {
  const FamilySafetySettings({
    this.screenTimeLimitEnabled = false,
    this.dailyScreenTimeLimitMinutes = 60,
    this.breakReminderEnabled = true,
    this.breakEveryMinutes = 20,
    this.storySafetyLevel = StorySafetyLevel.balanced,
    this.quietHoursEnabled = false,
    this.quietHoursStartHour = 21,
    this.quietHoursEndHour = 7,
    this.allowToyPhotoUpload = false,
    this.lowStimulusModeEnabled = false,
    this.allowAutoplayNarration = false,
    this.requireParentalConsentForAi = true,
    this.parentalConsentGranted = false,
    this.dataMinimizationMode = true,
    this.transparencyModeEnabled = true,
  });

  final bool screenTimeLimitEnabled;
  final int dailyScreenTimeLimitMinutes;
  final bool breakReminderEnabled;
  final int breakEveryMinutes;
  final StorySafetyLevel storySafetyLevel;
  final bool quietHoursEnabled;
  final int quietHoursStartHour;
  final int quietHoursEndHour;
  final bool allowToyPhotoUpload;
  final bool lowStimulusModeEnabled;
  final bool allowAutoplayNarration;
  final bool requireParentalConsentForAi;
  final bool parentalConsentGranted;
  final bool dataMinimizationMode;
  final bool transparencyModeEnabled;

  FamilySafetySettings copyWith({
    bool? screenTimeLimitEnabled,
    int? dailyScreenTimeLimitMinutes,
    bool? breakReminderEnabled,
    int? breakEveryMinutes,
    StorySafetyLevel? storySafetyLevel,
    bool? quietHoursEnabled,
    int? quietHoursStartHour,
    int? quietHoursEndHour,
    bool? allowToyPhotoUpload,
    bool? lowStimulusModeEnabled,
    bool? allowAutoplayNarration,
    bool? requireParentalConsentForAi,
    bool? parentalConsentGranted,
    bool? dataMinimizationMode,
    bool? transparencyModeEnabled,
  }) {
    return FamilySafetySettings(
      screenTimeLimitEnabled:
          screenTimeLimitEnabled ?? this.screenTimeLimitEnabled,
      dailyScreenTimeLimitMinutes:
          (dailyScreenTimeLimitMinutes ?? this.dailyScreenTimeLimitMinutes)
              .clamp(15, 240)
              .toInt(),
      breakReminderEnabled: breakReminderEnabled ?? this.breakReminderEnabled,
      breakEveryMinutes:
          (breakEveryMinutes ?? this.breakEveryMinutes).clamp(10, 60).toInt(),
      storySafetyLevel: storySafetyLevel ?? this.storySafetyLevel,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietHoursStartHour: (quietHoursStartHour ?? this.quietHoursStartHour)
          .clamp(0, 23)
          .toInt(),
      quietHoursEndHour:
          (quietHoursEndHour ?? this.quietHoursEndHour).clamp(0, 23).toInt(),
      allowToyPhotoUpload: allowToyPhotoUpload ?? this.allowToyPhotoUpload,
      lowStimulusModeEnabled:
          lowStimulusModeEnabled ?? this.lowStimulusModeEnabled,
      allowAutoplayNarration:
          allowAutoplayNarration ?? this.allowAutoplayNarration,
      requireParentalConsentForAi:
          requireParentalConsentForAi ?? this.requireParentalConsentForAi,
      parentalConsentGranted:
          parentalConsentGranted ?? this.parentalConsentGranted,
      dataMinimizationMode: dataMinimizationMode ?? this.dataMinimizationMode,
      transparencyModeEnabled:
          transparencyModeEnabled ?? this.transparencyModeEnabled,
    );
  }

  bool isWithinQuietHours(DateTime dateTime) {
    if (!quietHoursEnabled) return false;
    if (quietHoursStartHour == quietHoursEndHour) return false;

    final hour = dateTime.hour;
    if (quietHoursStartHour < quietHoursEndHour) {
      return hour >= quietHoursStartHour && hour < quietHoursEndHour;
    }
    return hour >= quietHoursStartHour || hour < quietHoursEndHour;
  }

  Map<String, dynamic> toMap() {
    return {
      'screenTimeLimitEnabled': screenTimeLimitEnabled,
      'dailyScreenTimeLimitMinutes': dailyScreenTimeLimitMinutes,
      'breakReminderEnabled': breakReminderEnabled,
      'breakEveryMinutes': breakEveryMinutes,
      'storySafetyLevel': storySafetyLevel.key,
      'quietHoursEnabled': quietHoursEnabled,
      'quietHoursStartHour': quietHoursStartHour,
      'quietHoursEndHour': quietHoursEndHour,
      'allowToyPhotoUpload': allowToyPhotoUpload,
      'lowStimulusModeEnabled': lowStimulusModeEnabled,
      'allowAutoplayNarration': allowAutoplayNarration,
      'requireParentalConsentForAi': requireParentalConsentForAi,
      'parentalConsentGranted': parentalConsentGranted,
      'dataMinimizationMode': dataMinimizationMode,
      'transparencyModeEnabled': transparencyModeEnabled,
    };
  }

  factory FamilySafetySettings.fromMap(Map<String, dynamic> map) {
    return FamilySafetySettings(
      screenTimeLimitEnabled: map['screenTimeLimitEnabled'] == true,
      dailyScreenTimeLimitMinutes:
          ((map['dailyScreenTimeLimitMinutes'] as num?)?.toInt() ?? 60)
              .clamp(15, 240)
              .toInt(),
      breakReminderEnabled: map['breakReminderEnabled'] != false,
      breakEveryMinutes: ((map['breakEveryMinutes'] as num?)?.toInt() ?? 20)
          .clamp(10, 60)
          .toInt(),
      storySafetyLevel:
          StorySafetyLevelX.fromKey(map['storySafetyLevel']?.toString()),
      quietHoursEnabled: map['quietHoursEnabled'] == true,
      quietHoursStartHour: ((map['quietHoursStartHour'] as num?)?.toInt() ?? 21)
          .clamp(0, 23)
          .toInt(),
      quietHoursEndHour: ((map['quietHoursEndHour'] as num?)?.toInt() ?? 7)
          .clamp(0, 23)
          .toInt(),
      allowToyPhotoUpload: map['allowToyPhotoUpload'] == true,
      lowStimulusModeEnabled: map['lowStimulusModeEnabled'] == true,
      allowAutoplayNarration: map['allowAutoplayNarration'] == true,
      requireParentalConsentForAi: map['requireParentalConsentForAi'] != false,
      parentalConsentGranted: map['parentalConsentGranted'] == true,
      dataMinimizationMode: map['dataMinimizationMode'] != false,
      transparencyModeEnabled: map['transparencyModeEnabled'] != false,
    );
  }
}

class FamilySettingsService {
  static const _keyScreenTimeLimitEnabled = 'family_screen_time_limit_enabled';
  static const _keyDailyScreenTimeLimitMinutes =
      'family_daily_screen_time_limit_minutes';
  static const _keyBreakReminderEnabled = 'family_break_reminder_enabled';
  static const _keyBreakEveryMinutes = 'family_break_every_minutes';
  static const _keyStorySafetyLevel = 'family_story_safety_level';
  static const _keyQuietHoursEnabled = 'family_quiet_hours_enabled';
  static const _keyQuietHoursStartHour = 'family_quiet_hours_start_hour';
  static const _keyQuietHoursEndHour = 'family_quiet_hours_end_hour';
  static const _keyAllowToyPhotoUpload = 'family_allow_toy_photo_upload';
  static const _keyLowStimulusModeEnabled = 'family_low_stimulus_mode_enabled';
  static const _keyAllowAutoplayNarration = 'family_allow_autoplay_narration';
  static const _keyRequireParentalConsentForAi =
      'family_require_parental_consent_for_ai';
  static const _keyParentalConsentGranted = 'family_parental_consent_granted';
  static const _keyDataMinimizationMode = 'family_data_minimization_mode';
  static const _keyTransparencyModeEnabled = 'family_transparency_mode_enabled';
  static const _keySettingsUpdatedAtMs = 'family_settings_updated_at_ms';

  FamilySettingsService._internal({
    LocalUserService? localUserService,
    AuthService? authService,
    FirestoreFamilySettingsService? cloudService,
    this.enableCloudSync = true,
  })  : _localUserService = localUserService ?? LocalUserService(),
        _authService = authService,
        _cloudService = cloudService;

  static final FamilySettingsService _instance =
      FamilySettingsService._internal();

  factory FamilySettingsService({
    LocalUserService? localUserService,
    AuthService? authService,
    FirestoreFamilySettingsService? cloudService,
    bool enableCloudSync = true,
  }) {
    final useDefault = localUserService == null &&
        authService == null &&
        cloudService == null &&
        enableCloudSync;
    if (useDefault) {
      return _instance;
    }
    return FamilySettingsService._internal(
      localUserService: localUserService,
      authService: authService,
      cloudService: cloudService,
      enableCloudSync: enableCloudSync,
    );
  }

  final LocalUserService _localUserService;
  final AuthService? _authService;
  final FirestoreFamilySettingsService? _cloudService;
  final bool enableCloudSync;
  static const bool _isTestEnvironment = bool.fromEnvironment('FLUTTER_TEST');
  Future<SharedPreferences>? _prefsFuture;
  FamilySafetySettings? _cachedSettings;
  DateTime? _cachedSettingsAt;
  String? _cachedUserId;

  Future<SharedPreferences> _getPrefs() async {
    if (_isTestEnvironment) {
      return SharedPreferences.getInstance();
    }
    return _prefsFuture ??= SharedPreferences.getInstance();
  }

  Future<FamilySafetySettings> getSettings({
    bool syncFromCloud = false,
  }) async {
    final userId = await _resolveLocalUserId();

    if (!syncFromCloud &&
        _cachedSettings != null &&
        _cachedUserId == userId &&
        _cachedSettingsAt != null &&
        DateTime.now().difference(_cachedSettingsAt!) <
            const Duration(seconds: 10)) {
      return _cachedSettings!;
    }

    if (syncFromCloud) {
      await syncFromCloudAndMerge();
    }

    final prefs = await _getPrefs();
    final settings = _readSettingsForUser(prefs, userId);
    _cachedSettings = settings;
    _cachedSettingsAt = DateTime.now();
    _cachedUserId = userId;
    return settings;
  }

  Future<void> saveSettings(
    FamilySafetySettings settings, {
    bool syncToCloud = true,
  }) async {
    final prefs = await _getPrefs();
    final userId = await _resolveLocalUserId();
    final updatedAtMs = DateTime.now().millisecondsSinceEpoch;

    await _writeSettingsForUser(
      prefs,
      userId: userId,
      settings: settings,
      updatedAtMs: updatedAtMs,
    );

    if (!syncToCloud) return;
    await _pushToCloud(
      userId: userId,
      settings: settings,
      updatedAtMs: updatedAtMs,
    );

    _cachedSettings = settings;
    _cachedSettingsAt = DateTime.now();
    _cachedUserId = userId;
  }

  Future<bool> syncFromCloudAndMerge() async {
    final syncIdentity = await _resolveSyncIdentity();
    if (syncIdentity == null) return false;
    final cloudService = _resolveCloudService();
    if (cloudService == null) return false;

    final prefs = await _getPrefs();
    final userId = syncIdentity.userId;
    final ownerUid = syncIdentity.ownerUid;

    final localSettings = _readSettingsForUser(prefs, userId);
    final localUpdatedAtMs = _readLocalUpdatedAtMs(prefs, userId);

    try {
      final remoteDoc = await cloudService.fetch(
        ownerUid: ownerUid,
        userId: userId,
      );

      if (remoteDoc == null || remoteDoc.isEmpty) {
        if (localUpdatedAtMs > 0) {
          await _pushToCloud(
            userId: userId,
            settings: localSettings,
            updatedAtMs: localUpdatedAtMs,
          );
        }
        return false;
      }

      final remoteUpdatedAtMs = cloudService.readUpdatedAtMs(remoteDoc);
      final remoteSettings = FamilySafetySettings.fromMap(
        _asStringDynamicMap(remoteDoc['settings']),
      );

      if (remoteUpdatedAtMs > localUpdatedAtMs) {
        await _writeSettingsForUser(
          prefs,
          userId: userId,
          settings: remoteSettings,
          updatedAtMs: remoteUpdatedAtMs,
        );
        _cachedSettings = remoteSettings;
        _cachedSettingsAt = DateTime.now();
        _cachedUserId = userId;
        return true;
      }

      if (localUpdatedAtMs > remoteUpdatedAtMs) {
        await _pushToCloud(
          userId: userId,
          settings: localSettings,
          updatedAtMs: localUpdatedAtMs,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('Family settings sync skipped: $error\n$stackTrace');
    }

    return false;
  }

  String hourLabel(int hour) {
    final safe = hour.clamp(0, 23).toInt();
    return '${safe.toString().padLeft(2, '0')}:00';
  }

  Future<void> _pushToCloud({
    required String userId,
    required FamilySafetySettings settings,
    required int updatedAtMs,
  }) async {
    if (!enableCloudSync) return;
    if (userId == LocalUserService.defaultUserId) return;

    try {
      final ownerUid = await _resolveOwnerUid();
      if (ownerUid == null || ownerUid.trim().isEmpty) return;
      final cloudService = _resolveCloudService();
      if (cloudService == null) return;

      await cloudService.upsert(
        ownerUid: ownerUid.trim(),
        userId: userId,
        settings: settings.toMap(),
        updatedAtMs: updatedAtMs,
      );
    } catch (error, stackTrace) {
      debugPrint('Family settings cloud write skipped: $error\n$stackTrace');
    }
  }

  Future<_FamilySyncIdentity?> _resolveSyncIdentity() async {
    if (!enableCloudSync) return null;
    final userId = await _resolveLocalUserId();
    if (userId == LocalUserService.defaultUserId) return null;

    try {
      final ownerUid = await _resolveOwnerUid();
      if (ownerUid == null || ownerUid.trim().isEmpty) {
        return null;
      }
      return _FamilySyncIdentity(
        ownerUid: ownerUid.trim(),
        userId: userId,
      );
    } catch (error) {
      debugPrint('Family settings sync identity unavailable: $error');
      return null;
    }
  }

  Future<String> _resolveLocalUserId() async {
    final selected = await _localUserService.getSelectedUserId();
    final normalized = selected.trim();
    if (normalized.isEmpty) return LocalUserService.defaultUserId;
    return normalized;
  }

  FamilySafetySettings _readSettingsForUser(
    SharedPreferences prefs,
    String userId,
  ) {
    final hasScoped = _hasScopedSettings(prefs, userId);
    final useScoped = hasScoped || !_hasLegacySettings(prefs);
    final source = _readRawSettingsMap(
      prefs,
      userId: userId,
      scoped: useScoped,
    );
    return FamilySafetySettings.fromMap(source);
  }

  Future<void> _writeSettingsForUser(
    SharedPreferences prefs, {
    required String userId,
    required FamilySafetySettings settings,
    required int updatedAtMs,
  }) async {
    final map = settings.toMap();

    await Future.wait(<Future<bool>>[
      prefs.setBool(
        _scopedKey(_keyScreenTimeLimitEnabled, userId),
        map['screenTimeLimitEnabled'] as bool,
      ),
      prefs.setInt(
        _scopedKey(_keyDailyScreenTimeLimitMinutes, userId),
        map['dailyScreenTimeLimitMinutes'] as int,
      ),
      prefs.setBool(
        _scopedKey(_keyBreakReminderEnabled, userId),
        map['breakReminderEnabled'] as bool,
      ),
      prefs.setInt(
        _scopedKey(_keyBreakEveryMinutes, userId),
        map['breakEveryMinutes'] as int,
      ),
      prefs.setString(
        _scopedKey(_keyStorySafetyLevel, userId),
        map['storySafetyLevel'] as String,
      ),
      prefs.setBool(
        _scopedKey(_keyQuietHoursEnabled, userId),
        map['quietHoursEnabled'] as bool,
      ),
      prefs.setInt(
        _scopedKey(_keyQuietHoursStartHour, userId),
        map['quietHoursStartHour'] as int,
      ),
      prefs.setInt(
        _scopedKey(_keyQuietHoursEndHour, userId),
        map['quietHoursEndHour'] as int,
      ),
      prefs.setBool(
        _scopedKey(_keyAllowToyPhotoUpload, userId),
        map['allowToyPhotoUpload'] as bool,
      ),
      prefs.setBool(
        _scopedKey(_keyLowStimulusModeEnabled, userId),
        map['lowStimulusModeEnabled'] as bool,
      ),
      prefs.setBool(
        _scopedKey(_keyAllowAutoplayNarration, userId),
        map['allowAutoplayNarration'] as bool,
      ),
      prefs.setBool(
        _scopedKey(_keyRequireParentalConsentForAi, userId),
        map['requireParentalConsentForAi'] as bool,
      ),
      prefs.setBool(
        _scopedKey(_keyParentalConsentGranted, userId),
        map['parentalConsentGranted'] as bool,
      ),
      prefs.setBool(
        _scopedKey(_keyDataMinimizationMode, userId),
        map['dataMinimizationMode'] as bool,
      ),
      prefs.setBool(
        _scopedKey(_keyTransparencyModeEnabled, userId),
        map['transparencyModeEnabled'] as bool,
      ),
      prefs.setInt(
        _scopedKey(_keySettingsUpdatedAtMs, userId),
        updatedAtMs,
      ),
    ]);
  }

  bool _hasScopedSettings(SharedPreferences prefs, String userId) {
    return prefs.containsKey(_scopedKey(_keySettingsUpdatedAtMs, userId)) ||
        prefs.containsKey(_scopedKey(_keyScreenTimeLimitEnabled, userId));
  }

  bool _hasLegacySettings(SharedPreferences prefs) {
    return prefs.containsKey(_keySettingsUpdatedAtMs) ||
        prefs.containsKey(_keyScreenTimeLimitEnabled) ||
        prefs.containsKey(_keyStorySafetyLevel);
  }

  int _readLocalUpdatedAtMs(SharedPreferences prefs, String userId) {
    final scoped = prefs.getInt(_scopedKey(_keySettingsUpdatedAtMs, userId));
    if (scoped != null) return scoped;
    return prefs.getInt(_keySettingsUpdatedAtMs) ?? 0;
  }

  Map<String, dynamic> _readRawSettingsMap(
    SharedPreferences prefs, {
    required String userId,
    required bool scoped,
  }) {
    final keyScreenTime = scoped
        ? _scopedKey(_keyScreenTimeLimitEnabled, userId)
        : _keyScreenTimeLimitEnabled;
    final keyDailyLimit = scoped
        ? _scopedKey(_keyDailyScreenTimeLimitMinutes, userId)
        : _keyDailyScreenTimeLimitMinutes;
    final keyBreakReminder = scoped
        ? _scopedKey(_keyBreakReminderEnabled, userId)
        : _keyBreakReminderEnabled;
    final keyBreakEvery = scoped
        ? _scopedKey(_keyBreakEveryMinutes, userId)
        : _keyBreakEveryMinutes;
    final keySafety = scoped
        ? _scopedKey(_keyStorySafetyLevel, userId)
        : _keyStorySafetyLevel;
    final keyQuietEnabled = scoped
        ? _scopedKey(_keyQuietHoursEnabled, userId)
        : _keyQuietHoursEnabled;
    final keyQuietStart = scoped
        ? _scopedKey(_keyQuietHoursStartHour, userId)
        : _keyQuietHoursStartHour;
    final keyQuietEnd = scoped
        ? _scopedKey(_keyQuietHoursEndHour, userId)
        : _keyQuietHoursEndHour;
    final keyToyUpload = scoped
        ? _scopedKey(_keyAllowToyPhotoUpload, userId)
        : _keyAllowToyPhotoUpload;
    final keyLowStimulus = scoped
        ? _scopedKey(_keyLowStimulusModeEnabled, userId)
        : _keyLowStimulusModeEnabled;
    final keyAutoplay = scoped
        ? _scopedKey(_keyAllowAutoplayNarration, userId)
        : _keyAllowAutoplayNarration;
    final keyRequireConsent = scoped
        ? _scopedKey(_keyRequireParentalConsentForAi, userId)
        : _keyRequireParentalConsentForAi;
    final keyConsentGranted = scoped
        ? _scopedKey(_keyParentalConsentGranted, userId)
        : _keyParentalConsentGranted;
    final keyMinimize = scoped
        ? _scopedKey(_keyDataMinimizationMode, userId)
        : _keyDataMinimizationMode;
    final keyTransparency = scoped
        ? _scopedKey(_keyTransparencyModeEnabled, userId)
        : _keyTransparencyModeEnabled;

    return {
      'screenTimeLimitEnabled': prefs.getBool(keyScreenTime) ?? false,
      'dailyScreenTimeLimitMinutes':
          (prefs.getInt(keyDailyLimit) ?? 60).clamp(15, 240).toInt(),
      'breakReminderEnabled': prefs.getBool(keyBreakReminder) ?? true,
      'breakEveryMinutes':
          (prefs.getInt(keyBreakEvery) ?? 20).clamp(10, 60).toInt(),
      'storySafetyLevel': StorySafetyLevelX.fromKey(
        prefs.getString(keySafety),
      ).key,
      'quietHoursEnabled': prefs.getBool(keyQuietEnabled) ?? false,
      'quietHoursStartHour':
          (prefs.getInt(keyQuietStart) ?? 21).clamp(0, 23).toInt(),
      'quietHoursEndHour':
          (prefs.getInt(keyQuietEnd) ?? 7).clamp(0, 23).toInt(),
      'allowToyPhotoUpload': prefs.getBool(keyToyUpload) ?? false,
      'lowStimulusModeEnabled': prefs.getBool(keyLowStimulus) ?? false,
      'allowAutoplayNarration': prefs.getBool(keyAutoplay) ?? false,
      'requireParentalConsentForAi': prefs.getBool(keyRequireConsent) ?? true,
      'parentalConsentGranted': prefs.getBool(keyConsentGranted) ?? false,
      'dataMinimizationMode': prefs.getBool(keyMinimize) ?? true,
      'transparencyModeEnabled': prefs.getBool(keyTransparency) ?? true,
    };
  }

  Map<String, dynamic> _asStringDynamicMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map(
        (key, dynamic innerValue) => MapEntry(key.toString(), innerValue),
      );
    }
    return <String, dynamic>{};
  }

  String _scopedKey(String baseKey, String userId) {
    return '${baseKey}_${userId.trim()}';
  }

  Future<String?> _resolveOwnerUid() async {
    try {
      final authService = _authService ?? AuthService();
      return await authService.getCurrentUserIdOrNull();
    } catch (error) {
      debugPrint('Family settings owner uid unavailable: $error');
      return null;
    }
  }

  FirestoreFamilySettingsService? _resolveCloudService() {
    try {
      return _cloudService ?? FirestoreFamilySettingsService();
    } catch (error) {
      debugPrint('Family settings cloud service unavailable: $error');
      return null;
    }
  }
}

class _FamilySyncIdentity {
  const _FamilySyncIdentity({
    required this.ownerUid,
    required this.userId,
  });

  final String ownerUid;
  final String userId;
}
