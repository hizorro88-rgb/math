import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

import 'curriculum.dart';
import 'premium.dart';

/// 맞힌 개수로 별(0~3개)을 계산한다.
int starsForScore(int correctCount, int totalCount) {
  final ratio = correctCount / totalCount;
  if (ratio >= 0.9) return 3;
  if (ratio >= 0.7) return 2;
  if (ratio >= 0.5) return 1;
  return 0;
}

/// 정답 한 개의 점수. 3연속 정답(콤보)부터 보너스가 붙는다.
int pointsForAnswer(int combo) => 10 + (combo >= 3 ? 5 : 0);

/// 틀렸던 문제를 다시 풀어서 맞혔을 때 주는 점수
const int retryPoints = 5;

/// 단계를 마쳤을 때 별 개수에 따라 주는 보너스 점수.
int completionBonus(int stars) => stars * 10;

/// 누적 점수로 얻는 칭호. 점수가 쌓일수록 멋진 동물로 자란다.
class Rank {
  const Rank(this.emoji, this.title, this.minPoints);

  final String emoji;
  final String title;
  final int minPoints;
}

const List<Rank> ranks = [
  Rank('🥚', '알', 0),
  Rank('🐣', '병아리', 100),
  Rank('🐿️', '다람쥐', 300),
  Rank('🐰', '토끼', 600),
  Rank('🦊', '여우', 1000),
  Rank('🐼', '판다', 1500),
  Rank('🦁', '사자', 2100),
  Rank('🐘', '코끼리', 2800),
  Rank('🦄', '유니콘', 3600),
  Rank('👑', '수학 왕', 4500),
];

/// 지금 점수의 칭호
Rank rankForPoints(int points) => ranks.lastWhere((r) => points >= r.minPoints);

/// 다음 칭호. 이미 최고 칭호면 null.
Rank? nextRankFor(int points) {
  final current = rankForPoints(points);
  final index = ranks.indexOf(current);
  return index + 1 < ranks.length ? ranks[index + 1] : null;
}

/// 단계별 별과 누적 점수를 기기에 저장하고 불러온다.
class ProgressStore {
  ProgressStore._();

  // v5: 새 묶음이 커리큘럼 중간에 들어갈 때마다 단계 번호가 바뀌어 키를 올린다.
  // 옛 기록(v2~v4)은 묶음 제목 기준으로 새 번호에 옮겨 담는다.
  static const _starsKey = 'level_stars_v5';
  static const _starsKeyV4 = 'level_stars_v4';
  static const _starsKeyV3 = 'level_stars_v3';
  static const _starsKeyV2 = 'level_stars_v2';

  static const _pointsKey = 'total_points_v1';
  static const _coinsKey = 'coins_v1';

