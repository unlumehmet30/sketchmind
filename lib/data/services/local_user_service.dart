import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalAuthResult {
  const LocalAuthResult({
    required this.success,
    this.isLockedOut = false,
    this.remainingLockSeconds = 0,
    this.resolvedUsername,
  });

  final bool success;
  final bool isLockedOut;
  final int remainingLockSeconds;
  final String? resolvedUsername;
}

class UserPersonalization {
  const UserPersonalization({
    this.displayName = '',
    this.about = '',
    this.ageBandKey = 'age_7_9',
    this.favoriteStoryStyleKey = 'adventure',
    this.favoriteGameKey = 'quick_math',
    this.interestTags = const <String>[],
    this.mascotName = '',
  });

  final String displayName;
  final String about;
  final String ageBandKey;
  final String favoriteStoryStyleKey;
  final String favoriteGameKey;
  final List<String> interestTags;
  final String mascotName;

  UserPersonalization copyWith({
    String? displayName,
    String? about,
    String? ageBandKey,
    String? favoriteStoryStyleKey,
    String? favoriteGameKey,
    List<String>? interestTags,
    String? mascotName,
  }) {
    return UserPersonalization(
      displayName: displayName ?? this.displayName,
      about: about ?? this.about,
      ageBandKey: ageBandKey ?? this.ageBandKey,
      favoriteStoryStyleKey:
          favoriteStoryStyleKey ?? this.favoriteStoryStyleKey,
      favoriteGameKey: favoriteGameKey ?? this.favoriteGameKey,
      interestTags: interestTags ?? this.interestTags,
      mascotName: mascotName ?? this.mascotName,
    );
  }
}

class ReadingAccessibilityProfile {
  const ReadingAccessibilityProfile({
    this.fontScale = 1.0,
    this.letterSpacing = 0.0,
    this.ttsRate = 0.5,
    this.ttsPitch = 1.0,
    this.lineHighlightEnabled = true,
  });

  final double fontScale;
  final double letterSpacing;
  final double ttsRate;
  final double ttsPitch;
  final bool lineHighlightEnabled;

  ReadingAccessibilityProfile copyWith({
    double? fontScale,
    double? letterSpacing,
    double? ttsRate,
    double? ttsPitch,
    bool? lineHighlightEnabled,
  }) {
    return ReadingAccessibilityProfile(
      fontScale: fontScale ?? this.fontScale,
      letterSpacing: letterSpacing ?? this.letterSpacing,
      ttsRate: ttsRate ?? this.ttsRate,
      ttsPitch: ttsPitch ?? this.ttsPitch,
      lineHighlightEnabled: lineHighlightEnabled ?? this.lineHighlightEnabled,
    );
  }
}

class LocalRouteAccessState {
  const LocalRouteAccessState({
    required this.anyUserExists,
    required this.selectedUserId,
    required this.isParentMode,
    required this.devModeBypass,
  });

  final bool anyUserExists;
  final String selectedUserId;
  final bool isParentMode;
  final bool devModeBypass;

  bool get isUserSelected => selectedUserId != LocalUserService.defaultUserId;
}

class LocalUserService {
  LocalUserService._internal();
  static final LocalUserService _instance = LocalUserService._internal();
  factory LocalUserService() => _instance;

