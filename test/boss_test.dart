import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/boss.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  group('주간 보스전', () {
    test('같은 주는 같은 키, 주가 바뀌면 다른 키', () {
      final wednesday = DateTime(2026, 8, 19); // 수요일
      final friday = DateTime(2026, 8, 21);
      final nextMonday = DateTime(2026, 8, 24);
      expect(BossStore.weekKey(wednesday), BossStore.weekKey(friday));
      expect(
        BossStore.weekKey(friday),
        isNot(BossStore.weekKey(nextMonday)),
      );
    });

    test('클리어하면 이번 주는 잠기고, 다음 주에 다시 열린다', () async {
      final thisWeek = DateTime(2026, 8, 19);
      final nextWeek = DateTime(2026, 8, 26);

      expect(await BossStore.isClearedThisWeek(now: thisWeek), isFalse);
      await BossStore.markCleared(now: thisWeek);
      expect(await BossStore.isClearedThisWeek(now: thisWeek), isTrue);
      expect(await BossStore.isClearedThisWeek(now: nextWeek), isFalse);
    });

    test('보스전 문제는 12개, 여러 유형이 섞여 있다', () {
      final questions = BossStore.buildQuestions(random: Random(7));
      expect(questions, hasLength(BossStore.questionCount));
      // 유형이 3가지 이상 섞여 있어야 보스전답다.
      final ops = questions.map((q) => q.op).toSet();
      expect(ops.length, greaterThanOrEqualTo(3));
      for (final q in questions) {
        expect(q.choices, contains(q.answer));
        expect(q.choices.toSet(), hasLength(4));
      }
    });
  });
}
