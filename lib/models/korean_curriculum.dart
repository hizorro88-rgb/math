import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'korean_question.dart';
import 'profile.dart';

/// 한글 과목의 카테고리. 수학과 마찬가지로 첫 단계는 항상 열려 있다.
class KrCategory {
  KrCategory({
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
  final List<KrUnit> units;

  late final int index;

  int get firstLevelNumber => units.first.firstLevelNumber;
  int get totalLevels => units.length * KoreanCurriculum.levelsPerUnit;
}

/// 10단계씩 묶인 한글 학습 묶음
class KrUnit {
  KrUnit({
    required this.title,
    required this.emoji,
    required this.type,
  });

  final String title;
  final String emoji;
  final KrQuizType type;

  late final int index;
  late final KrCategory category;
  late final int firstLevelNumber;

  Color get color => category.color;
}

/// 한글 커리큘럼의 한 단계
class KrLevel {
  const KrLevel({
    required this.number,
    required this.unit,
    required this.indexInUnit,
  });

  final int number;
  final KrUnit unit;

  /// 묶음 안에서의 위치 (0~9). 뒤로 갈수록 문제 풀이 재료가 넓어진다.
  final int indexInUnit;

  int get stage => indexInUnit;
}

/// 미취학 아동용 한글 커리큘럼.
/// 통문자(그림-낱말) → 소리·글자 → 낱말 완성 순서로,
/// 글자를 몰라도 소리(TTS)로 풀 수 있는 유형부터 시작한다.
class KoreanCurriculum {
  KoreanCurriculum._();

  static const levelsPerUnit = 10;

  static final List<KrCategory> categories = _build();

  static final List<KrUnit> units = [
    for (final category in categories) ...category.units,
  ];

  static final List<KrLevel> levels = [
    for (final unit in units)
      for (var i = 0; i < levelsPerUnit; i++)
        KrLevel(number: unit.firstLevelNumber + i, unit: unit, indexInUnit: i),
  ];

  static int get totalLevels => levels.length;

  static KrLevel levelAt(int number) => levels[number - 1];

  static List<KrCategory> _build() {
    final categories = [
      KrCategory(
        title: '한글 첫걸음',
        emoji: '🌱',
        desc: '그림과 소리로 낱말과 친해져요',
        color: const Color(0xFF1CB0F6),
        units: [
          KrUnit(
              title: '낱말 보고 그림 찾기',
              emoji: '🔍',
              type: KrQuizType.wordToPicture),
          KrUnit(
              title: '그림 보고 낱말 찾기',
              emoji: '🖼️',
              type: KrQuizType.pictureToWord),
          KrUnit(title: '모음 소리 찾기', emoji: '🎵', type: KrQuizType.listenVowel),
        ],
      ),
      KrCategory(
        title: '소리와 글자',
        emoji: '🔤',
        desc: '소리를 잘 듣고 글자를 찾아요',
        color: const Color(0xFFFF9600),
        units: [
          KrUnit(
              title: '글자 소리 찾기', emoji: '🔊', type: KrQuizType.listenSyllable),
          KrUnit(title: '가나다 순서', emoji: '🐾', type: KrQuizType.syllableOrder),
          KrUnit(
              title: '첫소리 찾기', emoji: '🎯', type: KrQuizType.firstConsonant),
        ],
      ),
      KrCategory(
        title: '낱말 완성',
        emoji: '✏️',
        desc: '글자를 채워서 낱말을 완성해요',
        color: const Color(0xFFA560E8),
        units: [
          KrUnit(title: '빈칸 채우기', emoji: '🧩', type: KrQuizType.fillBlank),
          KrUnit(title: '긴 낱말 도전', emoji: '🚀', type: KrQuizType.longWord),
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

/// 한글 과목의 단계별 별을 저장한다. (점수·코인은 수학과 공유 — ProgressStore)
class KoreanProgressStore {
  KoreanProgressStore._();

  static const _starsKey = 'kr_level_stars_v1';

  static Future<List<int>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(Profiles.scoped(_starsKey)) ?? const [];
    return List.generate(
      KoreanCurriculum.totalLevels,
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

  /// 별 1개 이상이면 통과. 카테고리 첫 단계는 항상 열려 있고,
  /// 그 뒤로는 같은 카테고리 안에서 앞 단계를 통과해야 열린다.
  static bool isUnlocked(List<int> stars, int levelNumber) {
    final level = KoreanCurriculum.levelAt(levelNumber);
    if (levelNumber == level.unit.category.firstLevelNumber) return true;
    return stars[levelNumber - 2] >= 1;
  }
}