  static const _keySelectedUserId = 'selectedUserId';
  static const _keyUserDatabase = 'userDatabase';
  static const _secureKeyUserDatabase = 'secureUserDatabase';
  static const _registeredUsersKey = 'registeredUsernamesList';
  static const _userAvatarPrefix = 'userAvatar_';
  static const _keyIsParentMode = 'isParentModeActive';
  static const _keyParentModeExpiresAtMs = 'parentModeExpiresAtMs';
  static const _keyDevModeBypass = 'devModeBypass';
  static const _keyAppThemePalette = 'appThemePalette';
  static const _userDisplayNamePrefix = 'userDisplayName_';
  static const _userAboutPrefix = 'userAbout_';
  static const _userAgeBandPrefix = 'userAgeBand_';
  static const _userFavoriteStoryStylePrefix = 'userFavoriteStoryStyle_';
  static const _userFavoriteGamePrefix = 'userFavoriteGame_';
  static const _userInterestsPrefix = 'userInterests_';
  static const _userMascotNamePrefix = 'userMascotName_';
  static const _readerFontScalePrefix = 'readerFontScale_';
  static const _readerLetterSpacingPrefix = 'readerLetterSpacing_';
  static const _readerTtsRatePrefix = 'readerTtsRate_';
  static const _readerTtsPitchPrefix = 'readerTtsPitch_';
  static const _readerLineHighlightPrefix = 'readerLineHighlight_';

