/// 함께 공부하며 키우는 친구(펫).
///
/// 쿼카 박사가 알 세 개를 보여 주고, 아이가 고른 알에서 아기가 태어난다.
/// 공부해서 모은 별과 돌봐 준 횟수가 쌓이면 5단계까지 자란다.
///
/// 설계 원칙 — 방치해도 벌하지 않는다.
/// 배가 고파도 아프거나 죽지 않고 조금 졸려 보일 뿐이며, 성장은 절대 뒤로
/// 가지 않는다. 매일 열지 않으면 손해라는 압박을 아이에게 주지 않는다.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'english_curriculum.dart';
import 'korean_curriculum.dart';
import 'language_packs.dart';
import 'profile.dart';
import 'progress.dart';



/// 펫 한 종류 (5단계 성장 모습을 함께 담는다)
class PetSpecies {
  const PetSpecies({
    required this.id,
    required this.name,
    required this.egg,
    required this.hint,
    required this.color,
    required this.stages,
  });

  /// 저장 키에 쓰는 짧은 id (순서가 아니라 id로 저장해서 종을 더 추가해도 안전)
  final String id;
  final String name;

  /// 고르기 전에 보여 주는 알 그림
  final String egg;

  /// 알을 눌렀을 때 나오는 귀띔
  final String hint;
  final Color color;

  /// 1~5단계 모습. 지금은 임시 이모지이고, 도트 그림이 준비되면 이 자리를
  /// assets/images/pets/<id>_<단계>.png 로 바꾼다.
  final List<String> stages;

  String emojiAt(int stage) => stages[stage.clamp(1, stages.length) - 1];
}

/// 단계 이름 (1~5)
const petStageNames = ['아기', '꼬마', '친구', '어른', '전설'];

/// 고를 수 있는 세 친구
const petSpeciesList = <PetSpecies>[
  PetSpecies(
    id: 'leaf',
    name: '새싹이',
    egg: '🥚',
    hint: '초록빛이 돌아요',
    color: Color(0xFF3DA35D),
    stages: ['🌱', '🌿', '🍀', '🌳', '🌲'],
  ),
  PetSpecies(
    id: 'drop',
    name: '방울이',
    egg: '🥚',
    hint: '시원한 소리가 나요',
    color: Color(0xFF4D96FF),
    stages: ['💧', '🐟', '🐬', '🐋', '🐳'],
  ),
  PetSpecies(
    id: 'ember',
    name: '햇살이',
    egg: '🥚',
    hint: '따끈따끈해요',
    color: Color(0xFFFF8B5C),
    stages: ['🐣', '🐤', '🐥', '🦅', '🦉'],
  ),
];

PetSpecies? petSpeciesById(String? id) {
  if (id == null) return null;
  for (final s in petSpeciesList) {
    if (s.id == id) return s;
  }
  return null;
}

/// 다음 단계로 자라는 데 필요한 조건.
/// 별(공부)과 돌봄을 둘 다 봐야 밥만 먹여서 진화시키는 우회로가 막힌다.
class PetStageRule {
  const PetStageRule({
    required this.stars,
    required this.meals,
    required this.drinks,
  });

  /// 모든 과목에서 모은 별의 합
  final int stars;
  final int meals;
  final int drinks;
}

/// 2~5단계가 되기 위한 조건 (index 0이 2단계 조건)
const petStageRules = <PetStageRule>[
  PetStageRule(stars: 10, meals: 5, drinks: 5),
  PetStageRule(stars: 40, meals: 20, drinks: 20),
  PetStageRule(stars: 100, meals: 50, drinks: 50),
  PetStageRule(stars: 200, meals: 100, drinks: 100),
];

/// 밥과 물 가격 (한 판에 약 150코인 버는 것에 맞춰 부담 없게 잡았다)
const petMealCost = 10;
const petDrinkCost = 5;

/// 하루에 줄 수 있는 횟수. 코인이 많다고 한 번에 몰아 먹여서
/// 진화를 사 버리지 못하게 막는다 — 돌봄은 꾸준함이어야 의미가 있다.
const petDailyCareLimit = 3;

/// 배부름·목마름이 한 칸 줄어드는 데 걸리는 시간.
/// 이틀쯤 지나면 0이 되지만, 0이어도 벌은 없고 졸려 보일 뿐이다.
const petDecayPerMinutes = 30;

