import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/question.dart';
import 'package:preschool_math/models/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

Question _q({required int left, required int right, required bool add}) =>
    Question(
      left: left,
      right: right,
      isAddition: add,
      choices: const [0, 1, 2, 3],
      emoji: '🍎',
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('StatsStore', () {
    test('유형별 정답/오답이 누적된다', () async {
      await StatsStore.recordAnswer(_q(left: 2, right: 1, add: true),
          correct: true);
      await StatsStore.recordAnswer(_q(left: 2, right: 1, add: true),
          correct: false);
      await StatsStore.recordAnswer(_q(left: 3, right: 1, add: false),
          correct: true);

      final stats = await StatsStore.load();
      expect(stats.addCorrect, 1);
      expect(stats.addWrong, 1);
      expect(stats.subCorrect, 1);
      expect(stats.subWrong, 0);
      expect(stats.totalAnswered, 3);
    });

    test('수 범위는 문제에 나오는 가장 큰 수 기준으로 나뉜다', () async {
      expect(statBandOf(_q(left: 2, right: 3, add: true)), 0); // 답 5 → 5까지
      expect(statBandOf(_q(left: 6, right: 4, add: true)), 1); // 답 10 → 10까지
      expect(statBandOf(_q(left: 12, right: 3, add: false)), 2); // 12 → 20까지

      await StatsStore.recordAnswer(_q(left: 2, right: 3, add: true),
          correct: true);
      await StatsStore.recordAnswer(_q(left: 12, right: 3, add: false),
          correct: false);

      final stats = await StatsStore.load();
      expect(stats.bandCorrect, [1, 0, 0]);
      expect(stats.bandWrong, [0, 0, 1]);
    });

    test('최근 7일 활동이 날짜별로 기록된다', () async {
      final today = DateTime(2026, 7, 28, 10);
      final yesterday = DateTime(2026, 7, 27, 10);

      await StatsStore.recordRoundDay(now: yesterday);
      await StatsStore.recordRoundDay(now: today);
      await StatsStore.recordRoundDay(now: today);

      final stats = await StatsStore.load(now: today);
      expect(stats.recentDays.length, 7);
      expect(stats.recentDays.last.rounds, 2); // 오늘
      expect(stats.recentDays[5].rounds, 1); // 어제
      expect(stats.recentDays.first.rounds, 0); // 6일 전
    });

    test('정답률 계산: 푼 문제가 없으면 null', () {
      expect(LearningStats.accuracy(0, 0), isNull);
      expect(LearningStats.accuracy(3, 1), 75);
      expect(LearningStats.accuracy(10, 0), 100);
    });
  });
}
