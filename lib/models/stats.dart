import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

import 'daily.dart';
import 'english_question.dart';
import 'korean_question.dart';
import 'question.dart';

/// 문제 유형과 수 범위별 정답/오답 횟수, 한글 유형별 기록, 최근 활동.
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
    required this.compareCorrect,
    required this.compareWrong,
    required this.patternCorrect,
    required this.patternWrong,
    required this.clockCorrect,
    required this.clockWrong,
    required this.bandCorrect,
    required this.bandWrong,
    required this.krCorrect,
    required this.krWrong,
    required this.enCorrect,
    required this.enWrong,
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

  /// 큰 수 찾기 / 규칙 찾기 / 시계 보기 정답/오답
  final int compareCorrect;
  final int compareWrong;
  final int patternCorrect;
  final int patternWrong;
  final int clockCorrect;
  final int clockWrong;

  /// 수 범위(0: 5까지, 1: 10까지, 2: 20까지, 3: 큰 수)별 정답/오답
  final List<int> bandCorrect;
  final List<int> bandWrong;

  /// 한글 유형별 정답/오답 (인덱스 = KrQuizType.index)
  final List<int> krCorrect;
  final List<int> krWrong;

  /// 영어 유형별 정답/오답 (인덱스 = EnQuizType.index)
  final List<int> enCorrect;
  final List<int> enWrong;

  /// 최근 7일 동안 하루에 푼 판 수 (오래된 날 → 오늘 순)
  final List<({String day, int rounds})> recentDays;

  int get mathCorrect =>
      addCorrect +
      subCorrect +
      countCorrect +
      mulCorrect +
      divCorrect +
      compareCorrect +
      patternCorrect +
      clockCorrect;
  int get mathWrong =>
      addWrong +
      subWrong +
      countWrong +
      mulWrong +
      divWrong +
      compareWrong +
      patternWrong +
      clockWrong;

  int get krTotalCorrect => krCorrect.fold(0, (a, b) => a + b);
  int get krTotalWrong => krWrong.fold(0, (a, b) => a + b);

  int get enTotalCorrect => enCorrect.fold(0, (a, b) => a + b);
  int get enTotalWrong => enWrong.fold(0, (a, b) => a + b);

  /// 수학 + 한글 + 영어 합계
  int get totalCorrect => mathCorrect + krTotalCorrect + enTotalCorrect;
  int get totalWrong => mathWrong + krTotalWrong + enTotalWrong;
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
  static const _compareCorrectKey = 'stats_compare_correct_v1';
  static const _compareWrongKey = 'stats_compare_wrong_v1';
  static const _patternCorrectKey = 'stats_pattern_correct_v1';
  static const _patternWrongKey = 'stats_pattern_wrong_v1';
  static const _clockCorrectKey = 'stats_clock_correct_v1';
  static const _clockWrongKey = 'stats_clock_wrong_v1';
  static const _bandCorrectKey = 'stats_band_correct_v1'; // 'a,b,c'
  static const _bandWrongKey = 'stats_band_wrong_v1';
  static const _krCorrectKey = 'stats_kr_correct_v1'; // KrQuizType.index별 CSV
  static const _krWrongKey = 'stats_kr_wrong_v1';
  static const _enCorrectKey = 'stats_en_correct_v1'; // EnQuizType.index별 CSV
  static const _enWrongKey = 'stats_en_wrong_v1';
  static const _daysKey = 'stats_days_v1'; // ['2026-07-28:3', ...]

  /// 수학 문제 하나의 첫 시도 결과를 기록한다. (재출제 풀이는 세지 않음)
  static Future<void> recordAnswer(Question question,
      {required bool correct}) async {
    final prefs = await SharedPreferences.getInstance();

    final typeKey = Profiles.scoped(switch (question.op) {
      // 모양 세기는 수 세기 계열로 함께 집계한다.
      QuestionOp.counting ||
      QuestionOp.shape =>
        correct ? _countCorrectKey : _countWrongKey,
      QuestionOp.add => correct ? _addCorrectKey : _addWrongKey,
      QuestionOp.sub => correct ? _subCorrectKey : _subWrongKey,
      QuestionOp.mul => correct ? _mulCorrectKey : _mulWrongKey,
      QuestionOp.div => correct ? _divCorrectKey : _divWrongKey,
      QuestionOp.compare => correct ? _compareCorrectKey : _compareWrongKey,
      QuestionOp.pattern => correct ? _patternCorrectKey : _patternWrongKey,
      QuestionOp.clock => correct ? _clockCorrectKey : _clockWrongKey,
    });
    await prefs.setInt(typeKey, (prefs.getInt(typeKey) ?? 0) + 1);

    final bandKey = Profiles.scoped(correct ? _bandCorrectKey : _bandWrongKey);
    final bands = _parseCsv(prefs.getString(bandKey), statBandNames.length);
    bands[statBandOf(question)]++;
    await prefs.setString(bandKey, bands.join(','));
  }

  /// 한글 문제 하나의 첫 시도 결과를 기록한다.
  static Future<void> recordKoreanAnswer(KrQuizType type,
      {required bool correct}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = Profiles.scoped(correct ? _krCorrectKey : _krWrongKey);
    final counts = _parseCsv(prefs.getString(key), KrQuizType.values.length);
    counts[type.index]++;
    await prefs.setString(key, counts.join(','));
  }

  /// 영어 문제 하나의 첫 시도 결과를 기록한다.
  static Future<void> recordEnglishAnswer(EnQuizType type,
      {required bool correct}) async {
    final prefs = await SharedPreferences.getInstance();
    final key = Profiles.scoped(correct ? _enCorrectKey : _enWrongKey);
    final counts = _parseCsv(prefs.getString(key), EnQuizType.values.length);
    counts[type.index]++;
    await prefs.setString(key, counts.join(','));
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

    int intOf(String key) => prefs.getInt(Profiles.scoped(key)) ?? 0;

    return LearningStats(
      addCorrect: intOf(_addCorrectKey),
      addWrong: intOf(_addWrongKey),
      subCorrect: intOf(_subCorrectKey),
      subWrong: intOf(_subWrongKey),
      countCorrect: intOf(_countCorrectKey),
      countWrong: intOf(_countWrongKey),
      mulCorrect: intOf(_mulCorrectKey),
      mulWrong: intOf(_mulWrongKey),
      divCorrect: intOf(_divCorrectKey),
      divWrong: intOf(_divWrongKey),
      compareCorrect: intOf(_compareCorrectKey),
      compareWrong: intOf(_compareWrongKey),
      patternCorrect: intOf(_patternCorrectKey),
      patternWrong: intOf(_patternWrongKey),
      clockCorrect: intOf(_clockCorrectKey),
      clockWrong: intOf(_clockWrongKey),
      bandCorrect: _parseCsv(
          prefs.getString(Profiles.scoped(_bandCorrectKey)),
          statBandNames.length),
      bandWrong: _parseCsv(prefs.getString(Profiles.scoped(_bandWrongKey)),
          statBandNames.length),
      krCorrect: _parseCsv(prefs.getString(Profiles.scoped(_krCorrectKey)),
          KrQuizType.values.length),
      krWrong: _parseCsv(prefs.getString(Profiles.scoped(_krWrongKey)),
          KrQuizType.values.length),
      enCorrect: _parseCsv(prefs.getString(Profiles.scoped(_enCorrectKey)),
          EnQuizType.values.length),
      enWrong: _parseCsv(prefs.getString(Profiles.scoped(_enWrongKey)),
          EnQuizType.values.length),
      recentDays: [
        for (var i = 6; i >= 0; i--)
          () {
            final day = DailyStore.dayKey(time.subtract(Duration(days: i)));
            return (day: day, rounds: entries[day] ?? 0);
          }(),
      ],
    );
  }

  /// 'a,b,c' 형태의 CSV를 길이 [length]의 목록으로 읽는다 (모자라면 0으로 채움).
  static List<int> _parseCsv(String? raw, int length) {
    final parts = (raw ?? '').split(',');
    return List.generate(
      length,
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
