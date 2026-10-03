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

  /// 보스전 문제: 여러 유형을 섞어 12문제. 나이(수학 카테고리 인덱스)에 맞춘다 —
  /// 4살에게 시계·10 만들기를 내면 다 틀리고 포기한다.
  /// [age]: 0=4살, 1=5살, 2=6살, 3 이상=7살~ (모르면 7살 기준)
  static List<Question> buildQuestions({Random? random, int? age}) {
    final generator = QuestionGenerator(random: random);
    List<Question> take(QuizMode mode, int max, int count) => generator
        .generate(QuizConfig(mode: mode, maxNumber: max, questionCount: count));
    final level = age ?? 3;
    final List<Question> questions;
    if (level <= 1) {
      // 4·5살: 5까지 세기·크기 비교·덧셈
      questions = [
        ...take(QuizMode.counting, 5, 4),
        ...take(QuizMode.compare, 5, 4),
        ...take(QuizMode.addition, 5, 4),
      ];
    } else if (level == 2) {
      // 6살: 10까지 덧뺄셈·비교·세기
      questions = [
        ...take(QuizMode.mixed, 10, 5),
        ...take(QuizMode.compare, 10, 3),
        ...take(QuizMode.counting, 10, 4),
      ];
    } else {
      questions = [
        ...take(QuizMode.mixed, 10, 4),
        ...take(QuizMode.compare, 10, 2),
        ...take(QuizMode.fillBlank, 10, 2),
        ...take(QuizMode.makeTen, 10, 2),
        ...take(QuizMode.clock, 12, 2),
      ];
    }
    return questions..shuffle(random ?? Random());
  }
}
