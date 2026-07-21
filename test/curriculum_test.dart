import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/curriculum.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/models/question.dart';

void main() {
  group('Curriculum', () {
    test('10개 묶음, 총 100단계로 구성된다', () {
      expect(Curriculum.units, hasLength(10));
      expect(Curriculum.levels, hasLength(100));
      expect(Curriculum.totalLevels, 100);

      // 단계 번호는 1부터 100까지 빠짐없이 이어진다.
      for (var i = 0; i < 100; i++) {
        expect(Curriculum.levels[i].number, i + 1);
        expect(Curriculum.levelAt(i + 1).number, i + 1);
      }

      // 각 묶음에는 정확히 10단계씩 들어 있다.
      for (final unit in Curriculum.units) {
        final count =
            Curriculum.levels.where((l) => l.unit.index == unit.index).length;
        expect(count, Curriculum.levelsPerUnit);
      }
    });

    test('묶음 안에서 난이도(최대값)가 점점 어려워진다', () {
      for (final unit in Curriculum.units) {
        final unitLevels =
            Curriculum.levels.where((l) => l.unit.index == unit.index).toList();

        expect(unitLevels.first.maxNumber, unit.startMax);
        expect(unitLevels.last.maxNumber, unit.endMax);

        for (var i = 1; i < unitLevels.length; i++) {
          expect(
            unitLevels[i].maxNumber,
            greaterThanOrEqualTo(unitLevels[i - 1].maxNumber),
          );
        }
      }
    });

    test('100단계 모두 문제를 만들 수 있다', () {
      final generator = QuestionGenerator(random: Random(7));
      for (final level in Curriculum.levels) {
        final questions = generator.generate(level.config);
        expect(questions, hasLength(10));
        for (final q in questions) {
          expect(q.answer, greaterThanOrEqualTo(0));
          expect(q.answer, lessThanOrEqualTo(level.maxNumber));
          expect(q.choices, contains(q.answer));
        }
      }
    });
  });

  group('진행 규칙', () {
    test('맞힌 개수에 따라 별이 계산된다', () {
      expect(starsForScore(10, 10), 3);
      expect(starsForScore(9, 10), 3);
      expect(starsForScore(8, 10), 2);
      expect(starsForScore(7, 10), 2);
      expect(starsForScore(6, 10), 1);
      expect(starsForScore(5, 10), 1);
      expect(starsForScore(4, 10), 0);
      expect(starsForScore(0, 10), 0);
    });

    test('앞 단계를 통과해야 다음 단계가 열린다', () {
      final stars = List.filled(100, 0);
      expect(ProgressStore.isUnlocked(stars, 1), isTrue);
      expect(ProgressStore.isUnlocked(stars, 2), isFalse);

      stars[0] = 1; // 1단계 통과
      expect(ProgressStore.isUnlocked(stars, 2), isTrue);
      expect(ProgressStore.isUnlocked(stars, 3), isFalse);
    });
  });
}
