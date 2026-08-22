import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

import 'question.dart';
import 'quiz_config.dart';

/// 주 1회 열리는 스페셜 판: 여러 유형을 섞은 12문제.
/// 통과하면 보너스 코인을 주고 다음 주까지 잠긴다.
class BossStore {
  BossStore._();

  static const _weekKey = 'boss_week_v1';

  /// 클리어 보너스 코인
  static const reward = 100;

  /// 한 판의 문제 수
  static const questionCount = 12;

  /// 이번 주를 대표하는 키 (그 주 월요일 날짜)
  static String weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return '${monday.year}-${monday.month}-${monday.day}';
  }

  static Future<bool> isClearedThisWeek({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(Profiles.scoped(_weekKey)) ==
        weekKey(now ?? DateTime.now());
  }

  static Future<void> markCleared({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        Profiles.scoped(_weekKey), weekKey(now ?? DateTime.now()));
  }

  /// 보스전 문제: 덧뺄셈·비교·빈칸·10 만들기·시계를 섞어 12문제.
  static List<Question> buildQuestions({Random? random}) {
    final generator = QuestionGenerator(random: random);
    List<Question> take(QuizMode mode, int max, int count) =>
        generator.generate(
            QuizConfig(mode: mode, maxNumber: max, questionCount: count));
    return [
      ...take(QuizMode.mixed, 10, 4),
      ...take(QuizMode.compare, 10, 2),
      ...take(QuizMode.fillBlank, 10, 2),
      ...take(QuizMode.makeTen, 10, 2),
      ...take(QuizMode.clock, 12, 2),
    ]..shuffle(random ?? Random());
  }
}
