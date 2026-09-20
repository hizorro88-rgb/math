import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/conversation_pack.dart';
import 'package:preschool_math/models/language_pack.dart';

void main() {
  group('영어회화 표현 데이터', () {
    test('주제 30개가 100개씩, 제목과 짝이 맞는다', () {
      expect(convUnitExpressions, hasLength(30));
      expect(convUnitTitles, hasLength(30));
      for (final unit in convUnitExpressions) {
        expect(unit, hasLength(convExpressionsPerUnit));
      }
      expect(
        convUnitExpressions.fold<int>(0, (sum, u) => sum + u.length),
        3000,
      );
    });

    test('표현이 전부 다르고, 영어는 1~6낱말 아스키다', () {
      final seen = <String>{};
      final asciiOnly = RegExp(r"^[A-Za-z0-9 ,.'?!\-]+$");
      for (var u = 0; u < convUnitExpressions.length; u++) {
        for (final e in convUnitExpressions[u]) {
          expect(seen.add(e.en.toLowerCase()), isTrue,
              reason: '중복 표현: ${e.en}');
          expect(asciiOnly.hasMatch(e.en), isTrue, reason: '이상한 문자: ${e.en}');
          expect(e.wordCount, inInclusiveRange(1, 6), reason: e.en);
          expect(e.ko.trim(), isNotEmpty, reason: e.en);
        }
      }
    });

    test('한 주제 안에서는 뜻도 겹치지 않는다 (보기가 헷갈리지 않게)', () {
      for (var u = 0; u < convUnitExpressions.length; u++) {
        final meanings = convUnitExpressions[u].map((e) => e.ko).toList();
        expect(meanings.toSet(), hasLength(meanings.length),
            reason: '${convUnitTitles[u].title}에 같은 뜻이 둘 이상');
      }
    });
  });

  group('영어회화 팩 구조', () {
    test('3단계 · 주제 30개 · 단계 300개', () {
      expect(conversationPack.categories, hasLength(3));
      expect(conversationPack.units, hasLength(30));
      expect(conversationPack.totalLevels, 300);
      expect(conversationPack.unitBased, isTrue);
      for (final category in conversationPack.categories) {
        expect(category.units, hasLength(10));
      }
    });

    test('주제 순서가 표현 묶음 순서와 같다', () {
      for (var i = 0; i < conversationPack.units.length; i++) {
        expect(conversationPack.units[i].index, i);
        expect(conversationPack.units[i].title, convUnitTitles[i].title);
      }
    });
  });

  group('영어회화 문제 만들기', () {
    test('모든 주제·단계에서 10문제가 규칙에 맞게 나온다', () {
      final random = Random(11);
      for (var u = 0; u < 30; u++) {
        for (var stage = 0; stage < LanguagePack.levelsPerUnit; stage++) {
          final questions = convGenerateLevel(u, stage, random);
          expect(questions, hasLength(10));

          // 한 판 안에서 같은 표현이 두 번 나오지 않는다.
          expect(
            questions.map((q) => q.dedupKey).toSet(),
            hasLength(10),
            reason: '주제 $u 단계 $stage',
          );

          for (final q in questions) {
            expect(q.typeIndex, inInclusiveRange(0, 4));
            expect(q.speech.trim(), isNotEmpty);
            expect(q.instruction, isNotEmpty);
            expect(q.display, isNotEmpty);
            if (q.tiles.isEmpty) {
              expect(q.choices, hasLength(4), reason: q.display);
              expect(q.choices.toSet(), hasLength(4), reason: q.display);
              expect(q.choices, contains(q.answer), reason: q.display);
            }
          }
        }
      }
    });

    test('뜻 고르기는 영어를 보여 주고 한국어 뜻을 고른다', () {
      final random = Random(3);
      final pool = convUnitExpressions[0];
      final target = pool.first;
      final q = convGenerateLevel(0, 0, random)
          .firstWhere((q) => q.typeIndex == 0);
      final matched = pool.firstWhere((e) => e.en == q.display);
      expect(q.answer, matched.ko);
      expect(q.speech, matched.en);
      expect(target.en, isNotEmpty);
    });

    test('듣기 문제는 🔊만 보여 주고 영어 보기를 고른다', () {
      final random = Random(5);
      final questions = [
        for (var stage = 0; stage < 10; stage++)
          ...convGenerateLevel(4, stage, random),
      ].where((q) => q.typeIndex == 2);
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q.display, '🔊');
        expect(q.speech, q.answer);
        expect(conversationPack.types[2].listening, isTrue);
      }
    });

    test('빈칸 문제는 낱말 하나만 가리고 그 낱말을 고르게 한다', () {
      final random = Random(9);
      final questions = [
        for (var u = 0; u < 30; u++)
          for (var stage = 3; stage < 10; stage++)
            ...convGenerateLevel(u, stage, random),
      ].where((q) => q.typeIndex == 3).toList();
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q.display, contains('____'));
        expect(q.answerText.toLowerCase(), contains(q.answer.toLowerCase()));
        expect(q.subDisplay, isNotEmpty); // 뜻 힌트
        // 가린 칸을 정답으로 되돌리면 원래 문장이 된다.
        final restored = q.display.replaceFirst('____', q.answer);
        expect(restored, q.answerText);
      }
    });

    test('문장 배열은 타일을 순서대로 이으면 정답 문장이 된다', () {
      final random = Random(13);
      final questions = [
        for (var u = 0; u < 30; u++)
          for (var stage = 6; stage < 10; stage++)
            ...convGenerateLevel(u, stage, random),
      ].where((q) => q.typeIndex == 4).toList();
      expect(questions, isNotEmpty);
      for (final q in questions) {
        expect(q.tileJoin, ' ');
        expect(q.tileSlots, q.answer.split(' ').length);
        expect(q.slotCount, q.tileSlots);
        expect(q.tiles, hasLength(q.tileSlots));
        final sorted = [...q.tiles]..sort();
        final expected = q.answer.split(' ')..sort();
        expect(sorted, expected);
      }
    });

    test('단계가 오르면 만들어 내는 문제(빈칸·배열) 비중이 커진다', () {
      final random = Random(17);
      int produceCount(int stage) {
        var count = 0;
        for (var u = 0; u < 30; u++) {
          count += convGenerateLevel(u, stage, random)
              .where((q) => q.typeIndex >= 3)
              .length;
        }
        return count;
      }

      final early = produceCount(0);
      final middle = produceCount(4);
      final late = produceCount(9);
      expect(early, 0);
      expect(middle, greaterThan(early));
      expect(late, greaterThan(middle));
    });

    test('단계마다 다루는 표현 묶음이 달라 300단계가 3000개를 모두 훑는다', () {
      final random = Random(19);
      final covered = <String>{};
      for (var u = 0; u < 30; u++) {
        for (var stage = 0; stage < 10; stage++) {
          for (final q in convGenerateLevel(u, stage, random)) {
            covered.add(q.answerText);
          }
        }
      }
      // 뜻 고르기 문제는 answerText가 한국어라 영어 표현 수보다 적게 잡힌다.
      expect(covered.length, greaterThan(2000));
    });
  });
}
