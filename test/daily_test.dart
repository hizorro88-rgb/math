import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/daily.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  final day1 = DateTime(2026, 7, 26, 10);
  final day2 = DateTime(2026, 7, 27, 9);
  final day3 = DateTime(2026, 7, 28, 20);
  final day4 = DateTime(2026, 7, 29, 12);
  final day5 = DateTime(2026, 7, 30, 8);

  group('오늘의 미션 뽑기', () {
    test('매일 3개: 1번은 항상 퀴즈 3판, 같은 날은 항상 같은 구성', () {
      final missions = DailyStore.missionsFor(day1);
      expect(missions, hasLength(3));
      expect(missions.first.id, 'rounds3');
      expect(missions.map((m) => m.id).toSet(), hasLength(3));
      // 같은 날 다시 뽑아도 동일
      expect(
        DailyStore.missionsFor(DateTime(2026, 7, 26, 23)).map((m) => m.id),
        missions.map((m) => m.id),
      );
    });

    test('날짜가 다르면 다른 구성도 나온다 (로테이션)', () {
      final seen = <String>{};
      for (var i = 0; i < 30; i++) {
        final missions =
            DailyStore.missionsFor(day1.add(Duration(days: i)));
        seen.add(missions.map((m) => m.id).join(','));
      }
      expect(seen.length, greaterThan(1));
    });
  });

  group('데일리 미션', () {
    test('퀴즈 3판을 풀면 미션이 완료되고 코인을 받는다', () async {
      await DailyStore.recordRound(correctCount: 5, stars: 1, now: day1);
      await DailyStore.recordRound(correctCount: 5, stars: 1, now: day1);
      final rewards =
          await DailyStore.recordRound(correctCount: 5, stars: 1, now: day1);

      expect(rewards.missions.map((m) => m.id), contains('rounds3'));
      expect(await ProgressStore.loadCoins(), greaterThanOrEqualTo(30));

      final state = await DailyStore.load(now: day1);
      expect(state.rounds, 3);
      expect(state.isDone(state.missions.first), isTrue);
    });

    test('충분히 풀면 오늘의 미션 3개가 모두 달성된다', () async {
      // 수학 5판 + 한글 1판, 매판 10문제 정답·별 3개
      // → 어떤 조합이 뽑혀도 전부 충족된다.
      for (var i = 0; i < 5; i++) {
        await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      }
      await DailyStore.recordRound(
          correctCount: 10, stars: 3, korean: true, now: day1);

      final state = await DailyStore.load(now: day1);
      for (final mission in state.missions) {
        expect(state.isDone(mission), isTrue,
            reason: '${mission.id} 미션이 완료되어야 함');
      }
    });

    test('이미 달성한 미션은 다시 보상을 주지 않는다', () async {
      for (var i = 0; i < 5; i++) {
        await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      }
      await DailyStore.recordRound(
          correctCount: 10, stars: 3, korean: true, now: day1);
      final coinsAfterDone = await ProgressStore.loadCoins();

      final rewards = await DailyStore.recordRound(
          correctCount: 10, stars: 3, korean: true, now: day1);
      expect(rewards.missions, isEmpty);
      expect(await ProgressStore.loadCoins(), coinsAfterDone);
    });

    test('날짜가 바뀌면 미션 진행도가 리셋된다', () async {
      await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      final nextDay = await DailyStore.load(now: day2);
      expect(nextDay.rounds, 0);
      expect(nextDay.correct, 0);
      expect(nextDay.claimed, isEmpty);
    });

    test('수학/한글 판 수가 따로 집계된다', () async {
      await DailyStore.recordRound(correctCount: 5, stars: 1, now: day1);
      await DailyStore.recordRound(
          correctCount: 5, stars: 1, korean: true, now: day1);
      final state = await DailyStore.load(now: day1);
      expect(state.mathRounds, 1);
      expect(state.koreanRounds, 1);
      expect(state.perfect, 0);

      await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      expect((await DailyStore.load(now: day1)).perfect, 1);
    });
  });

  group('출석 스트릭', () {
    test('연속으로 출석하면 스트릭이 올라간다', () async {
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day1);
      expect((await DailyStore.load(now: day1)).streak, 1);

      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day2);
      expect((await DailyStore.load(now: day2)).streak, 2);

      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day3);
      expect((await DailyStore.load(now: day3)).streak, 3);
    });

    test('같은 날 여러 판을 풀어도 스트릭은 하루 1만 오른다', () async {
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day1);
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day1);
      expect((await DailyStore.load(now: day1)).streak, 1);
    });

    test('하루를 건너뛰면 스트릭이 1부터 다시 시작한다', () async {
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day1);
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day2);
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day5);
      expect((await DailyStore.load(now: day5)).streak, 1);
    });

    test('어제 출석했으면 아직 안 푼 오늘도 스트릭이 유지되어 보인다', () async {
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day1);
      expect((await DailyStore.load(now: day2)).streak, 1);
      // 이틀 이상 지나면 0으로 보인다.
      expect((await DailyStore.load(now: day5)).streak, 0);
    });

    test('3일 연속이면 마일스톤 보너스를 한 번만 준다', () async {
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day1);
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day2);
      final rewards =
          await DailyStore.recordRound(correctCount: 1, stars: 0, now: day3);
      expect(rewards.milestoneDays, 3);
      expect(rewards.milestoneCoins, 30);

      // 스트릭이 끊겼다가 다시 3일이 되어도 보너스는 반복되지 않는다.
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day5);
      await DailyStore.recordRound(
          correctCount: 1, stars: 0, now: day5.add(const Duration(days: 1)));
      final again = await DailyStore.recordRound(
          correctCount: 1, stars: 0, now: day5.add(const Duration(days: 2)));
      expect(again.milestoneDays, 0);
    });
  });

  group('스트릭 지킴이', () {
    test('코인으로 사고, 하루 걸러도 스트릭이 이어진다', () async {
      await ProgressStore.addPoints(500);
      expect(await DailyStore.buyFreeze(), isTrue);
      expect((await DailyStore.load(now: day1)).freezes, 1);

      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day1);
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day2);
      // day3을 건너뛰고 day4에 출석 → 지킴이가 하나 쓰이고 스트릭 유지
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day4);

      final state = await DailyStore.load(now: day4);
      expect(state.streak, 3);
      expect(state.freezes, 0);
    });

    test('지킴이가 있으면 하루 안 푼 다음 날에도 스트릭이 살아 보인다', () async {
      await ProgressStore.addPoints(500);
      await DailyStore.buyFreeze();
      await DailyStore.recordRound(correctCount: 1, stars: 0, now: day1);
      // day2 건너뜀 → day3 화면에서는 아직 살아 있는 것으로 보인다.
      expect((await DailyStore.load(now: day3)).streak, 1);
    });

    test('코인이 모자라면 못 산다', () async {
      expect(await DailyStore.buyFreeze(), isFalse);
    });

    test('최대 2개까지만 살 수 있다', () async {
      await ProgressStore.addPoints(1000);
      expect(await DailyStore.buyFreeze(), isTrue);
      expect(await DailyStore.buyFreeze(), isTrue);
      expect(await DailyStore.buyFreeze(), isFalse);
    });
  });
}