  static const _defaultUserId = 'misafir_user';
  static const _maxFailedAttempts = 5;
  static const _hashIterations = 20000;
  static const Duration _loginLockDuration = Duration(minutes: 2);
  static const Duration _parentModeSessionDuration = Duration(minutes: 10);

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock,
    ),
  );

  static const bool _isTestEnvironment = bool.fromEnvironment('FLUTTER_TEST');
  Future<SharedPreferences>? _prefsFuture;

  Future<SharedPreferences> _getPrefs() async {
    if (_isTestEnvironment) {
      return SharedPreferences.getInstance();
    }
    return _prefsFuture ??= SharedPreferences.getInstance();
  }

  String _legacyHashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }

  String _hashPassword(String password, String salt) {
    var digestBytes = sha256.convert(utf8.encode('$salt::$password')).bytes;
    for (var i = 0; i < _hashIterations; i++) {
      digestBytes = sha256.convert(<int>[
        ...digestBytes,
        ...utf8.encode(salt),
      ]).bytes;
    }
    return base64UrlEncode(digestBytes);
  }

  bool _constantTimeEquals(String a, String b) {
    final aBytes = utf8.encode(a);
    final bBytes = utf8.encode(b);
    if (aBytes.length != bBytes.length) return false;

    var diff = 0;
    for (var i = 0; i < aBytes.length; i++) {
      diff |= aBytes[i] ^ bBytes[i];
    }
    return diff == 0;
  }

  String? _findUsernameMatch(String input, Iterable<String> usernames) {
    final normalizedInput = input.trim().toLowerCase();
    for (final name in usernames) {
      if (name.trim().toLowerCase() == normalizedInput) {
        return name;
      }
    }
    return null;
  }

  Future<Map<String, _LocalCredentialRecord>> _getUserDatabase() async {
    final prefs = await _getPrefs();
    String rawJson = '{}';
    var loadedFromSecure = false;

    if (_isTestEnvironment) {
      rawJson = prefs.getString(_keyUserDatabase) ?? '{}';
    } else {
      try {
        final secureJson =
            await _secureStorage.read(key: _secureKeyUserDatabase);
        if (secureJson != null && secureJson.isNotEmpty) {
          rawJson = secureJson;
          loadedFromSecure = true;
        }
      } catch (_) {}

      if (!loadedFromSecure) {
        rawJson = prefs.getString(_keyUserDatabase) ?? '{}';
      }
    }

    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) {
        return {};
      }

      final result = <String, _LocalCredentialRecord>{};
      decoded.forEach((key, value) {
        final record = _LocalCredentialRecord.fromStored(value);
        if (record != null) {
          result[key] = record;
        }
      });

      if (!loadedFromSecure &&
          result.isNotEmpty &&
          prefs.containsKey(_keyUserDatabase)) {
        try {
          await _secureStorage.write(
            key: _secureKeyUserDatabase,
            value: rawJson,
          );
          await prefs.remove(_keyUserDatabase);
        } catch (_) {}
      }

      return result;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveUserDatabase(Map<String, _LocalCredentialRecord> db) async {
    final jsonMap = db.map((key, value) => MapEntry(key, value.toMap()));
    final serialized = jsonEncode(jsonMap);

    if (_isTestEnvironment) {
      final prefs = await _getPrefs();
      await prefs.setString(_keyUserDatabase, serialized);
      return;
    }

    try {
      await _secureStorage.write(
        key: _secureKeyUserDatabase,
        value: serialized,
      );
      final prefs = await _getPrefs();
      await prefs.remove(_keyUserDatabase);
      return;
    } catch (_) {}

    final prefs = await _getPrefs();
    await prefs.setString(_keyUserDatabase, serialized);
  }

  static String? validateUsername(String username) {
    final trimmed = username.trim();
    final validPattern = RegExp(r'^[a-zA-Z0-9_çğıöşüÇĞİÖŞÜ]{3,24}$');
    if (!validPattern.hasMatch(trimmed)) {
      return 'Kullanıcı adı 3-24 karakter olmalı ve sadece harf/rakam/_ içermeli.';
    }
    return null;
  }

  static String? validatePassword(String password) {
    if (password.length < 6) {
      return 'Şifre en az 6 karakter olmalı.';
    }
    if (!RegExp(r'[A-Za-z]').hasMatch(password) ||
        !RegExp(r'[0-9]').hasMatch(password)) {
      return 'Şifre en az bir harf ve bir rakam içermeli.';
    }
    return null;
  }

  Future<void> setIsParentMode(bool isActive) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_keyIsParentMode, isActive);
    if (isActive) {
      final expiresAt =
          DateTime.now().add(_parentModeSessionDuration).millisecondsSinceEpoch;
      await prefs.setInt(_keyParentModeExpiresAtMs, expiresAt);
    } else {
      await prefs.remove(_keyParentModeExpiresAtMs);
    }
  }

  Future<void> refreshParentModeSession() async {
    final isParentMode = await getIsParentMode();
    if (!isParentMode) return;
    await setIsParentMode(true);
  }

  Future<bool> getIsParentMode() async {
    final prefs = await _getPrefs();
    final isActive = prefs.getBool(_keyIsParentMode) ?? false;
    if (!isActive) return false;

    final expiresAtMs = prefs.getInt(_keyParentModeExpiresAtMs);
    if (expiresAtMs == null) {
      await setIsParentMode(false);
      return false;
    }

    if (DateTime.now().millisecondsSinceEpoch >= expiresAtMs) {
      await setIsParentMode(false);
      return false;
    }
    return true;
  }

  Future<void> setDevModeBypass(bool enabled) async {
    if (!kDebugMode) {
      final prefs = await _getPrefs();
      await prefs.remove(_keyDevModeBypass);
      return;
    }
    final prefs = await _getPrefs();
    await prefs.setBool(_keyDevModeBypass, enabled);
  }

  Future<bool> getDevModeBypass() async {
    if (!kDebugMode) return false;
    final prefs = await _getPrefs();
    return prefs.getBool(_keyDevModeBypass) ?? false;
  }

  Future<LocalRouteAccessState> getRouteAccessState() async {
    final prefs = await _getPrefs();
    final selectedUserId =
        prefs.getString(_keySelectedUserId) ?? _defaultUserId;
    final registeredUsers =
        prefs.getStringList(_registeredUsersKey) ?? <String>[];
    final anyUserExists = registeredUsers.any(
      (user) => user.trim().isNotEmpty && user.trim() != _defaultUserId,
    );

    return LocalRouteAccessState(
      anyUserExists: anyUserExists,
      selectedUserId: selectedUserId,
      isParentMode: await getIsParentMode(),
      devModeBypass: await getDevModeBypass(),
    );
  }

  Future<void> setAppThemePalette(String paletteKey) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keyAppThemePalette, paletteKey);
  }

  Future<String> getAppThemePalette() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keyAppThemePalette) ?? 'candy_sky';
  }

  Future<bool> registerUser(
    String username,
    String password, {
    String? avatarUrl,
  }) async {
    final trimmedUsername = username.trim();
    final usernameError = validateUsername(trimmedUsername);
    final passwordError = validatePassword(password);
    if (usernameError != null || passwordError != null) {
      return false;
    }

    final db = await _getUserDatabase();
    final existing = _findUsernameMatch(trimmedUsername, db.keys);
    if (existing != null) return false;

    final salt = _generateSalt();
    db[trimmedUsername] = _LocalCredentialRecord(
      hash: _hashPassword(password, salt),
      salt: salt,
      failedAttempts: 0,
      lockUntilMs: 0,
    );
    await _saveUserDatabase(db);

    final prefs = await _getPrefs();
    final registeredUsers =
        prefs.getStringList(_registeredUsersKey) ?? <String>[];
    if (_findUsernameMatch(trimmedUsername, registeredUsers) == null) {
      registeredUsers.add(trimmedUsername);
      await prefs.setStringList(_registeredUsersKey, registeredUsers);
    }

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      await setSelectedUserAvatar(trimmedUsername, avatarUrl);
    }

    await setSelectedUserId(trimmedUsername);
    return true;
  }

  Future<LocalAuthResult> verifyPasswordDetailed(
    String username,
    String password,
  ) async {
    final trimmedUsername = username.trim();
    final db = await _getUserDatabase();
    final storedUsername = _findUsernameMatch(trimmedUsername, db.keys);
    if (storedUsername == null) {
      return const LocalAuthResult(success: false);
    }

    final record = db[storedUsername]!;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if ((record.lockUntilMs ?? 0) > nowMs) {
      final remainingSeconds =
          ((record.lockUntilMs! - nowMs) / 1000).ceil().clamp(1, 9999);
      return LocalAuthResult(
        success: false,
        isLockedOut: true,
        remainingLockSeconds: remainingSeconds,
        resolvedUsername: storedUsername,
      );
    }

    bool isPasswordValid = false;
    bool needsSave = false;
    var updatedRecord = record;

    if (record.legacyHash != null) {
      final candidateLegacyHash = _legacyHashPassword(password);
      isPasswordValid =
          _constantTimeEquals(candidateLegacyHash, record.legacyHash!);

      if (isPasswordValid) {
        final newSalt = _generateSalt();
        updatedRecord = _LocalCredentialRecord(
          hash: _hashPassword(password, newSalt),
          salt: newSalt,
          failedAttempts: 0,
          lockUntilMs: 0,
        );
        needsSave = true;
      }
    } else {
      final candidateHash = _hashPassword(password, record.salt!);
      isPasswordValid = _constantTimeEquals(candidateHash, record.hash!);
      if (isPasswordValid &&
          ((record.failedAttempts ?? 0) > 0 || (record.lockUntilMs ?? 0) > 0)) {
        updatedRecord = record.copyWith(failedAttempts: 0, lockUntilMs: 0);
        needsSave = true;
      }
    }

    if (isPasswordValid) {
      if (needsSave) {
        db[storedUsername] = updatedRecord;
        await _saveUserDatabase(db);
      }
      return LocalAuthResult(success: true, resolvedUsername: storedUsername);
    }

    final nextFailedAttempts = (record.failedAttempts ?? 0) + 1;
    final shouldLock = nextFailedAttempts >= _maxFailedAttempts;
    final lockUntilMs = shouldLock
        ? DateTime.now().add(_loginLockDuration).millisecondsSinceEpoch
        : 0;
    db[storedUsername] = record.copyWith(
      failedAttempts: shouldLock ? 0 : nextFailedAttempts,
      lockUntilMs: lockUntilMs,
    );
    await _saveUserDatabase(db);

    if (shouldLock) {
      return LocalAuthResult(
        success: false,
        isLockedOut: true,
        remainingLockSeconds: _loginLockDuration.inSeconds,
        resolvedUsername: storedUsername,
      );
    }

    return LocalAuthResult(success: false, resolvedUsername: storedUsername);
  }

  Future<LocalAuthResult> loginUserDetailed(
    String username,
    String password,
  ) async {
    final result = await verifyPasswordDetailed(username, password);
    if (!result.success) {
      return result;
    }

    await setSelectedUserId(result.resolvedUsername ?? username.trim());
    return result;
  }

  Future<bool> loginUser(String username, String password) async {
    final result = await loginUserDetailed(username, password);
    return result.success;
  }

  Future<bool> verifyPassword(String username, String password) async {
    final result = await verifyPasswordDetailed(username, password);
    return result.success;
  }

  Future<int> getRemainingLockSeconds(String username) async {
    final db = await _getUserDatabase();
    final storedUsername = _findUsernameMatch(username, db.keys);
    if (storedUsername == null) return 0;

    final lockUntilMs = db[storedUsername]?.lockUntilMs ?? 0;
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    if (lockUntilMs <= nowMs) return 0;
    return ((lockUntilMs - nowMs) / 1000).ceil();
  }

  Future<List<String>> getAllRegisteredUsernames() async {
    final prefs = await _getPrefs();
    final db = await _getUserDatabase();
    final usernames = prefs.getStringList(_registeredUsersKey) ?? <String>[];

    final validUsernames = usernames
        .where((name) =>
            name != _defaultUserId && _findUsernameMatch(name, db.keys) != null)
        .toList();

    if (validUsernames.length != usernames.length) {
      await prefs.setStringList(_registeredUsersKey, validUsernames);
    }

    return validUsernames;
  }

  Future<bool> anyUserRegistered() async {
    final users = await getAllRegisteredUsernames();
    return users.isNotEmpty;
  }

  Future<String> getSelectedUserId() async {
    final prefs = await _getPrefs();
    return prefs.getString(_keySelectedUserId) ?? _defaultUserId;
  }

  Future<void> setSelectedUserId(String userId) async {
    final prefs = await _getPrefs();
    await prefs.setString(_keySelectedUserId, userId.trim());
    await setIsParentMode(false);
  }

  Future<void> logoutUser() async {
    final prefs = await _getPrefs();
    await prefs.remove(_keySelectedUserId);
    await setIsParentMode(false);
  }

  Future<void> setSelectedUserAvatar(String userId, String avatarUrl) async {
    if (userId.isEmpty || userId == _defaultUserId || avatarUrl.isEmpty) return;
    final prefs = await _getPrefs();
    await prefs.setString('$_userAvatarPrefix$userId', avatarUrl);
  }

  Future<String?> getSelectedUserAvatar(String userId) async {
    if (userId == _defaultUserId) return null;
    final prefs = await _getPrefs();
    return prefs.getString('$_userAvatarPrefix$userId');
  }

  String _scopedKey(String prefix, String userId) {
    return '$prefix${userId.trim()}';
  }

  Future<void> saveUserPersonalization(
    String userId,
    UserPersonalization personalization,
  ) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty || normalizedUserId == _defaultUserId) return;

    final prefs = await _getPrefs();
    final cleanDisplayName = personalization.displayName.trim();
    final cleanAbout = personalization.about.trim();
    final cleanMascotName = personalization.mascotName.trim();

    final normalizedInterests = personalization.interestTags
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .take(6)
        .toList(growable: false);

    await prefs.setString(
      _scopedKey(_userDisplayNamePrefix, normalizedUserId),
      cleanDisplayName,
    );
    await prefs.setString(
      _scopedKey(_userAboutPrefix, normalizedUserId),
      cleanAbout,
    );
    await prefs.setString(
      _scopedKey(_userAgeBandPrefix, normalizedUserId),
      personalization.ageBandKey.trim().isEmpty
          ? 'age_7_9'
          : personalization.ageBandKey.trim(),
    );
    await prefs.setString(
      _scopedKey(_userFavoriteStoryStylePrefix, normalizedUserId),
      personalization.favoriteStoryStyleKey.trim().isEmpty
          ? 'adventure'
          : personalization.favoriteStoryStyleKey.trim(),
    );
    await prefs.setString(
      _scopedKey(_userFavoriteGamePrefix, normalizedUserId),
      personalization.favoriteGameKey.trim().isEmpty
          ? 'quick_math'
          : personalization.favoriteGameKey.trim(),
    );
    await prefs.setStringList(
      _scopedKey(_userInterestsPrefix, normalizedUserId),
      normalizedInterests,
    );
    await prefs.setString(
      _scopedKey(_userMascotNamePrefix, normalizedUserId),
      cleanMascotName,
    );
  }

  Future<UserPersonalization> getUserPersonalization(String userId) async {
    final normalizedUserId = userId.trim();
    if (normalizedUserId.isEmpty || normalizedUserId == _defaultUserId) {
      return const UserPersonalization();
    }

    final prefs = await _getPrefs();

    return UserPersonalization(
      displayName: prefs.getString(
              _scopedKey(_userDisplayNamePrefix, normalizedUserId)) ??
          '',
      about:
          prefs.getString(_scopedKey(_userAboutPrefix, normalizedUserId)) ?? '',
      ageBandKey:
          prefs.getString(_scopedKey(_userAgeBandPrefix, normalizedUserId)) ??
              'age_7_9',
      favoriteStoryStyleKey: prefs.getString(
            _scopedKey(_userFavoriteStoryStylePrefix, normalizedUserId),
          ) ??
          'adventure',
      favoriteGameKey: prefs.getString(
              _scopedKey(_userFavoriteGamePrefix, normalizedUserId)) ??
          'quick_math',
      interestTags: prefs.getStringList(
              _scopedKey(_userInterestsPrefix, normalizedUserId)) ??
          const <String>[],
      mascotName: prefs
              .getString(_scopedKey(_userMascotNamePrefix, normalizedUserId)) ??
          '',
    );
  }

  Future<Map<String, UserPersonalization>> getUserPersonalizations(
    Iterable<String> userIds,
  ) async {
    final prefs = await _getPrefs();
    final result = <String, UserPersonalization>{};

    for (final userId in userIds) {
      final normalizedUserId = userId.trim();
      if (normalizedUserId.isEmpty || normalizedUserId == _defaultUserId) {
        result[normalizedUserId] = const UserPersonalization();
        continue;
      }

      result[normalizedUserId] = UserPersonalization(
        displayName: prefs.getString(
              _scopedKey(_userDisplayNamePrefix, normalizedUserId),
            ) ??
            '',
        about:
            prefs.getString(_scopedKey(_userAboutPrefix, normalizedUserId)) ??
                '',
        ageBandKey:
            prefs.getString(_scopedKey(_userAgeBandPrefix, normalizedUserId)) ??
                'age_7_9',
        favoriteStoryStyleKey: prefs.getString(
              _scopedKey(_userFavoriteStoryStylePrefix, normalizedUserId),
            ) ??
            'adventure',
        favoriteGameKey: prefs.getString(
                _scopedKey(_userFavoriteGamePrefix, normalizedUserId)) ??
            'quick_math',
        interestTags: prefs.getStringList(
                _scopedKey(_userInterestsPrefix, normalizedUserId)) ??
            const <String>[],
        mascotName: prefs.getString(
                _scopedKey(_userMascotNamePrefix, normalizedUserId)) ??
            '',
      );
    }

    return result;
  }

  Future<void> saveReadingAccessibilityProfile(
    String userId,
    ReadingAccessibilityProfile profile,
  ) async {
    final trimmed = userId.trim();
    final normalizedUserId = trimmed.isEmpty ? _defaultUserId : trimmed;
    final prefs = await _getPrefs();

    await prefs.setDouble(
      _scopedKey(_readerFontScalePrefix, normalizedUserId),
      profile.fontScale.clamp(0.85, 1.45),
    );
    await prefs.setDouble(
      _scopedKey(_readerLetterSpacingPrefix, normalizedUserId),
      profile.letterSpacing.clamp(0.0, 2.0),
    );
    await prefs.setDouble(
      _scopedKey(_readerTtsRatePrefix, normalizedUserId),
      profile.ttsRate.clamp(0.3, 0.75),
    );
    await prefs.setDouble(
      _scopedKey(_readerTtsPitchPrefix, normalizedUserId),
      profile.ttsPitch.clamp(0.75, 1.3),
    );
    await prefs.setBool(
      _scopedKey(_readerLineHighlightPrefix, normalizedUserId),
      profile.lineHighlightEnabled,
    );
  }

  Future<ReadingAccessibilityProfile> getReadingAccessibilityProfile(
    String userId,
  ) async {
    final trimmed = userId.trim();
    final normalizedUserId = trimmed.isEmpty ? _defaultUserId : trimmed;
    final prefs = await _getPrefs();

    return ReadingAccessibilityProfile(
      fontScale: (prefs.getDouble(
                  _scopedKey(_readerFontScalePrefix, normalizedUserId)) ??
              1.0)
          .clamp(0.85, 1.45),
      letterSpacing: (prefs.getDouble(
                  _scopedKey(_readerLetterSpacingPrefix, normalizedUserId)) ??
              0.0)
          .clamp(0.0, 2.0),
      ttsRate: (prefs.getDouble(
                  _scopedKey(_readerTtsRatePrefix, normalizedUserId)) ??
              0.5)
          .clamp(0.3, 0.75),
      ttsPitch: (prefs.getDouble(
                  _scopedKey(_readerTtsPitchPrefix, normalizedUserId)) ??
              1.0)
          .clamp(0.75, 1.3),
      lineHighlightEnabled: prefs.getBool(
            _scopedKey(_readerLineHighlightPrefix, normalizedUserId),
          ) ??
          true,
    );
  }

  static String get defaultUserId => _defaultUserId;
}

