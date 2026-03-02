class DailyMissionStatus {
  const DailyMissionStatus({
    required this.id,
    required this.title,
    required this.description,
    required this.progress,
    required this.target,
  });

  final String id;
  final String title;
  final String description;
  final int progress;
  final int target;

  bool get isCompleted => progress >= target;
  double get completionRatio =>
      target <= 0 ? 0 : (progress / target).clamp(0, 1);
}

class WeeklyDaySummary {
  const WeeklyDaySummary({
    required this.date,
    required this.minutesSpent,
    required this.gamesPlayed,
    required this.storiesRead,
    required this.vocabularyCorrect,
  });

  final DateTime date;
  final int minutesSpent;
  final int gamesPlayed;
  final int storiesRead;
  final int vocabularyCorrect;
}

class WeeklyReport {
  const WeeklyReport({
    required this.days,
    required this.totalMinutes,
    required this.totalGames,
    required this.totalStories,
    required this.totalVocabularyCorrect,
  });

  final List<WeeklyDaySummary> days;
  final int totalMinutes;
  final int totalGames;
  final int totalStories;
  final int totalVocabularyCorrect;
}

class AdaptiveTutorPlan {
  const AdaptiveTutorPlan({
    required this.focusArea,
    required this.reason,
    required this.nextSteps,
    required this.confidence,
  });

  final String focusArea;
  final String reason;
  final List<String> nextSteps;
  final double confidence;
}

class ParentInterventionSettings {
  const ParentInterventionSettings({
    required this.dailyGoalMinutes,
    required this.breakReminderEnabled,
    required this.breakEveryMinutes,
  });

  final int dailyGoalMinutes;
  final bool breakReminderEnabled;
  final int breakEveryMinutes;
}

class DigitalSafetyStats {
  const DigitalSafetyStats({
    required this.sessionsPlayed,
    required this.bestScore,
    required this.lastScore,
  });

  final int sessionsPlayed;
  final int bestScore;
  final int lastScore;
}

class ReviewCard {
  const ReviewCard({
    required this.id,
    required this.word,
    required this.dueDate,
    required this.stage,
  });

  final String id;
  final String word;
  final DateTime dueDate;
  final int stage;
}

class LearningSnapshot {
  const LearningSnapshot({
    required this.userId,
    required this.streakDays,
    required this.badges,
    required this.dailyMissions,
    required this.weeklyReport,
    required this.mood,
    required this.quickMathLevel,
    required this.offlinePackEnabled,
    required this.teacherModeEnabled,
    required this.teacherAssignments,
    required this.recommendations,
    required this.vocabularyMasteredCount,
    required this.tournamentWins,
    required this.dueReviewCount,
    required this.completedReviewToday,
    required this.hintUsageToday,
    required this.parentSettings,
    required this.parentNudges,
    required this.adaptivePlan,
    required this.digitalSafetyStats,
  });

  final String userId;
  final int streakDays;
  final List<String> badges;
  final List<DailyMissionStatus> dailyMissions;
  final WeeklyReport weeklyReport;
  final String mood;
  final int quickMathLevel;
  final bool offlinePackEnabled;
  final bool teacherModeEnabled;
  final List<String> teacherAssignments;
  final List<String> recommendations;
  final int vocabularyMasteredCount;
  final int tournamentWins;
  final int dueReviewCount;
  final int completedReviewToday;
  final int hintUsageToday;
  final ParentInterventionSettings parentSettings;
  final List<String> parentNudges;
  final AdaptiveTutorPlan adaptivePlan;
  final DigitalSafetyStats digitalSafetyStats;
}
