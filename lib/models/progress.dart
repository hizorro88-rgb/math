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

/// 단계별 별 개수를 기기에 저장하고 불러온다.
class ProgressStore {
  ProgressStore._();

  static const _key = 'level_stars_v1';

  /// 100개 단계의 별 개수 목록 (인덱스 0 = 1단계)
  static Future<List<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_key) ?? const [];
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
    await prefs.setStringList(_key, current.map((s) => '$s').toList());
  }

  /// 별 1개 이상이면 통과. 1단계이거나 앞 단계를 통과했으면 도전할 수 있다.
  static bool isUnlocked(List<int> stars, int levelNumber) =>
      levelNumber == 1 || stars[levelNumber - 2] >= 1;
}
