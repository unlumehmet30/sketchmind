import 'package:shared_preferences/shared_preferences.dart';

class ScreenTimeStatus {
  const ScreenTimeStatus({
    required this.usedSeconds,
    required this.usedMinutes,
    required this.limitEnabled,
    required this.dailyLimitMinutes,
  });

  final int usedSeconds;
  final int usedMinutes;
  final bool limitEnabled;
  final int dailyLimitMinutes;

  bool get isLimitReached =>
      limitEnabled && dailyLimitMinutes > 0 && usedMinutes >= dailyLimitMinutes;

  int get remainingMinutes {
    if (!limitEnabled || dailyLimitMinutes <= 0) return 0;
    final remaining = dailyLimitMinutes - usedMinutes;
    return remaining < 0 ? 0 : remaining;
  }

  double get usageRatio {
    if (!limitEnabled || dailyLimitMinutes <= 0) return 0;
    return (usedMinutes / dailyLimitMinutes).clamp(0.0, 1.0);
  }
}

class ScreenTimeService {
  ScreenTimeService._internal();
  static final ScreenTimeService _instance = ScreenTimeService._internal();
  factory ScreenTimeService() => _instance;

  static const _keyDay = 'screen_time_day';
  static const _keyAccumulatedSeconds = 'screen_time_accumulated_seconds';
  static const _keyActiveStartMs = 'screen_time_active_start_ms';
  static const _keyLastBreakBucket = 'screen_time_last_break_bucket';
  static const bool _isTestEnvironment = bool.fromEnvironment('FLUTTER_TEST');

  Future<SharedPreferences>? _prefsFuture;
  ScreenTimeStatus? _cachedStatus;
  DateTime? _cachedStatusAt;

  Future<SharedPreferences> _getPrefs() async {
    if (_isTestEnvironment) {
      return SharedPreferences.getInstance();
    }
    return _prefsFuture ??= SharedPreferences.getInstance();
  }

  Future<void> onAppResumed() async {
    final prefs = await _getPrefs();
    await _normalizeDay(prefs, keepActiveSession: true);
    if (prefs.getInt(_keyActiveStartMs) == null) {
      await prefs.setInt(
          _keyActiveStartMs, DateTime.now().millisecondsSinceEpoch);
    }
    _cachedStatus = null;
    _cachedStatusAt = null;
  }

  Future<void> onAppPaused() async {
    final prefs = await _getPrefs();
    await _commitElapsedSeconds(prefs);
    _cachedStatus = null;
    _cachedStatusAt = null;
  }

  Future<ScreenTimeStatus> getStatus({
    required bool limitEnabled,
    required int dailyLimitMinutes,
  }) async {
    final now = DateTime.now();
    final cached = _cachedStatus;
    if (cached != null &&
        _cachedStatusAt != null &&
        now.difference(_cachedStatusAt!) < const Duration(seconds: 10) &&
        cached.limitEnabled == limitEnabled &&
        cached.dailyLimitMinutes == dailyLimitMinutes.clamp(0, 600).toInt()) {
      return cached;
    }

    final usedSeconds = await getTodayUsedSeconds();
    final usedMinutes = (usedSeconds / 60).floor();

    final status = ScreenTimeStatus(
      usedSeconds: usedSeconds,
      usedMinutes: usedMinutes,
      limitEnabled: limitEnabled,
      dailyLimitMinutes: dailyLimitMinutes.clamp(0, 600).toInt(),
    );
    _cachedStatus = status;
    _cachedStatusAt = now;
    return status;
  }

  Future<int> getTodayUsedMinutes() async {
    final seconds = await getTodayUsedSeconds();
    return (seconds / 60).floor();
  }

  Future<int> getTodayUsedSeconds() async {
    final prefs = await _getPrefs();
    await _normalizeDay(prefs, keepActiveSession: false);

    final accumulated = prefs.getInt(_keyAccumulatedSeconds) ?? 0;
    final activeStart = prefs.getInt(_keyActiveStartMs);
    if (activeStart == null) return accumulated;

    final elapsed = _elapsedSecondsFrom(activeStart);
    return accumulated + elapsed;
  }

  Future<int?> consumeDueBreakReminder({
    required bool enabled,
    required int intervalMinutes,
  }) async {
    if (!enabled) return null;

    final safeInterval = intervalMinutes.clamp(10, 120).toInt();
    final usedMinutes = await getTodayUsedMinutes();
    if (usedMinutes < safeInterval) return null;

    final bucket = usedMinutes ~/ safeInterval;
    if (bucket <= 0) return null;

    final prefs = await _getPrefs();
    await _normalizeDay(prefs, keepActiveSession: false);
    final lastBucket = prefs.getInt(_keyLastBreakBucket) ?? 0;

    if (bucket <= lastBucket) return null;
    await prefs.setInt(_keyLastBreakBucket, bucket);

    return bucket * safeInterval;
  }

  Future<void> _commitElapsedSeconds(SharedPreferences prefs) async {
    await _normalizeDay(prefs, keepActiveSession: false);

    final activeStart = prefs.getInt(_keyActiveStartMs);
    if (activeStart == null) return;

    final elapsed = _elapsedSecondsFrom(activeStart);
    final current = prefs.getInt(_keyAccumulatedSeconds) ?? 0;
    await prefs.setInt(_keyAccumulatedSeconds, current + elapsed);
    await prefs.remove(_keyActiveStartMs);
  }

  Future<void> _normalizeDay(
    SharedPreferences prefs, {
    required bool keepActiveSession,
  }) async {
    final todayKey = _todayKey();
    final storedDay = prefs.getString(_keyDay);
    if (storedDay == todayKey) return;

    await prefs.setString(_keyDay, todayKey);
    await prefs.setInt(_keyAccumulatedSeconds, 0);
    await prefs.setInt(_keyLastBreakBucket, 0);

    if (keepActiveSession) {
      await prefs.setInt(
          _keyActiveStartMs, DateTime.now().millisecondsSinceEpoch);
    } else {
      await prefs.remove(_keyActiveStartMs);
    }
  }

  int _elapsedSecondsFrom(int startMs) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final elapsedMs = nowMs - startMs;
    if (elapsedMs <= 0) return 0;
    return (elapsedMs / 1000).floor();
  }

  String _todayKey() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
