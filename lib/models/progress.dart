import 'package:shared_preferences/shared_preferences.dart';

import 'curriculum.dart';

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

  static const _starsKey = 'level_stars_v1';
  static const _pointsKey = 'total_points_v1';
  static const _coinsKey = 'coins_v1';

  /// 100개 단계의 별 개수 목록 (인덱스 0 = 1단계)
  static Future<List<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_starsKey) ?? const [];
    return List.generate(
      Curriculum.totalLevels,
      (i) => i < saved.length ? int.tryParse(saved[i]) ?? 0 : 0,
    );
  }

  /// 더 좋은 기록일 때만 별을 저장한다.
  static Future<void> saveStars(int levelNumber, int stars) async {
    final current = await load();
    final index = levelNumber - 1;
    if (stars <= current[index]) return;
    current[index] = stars;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_starsKey, current.map((s) => '$s').toList());
  }

  /// 지금까지 모은 누적 점수
  static Future<int> loadPoints() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_pointsKey) ?? 0;
  }

  /// 점수를 더해서 저장하고, 더한 뒤의 누적 점수를 돌려준다.
  /// 같은 만큼 상점에서 쓸 수 있는 코인도 함께 쌓인다.
  /// (칭호는 누적 점수 기준이라 코인을 써도 내려가지 않는다)
  static Future<int> addPoints(int earned) async {
    final prefs = await SharedPreferences.getInstance();
    final total = (prefs.getInt(_pointsKey) ?? 0) + earned;
    await prefs.setInt(_pointsKey, total);
    await prefs.setInt(_coinsKey, (prefs.getInt(_coinsKey) ?? 0) + earned);
    return total;
  }

  /// 상점에서 쓸 수 있는 코인 잔액.
  /// 예전 버전에서 넘어온 경우 그동안 모은 점수만큼 코인을 채워 준다.
  static Future<int> loadCoins() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(_coinsKey)) {
      final migrated = prefs.getInt(_pointsKey) ?? 0;
      await prefs.setInt(_coinsKey, migrated);
      return migrated;
    }
    return prefs.getInt(_coinsKey) ?? 0;
  }

  /// 코인이 충분하면 차감하고 true를 돌려준다.
  static Future<bool> spendCoins(int cost) async {
    final prefs = await SharedPreferences.getInstance();
    final coins = prefs.getInt(_coinsKey) ?? 0;
    if (coins < cost) return false;
    await prefs.setInt(_coinsKey, coins - cost);
    return true;
  }

  /// 별 1개 이상이면 통과. 1단계이거나 앞 단계를 통과했으면 도전할 수 있다.
  static bool isUnlocked(List<int> stars, int levelNumber) =>
      levelNumber == 1 || stars[levelNumber - 2] >= 1;
}
