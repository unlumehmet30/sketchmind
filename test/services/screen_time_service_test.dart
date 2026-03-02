import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:sketchmind/data/services/screen_time_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  test('calculates status and limit from stored usage', () async {
    final now = DateTime.now();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final startMs = DateTime.now()
        .subtract(const Duration(minutes: 5))
        .millisecondsSinceEpoch;

    SharedPreferences.setMockInitialValues(<String, Object>{
      'screen_time_day': todayKey,
      'screen_time_accumulated_seconds': 1200,
      'screen_time_active_start_ms': startMs,
      'screen_time_last_break_bucket': 0,
    });

    final service = ScreenTimeService();
    final status = await service.getStatus(
      limitEnabled: true,
      dailyLimitMinutes: 24,
    );

    expect(status.usedMinutes, greaterThanOrEqualTo(24));
    expect(status.isLimitReached, isTrue);
    expect(status.remainingMinutes, 0);
  });

  test('break reminder is consumed only once per bucket', () async {
    final now = DateTime.now();
    final todayKey =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    SharedPreferences.setMockInitialValues(<String, Object>{
      'screen_time_day': todayKey,
      'screen_time_accumulated_seconds': 1500,
      'screen_time_last_break_bucket': 0,
    });

    final service = ScreenTimeService();
    final first = await service.consumeDueBreakReminder(
      enabled: true,
      intervalMinutes: 10,
    );
    final second = await service.consumeDueBreakReminder(
      enabled: true,
      intervalMinutes: 10,
    );

    expect(first, 20);
    expect(second, isNull);
  });
}
