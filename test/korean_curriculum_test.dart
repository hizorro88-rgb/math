import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/korean_curriculum.dart';
import 'package:preschool_math/models/korean_question.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  group('KoreanCurriculum', () {
    test('3개 카테고리, 묶음마다 10단계로 이어진다', () {
      expect(KoreanCurriculum.categories, hasLength(3));
      expect(
        KoreanCurriculum.categories.map((c) => c.title).toList(),
        ['한글 첫걸음', '소리와 글자', '낱말 완성'],
      );
      expect(
        KoreanCurriculum.totalLevels,
        KoreanCurriculum.units.length * KoreanCurriculum.levelsPerUnit,
      );
      for (var i = 0; i < KoreanCurriculum.totalLevels; i++) {
        expect(KoreanCurriculum.levels[i].number, i + 1);
        expect(KoreanCurriculum.levelAt(i + 1).number, i + 1);
      }
    });

    test('글자를 몰라도 풀 수 있는 유형(낱말→그림)으로 시작한다', () {
      expect(
        KoreanCurriculum.categories.first.units.first.type,
        KrQuizType.wordToPicture,
      );
    });

    test('모든 단계에서 문제를 만들 수 있다', () {
      final generator = KoreanQuestionGenerator(random: Random(7));
      for (final level in KoreanCurriculum.levels) {
        final questions =
            generator.generate(level.unit.type, stage: level.stage);
        expect(questions, hasLength(10));
        for (final q in questions) {
          if (q.tiles.isNotEmpty) {
            // 낱말 만들기: 타일로 정답 낱말을 조립할 수 있어야 한다.
            final remaining = [...q.tiles];
            for (final ch in q.answer.split('')) {
              expect(remaining.remove(ch), isTrue,
                  reason: '$ch가 타일에 부족함 (${q.answer})');
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

  group('KoreanProgressStore', () {
    test('카테고리 첫 단계는 항상 열려 있다', () {
      final stars = List.filled(KoreanCurriculum.totalLevels, 0);
      for (final category in KoreanCurriculum.categories) {
        expect(
          KoreanProgressStore.isUnlocked(stars, category.firstLevelNumber),
          isTrue,
          reason: '${category.title} 첫 단계는 열려 있어야 함',
        );
      }
      expect(KoreanProgressStore.isUnlocked(stars, 2), isFalse);
      stars[0] = 1;
      expect(KoreanProgressStore.isUnlocked(stars, 2), isTrue);
    });

    test('예전(v1) 별 기록이 새 단계 번호로 이사한다', () async {
      // v1 시절: '빈칸 채우기'는 7번째 묶음(61~70단계)이었다.
      final old = List.filled(80, '0');
      old[0] = '3'; // 1단계 (낱말 보고 그림 찾기)
      old[60] = '2'; // 61단계 (빈칸 채우기 첫 단계)
      SharedPreferences.setMockInitialValues({'kr_level_stars_v1': old});
      Profiles.activeId = 1;

      final stars = await KoreanProgressStore.load();
      expect(stars[0], 3);

      final unit =
          KoreanCurriculum.units.firstWhere((u) => u.title == '빈칸 채우기');
      expect(unit.firstLevelNumber, isNot(61)); // 글자 만들기 뒤로 밀림
      expect(stars[unit.firstLevelNumber - 1], 2);
    });

    test('별을 저장하면 더 좋은 기록만 남는다', () async {
      await KoreanProgressStore.saveStars(1, 2);
      expect((await KoreanProgressStore.load())[0], 2);

      await KoreanProgressStore.saveStars(1, 1); // 더 나쁜 기록은 무시
      expect((await KoreanProgressStore.load())[0], 2);

      await KoreanProgressStore.saveStars(1, 3);
      expect((await KoreanProgressStore.load())[0], 3);
    });
  });
}
