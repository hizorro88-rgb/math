import 'package:flutter/material.dart';

import 'english_question.dart';
import 'premium.dart';
import 'unit_stars.dart';
import '../theme.dart';

/// 영어 과목의 카테고리. 첫 단계는 항상 열려 있다.
class EnCategory {
  EnCategory({
    required this.title,
    required this.emoji,
    required this.desc,
    required this.color,
    required this.units,
  });

  final String title;
  final String emoji;
  final String desc;
  final Color color;
  final List<EnUnit> units;

  late final int index;

  int get firstLevelNumber => units.first.firstLevelNumber;
  int get totalLevels => units.length * EnglishCurriculum.levelsPerUnit;
}

/// 10단계씩 묶인 영어 학습 묶음
class EnUnit {
  EnUnit({
    required this.title,
    required this.emoji,
    required this.type,
  });

  final String title;
  final String emoji;
  final EnQuizType type;

  late final int index;
  late final EnCategory category;
  late final int firstLevelNumber;

  Color get color => category.color;
}

/// 영어 커리큘럼의 한 단계
class EnLevel {
  const EnLevel({
    required this.number,
    required this.unit,
    required this.indexInUnit,
  });

  final int number;
  final EnUnit unit;
  final int indexInUnit;

  int get stage => indexInUnit;
}

/// 미취학 아동용 영어 커리큘럼.
/// 소리(듣기)로 시작해서 알파벳 → 파닉스(글자의 소리) → 낱말 → 스펠링 순서로 나아간다.
class EnglishCurriculum {
  EnglishCurriculum._();

  static const levelsPerUnit = 10;

  static final List<EnCategory> categories = _build();

  static final List<EnUnit> units = [
    for (final category in categories) ...category.units,
  ];

  static final List<EnLevel> levels = [
    for (final unit in units)
      for (var i = 0; i < levelsPerUnit; i++)
        EnLevel(number: unit.firstLevelNumber + i, unit: unit, indexInUnit: i),
  ];

  static int get totalLevels => levels.length;

  /// 문제 유형을 배우는 순서대로 (연습·리포트 목록용 — enum 순서는 저장용이라 뒤죽박죽)
  static List<EnQuizType> get typesInOrder => {
        for (final u in units) u.type,
        ...EnQuizType.values,
      }.toList();

  static EnLevel levelAt(int number) => levels[number - 1];

  static List<EnCategory> _build() {
    final categories = [
      EnCategory(
        title: '알파벳 첫걸음',
        emoji: '🅰️',
        desc: '소리로 알파벳과 친해져요',
        color: UnitColors.pink,
        units: [
          EnUnit(
              title: '알파벳 소리 찾기', emoji: '👂', type: EnQuizType.listenLetter),
          EnUnit(title: 'ABC 순서', emoji: '🐾', type: EnQuizType.alphabetOrder),
          EnUnit(title: '대문자 소문자 짝', emoji: '🅰️', type: EnQuizType.caseMatch),
        ],
      ),
      EnCategory(
        title: '파닉스',
        emoji: '🔠',
        desc: '글자가 내는 소리로 낱말을 읽어요',
        color: UnitColors.purple,
        units: [
          EnUnit(
              title: '글자 소리로 시작해요', emoji: '🔠', type: EnQuizType.letterSound),
          EnUnit(title: '가운데 소리 찾기', emoji: '🎈', type: EnQuizType.shortVowel),
          EnUnit(title: '읽고 그림 찾기', emoji: '📖', type: EnQuizType.decode),
          EnUnit(title: '끝소리 짝 찾기', emoji: '🎵', type: EnQuizType.rhyme),
          EnUnit(title: '두 글자 소리', emoji: '👯', type: EnQuizType.cluster),
        ],
      ),
      EnCategory(
        title: '영어 낱말',
        emoji: '🍎',
        desc: '듣고 보며 영어 낱말을 익혀요',
        color: UnitColors.orange,
        units: [
          EnUnit(
              title: '낱말 듣고 그림 찾기',
              emoji: '🔍',
              type: EnQuizType.wordToPicture),
          EnUnit(
              title: '그림 보고 낱말 찾기',
              emoji: '🖼️',
              type: EnQuizType.pictureToWord),
          EnUnit(title: '첫 글자 찾기', emoji: '🎯', type: EnQuizType.firstLetter),
        ],
      ),
      EnCategory(
        title: '스펠링 도전',
        emoji: '✏️',
        desc: '글자를 이어서 낱말을 완성해요',
        color: UnitColors.teal,
        units: [
          EnUnit(title: '낱말 만들기', emoji: '🏗️', type: EnQuizType.wordBuild),
          EnUnit(title: '긴 낱말 도전', emoji: '🚀', type: EnQuizType.longWord),
        ],
      ),
    ];

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

/// 영어 과목의 단계별 별을 저장한다. (점수·코인은 다른 과목과 공유)
class EnglishProgressStore {
  EnglishProgressStore._();

  // 별은 묶음 제목 기준으로 저장한다 (UnitStarStore). 옛 순서 기록은
  // 처음 열 때 한 번 옮겨 담는다.
  static final _stars = UnitStarStore(
    key: 'en_unit_stars_v1',
    titles: () => [for (final u in EnglishCurriculum.units) u.title],
    perUnit: EnglishCurriculum.levelsPerUnit,
    legacy: const [LegacyStarLayout('en_level_stars_v1', _v1UnitTitles)],
  );

  /// v1 시절(8묶음) 순서 — 파닉스·단어 퀴즈가 들어가기 전
  static const _v1UnitTitles = [
    '알파벳 소리 찾기', 'ABC 순서', '대문자 소문자 짝', //
    '낱말 듣고 그림 찾기', '그림 보고 낱말 찾기', '첫 글자 찾기', //
    '낱말 만들기', '긴 낱말 도전',
  ];

  static Future<List<int>> load() => _stars.load();

  /// 더 좋은 기록일 때만 별을 저장한다.
  static Future<void> saveStars(int levelNumber, int stars) =>
      _stars.save(levelNumber, stars);

  /// 별 1개 이상이면 통과. 카테고리 첫 단계는 항상 열려 있다.
  static bool isUnlocked(List<int> stars, int levelNumber) {
    if (PremiumStore.allUnlocked) return true;
    final level = EnglishCurriculum.levelAt(levelNumber);
    if (levelNumber == level.unit.category.firstLevelNumber) return true;
    return stars[levelNumber - 2] >= 1;
  }
}
