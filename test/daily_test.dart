import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/daily.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final day1 = DateTime(2026, 7, 26, 10);
  final day2 = DateTime(2026, 7, 27, 9);
  final day3 = DateTime(2026, 7, 28, 20);
  final day5 = DateTime(2026, 7, 30, 8);

  group('데일리 미션', () {
    test('퀴즈 3판을 풀면 미션이 완료되고 코인을 받는다', () async {
      await DailyStore.recordRound(correctCount: 5, stars: 1, now: day1);
      await DailyStore.recordRound(correctCount: 5, stars: 1, now: day1);
      final done =
          await DailyStore.recordRound(correctCount: 5, stars: 1, now: day1);

      expect(done.map((m) => m.id), contains('rounds3'));
      // 보상 30코인 지급
      expect(await ProgressStore.loadCoins(), greaterThanOrEqualTo(30));

      final state = await DailyStore.load(now: day1);
      expect(state.rounds, 3);
      expect(state.isDone(dailyMissions[0]), isTrue);
    });

    test('정답 20개·별 5개 미션도 누적으로 달성된다', () async {
      await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      final done =
          await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);

      final ids = done.map((m) => m.id).toList();
      expect(ids, contains('correct20'));
      expect(ids, contains('stars5'));
    });

    test('이미 달성한 미션은 다시 보상을 주지 않는다', () async {
      await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      final coinsAfterDone = await ProgressStore.loadCoins();

      final done =
          await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      // rounds3만 새로 달성 (3판째)
      expect(done.map((m) => m.id).toList(), ['rounds3']);
      expect(await ProgressStore.loadCoins(), coinsAfterDone + 30);
    });

    test('날짜가 바뀌면 미션 진행도가 리셋된다', () async {
      await DailyStore.recordRound(correctCount: 10, stars: 3, now: day1);
      final nextDay = await DailyStore.load(now: day2);
      expect(nextDay.rounds, 0);
      expect(nextDay.correct, 0);
      expect(nextDay.claimed, isEmpty);
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
  });
}
