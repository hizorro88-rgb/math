import 'package:flutter/material.dart';

import 'quiz_config.dart';

/// 연령/학년 카테고리. 카테고리마다 첫 단계는 항상 열려 있어서
/// 아이 나이에 맞는 곳에서 바로 시작할 수 있다.
class AgeCategory {
  AgeCategory({
    required this.title,
    required this.emoji,
    required this.desc,
    required this.color,
    required this.units,
  });

  final String title;
  final String emoji;

  /// 무엇을 배우는지 한 줄 설명 (교육과정 근거)
  final String desc;
  final Color color;
  final List<Unit> units;

  late final int index;

  int get firstLevelNumber => units.first.firstLevelNumber;
  int get lastLevelNumber =>
      units.last.firstLevelNumber + Curriculum.levelsPerUnit - 1;
  int get totalLevels => units.length * Curriculum.levelsPerUnit;
}

/// 10단계씩 묶인 학습 묶음(유닛)
class Unit {
  Unit({
    required this.title,
    required this.emoji,
    required this.mode,
    required this.startMax,
    required this.endMax,
  });

  final String title;
  final String emoji;
  final QuizMode mode;

  /// 묶음 안에서 난이도 기준값이 startMax에서 endMax까지 점점 커진다.
  /// (덧뺄셈·수 세기: 최대 수 / 곱셈: 몇 단까지 / 나눗셈: 나누는 수 최대)
  final int startMax;
  final int endMax;

  late final int index;
  late final AgeCategory category;
  late final int firstLevelNumber;

  Color get color => category.color;
}

/// 전체 커리큘럼 중 한 단계
class Level {
  const Level({
    required this.number,
    required this.unit,
    required this.indexInUnit,
  });

  /// 전체 단계 번호 (1부터)
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

/// 나이·학년별 교육과정에 맞춘 커리큘럼.
///
/// 근거 (누리과정 · 2022 개정 초등 수학 교육과정):
/// - 4~5살: 놀이로 수 세기 (5까지 → 10까지)
/// - 6~7살: 20까지 세기, 10 이내 덧셈·뺄셈 (취학 준비)
/// - 초1: 받아올림·받아내림 포함 20까지 덧셈·뺄셈
/// - 초2: 두 자리 덧셈·뺄셈, 곱셈구구(2~9단)
/// - 초3: 세 자리 덧셈·뺄셈, 나눗셈(구구 기반), 큰 수 곱셈
class Curriculum {
  Curriculum._();

  static const levelsPerUnit = 10;

  static final List<AgeCategory> categories = _build();

  static final List<Unit> units = [
    for (final category in categories) ...category.units,
  ];

  /// 1번부터 이어지는 모든 단계
  static final List<Level> levels = [
    for (final unit in units)
      for (var i = 0; i < levelsPerUnit; i++)
        Level(number: unit.firstLevelNumber + i, unit: unit, indexInUnit: i),
  ];

  static int get totalLevels => levels.length;

  /// 단계 번호로 단계를 찾는다.
  static Level levelAt(int number) => levels[number - 1];

