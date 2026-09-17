import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'english_question.dart';
import 'premium.dart';
import 'profile.dart';

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
/// 소리(듣기)로 시작해서 알파벳 → 낱말 읽기 → 스펠링 조립 순서로 나아간다.
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

  static EnLevel levelAt(int number) => levels[number - 1];

  static List<EnCategory> _build() {
    final categories = [
      EnCategory(
        title: '알파벳 첫걸음',
        emoji: '🅰️',
        desc: '소리로 알파벳과 친해져요',
        color: const Color(0xFFFF4B4B),
        units: [
          EnUnit(
              title: '알파벳 소리 찾기',
              emoji: '🔊',
              type: EnQuizType.listenLetter),
          EnUnit(title: 'ABC 순서', emoji: '🐾', type: EnQuizType.alphabetOrder),
          EnUnit(
              title: '대문자 소문자 짝', emoji: '🅰️', type: EnQuizType.caseMatch),
        ],
      ),
      EnCategory(
        title: '영어 낱말',
        emoji: '🍎',
        desc: '듣고 보며 영어 낱말을 익혀요',
        color: const Color(0xFF1CB0F6),
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
        color: const Color(0xFF2FB8A6),
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

  static const _starsKey = 'en_level_stars_v1';

  static Future<List<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(Profiles.scoped(_starsKey)) ?? const [];
    return List.generate(
      EnglishCurriculum.totalLevels,
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
    await prefs.setStringList(
        Profiles.scoped(_starsKey), current.map((s) => '$s').toList());
  }

  /// 별 1개 이상이면 통과. 카테고리 첫 단계는 항상 열려 있다.
  static bool isUnlocked(List<int> stars, int levelNumber) {
    if (PremiumStore.allUnlocked) return true;
    final level = EnglishCurriculum.levelAt(levelNumber);
    if (levelNumber == level.unit.category.firstLevelNumber) return true;
    return stars[levelNumber - 2] >= 1;
  }
}
