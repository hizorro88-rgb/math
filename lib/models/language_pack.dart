import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

/// 언어 과목(일본어·중국어…) 한 문제.
/// 발음은 [speech]를 팩의 TTS 언어로 읽는다.
class LangQuestion {
  const LangQuestion({
    required this.typeIndex,
    required this.instruction,
    required this.display,
    required this.choices,
    required this.answer,
    required this.answerText,
    required this.speech,
    this.subDisplay = '',
    this.emojiChoices = false,
    this.tiles = const [],
    required this.dedupKey,
  });

  /// LanguagePack.types 안에서의 유형 번호 (통계 저장에 쓰여서 순서 고정)
  final int typeIndex;

  final String instruction;
  final String display;
  final String subDisplay;
  final List<String> choices;
  final String answer;
  final String answerText;
  final String speech;
  final bool emojiChoices;

  /// 낱말 만들기용 글자 타일. 비어 있지 않으면 타일 조립 UI로 푼다.
  final List<String> tiles;

  final String dedupKey;
}

/// 언어 팩의 문제 유형 (통계 인덱스가 순서 기반이라 끝에만 추가할 것)
class LangUnitType {
  const LangUnitType(
    this.label,
    this.shortLabel,
    this.emoji, {
    this.listening = false,
    this.textDisplay = false,
  });

  final String label;
  final String shortLabel;
  final String emoji;

  /// 소리를 들어야만 풀 수 있는 유형 (듣기 가드 대상)
  final bool listening;

  /// 카드 가운데 표시가 글자(낱말·배열)라 작게 그린다.
  final bool textDisplay;
}

/// 10단계씩 묶인 학습 묶음
class LangUnit {
  LangUnit({required this.title, required this.emoji, required this.typeIndex});

  final String title;
  final String emoji;
  final int typeIndex;

  late final int index;
  late final LangCategory category;
  late final int firstLevelNumber;

  Color get color => category.color;
}

class LangCategory {
  LangCategory({
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
  final List<LangUnit> units;

  late final int index;

  int get firstLevelNumber => units.first.firstLevelNumber;
  int get totalLevels => units.length * LanguagePack.levelsPerUnit;
}

class LangLevel {
  const LangLevel({
    required this.number,
    required this.unit,
    required this.indexInUnit,
  });

  final int number;
  final LangUnit unit;
  final int indexInUnit;

  int get stage => indexInUnit;
}

/// 언어 과목 하나(일본어·중국어…)를 통째로 담는 팩.
/// 화면·저장소·통계는 팩만 갈아끼우면 그대로 동작한다.
class LanguagePack {
  LanguagePack({
    required this.id,
    required this.name,
    required this.emoji,
    required this.ttsLang,
    required this.types,
    required this.categories,
    required this.generateOne,
  }) {
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
    units = [for (final c in categories) ...c.units];
    levels = [
      for (final unit in units)
        for (var i = 0; i < levelsPerUnit; i++)
          LangLevel(
              number: unit.firstLevelNumber + i, unit: unit, indexInUnit: i),
    ];
  }

  static const levelsPerUnit = 10;

  /// 저장 키에 쓰는 짧은 id (예: 'ja', 'zh')
  final String id;

  /// 과목 이름 (예: '일본어')
  final String name;
  final String emoji;

  /// 발음에 쓰는 TTS 언어 (예: 'ja-JP')
  final String ttsLang;

  final List<LangUnitType> types;
  final List<LangCategory> categories;

  /// 유형·단계에 맞는 문제 하나를 만든다.
  final LangQuestion Function(int typeIndex, int stage, Random random)
      generateOne;

  late final List<LangUnit> units;
  late final List<LangLevel> levels;

  int get totalLevels => levels.length;

  LangLevel levelAt(int number) => levels[number - 1];

  /// 같은 문제가 연달아 나오지 않게 [count]개를 만든다.
  List<LangQuestion> generate(int typeIndex,
      {int stage = 0, int count = 10, Random? random}) {
    final rng = random ?? Random();
    final questions = <LangQuestion>[];
    String? previousKey;
    for (var i = 0; i < count; i++) {
      LangQuestion question;
      do {
        question = generateOne(typeIndex, stage, rng);
      } while (question.dedupKey == previousKey);
      previousKey = question.dedupKey;
      questions.add(question);
    }
    return questions;
  }
}

/// 언어 팩의 단계별 별 저장소 (팩마다 키가 분리된다)
class LangProgressStore {
  LangProgressStore._();

  static String _key(LanguagePack pack) => 'lang_${pack.id}_stars_v1';

  static Future<List<int>> load(LanguagePack pack) async {
    final prefs = await SharedPreferences.getInstance();
    final saved =
        prefs.getStringList(Profiles.scoped(_key(pack))) ?? const [];
    return List.generate(
      pack.totalLevels,
      (i) => i < saved.length ? int.tryParse(saved[i]) ?? 0 : 0,
    );
  }

  /// 더 좋은 기록일 때만 별을 저장한다.
  static Future<void> saveStars(
      LanguagePack pack, int levelNumber, int stars) async {
    final current = await load(pack);
    final index = levelNumber - 1;
    if (stars <= current[index]) return;
    current[index] = stars;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        Profiles.scoped(_key(pack)), current.map((s) => '$s').toList());
  }

  /// 별 1개 이상이면 통과. 카테고리 첫 단계는 항상 열려 있다.
  static bool isUnlocked(LanguagePack pack, List<int> stars, int levelNumber) {
    final level = pack.levelAt(levelNumber);
    if (levelNumber == level.unit.category.firstLevelNumber) return true;
    return stars[levelNumber - 2] >= 1;
  }
}

/// 언어 낱말 하나: 낱말과 그림.
/// [group]이 같은 낱말끼리는 그림이 헷갈려서 같은 판 보기에 함께 안 나온다.
class LangWord {
  const LangWord(this.word, this.emoji, [this.group]);

  final String word;
  final String emoji;
  final String? group;
}

/// 낱말 4개를 고른다 (첫 번째가 정답). 같은 그룹 낱말은 오답으로 안 넣는다.
List<LangWord> pickLangWords(List<LangWord> pool, Random random) {
  final target = pool[random.nextInt(pool.length)];
  final others = [
    for (final w in pool)
      if (w.word != target.word &&
          (w.group == null || w.group != target.group))
        w,
  ]..shuffle(random);
  return [target, ...others.take(3)];
}

/// 목록에서 서로 다른 n개를 고른다. 첫 번째가 출제 대상이 된다.
List<T> pickLangItems<T>(List<T> pool, int n, Random random) {
  final copy = [...pool]..shuffle(random);
  return copy.take(n).toList();
}
