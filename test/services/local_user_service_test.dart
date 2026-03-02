import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sketchmind/data/services/local_user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('registers and logs in a local profile', () async {
    final service = LocalUserService();

    final registered = await service.registerUser('Cocuk_01', 'abc123');
    final loggedIn = await service.loginUser('Cocuk_01', 'abc123');
    final selectedUser = await service.getSelectedUserId();

    expect(registered, isTrue);
    expect(loggedIn, isTrue);
    expect(selectedUser, 'Cocuk_01');
  });

  test('locks account after repeated wrong passwords', () async {
    final service = LocalUserService();
    await service.registerUser('Cocuk_02', 'abc123');

    LocalAuthResult result =
        const LocalAuthResult(success: false, isLockedOut: false);

    for (var i = 0; i < 5; i++) {
      result = await service.verifyPasswordDetailed('Cocuk_02', 'wrong999');
    }

    final loginWhileLocked = await service.loginUser('Cocuk_02', 'abc123');

    expect(result.success, isFalse);
    expect(result.isLockedOut, isTrue);
    expect(result.remainingLockSeconds, greaterThan(0));
    expect(loginWhileLocked, isFalse);
  });

  test('stores personalization data per user profile', () async {
    final service = LocalUserService();
    await service.registerUser('Cocuk_03', 'abc123');

    await service.saveUserPersonalization(
      'Cocuk_03',
      const UserPersonalization(
        displayName: 'Mavi Kaplan',
        about: 'Uzay ve bulmaca severim',
        ageBandKey: 'age_10_12',
        favoriteStoryStyleKey: 'adventure',
        favoriteGameKey: 'mini_tournament',
        interestTags: <String>['Uzay', 'Bulmaca', 'Robot'],
        mascotName: 'Roko',
      ),
    );

    final profile = await service.getUserPersonalization('Cocuk_03');

    expect(profile.displayName, 'Mavi Kaplan');
    expect(profile.ageBandKey, 'age_10_12');
    expect(profile.favoriteStoryStyleKey, 'adventure');
    expect(profile.favoriteGameKey, 'mini_tournament');
    expect(profile.interestTags, containsAll(<String>['Uzay', 'Bulmaca']));
    expect(profile.mascotName, 'Roko');
  });

  test('stores reading accessibility profile per user', () async {
    final service = LocalUserService();
    await service.registerUser('Cocuk_04', 'abc123');

    await service.saveReadingAccessibilityProfile(
      'Cocuk_04',
      const ReadingAccessibilityProfile(
        fontScale: 1.2,
        letterSpacing: 0.6,
        ttsRate: 0.42,
        ttsPitch: 1.08,
        lineHighlightEnabled: false,
      ),
    );

    final profile = await service.getReadingAccessibilityProfile('Cocuk_04');

    expect(profile.fontScale, closeTo(1.2, 0.0001));
    expect(profile.letterSpacing, closeTo(0.6, 0.0001));
    expect(profile.ttsRate, closeTo(0.42, 0.0001));
    expect(profile.ttsPitch, closeTo(1.08, 0.0001));
    expect(profile.lineHighlightEnabled, isFalse);
  });
}
