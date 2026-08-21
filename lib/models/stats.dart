import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

import 'daily.dart';
import 'question.dart';

/// 문제 유형(덧셈/뺄셈)과 수 범위별 정답/오답 횟수, 최근 활동 기록.
/// 부모용 학습 리포트에 쓰인다.
class LearningStats {
  const LearningStats({
    required this.addCorrect,
    required this.addWrong,
    required this.subCorrect,
    required this.subWrong,
    required this.countCorrect,
    required this.countWrong,
    required this.mulCorrect,
    required this.mulWrong,
    required this.divCorrect,
    required this.divWrong,
    required this.bandCorrect,
    required this.bandWrong,
    required this.recentDays,
  });

  final int addCorrect;
  final int addWrong;
  final int subCorrect;
  final int subWrong;

  /// 수 세기 모드 정답/오답
  final int countCorrect;
  final int countWrong;

  /// 곱셈/나눗셈 정답/오답
  final int mulCorrect;
  final int mulWrong;
  final int divCorrect;
  final int divWrong;

  /// 수 범위(0: 5까지, 1: 10까지, 2: 20까지)별 정답/오답
  final List<int> bandCorrect;
  final List<int> bandWrong;

  /// 최근 7일 동안 하루에 푼 판 수 (오래된 날 → 오늘 순)
  final List<({String day, int rounds})> recentDays;

  int get totalCorrect =>
      addCorrect + subCorrect + countCorrect + mulCorrect + divCorrect;
  int get totalWrong => addWrong + subWrong + countWrong + mulWrong + divWrong;
  int get totalAnswered => totalCorrect + totalWrong;

  /// 정답률(%). 푼 문제가 없으면 null.
  static int? accuracy(int correct, int wrong) {
    final total = correct + wrong;
    if (total == 0) return null;
    return (correct * 100 / total).round();
  }
}

/// 수 범위 이름 (리포트 표시용)
const List<String> statBandNames = ['5까지', '10까지', '20까지', '큰 수'];

/// 문제가 속하는 수 범위: 등장하는 가장 큰 수 기준
int statBandOf(Question q) {
  final biggest = [q.left, q.right, q.answer].reduce((a, b) => a > b ? a : b);
  if (biggest <= 5) return 0;
  if (biggest <= 10) return 1;
  if (biggest <= 20) return 2;
  return 3;
}

/// 학습 통계를 기기에 저장하고 불러온다.
class StatsStore {
  StatsStore._();

  static const _addCorrectKey = 'stats_add_correct_v1';
  static const _addWrongKey = 'stats_add_wrong_v1';
  static const _subCorrectKey = 'stats_sub_correct_v1';
  static const _subWrongKey = 'stats_sub_wrong_v1';
  static const _countCorrectKey = 'stats_count_correct_v1';
  static const _countWrongKey = 'stats_count_wrong_v1';
  static const _mulCorrectKey = 'stats_mul_correct_v1';
  static const _mulWrongKey = 'stats_mul_wrong_v1';
  static const _divCorrectKey = 'stats_div_correct_v1';
  static const _divWrongKey = 'stats_div_wrong_v1';
  static const _bandCorrectKey = 'stats_band_correct_v1'; // 'a,b,c'
  static const _bandWrongKey = 'stats_band_wrong_v1';
  static const _daysKey = 'stats_days_v1'; // ['2026-07-28:3', ...]

  /// 문제 하나의 첫 시도 결과를 기록한다. (재출제 풀이는 세지 않음)
  static Future<void> recordAnswer(Question question,
      {required bool correct}) async {
    final prefs = await SharedPreferences.getInstance();

    final String? baseKey = switch (question.op) {
      QuestionOp.counting => correct ? _countCorrectKey : _countWrongKey,
      QuestionOp.add => correct ? _addCorrectKey : _addWrongKey,
      QuestionOp.sub => correct ? _subCorrectKey : _subWrongKey,
      QuestionOp.mul => correct ? _mulCorrectKey : _mulWrongKey,
      QuestionOp.div => correct ? _divCorrectKey : _divWrongKey,
      // 비교·규칙 찾기는 아직 리포트 항목이 없어서 기록하지 않는다.
      QuestionOp.compare || QuestionOp.pattern => null,
    };
    if (baseKey == null) return;
    final typeKey = Profiles.scoped(baseKey);
    await prefs.setInt(typeKey, (prefs.getInt(typeKey) ?? 0) + 1);

    final bandKey = Profiles.scoped(correct ? _bandCorrectKey : _bandWrongKey);
    final bands = _parseBands(prefs.getString(bandKey));
    bands[statBandOf(question)]++;
    await prefs.setString(bandKey, bands.join(','));
  }

  /// 판 완료를 오늘 날짜에 기록한다 (최근 14일만 보관).
  static Future<void> recordRoundDay({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final today = DailyStore.dayKey(now ?? DateTime.now());
    final entries = _parseDays(prefs.getStringList(Profiles.scoped(_daysKey)));
    entries[today] = (entries[today] ?? 0) + 1;

    final keys = entries.keys.toList()..sort();
    final kept = keys.length > 14 ? keys.sublist(keys.length - 14) : keys;
    await prefs.setStringList(
      Profiles.scoped(_daysKey),
      [for (final k in kept) '$k:${entries[k]}'],
    );
  }

  static Future<LearningStats> load({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _parseDays(prefs.getStringList(Profiles.scoped(_daysKey)));
    final time = now ?? DateTime.now();

    return LearningStats(
      addCorrect: prefs.getInt(Profiles.scoped(_addCorrectKey)) ?? 0,
      addWrong: prefs.getInt(Profiles.scoped(_addWrongKey)) ?? 0,
      subCorrect: prefs.getInt(Profiles.scoped(_subCorrectKey)) ?? 0,
      subWrong: prefs.getInt(Profiles.scoped(_subWrongKey)) ?? 0,
      countCorrect: prefs.getInt(Profiles.scoped(_countCorrectKey)) ?? 0,
      countWrong: prefs.getInt(Profiles.scoped(_countWrongKey)) ?? 0,
      mulCorrect: prefs.getInt(Profiles.scoped(_mulCorrectKey)) ?? 0,
      mulWrong: prefs.getInt(Profiles.scoped(_mulWrongKey)) ?? 0,
      divCorrect: prefs.getInt(Profiles.scoped(_divCorrectKey)) ?? 0,
      divWrong: prefs.getInt(Profiles.scoped(_divWrongKey)) ?? 0,
      bandCorrect:
          _parseBands(prefs.getString(Profiles.scoped(_bandCorrectKey))),
      bandWrong: _parseBands(prefs.getString(Profiles.scoped(_bandWrongKey))),
      recentDays: [
        for (var i = 6; i >= 0; i--)
          () {
            final day = DailyStore.dayKey(time.subtract(Duration(days: i)));
            return (day: day, rounds: entries[day] ?? 0);
          }(),
      ],
    );
  }

  static List<int> _parseBands(String? raw) {
    final parts = (raw ?? '').split(',');
    return List.generate(
      statBandNames.length,
      (i) => i < parts.length ? int.tryParse(parts[i]) ?? 0 : 0,
    );
  }

  static Map<String, int> _parseDays(List<String>? raw) {
    final map = <String, int>{};
    for (final entry in raw ?? const <String>[]) {
      final sep = entry.lastIndexOf(':');
      if (sep <= 0) continue;
      map[entry.substring(0, sep)] =
          int.tryParse(entry.substring(sep + 1)) ?? 0;
    }
    return map;
  }
}
