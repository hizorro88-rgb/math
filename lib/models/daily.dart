import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

import 'progress.dart';

/// 매일 리셋되는 미션. 달성하면 코인을 보상으로 받는다.
class DailyMission {
  const DailyMission({
    required this.id,
    required this.emoji,
    required this.title,
    required this.target,
    required this.reward,
  });

  final String id;
  final String emoji;
  final String title;
  final int target;

  /// 달성 보상 코인
  final int reward;
}

const List<DailyMission> dailyMissions = [
  DailyMission(
      id: 'rounds3', emoji: '🎯', title: '퀴즈 3판 풀기', target: 3, reward: 30),
  DailyMission(
      id: 'correct20',
      emoji: '✏️',
      title: '정답 20개 맞히기',
      target: 20,
      reward: 40),
  DailyMission(
      id: 'stars5', emoji: '⭐', title: '별 5개 받기', target: 5, reward: 50),
];

/// 오늘의 미션 진행 상황과 연속 출석
class DailyState {
  const DailyState({
    required this.rounds,
    required this.correct,
    required this.stars,
    required this.claimed,
    required this.streak,
  });

  /// 오늘 푼 판 수 / 맞힌 문제 수 / 받은 별 수
  final int rounds;
  final int correct;
  final int stars;

  /// 오늘 보상을 받은 미션 id들
  final Set<String> claimed;

  /// 연속 출석 일수 (어제까지 이어져 있으면 유지)
  final int streak;

  int progressOf(DailyMission mission) => switch (mission.id) {
        'rounds3' => rounds,
        'correct20' => correct,
        'stars5' => stars,
        _ => 0,
      };

  bool isDone(DailyMission mission) => claimed.contains(mission.id);
}

/// 데일리 미션·출석을 저장한다. 날짜가 바뀌면 미션 진행도는 리셋된다.
class DailyStore {
  DailyStore._();

  static const _dateKey = 'daily_date_v1';
  static const _roundsKey = 'daily_rounds_v1';
  static const _correctKey = 'daily_correct_v1';
  static const _starsKey = 'daily_stars_v1';
  static const _claimedKey = 'daily_claimed_v1';
  static const _streakKey = 'streak_count_v1';
  static const _streakDayKey = 'streak_last_day_v1';

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 오늘 상태를 불러온다. 날짜가 바뀌었으면 미션 진행도를 리셋한다.
  /// [now]는 테스트용 주입 시각.
  static Future<DailyState> load({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final time = now ?? DateTime.now();
    final today = dayKey(time);

    if (prefs.getString(Profiles.scoped(_dateKey)) != today) {
      await prefs.setString(Profiles.scoped(_dateKey), today);
      await prefs.setInt(Profiles.scoped(_roundsKey), 0);
      await prefs.setInt(Profiles.scoped(_correctKey), 0);
      await prefs.setInt(Profiles.scoped(_starsKey), 0);
      await prefs.setStringList(Profiles.scoped(_claimedKey), const []);
    }

    // 마지막 출석이 어제보다 오래됐으면 스트릭은 끊긴 것으로 보여 준다.
    final lastDay = prefs.getString(Profiles.scoped(_streakDayKey));
    final yesterday = dayKey(time.subtract(const Duration(days: 1)));
    var streak = prefs.getInt(Profiles.scoped(_streakKey)) ?? 0;
    if (lastDay != today && lastDay != yesterday) streak = 0;

    return DailyState(
      rounds: prefs.getInt(Profiles.scoped(_roundsKey)) ?? 0,
      correct: prefs.getInt(Profiles.scoped(_correctKey)) ?? 0,
      stars: prefs.getInt(Profiles.scoped(_starsKey)) ?? 0,
      claimed: (prefs.getStringList(Profiles.scoped(_claimedKey)) ?? const [])
          .toSet(),
      streak: streak,
    );
  }

  /// 퀴즈 한 판이 끝날 때 호출: 진행도와 스트릭을 올리고,
  /// 새로 달성한 미션의 보상 코인을 지급한 뒤 그 목록을 돌려준다.
  static Future<List<DailyMission>> recordRound({
    required int correctCount,
    required int stars,
    DateTime? now,
  }) async {
    final before = await load(now: now); // 날짜 리셋 보장
    final prefs = await SharedPreferences.getInstance();
    final time = now ?? DateTime.now();
    final today = dayKey(time);

    final rounds = before.rounds + 1;
    final correct = before.correct + correctCount;
    final starsTotal = before.stars + stars;
    await prefs.setInt(Profiles.scoped(_roundsKey), rounds);
    await prefs.setInt(Profiles.scoped(_correctKey), correct);
    await prefs.setInt(Profiles.scoped(_starsKey), starsTotal);

    // 출석 스트릭: 오늘 처음 완료했을 때만 갱신
    if (prefs.getString(Profiles.scoped(_streakDayKey)) != today) {
      final yesterday = dayKey(time.subtract(const Duration(days: 1)));
      final wasYesterday =
          prefs.getString(Profiles.scoped(_streakDayKey)) == yesterday;
      await prefs.setInt(
        Profiles.scoped(_streakKey),
        wasYesterday ? (prefs.getInt(Profiles.scoped(_streakKey)) ?? 0) + 1 : 1,
      );
      await prefs.setString(Profiles.scoped(_streakDayKey), today);
    }

    // 새로 달성한 미션 보상 지급
    final after = DailyState(
      rounds: rounds,
      correct: correct,
      stars: starsTotal,
      claimed: before.claimed,
      streak: 0,
    );
    final newlyDone = <DailyMission>[];
    final claimed = {...before.claimed};
    for (final mission in dailyMissions) {
      if (!claimed.contains(mission.id) &&
          after.progressOf(mission) >= mission.target) {
        claimed.add(mission.id);
        newlyDone.add(mission);
        await ProgressStore.addPoints(mission.reward);
      }
    }
    await prefs.setStringList(Profiles.scoped(_claimedKey), claimed.toList());
    return newlyDone;
  }
}
