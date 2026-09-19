import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/curriculum.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/models/question.dart';
import 'package:preschool_math/models/quiz_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Curriculum', () {
    test('연령/학년 8개 카테고리, 묶음마다 10단계로 구성된다', () {
      expect(Curriculum.categories, hasLength(8));
      expect(
        Curriculum.categories.map((c) => c.title).toList(),
        ['4살', '5살', '6살', '7살', '초등 1학년', '초등 2학년', '초등 3학년', '초3·4 심화'],
      );

      // 전체 단계 수 = 묶음 수 × 10
      expect(
        Curriculum.totalLevels,
        Curriculum.units.length * Curriculum.levelsPerUnit,
      );

      // 단계 번호는 1부터 빠짐없이 이어진다.
      for (var i = 0; i < Curriculum.totalLevels; i++) {
        expect(Curriculum.levels[i].number, i + 1);
        expect(Curriculum.levelAt(i + 1).number, i + 1);
      }
    });

    test('교육과정 순서: 수 세기 → 덧뺄셈 → 곱셈 → 나눗셈', () {
      // 4살은 수 세기로 시작
      expect(Curriculum.categories.first.units.first.mode, QuizMode.counting);
      // 초등 2학년에 곱셈이 처음 나온다.
      final firstMul =
          Curriculum.units.firstWhere((u) => u.mode == QuizMode.multiplication);
      expect(firstMul.category.title, '초등 2학년');
      // 초등 3학년에 나눗셈이 처음 나온다.
      final firstDiv =
          Curriculum.units.firstWhere((u) => u.mode == QuizMode.division);
      expect(firstDiv.category.title, '초등 3학년');
    });

    test('묶음 안에서 난이도(기준값)가 점점 어려워진다', () {
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

    test('모든 단계에서 문제를 만들 수 있다', () {
      final generator = QuestionGenerator(random: Random(7));
      for (final level in Curriculum.levels) {
        final questions = generator.generate(level.config);
        expect(questions, hasLength(10));
        for (final q in questions) {
          expect(q.answer, greaterThanOrEqualTo(0));
          expect(q.choices, contains(q.answer));
          expect(q.choices.toSet(), hasLength(4));
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

    test('카테고리 첫 단계는 항상 열려 있다 (나이에 맞게 바로 시작)', () {
      final stars = List.filled(Curriculum.totalLevels, 0);
      for (final category in Curriculum.categories) {
        expect(
          ProgressStore.isUnlocked(stars, category.firstLevelNumber),
          isTrue,
          reason: '${category.title} 첫 단계는 열려 있어야 함',
        );
      }
    });

    test('카테고리 안에서는 앞 단계를 통과해야 다음이 열린다', () {
      final stars = List.filled(Curriculum.totalLevels, 0);
      expect(ProgressStore.isUnlocked(stars, 2), isFalse);

      stars[0] = 1; // 1단계 통과
      expect(ProgressStore.isUnlocked(stars, 2), isTrue);
      expect(ProgressStore.isUnlocked(stars, 3), isFalse);

      // 초등 2학년 중간 단계도 같은 규칙
      final grade2 =
          Curriculum.categories.firstWhere((c) => c.title == '초등 2학년');
      final second = grade2.firstLevelNumber + 1;
      expect(ProgressStore.isUnlocked(stars, second), isFalse);
      stars[grade2.firstLevelNumber - 1] = 2;
      expect(ProgressStore.isUnlocked(stars, second), isTrue);
    });

    test('예전(v4) 별 기록이 새 단계 번호로 이사한다', () async {
      // v4 시절(42묶음, 420단계): 7살에 '시계 읽기'가 들어가기 전.
      // '덧뺄셈 마스터'는 v4에서 23번째 묶음(221~230단계)이었다.
      final old = List.filled(420, '0');
      old[0] = '3';
      old[220] = '2'; // 221단계 (덧뺄셈 마스터 첫 단계)
      SharedPreferences.setMockInitialValues({'level_stars_v4': old});
      Profiles.activeId = 1;

      final stars = await ProgressStore.load();
      expect(stars.length, Curriculum.totalLevels);
      expect(stars[0], 3);

      // 이제 7살 '시계 읽기' 10단계만큼 뒤로 밀렸다.
      final unit =
          Curriculum.units.firstWhere((u) => u.title == '덧뺄셈 마스터');
      expect(stars[unit.firstLevelNumber - 1], 2);
      final clock =
          Curriculum.units.firstWhere((u) => u.title == '시계 읽기');
      expect(clock.category.title, '7살');
    });

    test('예전(v3) 별 기록이 새 단계 번호로 이사한다', () async {
      // v3 시절: '덧뺄셈 마스터'는 21번째 묶음(201~210단계)이었다.
      final old = List.filled(350, '0');
      old[0] = '3';
      old[200] = '2'; // 201단계 (덧뺄셈 마스터 첫 단계)
      SharedPreferences.setMockInitialValues({'level_stars_v3': old});
      Profiles.activeId = 1;

      final stars = await ProgressStore.load();
      expect(stars[0], 3);

      // '덧뺄셈 마스터'는 이제 '시계 보기' 뒤로 밀려났다.
      final unit =
          Curriculum.units.firstWhere((u) => u.title == '덧뺄셈 마스터');
      expect(unit.firstLevelNumber, isNot(201));
      expect(stars[unit.firstLevelNumber - 1], 2);
    });

    test('예전(v2) 별 기록이 새 단계 번호로 이사한다', () async {
      // v2 시절: '덧셈 첫걸음'은 4번째 묶음(31~40단계)이었다.
      final old = List.filled(40, '0');
      old[0] = '3'; // 1단계 (수 세기 첫걸음)
      old[30] = '2'; // 31단계 (덧셈 첫걸음 첫 단계)
      SharedPreferences.setMockInitialValues({'level_stars_v2': old});
      Profiles.activeId = 1;

      final stars = await ProgressStore.load();
      expect(stars[0], 3); // 첫 단계는 그대로

      // '덧셈 첫걸음'은 이제 '큰 수 찾기' 뒤로 밀려났다.
      final unit =
          Curriculum.units.firstWhere((u) => u.title == '덧셈 첫걸음');
      expect(stars[unit.firstLevelNumber - 1], 2);
      // 옛 위치(31단계 자리)에는 별이 남아 있지 않아야 한다.
      expect(unit.firstLevelNumber, isNot(31));
      expect(stars[30], 0);
    });
  });
}
