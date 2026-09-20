import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/pet.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  group('펫 종류', () {
    test('세 친구가 모두 5단계 모습을 갖고 있다', () {
      expect(petSpeciesList, hasLength(3));
      expect(petStageNames, hasLength(5));
      for (final s in petSpeciesList) {
        expect(s.stages, hasLength(5), reason: s.id);
        expect(s.name, isNotEmpty);
        expect(s.hint, isNotEmpty);
      }
    });

    test('id가 겹치지 않고 id로 찾을 수 있다', () {
      final ids = petSpeciesList.map((s) => s.id).toSet();
      expect(ids, hasLength(petSpeciesList.length));
      expect(petSpeciesById('leaf')?.name, '새싹이');
      expect(petSpeciesById(null), isNull);
      expect(petSpeciesById('없는id'), isNull);
    });

    test('단계 번호를 벗어나도 안전하게 모습을 돌려준다', () {
      final s = petSpeciesList.first;
      expect(s.emojiAt(1), s.stages.first);
      expect(s.emojiAt(5), s.stages.last);
      expect(s.emojiAt(0), s.stages.first);
      expect(s.emojiAt(99), s.stages.last);
    });
  });

  group('진화 조건', () {
    PetState state({
      int stage = 1,
      int stars = 0,
      int meals = 0,
      int drinks = 0,
      int coins = 1000,
      int fullness = 100,
      int hydration = 100,
      int mealsToday = 0,
      int drinksToday = 0,
    }) =>
        PetState(
          species: petSpeciesList.first,
          stage: stage,
          meals: meals,
          drinks: drinks,
          stars: stars,
          fullness: fullness,
          hydration: hydration,
          mealsToday: mealsToday,
          drinksToday: drinksToday,
          coins: coins,
        );

    test('조건이 오르는 순서대로 정렬되어 있다', () {
      for (var i = 1; i < petStageRules.length; i++) {
        expect(petStageRules[i].stars,
            greaterThan(petStageRules[i - 1].stars));
        expect(petStageRules[i].meals,
            greaterThan(petStageRules[i - 1].meals));
      }
    });

    test('별만 많고 돌봄이 없으면 자라지 않는다', () {
      expect(state(stars: 9999).earnedStage, 1);
    });

    test('돌봄만 많고 별이 없으면 자라지 않는다 — 밥으로 진화를 살 수 없다', () {
      expect(state(meals: 9999, drinks: 9999).earnedStage, 1);
    });

    test('둘 다 채우면 그 단계까지 자란다', () {
      expect(state(stars: 10, meals: 5, drinks: 5).earnedStage, 2);
      expect(state(stars: 40, meals: 20, drinks: 20).earnedStage, 3);
      expect(state(stars: 100, meals: 50, drinks: 50).earnedStage, 4);
      expect(state(stars: 200, meals: 100, drinks: 100).earnedStage, 5);
    });

    test('한 조건이라도 모자라면 그 앞 단계에서 멈춘다', () {
      expect(state(stars: 200, meals: 100, drinks: 49).earnedStage, 3);
    });

    test('마지막 단계에서는 더 요구하지 않는다', () {
      final s = state(stage: 5, stars: 999, meals: 999, drinks: 999);
      expect(s.isFinalStage, isTrue);
      expect(s.nextRule, isNull);
      expect(s.progress, 1);
    });

    test('진행률은 세 조건을 고르게 반영한다', () {
      expect(state(stars: 0, meals: 0, drinks: 0).progress, 0);
      expect(state(stars: 10, meals: 5, drinks: 5).progress, 1);
      // 하나만 다 채우면 3분의 1
      expect(state(stars: 10).progress, closeTo(1 / 3, 0.001));
    });

    test('조건을 넘겨도 진행률이 1을 넘지 않는다', () {
      expect(state(stars: 9999, meals: 9999, drinks: 9999).progress, 1);
    });
  });

  group('돌봄 상태', () {
    PetState care({
      int coins = 1000,
      int mealsToday = 0,
      int drinksToday = 0,
      int fullness = 100,
      int hydration = 100,
    }) =>
        PetState(
          species: petSpeciesList.first,
          stage: 1,
          meals: 0,
          drinks: 0,
          stars: 0,
          fullness: fullness,
          hydration: hydration,
          mealsToday: mealsToday,
          drinksToday: drinksToday,
          coins: coins,
        );

    test('코인이 모자라면 줄 수 없다', () {
      expect(care(coins: 0).canFeed, isFalse);
      expect(care(coins: petMealCost).canFeed, isTrue);
    });

    test('하루 한도를 넘기면 줄 수 없다', () {
      expect(care(mealsToday: petDailyCareLimit).canFeed, isFalse);
      expect(care(mealsToday: petDailyCareLimit - 1).canFeed, isTrue);
    });

    test('배도 고프고 목도 마를 때만 졸려 보인다', () {
      expect(care(fullness: 10, hydration: 10).sleepy, isTrue);
      expect(care(fullness: 10, hydration: 100).sleepy, isFalse);
      expect(care(fullness: 100, hydration: 100).sleepy, isFalse);
    });
  });

  group('저장소', () {
    test('처음에는 아무도 고르지 않은 상태다', () async {
      final s = await PetStore.load();
      expect(s.chosen, isFalse);
      expect(s.species, isNull);
      expect(s.stage, 1);
    });

    test('고르면 아기 단계로 시작하고 배가 부르다', () async {
      await PetStore.choose(petSpeciesList[1]);
      final s = await PetStore.load();
      expect(s.chosen, isTrue);
      expect(s.species?.id, 'drop');
      expect(s.stage, 1);
      expect(s.fullness, 100);
      expect(s.hydration, 100);
      expect(s.meals, 0);
    });

    test('밥을 주면 코인이 줄고 횟수가 쌓인다', () async {
      await PetStore.choose(petSpeciesList.first);
      await ProgressStore.addPoints(100);
      final before = await ProgressStore.loadCoins();

      expect(await PetStore.care(meal: true), isTrue);
      final s = await PetStore.load();
      expect(s.meals, 1);
      expect(s.mealsToday, 1);
      expect(s.coins, before - petMealCost);
      expect(s.fullness, 100);
    });

    test('코인이 없으면 밥을 줄 수 없고 횟수도 안 늘어난다', () async {
      await PetStore.choose(petSpeciesList.first);
      expect(await PetStore.care(meal: true), isFalse);
      final s = await PetStore.load();
      expect(s.meals, 0);
    });

    test('하루 한도를 넘기면 코인이 있어도 못 준다', () async {
      await PetStore.choose(petSpeciesList.first);
      await ProgressStore.addPoints(1000);
      for (var i = 0; i < petDailyCareLimit; i++) {
        expect(await PetStore.care(meal: false), isTrue, reason: '$i번째');
      }
      expect(await PetStore.care(meal: false), isFalse);
      final s = await PetStore.load();
      expect(s.drinks, petDailyCareLimit);
      // 밥은 따로 세므로 아직 줄 수 있다.
      expect(s.canFeed, isTrue);
    });

    test('조건을 채우면 단계가 오르고, 한 번 오르면 다시 안 오른다', () async {
      await PetStore.choose(petSpeciesList.first);
      SharedPreferences.setMockInitialValues({
        'pet_species_v1': 'leaf',
        'pet_stage_v1': 1,
        'pet_meals_v1': 5,
        'pet_drinks_v1': 5,
        'level_stars_v5': ['3', '3', '3', '3'], // 별 12개
      });
      Profiles.activeId = 1;

      expect(await PetStore.evolveIfReady(), 2);
      expect(await PetStore.evolveIfReady(), isNull);
      expect((await PetStore.load()).stage, 2);
    });

    test('성장은 뒤로 가지 않는다 (배가 고파도 단계 유지)', () async {
      SharedPreferences.setMockInitialValues({
        'pet_species_v1': 'leaf',
        'pet_stage_v1': 3,
        'pet_fullness_v1': 0,
        'pet_hydration_v1': 0,
      });
      Profiles.activeId = 1;
      final s = await PetStore.load();
      expect(s.stage, 3);
      expect(s.sleepy, isTrue);
      expect(await PetStore.evolveIfReady(), isNull);
      expect((await PetStore.load()).stage, 3);
    });

    test('프로필마다 따로 키운다', () async {
      await PetStore.choose(petSpeciesList[0]);
      Profiles.activeId = 2;
      expect((await PetStore.load()).chosen, isFalse);
      await PetStore.choose(petSpeciesList[2]);
      expect((await PetStore.load()).species?.id, 'ember');
      Profiles.activeId = 1;
      expect((await PetStore.load()).species?.id, 'leaf');
    });

    test('지우면 다시 고르기 전 상태로 돌아간다', () async {
      await PetStore.choose(petSpeciesList.first);
      await PetStore.clear();
      expect((await PetStore.load()).chosen, isFalse);
    });
  });
}
