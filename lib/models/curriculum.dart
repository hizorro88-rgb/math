import 'package:flutter/material.dart';

import 'quiz_config.dart';

/// 10단계씩 묶인 학습 묶음(유닛). 총 10개 = 100단계.
class Unit {
  const Unit({
    required this.index,
    required this.title,
    required this.emoji,
    required this.mode,
    required this.startMax,
    required this.endMax,
    required this.color,
  });

  /// 0부터 시작하는 묶음 번호
  final int index;
  final String title;
  final String emoji;
  final QuizMode mode;

  /// 묶음 안에서 답의 최대값이 startMax에서 endMax까지 점점 커진다.
  final int startMax;
  final int endMax;
  final Color color;

  /// 이 묶음의 첫 단계 번호 (1부터 시작)
  int get firstLevelNumber => index * Curriculum.levelsPerUnit + 1;
}

/// 100단계 중 한 단계
class Level {
  const Level(
      {required this.number, required this.unit, required this.indexInUnit});

  /// 전체 단계 번호 (1~100)
  final int number;
  final Unit unit;

  /// 묶음 안에서의 위치 (0~9)
  final int indexInUnit;

  /// 묶음 안에서 뒤로 갈수록 수가 커진다.
  int get maxNumber =>
      unit.startMax +
      ((unit.endMax - unit.startMax) *
              indexInUnit /
              (Curriculum.levelsPerUnit - 1))
          .round();

  QuizConfig get config => QuizConfig(mode: unit.mode, maxNumber: maxNumber);
}

/// 덧셈·뺄셈에 차근차근 익숙해지는 100단계 커리큘럼
class Curriculum {
  Curriculum._();

  static const levelsPerUnit = 10;

  static const List<Unit> units = [
    Unit(
        index: 0,
        title: '덧셈 첫걸음',
        emoji: '🐣',
        mode: QuizMode.addition,
        startMax: 3,
        endMax: 5,
        color: Color(0xFF58CC02)),
    Unit(
        index: 1,
        title: '뺄셈 첫걸음',
        emoji: '🐤',
        mode: QuizMode.subtraction,
        startMax: 3,
        endMax: 5,
        color: Color(0xFF1CB0F6)),
    Unit(
        index: 2,
        title: '섞어서 연습',
        emoji: '🐥',
        mode: QuizMode.mixed,
        startMax: 4,
        endMax: 5,
        color: Color(0xFFFF9600)),
    Unit(
        index: 3,
        title: '덧셈 도전',
        emoji: '🦊',
        mode: QuizMode.addition,
        startMax: 6,
        endMax: 10,
        color: Color(0xFFFF4B4B)),
    Unit(
        index: 4,
        title: '뺄셈 도전',
        emoji: '🐼',
        mode: QuizMode.subtraction,
        startMax: 6,
        endMax: 10,
        color: Color(0xFFA560E8)),
    Unit(
        index: 5,
        title: '섞어서 도전',
        emoji: '🦁',
        mode: QuizMode.mixed,
        startMax: 7,
        endMax: 10,
        color: Color(0xFF2FB8A6)),
    Unit(
        index: 6,
        title: '큰 수 덧셈',
        emoji: '🐘',
        mode: QuizMode.addition,
        startMax: 11,
        endMax: 15,
        color: Color(0xFFF2557B)),
    Unit(
        index: 7,
        title: '큰 수 뺄셈',
        emoji: '🦒',
        mode: QuizMode.subtraction,
        startMax: 11,
        endMax: 15,
        color: Color(0xFF7A6FF0)),
    Unit(
        index: 8,
        title: '큰 수 섞어서',
        emoji: '🦄',
        mode: QuizMode.mixed,
        startMax: 12,
        endMax: 15,
        color: Color(0xFF00A8C6)),
    Unit(
        index: 9,
        title: '수학 왕 되기',
        emoji: '👑',
        mode: QuizMode.mixed,
        startMax: 16,
        endMax: 20,
        color: Color(0xFFE0A100)),
  ];

  /// 1번부터 100번까지의 모든 단계
  static final List<Level> levels = [
    for (final unit in units)
      for (var i = 0; i < levelsPerUnit; i++)
        Level(number: unit.firstLevelNumber + i, unit: unit, indexInUnit: i),
  ];

  static int get totalLevels => levels.length;

  /// 단계 번호(1~100)로 단계를 찾는다.
  static Level levelAt(int number) => levels[number - 1];
}
