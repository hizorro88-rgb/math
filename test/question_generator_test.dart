import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/question.dart';
import 'package:preschool_math/models/quiz_config.dart';

void main() {
  group('QuestionGenerator', () {
    for (final mode in QuizMode.values) {
      for (final maxNumber in [3, 5, 10, 15, 20]) {
        test('${mode.label} / $maxNumber까지 문제가 규칙에 맞는다', () {
          final generator = QuestionGenerator(random: Random(42));
          // 여러 판을 만들어 다양한 경우를 확인한다.
          for (var round = 0; round < 50; round++) {
            final questions = generator.generate(
              QuizConfig(mode: mode, maxNumber: maxNumber),
            );
            expect(questions, hasLength(10));

            for (final q in questions) {
              // 모드에 맞는 연산인지
              if (mode == QuizMode.addition) expect(q.isAddition, isTrue);
              if (mode == QuizMode.subtraction) expect(q.isAddition, isFalse);

              // 답이 0 이상, 최대값 이하인지
              expect(q.answer, greaterThanOrEqualTo(0));
              expect(q.answer, lessThanOrEqualTo(maxNumber));

              // 피연산자는 1 이상 (0 + n 같은 문제는 내지 않는다)
              expect(q.left, greaterThanOrEqualTo(1));
              expect(q.right, greaterThanOrEqualTo(1));

              // 보기: 4개, 중복 없음, 정답 포함, 음수 없음
              expect(q.choices, hasLength(4));
              expect(q.choices.toSet(), hasLength(4));
              expect(q.choices, contains(q.answer));
              expect(q.choices.every((c) => c >= 0), isTrue);
            }

            // 바로 앞 문제와 같은 문제가 연달아 나오지 않는지
            for (var i = 1; i < questions.length; i++) {
              expect(
                questions[i].expression,
                isNot(questions[i - 1].expression),
              );
            }
          }
        });
      }
    }
  });
}
