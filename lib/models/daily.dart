import 'dart:math';

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

/// 전체 미션 풀. 매일 이 중 3개가 뽑힌다 (1번은 항상 '퀴즈 3판').
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
      id: 'correct30',
      emoji: '📚',
      title: '정답 30개 맞히기',
      target: 30,
      reward: 60),
  DailyMission(
      id: 'stars5', emoji: '⭐', title: '별 5개 받기', target: 5, reward: 50),
  DailyMission(
      id: 'perfect1', emoji: '🏆', title: '별 3개로 통과하기', target: 1, reward: 40),
  DailyMission(
      id: 'math1', emoji: '🧮', title: '수학 1판 풀기', target: 1, reward: 20),
  DailyMission(
      id: 'korean1', emoji: '📖', title: '한글 1판 풀기', target: 1, reward: 20),
  DailyMission(
      id: 'rounds5', emoji: '🏃', title: '퀴즈 5판 풀기', target: 5, reward: 50),
];

DailyMission _missionById(String id) =>
    dailyMissions.firstWhere((m) => m.id == id);

/// 판이 끝났을 때 받은 보상 묶음
class RoundRewards {
  const RoundRewards({
    required this.missions,
    this.milestoneDays = 0,
    this.milestoneCoins = 0,
  });

  /// 이번 판으로 새로 달성한 미션들
  final List<DailyMission> missions;

  /// 스트릭 마일스톤(3·7·14·30일)에 막 도달했으면 그 일수와 보너스 코인
  final int milestoneDays;
  final int milestoneCoins;
}

/// 오늘의 미션 진행 상황과 연속 출석
class DailyState {
  const DailyState({
    required this.rounds,
    required this.correct,
    required this.stars,
    required this.perfect,
    required this.mathRounds,
    required this.koreanRounds,
    required this.claimed,
    required this.streak,
    required this.freezes,
    required this.missions,
  });

  /// 오늘 푼 판 수 / 맞힌 문제 수 / 받은 별 수 / 3별 판 수
  final int rounds;
  final int correct;
  final int stars;
  final int perfect;

  /// 오늘 푼 수학/한글 판 수
  final int mathRounds;
  final int koreanRounds;

  /// 오늘 보상을 받은 미션 id들
  final Set<String> claimed;

  /// 연속 출석 일수 (어제까지 이어져 있으면 유지)
  final int streak;

  /// 갖고 있는 스트릭 지킴이(하루 걸러도 스트릭 유지) 개수
  final int freezes;

  /// 오늘의 미션 3개
  final List<DailyMission> missions;

  int progressOf(DailyMission mission) => switch (mission.id) {
        'rounds3' || 'rounds5' => rounds,
        'correct20' || 'correct30' => correct,
        'stars5' => stars,
        'perfect1' => perfect,
        'math1' => mathRounds,
        'korean1' => koreanRounds,
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
  static const _perfectKey = 'daily_perfect_v1';
  static const _mathRoundsKey = 'daily_math_rounds_v1';
  static const _koreanRoundsKey = 'daily_korean_rounds_v1';
  static const _claimedKey = 'daily_claimed_v1';
  static const _streakKey = 'streak_count_v1';
  static const _streakDayKey = 'streak_last_day_v1';
  static const _freezeKey = 'streak_freeze_v1';
  static const _milestonesKey = 'streak_milestones_v1';

  /// 스트릭 지킴이 가격과 최대 보유 개수
  static const freezeCost = 200;
  static const maxFreezes = 2;

  /// 스트릭 마일스톤 (도달하면 일수×10 코인 보너스)
  static const milestones = [3, 7, 14, 30];

  static String dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 오늘의 미션 3개: 1번은 항상 '퀴즈 3판', 나머지 둘은 날짜에 따라 바뀐다.
  /// (같은 날에는 언제 다시 켜도 같은 미션이 나온다)
  static List<DailyMission> missionsFor(DateTime time) {
    final day = dayKey(time);
    // String.hashCode는 플랫폼마다 다를 수 있어 직접 안정적인 해시를 만든다.
    var seed = 0;
    for (final c in day.codeUnits) {
      seed = (seed * 31 + c) & 0x7fffffff;
    }
    final random = Random(seed);
    const bucketB = ['correct20', 'correct30', 'stars5', 'perfect1'];
    const bucketC = ['math1', 'korean1', 'rounds5'];
    return [
      _missionById('rounds3'),
      _missionById(bucketB[random.nextInt(bucketB.length)]),
      _missionById(bucketC[random.nextInt(bucketC.length)]),
    ];
  }

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
      await prefs.setInt(Profiles.scoped(_perfectKey), 0);
      await prefs.setInt(Profiles.scoped(_mathRoundsKey), 0);
      await prefs.setInt(Profiles.scoped(_koreanRoundsKey), 0);
      await prefs.setStringList(Profiles.scoped(_claimedKey), const []);
    }

    // 마지막 출석이 어제보다 오래됐으면 스트릭은 끊긴 것으로 보여 준다.
    // 단 하루만 건너뛰었고 지킴이가 있으면 아직 살아 있는 것으로 본다.
    final lastDay = prefs.getString(Profiles.scoped(_streakDayKey));
    final yesterday = dayKey(time.subtract(const Duration(days: 1)));
    final twoDaysAgo = dayKey(time.subtract(const Duration(days: 2)));
    final freezes = prefs.getInt(Profiles.scoped(_freezeKey)) ?? 0;
    var streak = prefs.getInt(Profiles.scoped(_streakKey)) ?? 0;
    final alive = lastDay == today ||
        lastDay == yesterday ||
        (lastDay == twoDaysAgo && freezes > 0);
    if (!alive) streak = 0;