  /// 전체 단계의 별 개수 목록 (인덱스 0 = 1단계)
  static Future<List<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    var saved = prefs.getStringList(Profiles.scoped(_starsKey));
    if (saved == null) {
      // 가장 최근 버전의 옛 기록부터 이사한다.
      final v4 = prefs.getStringList(Profiles.scoped(_starsKeyV4));
      final v3 = prefs.getStringList(Profiles.scoped(_starsKeyV3));
      final v2 = prefs.getStringList(Profiles.scoped(_starsKeyV2));
      saved = v4 != null
          ? _migrateByTitles(v4, _v4UnitTitles)
          : v3 != null
              ? _migrateByTitles(v3, _v3UnitTitles)
              : _migrateByTitles(v2, _v2UnitTitles);
      if (saved != null) {
        await prefs.setStringList(Profiles.scoped(_starsKey), saved);
      }
    }
    final list = saved ?? const <String>[];
    return List.generate(
      Curriculum.totalLevels,
      (i) => i < list.length ? int.tryParse(list[i]) ?? 0 : 0,
    );
  }

  /// v2 시절(30묶음) 순서
  static const _v2UnitTitles = [
    '수 세기 첫걸음', '5까지 세기', // 4살
    '10까지 세기', '덧셈 첫걸음', // 5살
    '뺄셈 첫걸음', '섞어서 연습', '20까지 세기', // 6살
    '덧셈 도전', '뺄셈 도전', '섞어서 도전', // 7살
    '큰 수 덧셈', '큰 수 뺄셈', '받아올림 덧셈', '받아내림 뺄셈',
    '세로 덧셈 첫걸음', '세로 뺄셈 첫걸음', '덧뺄셈 마스터', // 초1
    '두 자리 덧셈', '받아올림 세로 덧셈', '받아내림 세로 뺄셈', '두 자리 뺄셈',
    '곱셈 첫걸음 (2~3단)', '곱셈 쑥쑥 (4~5단)', '곱셈 점프 (6~7단)', '곱셈 완성 (8~9단)', // 초2
    '나눗셈 첫걸음', '나눗셈 도전', '큰 수 곱셈', '세 자리 덧뺄셈', '수학 왕 되기', // 초3
  ];

  /// v3 시절(35묶음) 순서
  static const _v3UnitTitles = [
    '수 세기 첫걸음', '5까지 세기', // 4살
    '10까지 세기', '큰 수 찾기', '덧셈 첫걸음', // 5살
    '뺄셈 첫걸음', '섞어서 연습', '듣고 풀기', '20까지 세기', // 6살
    '덧셈 도전', '뺄셈 도전', '섞어서 도전', '빈칸 채우기', // 7살
    '큰 수 덧셈', '큰 수 뺄셈', '10 만들기', '받아올림 덧셈', '받아내림 뺄셈',
    '세로 덧셈 첫걸음', '세로 뺄셈 첫걸음', '덧뺄셈 마스터', // 초1
    '두 자리 덧셈', '받아올림 세로 덧셈', '받아내림 세로 뺄셈', '두 자리 뺄셈', '규칙 찾기',
    '곱셈 첫걸음 (2~3단)', '곱셈 쑥쑥 (4~5단)', '곱셈 점프 (6~7단)', '곱셈 완성 (8~9단)', // 초2
    '나눗셈 첫걸음', '나눗셈 도전', '큰 수 곱셈', '세 자리 덧뺄셈', '수학 왕 되기', // 초3
  ];

  /// v4 시절(42묶음) 순서 — 7살에 '시계 읽기'가 들어가기 전
  static const _v4UnitTitles = [
    '수 세기 첫걸음', '5까지 세기', '모양 세기', // 4살
    '10까지 세기', '큰 수 찾기', '덧셈 첫걸음', // 5살
    '뺄셈 첫걸음', '섞어서 연습', '듣고 풀기', '20까지 세기', // 6살
    '덧셈 도전', '뺄셈 도전', '섞어서 도전', '빈칸 채우기', // 7살
    '큰 수 덧셈', '큰 수 뺄셈', '10 만들기', '받아올림 덧셈', '받아내림 뺄셈',
    '세로 덧셈 첫걸음', '세로 뺄셈 첫걸음', '시계 보기', '덧뺄셈 마스터', // 초1
    '두 자리 덧셈', '받아올림 세로 덧셈', '받아내림 세로 뺄셈', '두 자리 뺄셈', '규칙 찾기',
    '곱셈 첫걸음 (2~3단)', '곱셈 쑥쑥 (4~5단)', '곱셈 점프 (6~7단)', '곱셈 완성 (8~9단)', // 초2
    '나눗셈 첫걸음', '나눗셈 도전', '큰 수 곱셈', '세 자리 덧뺄셈', '수학 왕 되기', // 초3
    '분수 첫걸음', '분수 도전', '소수 첫걸음', '소수 도전', '시간 계산', // 초3·4 심화
  ];

  /// 옛 별 기록을 묶음 제목으로 맞춰 새 단계 번호에 옮겨 담는다.
  static List<String>? _migrateByTitles(
      List<String>? old, List<String> oldTitles) {
    if (old == null) return null;
    final stars = List.filled(Curriculum.totalLevels, '0');
    for (var u = 0; u < oldTitles.length; u++) {
      final matches = Curriculum.units.where((x) => x.title == oldTitles[u]);
      if (matches.isEmpty) continue;
      final unit = matches.first;
      for (var i = 0; i < Curriculum.levelsPerUnit; i++) {
        final oldIndex = u * Curriculum.levelsPerUnit + i;
        if (oldIndex < old.length) {
          stars[unit.firstLevelNumber - 1 + i] = old[oldIndex];
        }
      }
    }
    return stars;
  }

  /// 더 좋은 기록일 때만 별을 저장한다.
  static Future<void> saveStars(int levelNumber, int stars) async {
    final current = await load();
    final index = levelNumber - 1;
    if (stars <= current[index]) return;
    current[index] = stars;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        Profiles.scoped(_starsKey), current.map((s) => '$s').toList());
  }

  /// 지금까지 모은 누적 점수
  static Future<int> loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(Profiles.scoped(_pointsKey)) ?? 0;
  }

  /// 점수를 더해서 저장하고, 더한 뒤의 누적 점수를 돌려준다.
  /// 같은 만큼 상점에서 쓸 수 있는 코인도 함께 쌓인다.
  /// (칭호는 누적 점수 기준이라 코인을 써도 내려가지 않는다)
  static Future<int> addPoints(int earned) async {
    final prefs = await SharedPreferences.getInstance();
    final total = (prefs.getInt(Profiles.scoped(_pointsKey)) ?? 0) + earned;
    await prefs.setInt(Profiles.scoped(_pointsKey), total);
    await prefs.setInt(Profiles.scoped(_coinsKey),
        (prefs.getInt(Profiles.scoped(_coinsKey)) ?? 0) + earned);
    return total;
  }

  /// 상점에서 쓸 수 있는 코인 잔액.
  /// 예전 버전에서 넘어온 경우 그동안 모은 점수만큼 코인을 채워 준다.
  static Future<int> loadCoins() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(Profiles.scoped(_coinsKey))) {
      final migrated = prefs.getInt(Profiles.scoped(_pointsKey)) ?? 0;
      await prefs.setInt(Profiles.scoped(_coinsKey), migrated);
      return migrated;
    }
    return prefs.getInt(Profiles.scoped(_coinsKey)) ?? 0;
  }

  /// 코인이 충분하면 차감하고 true를 돌려준다.
  static Future<bool> spendCoins(int cost) async {
    final prefs = await SharedPreferences.getInstance();
    final coins = prefs.getInt(Profiles.scoped(_coinsKey)) ?? 0;
    if (coins < cost) return false;
    await prefs.setInt(Profiles.scoped(_coinsKey), coins - cost);
    return true;
  }

  /// 별 1개 이상이면 통과.
  /// 각 연령 카테고리의 첫 단계는 항상 열려 있고(나이에 맞게 바로 시작),
  /// 그 뒤로는 같은 카테고리 안에서 앞 단계를 통과해야 열린다.
  static bool isUnlocked(List<int> stars, int levelNumber) {
    if (PremiumStore.allUnlocked) return true;
    final level = Curriculum.levelAt(levelNumber);
    if (levelNumber == level.unit.category.firstLevelNumber) return true;
    return stars[levelNumber - 2] >= 1;
  }
}