  static List<AgeCategory> _build() {
    final categories = [
      AgeCategory(
        title: '4살',
        emoji: '🍼',
        desc: '다섯까지 수 세기',
        color: const Color(0xFF58CC02),
        units: [
          Unit(
              title: '수 세기 첫걸음',
              emoji: '🐣',
              mode: QuizMode.counting,
              startMax: 2,
              endMax: 3),
          Unit(
              title: '다섯까지 세기',
              emoji: '🐤',
              mode: QuizMode.counting,
              startMax: 4,
              endMax: 5),
        ],
      ),
      AgeCategory(
        title: '5살',
        emoji: '🧸',
        desc: '열까지 세기 · 더하기 시작',
        color: const Color(0xFF1CB0F6),
        units: [
          Unit(
              title: '열까지 세기',
              emoji: '🐥',
              mode: QuizMode.counting,
              startMax: 6,
              endMax: 10),
          Unit(
              title: '큰 수 찾기',
              emoji: '⚖️',
              mode: QuizMode.compare,
              startMax: 5,
              endMax: 10),
          Unit(
              title: '덧셈 첫걸음',
              emoji: '🐞',
              mode: QuizMode.addition,
              startMax: 3,
              endMax: 5),
        ],
      ),
      AgeCategory(
        title: '6살',
        emoji: '🎨',
        desc: '5까지 덧셈·뺄셈 · 스무까지 세기',
        color: const Color(0xFFFF9600),
        units: [
          Unit(
              title: '뺄셈 첫걸음',
              emoji: '🐰',
              mode: QuizMode.subtraction,
              startMax: 3,
              endMax: 5),
          Unit(
              title: '섞어서 연습',
              emoji: '🦝',
              mode: QuizMode.mixed,
              startMax: 4,
              endMax: 5),
          Unit(
              title: '듣고 풀기',
              emoji: '👂',
              mode: QuizMode.listen,
              startMax: 3,
              endMax: 5),
          Unit(
              title: '스무까지 세기',
              emoji: '🦉',
              mode: QuizMode.counting,
              startMax: 11,
              endMax: 20),
        ],
      ),
      AgeCategory(
        title: '7살',
        emoji: '🎒',
        desc: '10까지 덧셈·뺄셈 (학교 갈 준비!)',
        color: const Color(0xFFFF4B4B),
        units: [
          Unit(
              title: '덧셈 도전',
              emoji: '🦊',
              mode: QuizMode.addition,
              startMax: 6,
              endMax: 10),
          Unit(
              title: '뺄셈 도전',
              emoji: '🐼',
              mode: QuizMode.subtraction,
              startMax: 6,
              endMax: 10),
          Unit(
              title: '섞어서 도전',
              emoji: '🦁',
              mode: QuizMode.mixed,
              startMax: 7,
              endMax: 10),
          Unit(
              title: '빈칸 채우기',
              emoji: '❓',
              mode: QuizMode.fillBlank,
              startMax: 6,
              endMax: 10),
        ],
      ),
      AgeCategory(
        title: '초등 1학년',
        emoji: '✏️',
        desc: '받아올림·받아내림, 20까지 덧셈·뺄셈',
        color: const Color(0xFFA560E8),
        units: [
          Unit(
              title: '큰 수 덧셈',
              emoji: '🐘',
              mode: QuizMode.addition,
              startMax: 11,
              endMax: 15),
          Unit(
              title: '큰 수 뺄셈',
              emoji: '🦒',
              mode: QuizMode.subtraction,
              startMax: 11,
              endMax: 15),
          Unit(
              title: '10 만들기',
              emoji: '🔟',
              mode: QuizMode.makeTen,
              startMax: 10,
              endMax: 10),
          Unit(
              title: '받아올림 덧셈',
              emoji: '🐳',
              mode: QuizMode.addition,
              startMax: 16,
              endMax: 20),
          Unit(
              title: '받아내림 뺄셈',
              emoji: '🦈',
              mode: QuizMode.subtraction,
              startMax: 16,
              endMax: 20),
          Unit(
              title: '세로 덧셈 첫걸음',
              emoji: '🧮',
              mode: QuizMode.verticalAdd,
              startMax: 20,
              endMax: 40),
          Unit(
              title: '세로 뺄셈 첫걸음',
              emoji: '📝',
              mode: QuizMode.verticalSub,
              startMax: 20,
              endMax: 40),
          Unit(
              title: '덧뺄셈 마스터',
              emoji: '🦄',
              mode: QuizMode.mixed,
              startMax: 16,
              endMax: 20),
        ],
      ),
      AgeCategory(
        title: '초등 2학년',
        emoji: '📗',
        desc: '두 자리 덧셈·뺄셈 · 곱셈구구(2~9단)',
        color: const Color(0xFF2FB8A6),
        units: [
          Unit(
              title: '두 자리 덧셈',
              emoji: '🚂',
              mode: QuizMode.addition,
              startMax: 25,
              endMax: 50),
          Unit(
              title: '받아올림 세로 덧셈',
              emoji: '🚜',
              mode: QuizMode.verticalAdd,
              startMax: 50,
              endMax: 99),
          Unit(
              title: '받아내림 세로 뺄셈',
              emoji: '⛵',
              mode: QuizMode.verticalSub,
              startMax: 50,
              endMax: 99),
          Unit(
              title: '두 자리 뺄셈',
              emoji: '🚁',
              mode: QuizMode.subtraction,
              startMax: 25,
              endMax: 50),
          Unit(
              title: '규칙 찾기',
              emoji: '🧩',
              mode: QuizMode.pattern,
              startMax: 2,
              endMax: 5),
          Unit(
              title: '곱셈 첫걸음 (2~3단)',
              emoji: '🐹',
              mode: QuizMode.multiplication,
              startMax: 2,
              endMax: 3),
          Unit(
              title: '곱셈 쑥쑥 (4~5단)',
              emoji: '🐨',
              mode: QuizMode.multiplication,
              startMax: 4,
              endMax: 5),
          Unit(
              title: '곱셈 점프 (6~7단)',
              emoji: '🐙',
              mode: QuizMode.multiplication,
              startMax: 6,
              endMax: 7),
          Unit(
              title: '곱셈 완성 (8~9단)',
              emoji: '🦅',
              mode: QuizMode.multiplication,
              startMax: 8,
              endMax: 9),
        ],
      ),
      AgeCategory(
        title: '초등 3학년',
        emoji: '📘',
        desc: '나눗셈 · 큰 수 곱셈 · 세 자리 덧셈·뺄셈',
        color: const Color(0xFFE0A100),
        units: [
          Unit(
              title: '나눗셈 첫걸음',
              emoji: '🐬',
              mode: QuizMode.division,
              startMax: 3,
              endMax: 5),
          Unit(
              title: '나눗셈 도전',
              emoji: '🦕',
              mode: QuizMode.division,
              startMax: 6,
              endMax: 9),
          Unit(
              title: '큰 수 곱셈',
              emoji: '🚀',
              mode: QuizMode.multiplication,
              startMax: 11,
              endMax: 15),
          Unit(
              title: '세 자리 덧뺄셈',
              emoji: '🏰',
              mode: QuizMode.mixed,
              startMax: 100,
              endMax: 200),
          Unit(
              title: '수학 왕 되기',
              emoji: '👑',
              mode: QuizMode.mixed,
              startMax: 200,
              endMax: 300),
        ],
      ),
    ];

    // 전체 번호와 소속을 이어 붙인다.
    var unitIndex = 0;
    var levelNumber = 1;
    for (var c = 0; c < categories.length; c++) {
      categories[c].index = c;
      for (final unit in categories[c].units) {
        unit.index = unitIndex++;
        unit.category = categories[c];
        unit.firstLevelNumber = levelNumber;
        levelNumber += levelsPerUnit;
      }
    }
    return categories;
  }
}