/// 펫의 현재 상태 (저장된 값 + 계산된 값)
class PetState {
  const PetState({
    required this.species,
    required this.stage,
    required this.meals,
    required this.drinks,
    required this.stars,
    required this.fullness,
    required this.hydration,
    required this.mealsToday,
    required this.drinksToday,
    required this.coins,
  });

  /// 아직 고르지 않았으면 null
  final PetSpecies? species;

  /// 1~5
  final int stage;

  final int meals;
  final int drinks;
  final int stars;

  /// 0~100
  final int fullness;
  final int hydration;

  final int mealsToday;
  final int drinksToday;
  final int coins;

  bool get chosen => species != null;
  bool get isFinalStage => stage >= petStageNames.length;

  PetStageRule? get nextRule =>
      isFinalStage ? null : petStageRules[stage - 1];

  bool get canFeed =>
      chosen && mealsToday < petDailyCareLimit && coins >= petMealCost;
  bool get canDrink =>
      chosen && drinksToday < petDailyCareLimit && coins >= petDrinkCost;

  /// 배도 고프고 목도 마르면 졸려 보인다 (벌이 아니라 표정일 뿐)
  bool get sleepy => fullness <= 20 && hydration <= 20;

  /// 다음 단계까지 얼마나 왔는지 0.0~1.0 (세 조건의 평균)
  double get progress {
    final rule = nextRule;
    if (rule == null) return 1;
    double ratio(int now, int need) =>
        need == 0 ? 1 : (now / need).clamp(0.0, 1.0);
    return (ratio(stars, rule.stars) +
            ratio(meals, rule.meals) +
            ratio(drinks, rule.drinks)) /
        3;
  }

  /// 지금 값으로 도달할 수 있는 단계 (조건을 넘겼으면 자란다)
  int get earnedStage {
    var s = 1;
    for (final rule in petStageRules) {
      if (stars >= rule.stars && meals >= rule.meals && drinks >= rule.drinks) {
        s++;
      } else {
        break;
      }
    }
    return s;
  }
}

/// 펫 기록 저장소 (프로필별로 따로 저장된다)
class PetStore {
  PetStore._();

  static const _speciesKey = 'pet_species_v1';
  static const _stageKey = 'pet_stage_v1';
  static const _mealsKey = 'pet_meals_v1';
  static const _drinksKey = 'pet_drinks_v1';
  static const _fullnessKey = 'pet_fullness_v1';
  static const _hydrationKey = 'pet_hydration_v1';
  static const _tickKey = 'pet_tick_v1';
  static const _todayKey = 'pet_care_date_v1';
  static const _mealsTodayKey = 'pet_meals_today_v1';
  static const _drinksTodayKey = 'pet_drinks_today_v1';

  static String _today() {
    final now = DateTime.now();
    return '${now.year}-${now.month}-${now.day}';
  }

  /// 모든 과목에서 모은 별의 합 (이미 저장돼 있는 기록을 그대로 쓴다)
  static Future<int> totalStars() async {
    var sum = 0;
    for (final stars in [
      await ProgressStore.load(),
      await KoreanProgressStore.load(),
      await EnglishProgressStore.load(),
      for (final pack in languagePacks) await LangProgressStore.load(pack),
    ]) {
      sum += stars.fold<int>(0, (a, b) => a + b);
    }
    return sum;
  }

  /// 마지막으로 본 뒤 흐른 시간만큼 배부름·목마름을 줄인다 (0 아래로는 안 간다)
  static Future<void> _applyDecay(SharedPreferences prefs) async {
    final last = prefs.getString(Profiles.scoped(_tickKey));
    final now = DateTime.now();
    if (last != null) {
      final then = DateTime.tryParse(last);
      if (then != null) {
        final steps = now.difference(then).inMinutes ~/ petDecayPerMinutes;
        if (steps > 0) {
          for (final key in [_fullnessKey, _hydrationKey]) {
            final v = prefs.getInt(Profiles.scoped(key)) ?? 100;
            await prefs.setInt(
                Profiles.scoped(key), (v - steps).clamp(0, 100));
          }
        } else {
          return; // 아직 한 칸도 안 줄었으면 시각을 그대로 둔다
        }
      }
    }
    await prefs.setString(Profiles.scoped(_tickKey), now.toIso8601String());
  }

