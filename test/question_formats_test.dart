import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/curriculum.dart';
import 'package:preschool_math/models/english_question.dart';
import 'package:preschool_math/models/korean_question.dart';
import 'package:preschool_math/models/question.dart';
import 'package:preschool_math/services/sounds.dart';
import 'package:preschool_math/widgets/quiz_parts.dart';

void main() {
  test('맞을까 틀릴까: 보여 준 식이 맞으면 정답은 맞아요(1)', () {
    for (final title in ['맞을까 틀릴까', '구구단 맞을까']) {
      final u = Curriculum.units.firstWhere((u) => u.title == title);
      for (var i = 0; i < 10; i++) {
        final level = Curriculum.levelAt(u.firstLevelNumber + i);
        for (final q
            in QuestionGenerator(random: Random(i)).generate(level.config)) {
          final s = q.sequence;
          final real = switch (s[3]) {
            0 => s[0] + s[1],
            1 => s[0] - s[1],
            _ => s[0] * s[1],
          };
          expect(q.answer, real == s[2] ? 1 : 0, reason: q.expression);
          expect(q.choices.toSet(), {0, 1});
          expect(s[2], greaterThanOrEqualTo(0));
          if (title == '구구단 맞을까') expect(s[3], 2);
        }
      }
    }
  });

  test('짝 맞추기(영어·한글): 짝 4개, 양쪽 모두 겹치지 않는다', () {
    for (var stage = 0; stage < 10; stage++) {
      for (final q in EnglishQuestionGenerator(random: Random(stage))
          .generate(EnQuizType.matchPairs, stage: stage)) {
        expect(q.pairs, hasLength(4));
        expect({for (final p in q.pairs) p.$1}, hasLength(4));
        expect({for (final p in q.pairs) p.$2}, hasLength(4));
      }
      for (final q in KoreanQuestionGenerator(random: Random(stage))
          .generate(KrQuizType.matchPairs, stage: stage)) {
        expect(q.pairs, hasLength(4));
        expect({for (final p in q.pairs) p.$1}, hasLength(4));
        expect({for (final p in q.pairs) p.$2}, hasLength(4));
      }
    }
  });

  testWidgets('짝 맞추기 판: 다 맞추면 끝나고, 틀린 횟수를 알려 준다', (tester) async {
    Sounds.enabled = false;
    int? result;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: QuizMatchBoard(
          pairs: const [('🐱', 'CAT'), ('🐶', 'DOG'), ('🐷', 'PIG')],
          onDone: (ok) => result = ok,
        ),
      ),
    ));
    // 일부러 한 번 틀린다
    await tester.tap(find.text('🐱'));
    await tester.tap(find.text('DOG'));
    await tester.pump(const Duration(milliseconds: 500));
    for (final (l, r) in [('🐱', 'CAT'), ('🐶', 'DOG'), ('🐷', 'PIG')]) {
      await tester.tap(find.text(l));
      await tester.tap(find.text(r));
      await tester.pump();
    }
    expect(result, 1);
  });
}
