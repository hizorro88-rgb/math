import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/korean_extra.dart';
import 'package:preschool_math/models/korean_question.dart';

void main() {
  const types = [
    KrQuizType.doubleConsonant,
    KrQuizType.complexVowel,
    KrQuizType.batchimCombine,
    KrQuizType.opposite,
    KrQuizType.mimetic,
    KrQuizType.verbMatch,
    KrQuizType.oddOneOut,
    KrQuizType.honorific,
    KrQuizType.counterWord,
  ];

  test('글자 합치기: 감·밥·솔', () {
    expect(krCompose('ㄱ', 'ㅏ', 'ㅁ'), '감');
    expect(krCompose('ㅂ', 'ㅏ', 'ㅂ'), '밥');
    expect(krCompose('ㅅ', 'ㅗ', 'ㄹ'), '솔');
    expect(krCompose('ㄲ', 'ㅏ'), '까');
    expect(krCompose('ㅇ', 'ㅘ'), '와');
  });

  test('새 한글 문제: 보기 4개가 다르고 정답이 들어 있다', () {
    final gen = KoreanQuestionGenerator(random: Random(13));
    for (final type in types) {
      for (var stage = 0; stage < 10; stage++) {
        for (final q in gen.generate(type, stage: stage)) {
          expect(q.choices, hasLength(4), reason: '$type');
          expect(q.choices.toSet(), hasLength(4), reason: '${q.choices}');
          expect(q.choices, contains(q.answer));
        }
      }
    }
  });

  test('이중모음: 소리가 같은 모음(ㅐ·ㅔ)은 함께 나오지 않는다', () {
    final groupOf = {for (final v in krComplexVowels) v.letter: v.group};
    final gen = KoreanQuestionGenerator(random: Random(2));
    for (var stage = 0; stage < 10; stage++) {
      for (final q in gen.generate(KrQuizType.complexVowel, stage: stage)) {
        final groups = [for (final c in q.choices) groupOf[c]];
        expect(groups.toSet().length, 4, reason: '${q.choices}');
      }
    }
  });

  test('센소리: 같은 무리(가·까·카 / 사·싸) + 다른 소리로 4개', () {
    final gen = KoreanQuestionGenerator(random: Random(4));
    for (final q in gen.generate(KrQuizType.doubleConsonant, count: 30)) {
      expect(q.speech, q.answer);
      expect(q.display, '🔊');
    }
  });

  test('반대말·흉내말·어울리는 말 데이터가 겹치지 않는다', () {
    final opp = [
      for (final p in krOpposites) ...[p.$1, p.$2]
    ];
    expect(opp.toSet().length, opp.length);
    expect({for (final m in krMimetics) m.$2}.length, krMimetics.length);
    expect({for (final v in krVerbPairs) v.$3}.length, krVerbPairs.length,
        reason: '같은 동사가 두 대상과 짝지어지면 정답이 둘이 된다');
    expect({for (final h in krHonorifics) h.$2}.length, krHonorifics.length);
    final items = [
      for (final c in krCategories.values)
        for (final x in c) x.$2
    ];
    expect(items.toSet().length, items.length);
  });

  test('다른 것 찾기: 정답만 다른 무리', () {
    String catOf(String label) => krCategories.entries
        .firstWhere((e) => e.value.any((x) => '${x.$1} ${x.$2}' == label))
        .key;
    final gen = KoreanQuestionGenerator(random: Random(6));
    for (var stage = 0; stage < 10; stage++) {
      for (final q in gen.generate(KrQuizType.oddOneOut, stage: stage)) {
        final cats = [for (final c in q.choices) catOf(c)];
        final odd = catOf(q.answer);
        expect(cats.where((c) => c == odd), hasLength(1));
        expect(cats.where((c) => c != odd).toSet(), hasLength(1));
      }
    }
  });

  test('어울리는 말: 함께 어울리는 동사(사과를 씻어요)는 오답으로 안 나온다', () {
    final gen = KoreanQuestionGenerator(random: Random(9));
    for (var stage = 0; stage < 10; stage++) {
      for (final q in gen.generate(KrQuizType.verbMatch, stage: stage)) {
        final pair = krVerbPairs.firstWhere((v) => v.$3 == q.answer);
        for (final c in q.choices.where((c) => c != q.answer)) {
          expect(pair.$4.contains(c), isFalse, reason: '${pair.$2} $c');
        }
      }
    }
  });

  test('흉내말: 소리는 소리끼리, 움직임은 움직임끼리 보기', () {
    final kindOf = {for (final m in krMimetics) m.$2: m.$4};
    final gen = KoreanQuestionGenerator(random: Random(10));
    for (var stage = 0; stage < 10; stage++) {
      for (final q in gen.generate(KrQuizType.mimetic, stage: stage)) {
        final kinds = {for (final c in q.choices) kindOf[c]};
        expect(kinds, hasLength(1), reason: '${q.choices}');
      }
    }
  });

  test('받침 글자 만들기는 정답 글자를 미리 읽지 않는다', () {
    final gen = KoreanQuestionGenerator(random: Random(11));
    for (final q in gen.generate(KrQuizType.batchimCombine, count: 20)) {
      // 자모 이름으로 읽는다 ('이응'처럼 이름 안에 글자가 들어가는 건 괜찮다)
      expect(q.speech, endsWith('합치면?'));
      expect(q.speech.split(', ').contains(q.answer), isFalse,
          reason: q.speech);
      expect(q.speech.contains('받침'), isTrue);
    }
  });
}