  /// 지금 상태를 읽는다. 조건을 넘겼으면 단계도 함께 올려 저장한다.
  static Future<PetState> load() async {
    final prefs = await SharedPreferences.getInstance();
    await _applyDecay(prefs);

    // 날짜가 바뀌었으면 오늘 준 횟수를 초기화한다.
    if (prefs.getString(Profiles.scoped(_todayKey)) != _today()) {
      await prefs.setString(Profiles.scoped(_todayKey), _today());
      await prefs.setInt(Profiles.scoped(_mealsTodayKey), 0);
      await prefs.setInt(Profiles.scoped(_drinksTodayKey), 0);
    }

    final species = petSpeciesById(prefs.getString(Profiles.scoped(_speciesKey)));
    final state = PetState(
      species: species,
      stage: prefs.getInt(Profiles.scoped(_stageKey)) ?? 1,
      meals: prefs.getInt(Profiles.scoped(_mealsKey)) ?? 0,
      drinks: prefs.getInt(Profiles.scoped(_drinksKey)) ?? 0,
      stars: species == null ? 0 : await totalStars(),
      fullness: prefs.getInt(Profiles.scoped(_fullnessKey)) ?? 100,
      hydration: prefs.getInt(Profiles.scoped(_hydrationKey)) ?? 100,
      mealsToday: prefs.getInt(Profiles.scoped(_mealsTodayKey)) ?? 0,
      drinksToday: prefs.getInt(Profiles.scoped(_drinksTodayKey)) ?? 0,
      coins: await ProgressStore.loadCoins(),
    );
    return state;
  }

  /// 아이가 고른 알에서 아기가 태어난다.
  static Future<void> choose(PetSpecies species) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Profiles.scoped(_speciesKey), species.id);
    await prefs.setInt(Profiles.scoped(_stageKey), 1);
    await prefs.setInt(Profiles.scoped(_mealsKey), 0);
    await prefs.setInt(Profiles.scoped(_drinksKey), 0);
    await prefs.setInt(Profiles.scoped(_fullnessKey), 100);
    await prefs.setInt(Profiles.scoped(_hydrationKey), 100);
    await prefs.setString(
        Profiles.scoped(_tickKey), DateTime.now().toIso8601String());
  }

  /// 밥이나 물을 준다. 코인이 모자라거나 오늘 다 줬으면 false.
  static Future<bool> care({required bool meal}) async {
    final state = await load();
    if (meal ? !state.canFeed : !state.canDrink) return false;
    if (!await ProgressStore.spendCoins(meal ? petMealCost : petDrinkCost)) {
      return false;
    }
    final prefs = await SharedPreferences.getInstance();
    final countKey = meal ? _mealsKey : _drinksKey;
    final todayKey = meal ? _mealsTodayKey : _drinksTodayKey;
    final gaugeKey = meal ? _fullnessKey : _hydrationKey;
    await prefs.setInt(Profiles.scoped(countKey),
        (prefs.getInt(Profiles.scoped(countKey)) ?? 0) + 1);
    await prefs.setInt(Profiles.scoped(todayKey),
        (prefs.getInt(Profiles.scoped(todayKey)) ?? 0) + 1);
    await prefs.setInt(Profiles.scoped(gaugeKey), 100);
    return true;
  }

  /// 조건을 넘겼으면 단계를 올리고 새 단계를 돌려준다.
  /// 이미 최신이면 null (진화 연출을 띄울지 판단하는 데 쓴다).
  static Future<int?> evolveIfReady() async {
    final state = await load();
    if (!state.chosen) return null;
    final earned = state.earnedStage;
    if (earned <= state.stage) return null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(Profiles.scoped(_stageKey), earned);
    return earned;
  }

  /// 프로필을 지울 때 함께 지운다.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [
      _speciesKey,
      _stageKey,
      _mealsKey,
      _drinksKey,
      _fullnessKey,
      _hydrationKey,
      _tickKey,
      _todayKey,
      _mealsTodayKey,
      _drinksTodayKey,
    ]) {
      await prefs.remove(Profiles.scoped(key));
    }
  }
}