class _LocalCredentialRecord {
  const _LocalCredentialRecord({
    this.hash,
    this.salt,
    this.failedAttempts = 0,
    this.lockUntilMs = 0,
    this.legacyHash,
  });

  final String? hash;
  final String? salt;
  final int? failedAttempts;
  final int? lockUntilMs;
  final String? legacyHash;

  Map<String, dynamic> toMap() {
    return {
      'hash': hash,
      'salt': salt,
      'failedAttempts': failedAttempts ?? 0,
      'lockUntilMs': lockUntilMs ?? 0,
      if (legacyHash != null) 'legacyHash': legacyHash,
    };
  }

  _LocalCredentialRecord copyWith({
    String? hash,
    String? salt,
    int? failedAttempts,
    int? lockUntilMs,
    String? legacyHash,
  }) {
    return _LocalCredentialRecord(
      hash: hash ?? this.hash,
      salt: salt ?? this.salt,
      failedAttempts: failedAttempts ?? this.failedAttempts,
      lockUntilMs: lockUntilMs ?? this.lockUntilMs,
      legacyHash: legacyHash ?? this.legacyHash,
    );
  }

  static _LocalCredentialRecord? fromStored(dynamic value) {
    if (value is String) {
      return _LocalCredentialRecord(legacyHash: value);
    }
    if (value is! Map) return null;

    final map = Map<String, dynamic>.from(value);
    final hash = map['hash']?.toString();
    final salt = map['salt']?.toString();
    final legacyHash = map['legacyHash']?.toString();

    final failedAttempts = (map['failedAttempts'] as num?)?.toInt() ?? 0;
    final lockUntilMs = (map['lockUntilMs'] as num?)?.toInt() ?? 0;

    if ((hash == null || salt == null) && legacyHash == null) {
      return null;
    }

    return _LocalCredentialRecord(
      hash: hash,
      salt: salt,
      failedAttempts: failedAttempts,
      lockUntilMs: lockUntilMs,
      legacyHash: legacyHash,
    );
  }
}