    return DailyState(
      rounds: prefs.getInt(Profiles.scoped(_roundsKey)) ?? 0,
      correct: prefs.getInt(Profiles.scoped(_correctKey)) ?? 0,
      stars: prefs.getInt(Profiles.scoped(_starsKey)) ?? 0,
      perfect: prefs.getInt(Profiles.scoped(_perfectKey)) ?? 0,
      mathRounds: prefs.getInt(Profiles.scoped(_mathRoundsKey)) ?? 0,
      koreanRounds: prefs.getInt(Profiles.scoped(_koreanRoundsKey)) ?? 0,
      claimed: (prefs.getStringList(Profiles.scoped(_claimedKey)) ?? const [])
          .toSet(),
      streak: streak,
      freezes: freezes,
      missions: missionsFor(time),
    );
  }

  /// 코인으로 스트릭 지킴이를 산다. 성공하면 true.
  static Future<bool> buyFreeze() async {
    final prefs = await SharedPreferences.getInstance();
    final have = prefs.getInt(Profiles.scoped(_freezeKey)) ?? 0;
    if (have >= maxFreezes) return false;
    if (!await ProgressStore.spendCoins(freezeCost)) return false;
    await prefs.setInt(Profiles.scoped(_freezeKey), have + 1);
    return true;
  }

  /// 퀴즈 한 판이 끝날 때 호출: 진행도와 스트릭을 올리고,
  /// 새로 달성한 미션·마일스톤 보상 코인을 지급한 뒤 그 내역을 돌려준다.
  static Future<RoundRewards> recordRound({
    required int correctCount,
    required int stars,
    bool korean = false,
    DateTime? now,
  }) async {
    final before = await load(now: now); // 날짜 리셋 보장
    final prefs = await SharedPreferences.getInstance();
    final time = now ?? DateTime.now();
    final today = dayKey(time);

    final rounds = before.rounds + 1;
    final correct = before.correct + correctCount;
    final starsTotal = before.stars + stars;
    final perfect = before.perfect + (stars >= 3 ? 1 : 0);
    final mathRounds = before.mathRounds + (korean ? 0 : 1);
    final koreanRounds = before.koreanRounds + (korean ? 1 : 0);
    await prefs.setInt(Profiles.scoped(_roundsKey), rounds);
    await prefs.setInt(Profiles.scoped(_correctKey), correct);
    await prefs.setInt(Profiles.scoped(_starsKey), starsTotal);
    await prefs.setInt(Profiles.scoped(_perfectKey), perfect);
    await prefs.setInt(Profiles.scoped(_mathRoundsKey), mathRounds);
    await prefs.setInt(Profiles.scoped(_koreanRoundsKey), koreanRounds);

    // 출석 스트릭: 오늘 처음 완료했을 때만 갱신.
    // 어제 출석 → +1 / 하루 걸렀는데 지킴이가 있으면 하나 쓰고 이어감 / 아니면 1부터.
    var milestoneDays = 0;
    var milestoneCoins = 0;
    final lastDay = prefs.getString(Profiles.scoped(_streakDayKey));
    if (lastDay != today) {
      final yesterday = dayKey(time.subtract(const Duration(days: 1)));
      final twoDaysAgo = dayKey(time.subtract(const Duration(days: 2)));
      final freezes = prefs.getInt(Profiles.scoped(_freezeKey)) ?? 0;
      final current = prefs.getInt(Profiles.scoped(_streakKey)) ?? 0;

      int streak;
      if (lastDay == yesterday) {
        streak = current + 1;
      } else if (lastDay == twoDaysAgo && freezes > 0) {
        await prefs.setInt(Profiles.scoped(_freezeKey), freezes - 1);
        streak = current + 1;
      } else {
        streak = 1;
      }
      await prefs.setInt(Profiles.scoped(_streakKey), streak);
      await prefs.setString(Profiles.scoped(_streakDayKey), today);

      // 마일스톤 보너스는 한 번만
      if (milestones.contains(streak)) {
        final claimed =
            prefs.getStringList(Profiles.scoped(_milestonesKey)) ?? const [];
        if (!claimed.contains('$streak')) {
          milestoneDays = streak;
          milestoneCoins = streak * 10;
          await ProgressStore.addPoints(milestoneCoins);
          await prefs.setStringList(
              Profiles.scoped(_milestonesKey), [...claimed, '$streak']);
        }
      }
    }

    // 새로 달성한 미션 보상 지급 (오늘의 미션 3개만 대상)
    final after = DailyState(
      rounds: rounds,
      correct: correct,
      stars: starsTotal,
      perfect: perfect,
      mathRounds: mathRounds,
      koreanRounds: koreanRounds,
      claimed: before.claimed,
      streak: 0,
      freezes: 0,
      missions: before.missions,
    );
    final newlyDone = <DailyMission>[];
    final claimed = {...before.claimed};
    for (final mission in before.missions) {
      if (!claimed.contains(mission.id) &&
          after.progressOf(mission) >= mission.target) {
        claimed.add(mission.id);
        newlyDone.add(mission);
        await ProgressStore.addPoints(mission.reward);
      }
    }
    await prefs.setStringList(Profiles.scoped(_claimedKey), claimed.toList());
    return RoundRewards(
      missions: newlyDone,
      milestoneDays: milestoneDays,
      milestoneCoins: milestoneCoins,
    );
  }
}
