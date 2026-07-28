import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/question.dart';
import 'package:preschool_math/models/quiz_config.dart';

void main() {
  group('QuestionGenerator 수 세기', () {
    test('그림 개수가 정답이고 1~최대값 범위다', () {
      final generator = QuestionGenerator(random: Random(7));
      for (final maxNumber in [3, 5, 10]) {
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.counting, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.counting);
            expect(q.answer, q.left);
            expect(q.left, greaterThanOrEqualTo(1));
            expect(q.left, lessThanOrEqualTo(maxNumber));
            expect(q.expression, '몇 개일까요?');
            expect(q.choices, hasLength(4));
            expect(q.choices.toSet(), hasLength(4));
            expect(q.choices, contains(q.answer));
          }
        }
      }
    });

    test('섞어서 모드에는 수 세기 문제가 나오지 않는다', () {
      final generator = QuestionGenerator(random: Random(3));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(
          const QuizConfig(mode: QuizMode.mixed, maxNumber: 10),
        );
        expect(
          questions.every(
            (q) => q.op == QuestionOp.add || q.op == QuestionOp.sub,
          ),
          isTrue,
        );
      }
    });
  });

  group('QuestionGenerator 곱셈', () {
    test('max단까지의 구구단이 나온다 (2~max) × (1~9)', () {
      final generator = QuestionGenerator(random: Random(11));
      for (final maxNumber in [3, 5, 9, 15]) {
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.multiplication, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.mul);
            expect(q.left, greaterThanOrEqualTo(2));
            expect(q.left, lessThanOrEqualTo(maxNumber));
            expect(q.right, greaterThanOrEqualTo(1));
            expect(q.right, lessThanOrEqualTo(9));
            expect(q.answer, q.left * q.right);
            expect(q.expression, '${q.left} × ${q.right} = ?');
            expect(q.choices, hasLength(4));
            expect(q.choices.toSet(), hasLength(4));
            expect(q.choices, contains(q.answer));
            expect(q.choices.every((c) => c >= 0), isTrue);
          }
        }
      }
    });
  });

  group('QuestionGenerator 나눗셈', () {
    test('나누어떨어지는 나눗셈만 나온다 (몫 1~9)', () {
      final generator = QuestionGenerator(random: Random(13));
      for (final maxNumber in [3, 5, 9]) {
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.division, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.div);
            expect(q.right, greaterThanOrEqualTo(2)); // 나누는 수
            expect(q.right, lessThanOrEqualTo(maxNumber));
            expect(q.left % q.right, 0); // 항상 나누어떨어짐
            expect(q.answer, greaterThanOrEqualTo(1)); // 몫
            expect(q.answer, lessThanOrEqualTo(9));
            expect(q.answer, q.left ~/ q.right);
            expect(q.expression, '${q.left} ÷ ${q.right} = ?');
            expect(q.choices, hasLength(4));
            expect(q.choices.toSet(), hasLength(4));
            expect(q.choices, contains(q.answer));
          }
        }
      }
    });
  });

  group('QuestionGenerator 세로셈', () {
    test('세로 덧셈: 두 자리 수 중심, 합이 범위를 넘지 않는다', () {
      final generator = QuestionGenerator(random: Random(21));
      for (final maxNumber in [5, 20, 40, 99]) {
        final effectiveMax = maxNumber < 20 ? 20 : maxNumber;
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.verticalAdd, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.vertical, isTrue);
            expect(q.op, QuestionOp.add);
            expect(q.left, greaterThanOrEqualTo(10)); // 두 자리
            expect(q.right, greaterThanOrEqualTo(1));
            expect(q.answer, lessThanOrEqualTo(effectiveMax));
          }
        }
      }
    });

    test('세로 뺄셈: 두 자리 수에서 빼고 답은 0 이상', () {
      final generator = QuestionGenerator(random: Random(23));
      for (final maxNumber in [20, 40, 99]) {
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.verticalSub, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.vertical, isTrue);
            expect(q.op, QuestionOp.sub);
            expect(q.left, greaterThanOrEqualTo(11)); // 두 자리
            expect(q.left, lessThanOrEqualTo(maxNumber));
            expect(q.right, greaterThanOrEqualTo(1));
            expect(q.answer, greaterThanOrEqualTo(0));
          }
        }
      }
    });
  });

  group('QuestionGenerator 덧셈·뺄셈', () {
    for (final mode in [
      QuizMode.addition,
      QuizMode.subtraction,
      QuizMode.mixed,
    ]) {
      for (final maxNumber in [3, 5, 10, 20, 50, 300]) {
        test('${mode.label} / $maxNumber까지 문제가 규칙에 맞는다', () {
          final generator = QuestionGenerator(random: Random(42));
          for (var round = 0; round < 30; round++) {
            final questions = generator.generate(
              QuizConfig(mode: mode, maxNumber: maxNumber),
            );
            expect(questions, hasLength(10));

            for (final q in questions) {
              // 모드에 맞는 연산인지
              if (mode == QuizMode.addition) expect(q.op, QuestionOp.add);
              if (mode == QuizMode.subtraction) expect(q.op, QuestionOp.sub);

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
              expect(questions[i].dedupKey, isNot(questions[i - 1].dedupKey));
            }
          }
        });
      }
    }
  });
}
