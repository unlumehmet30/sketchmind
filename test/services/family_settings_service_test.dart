import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sketchmind/data/services/family_settings_service.dart';
import 'package:sketchmind/data/services/local_user_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('returns defaults when there is no stored family setting', () async {
    final service = FamilySettingsService(enableCloudSync: false);
    final settings = await service.getSettings();

    expect(settings.screenTimeLimitEnabled, isFalse);
    expect(settings.dailyScreenTimeLimitMinutes, 60);
    expect(settings.breakReminderEnabled, isTrue);
    expect(settings.breakEveryMinutes, 20);
    expect(settings.storySafetyLevel, StorySafetyLevel.balanced);
    expect(settings.quietHoursEnabled, isFalse);
    expect(settings.allowToyPhotoUpload, isFalse);
    expect(settings.lowStimulusModeEnabled, isFalse);
    expect(settings.allowAutoplayNarration, isFalse);
    expect(settings.requireParentalConsentForAi, isTrue);
    expect(settings.parentalConsentGranted, isFalse);
    expect(settings.dataMinimizationMode, isTrue);
    expect(settings.transparencyModeEnabled, isTrue);
  });

  test('persists and reloads safety settings correctly', () async {
    final service = FamilySettingsService(enableCloudSync: false);

    const custom = FamilySafetySettings(
      screenTimeLimitEnabled: true,
      dailyScreenTimeLimitMinutes: 45,
      breakReminderEnabled: true,
      breakEveryMinutes: 15,
      storySafetyLevel: StorySafetyLevel.strict,
      quietHoursEnabled: true,
      quietHoursStartHour: 21,
      quietHoursEndHour: 7,
      allowToyPhotoUpload: true,
      lowStimulusModeEnabled: true,
      allowAutoplayNarration: true,
      requireParentalConsentForAi: true,
      parentalConsentGranted: true,
      dataMinimizationMode: false,
      transparencyModeEnabled: false,
    );

    await service.saveSettings(custom);
    final loaded = await service.getSettings();

    expect(loaded.screenTimeLimitEnabled, isTrue);
    expect(loaded.dailyScreenTimeLimitMinutes, 45);
    expect(loaded.breakReminderEnabled, isTrue);
    expect(loaded.breakEveryMinutes, 15);
    expect(loaded.storySafetyLevel, StorySafetyLevel.strict);
    expect(loaded.allowToyPhotoUpload, isTrue);
    expect(loaded.lowStimulusModeEnabled, isTrue);
    expect(loaded.allowAutoplayNarration, isTrue);
    expect(loaded.requireParentalConsentForAi, isTrue);
    expect(loaded.parentalConsentGranted, isTrue);
    expect(loaded.dataMinimizationMode, isFalse);
    expect(loaded.transparencyModeEnabled, isFalse);
    expect(loaded.isWithinQuietHours(DateTime(2026, 2, 24, 22)), isTrue);
    expect(loaded.isWithinQuietHours(DateTime(2026, 2, 24, 6)), isTrue);
    expect(loaded.isWithinQuietHours(DateTime(2026, 2, 24, 12)), isFalse);
  });

  test('stores settings per selected profile locally', () async {
    final localUserService = LocalUserService();
    final service = FamilySettingsService(
      localUserService: localUserService,
      enableCloudSync: false,
    );

    await localUserService.setSelectedUserId('KidA');
    await service.saveSettings(
      const FamilySafetySettings(
        screenTimeLimitEnabled: true,
        dailyScreenTimeLimitMinutes: 30,
        storySafetyLevel: StorySafetyLevel.strict,
      ),
      syncToCloud: false,
    );

    await localUserService.setSelectedUserId('KidB');
    await service.saveSettings(
      const FamilySafetySettings(
        screenTimeLimitEnabled: true,
        dailyScreenTimeLimitMinutes: 90,
        storySafetyLevel: StorySafetyLevel.creative,
      ),
      syncToCloud: false,
    );

    await localUserService.setSelectedUserId('KidA');
    final kidA = await service.getSettings();

    await localUserService.setSelectedUserId('KidB');
    final kidB = await service.getSettings();

    expect(kidA.dailyScreenTimeLimitMinutes, 30);
    expect(kidA.storySafetyLevel, StorySafetyLevel.strict);
    expect(kidB.dailyScreenTimeLimitMinutes, 90);
    expect(kidB.storySafetyLevel, StorySafetyLevel.creative);
  });
}
