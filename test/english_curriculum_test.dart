import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/english_curriculum.dart';
import 'package:preschool_math/models/english_question.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  group('EnglishCurriculum', () {
    test('3개 카테고리, 묶음마다 10단계로 이어진다', () {
      expect(EnglishCurriculum.categories, hasLength(3));
      expect(
        EnglishCurriculum.categories.map((c) => c.title).toList(),
        ['알파벳 첫걸음', '영어 낱말', '스펠링 도전'],
      );
      expect(
        EnglishCurriculum.totalLevels,
        EnglishCurriculum.units.length * EnglishCurriculum.levelsPerUnit,
      );
      for (var i = 0; i < EnglishCurriculum.totalLevels; i++) {
        expect(EnglishCurriculum.levels[i].number, i + 1);
      }
    });

    test('소리(듣기)로 시작한다', () {
      expect(
        EnglishCurriculum.categories.first.units.first.type,
        EnQuizType.listenLetter,
      );
    });

    test('모든 단계에서 문제를 만들 수 있다', () {
      final generator = EnglishQuestionGenerator(random: Random(7));
      for (final level in EnglishCurriculum.levels) {
        final questions =
            generator.generate(level.unit.type, stage: level.stage);
        expect(questions, hasLength(10));
        for (final q in questions) {
          if (q.tiles.isNotEmpty) {
            final remaining = [...q.tiles];
            for (final ch in q.answer.split('')) {
              expect(remaining.remove(ch), isTrue);
            }
          } else {
            expect(q.choices, hasLength(4));
            expect(q.choices.toSet(), hasLength(4));
            expect(q.choices, contains(q.answer));
          }
        }
      }
    });
  });

  group('EnglishProgressStore', () {
    test('카테고리 첫 단계는 항상 열려 있고, 별 저장은 좋은 기록만 남는다', () async {
      final stars = List.filled(EnglishCurriculum.totalLevels, 0);
      for (final category in EnglishCurriculum.categories) {
        expect(
          EnglishProgressStore.isUnlocked(stars, category.firstLevelNumber),
          isTrue,
        );
      }
      expect(EnglishProgressStore.isUnlocked(stars, 2), isFalse);

      await EnglishProgressStore.saveStars(1, 2);
      expect((await EnglishProgressStore.load())[0], 2);
      await EnglishProgressStore.saveStars(1, 1);
      expect((await EnglishProgressStore.load())[0], 2);
    });
  });
}
