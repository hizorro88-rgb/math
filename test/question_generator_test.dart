import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/curriculum.dart';
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

  group('QuestionGenerator 빈칸 채우기', () {
    test('가려진 피연산자가 정답이고 식이 성립한다', () {
      final generator = QuestionGenerator(random: Random(31));
      for (final maxNumber in [5, 10, 20]) {
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.fillBlank, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect([1, 2], contains(q.blankSide));
            expect(q.expression, contains('□'));
            expect(q.answer, q.blankSide == 1 ? q.left : q.right);
            expect(q.answer, greaterThanOrEqualTo(1));
            if (q.op == QuestionOp.add) {
              expect(q.left + q.right, lessThanOrEqualTo(maxNumber));
            } else {
              expect(q.op, QuestionOp.sub);
              expect(q.left - q.right, greaterThanOrEqualTo(0));
              expect(q.left, lessThanOrEqualTo(maxNumber));
            }
            expect(q.choices, hasLength(4));
            expect(q.choices.toSet(), hasLength(4));
            expect(q.choices, contains(q.answer));
          }
        }
      }
    });
  });

  group('QuestionGenerator 10 만들기', () {
    test('두 수의 합이 항상 10이고 오른쪽이 가려진다', () {
      final generator = QuestionGenerator(random: Random(33));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(
          const QuizConfig(mode: QuizMode.makeTen, maxNumber: 10),
        );
        for (final q in questions) {
          expect(q.op, QuestionOp.add);
          expect(q.blankSide, 2);
          expect(q.left + q.right, 10);
          expect(q.answer, 10 - q.left);
          expect(q.expression, '${q.left} + □ = 10');
          expect(q.choices, contains(q.answer));
        }
      }
    });
  });

  group('QuestionGenerator 큰 수 찾기', () {
    test('보기 4개 중 가장 큰(작은) 수가 정답이다', () {
      final generator = QuestionGenerator(random: Random(35));
      for (final maxNumber in [5, 10, 50]) {
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.compare, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.compare);
            expect(q.choices, hasLength(4));
            expect(q.choices.toSet(), hasLength(4));
            final expected = q.right == 1
                ? q.choices.reduce((a, b) => a > b ? a : b)
                : q.choices.reduce((a, b) => a < b ? a : b);
            expect(q.answer, expected);
            expect(
              q.expression,
              q.right == 1 ? '가장 큰 수는?' : '가장 작은 수는?',
            );
            expect(q.choices.every((c) => c >= 1), isTrue);
          }
        }
      }
    });
  });

  group('QuestionGenerator 규칙 찾기', () {
    test('일정하게 커지는 배열의 다음 수가 정답이다', () {
      final generator = QuestionGenerator(random: Random(37));
      for (final maxNumber in [2, 5]) {
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.pattern, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.pattern);
            expect(q.sequence, hasLength(3));
            final step = q.sequence[1] - q.sequence[0];
            expect(step, greaterThanOrEqualTo(1));
            expect(step, lessThanOrEqualTo(maxNumber));
            expect(q.sequence[2] - q.sequence[1], step);
            expect(q.answer, q.sequence.last + step);
            expect(q.choices, contains(q.answer));
          }
        }
      }
    });
  });

  group('QuestionGenerator 듣고 풀기', () {
    test('식은 감추고 소리로만 문제를 낸다', () {
      final generator = QuestionGenerator(random: Random(39));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(
          const QuizConfig(mode: QuizMode.listen, maxNumber: 10),
        );
        for (final q in questions) {
          expect(q.listenOnly, isTrue);
          expect(q.expression, isNot(contains('=')));
          expect(
            q.speechText,
            anyOf(contains('더하기'), contains('빼기')),
          );
          expect(q.answer,
              q.op == QuestionOp.add ? q.left + q.right : q.left - q.right);
          expect(q.choices, contains(q.answer));
        }
      }
    });
  });

  group('QuestionGenerator 시계 보기', () {
    test('기준값이 작으면 정각만 나온다 (분 부호화)', () {
      final generator = QuestionGenerator(random: Random(41));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(
          const QuizConfig(mode: QuizMode.clock, maxNumber: 12),
        );
        for (final q in questions) {
          expect(q.op, QuestionOp.clock);
          expect(q.left % 60, 0); // 정각만
          expect(q.left ~/ 60, inInclusiveRange(1, 12));
          expect(q.answer, q.left);
          expect(q.answerLabel, '${q.left ~/ 60}시');
          expect(q.expression, '시계는 몇 시일까요?');
          expect(q.choices, hasLength(4));
          expect(q.choices.toSet(), hasLength(4));
          expect(q.choices, contains(q.answer));
        }
      }
    });

    test('기준값이 18 이상이면 몇 시 반도 나온다', () {
      final generator = QuestionGenerator(random: Random(43));
      var sawHalf = false;
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(
          const QuizConfig(mode: QuizMode.clock, maxNumber: 24),
        );
        for (final q in questions) {
          expect(q.left % 30, 0); // 정각 또는 30분
          expect(q.left ~/ 60, inInclusiveRange(1, 12));
          if (q.left % 60 == 30) {
            sawHalf = true;
            expect(q.answerLabel, '${q.left ~/ 60}시 30분');
          }
          expect(q.choices, contains(q.answer));
          expect(q.choices.toSet(), hasLength(4));
        }
      }
      expect(sawHalf, isTrue);
    });
  });

  group('QuestionGenerator 모양 세기', () {
    test('정답 모양의 개수가 정답이고, 다른 모양이 섞여 있다', () {
      final generator = QuestionGenerator(random: Random(43));
      for (final maxNumber in [3, 5]) {
        for (var round = 0; round < 30; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.shapeCount, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.shape);
            final targetCount =
                q.shapeItems.where((s) => s == q.emoji).length;
            expect(q.answer, targetCount);
            expect(q.answer, greaterThanOrEqualTo(1));
            expect(q.answer, lessThanOrEqualTo(maxNumber < 6 ? maxNumber : 6));
            // 다른 모양도 섞여 있다.
            expect(q.shapeItems.any((s) => s != q.emoji), isTrue);
            expect(q.choices, contains(q.answer));
            expect(q.choices.toSet(), hasLength(4));
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

  group('QuestionGenerator 난이도 하한', () {
    test('덧셈: 답이 minNumber 아래로 내려가지 않는다', () {
      final generator = QuestionGenerator(random: Random(51));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(const QuizConfig(
            mode: QuizMode.addition, maxNumber: 50, minNumber: 25));
        for (final q in questions) {
          expect(q.answer, inInclusiveRange(25, 50));
        }
      }
    });

    test('뺄셈: 처음 수가 minNumber 아래로 내려가지 않는다', () {
      final generator = QuestionGenerator(random: Random(53));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(const QuizConfig(
            mode: QuizMode.subtraction, maxNumber: 50, minNumber: 25));
        for (final q in questions) {
          expect(q.left, inInclusiveRange(25, 50));
        }
      }
    });

    test('곱셈: 8~9단 설정에서 2단이 나오지 않는다', () {
      final generator = QuestionGenerator(random: Random(55));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(const QuizConfig(
            mode: QuizMode.multiplication, maxNumber: 9, minNumber: 8));
        for (final q in questions) {
          expect(q.left, inInclusiveRange(8, 9));
        }
      }
    });

    test('나눗셈: 나누는 수가 minNumber 아래로 내려가지 않는다', () {
      final generator = QuestionGenerator(random: Random(57));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(const QuizConfig(
            mode: QuizMode.division, maxNumber: 9, minNumber: 6));
        for (final q in questions) {
          expect(q.right, inInclusiveRange(6, 9));
        }
      }
    });

    test('커리큘럼 단계가 하한을 실어 보낸다', () {
      // 곱셈 유닛: 단수 하한 = 유닛의 시작 단수 (뒤 단원에서 2단 금지)
      final mulUnit =
          Curriculum.units.firstWhere((u) => u.title == '곱셈 완성 (8~9단)');
      expect(Curriculum.levelAt(mulUnit.firstLevelNumber).config.minNumber, 8);

      // 덧셈 유닛: 답 하한이 최대값의 절반 이상
      final addUnit =
          Curriculum.units.firstWhere((u) => u.title == '두 자리 덧셈');
      final config = Curriculum.levelAt(addUnit.firstLevelNumber).config;
      expect(config.minNumber, greaterThanOrEqualTo(config.maxNumber ~/ 2));
    });
  });

  group('QuestionGenerator 초3·4 심화', () {
    test('분수: 부호화·보기·읽어주기가 규칙에 맞는다', () {
      final generator = QuestionGenerator(random: Random(21));
      for (final maxNumber in [2, 5, 9]) {
        for (var round = 0; round < 20; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.fraction, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.fraction);
            expect(q.choices, hasLength(4));
            expect(q.choices.toSet(), hasLength(4));
            expect(q.choices, contains(q.answer));
            final n = q.answer ~/ 100;
            final d = q.answer % 100;
            expect(d, inInclusiveRange(2, 9));
            expect(n, inInclusiveRange(1, d - 1 == 0 ? 1 : d - 1));
            expect(q.answerLabel, '$n/$d');
            expect(q.answerSpeech, '$d분의 $n');
            expect(q.prompt, isNotEmpty);
            if (q.variant == 1) {
              // 비교: 같은 분모 중 분자가 가장 큰 것
              for (final c in q.choices) {
                expect(c % 100, d);
                expect(c ~/ 100, lessThanOrEqualTo(n));
              }
            }
            if (q.variant == 2) {
              // 덧셈: a/d + b/d 문장에서 답을 다시 계산해 확인
              final match =
                  RegExp(r'^(\d+)/(\d+) \+ (\d+)/\d+ = \?$').firstMatch(q.prompt);
              expect(match, isNotNull, reason: q.prompt);
              expect(
                int.parse(match!.group(1)!) + int.parse(match.group(3)!),
                n,
              );
              expect(int.parse(match.group(2)!), d);
            }
          }
        }
      }
    });

    test('소수: 0.1 단위 부호화와 표기가 맞는다', () {
      final generator = QuestionGenerator(random: Random(23));
      for (final maxNumber in [4, 9, 19]) {
        for (var round = 0; round < 20; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.decimal, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.decimal);
            expect(q.answer, inInclusiveRange(1, 19));
            expect(q.answerLabel, (q.answer / 10).toStringAsFixed(1));
            expect(q.choices, contains(q.answer));
            expect(q.choices.toSet(), hasLength(4));
            if (q.variant == 1) {
              // 비교: 정답이 보기 중 가장 크다
              expect(q.answer, q.choices.reduce((a, b) => a > b ? a : b));
            }
          }
        }
      }
    });

    test('분수 4학년 확장: 분모 12까지 나오고 뺄셈·가분수·대분수 유형이 맞는다', () {
      final generator = QuestionGenerator(random: Random(29));
      final seenVariants = <int>{};
      var bigDenominator = false;
      for (var round = 0; round < 120; round++) {
        final questions = generator.generate(
          const QuizConfig(mode: QuizMode.fraction, maxNumber: 12),
        );
        for (final q in questions) {
          expect(q.op, QuestionOp.fraction);
          seenVariants.add(q.variant);
          final n = q.answer ~/ 100;
          final d = q.answer % 100;
          expect(d, inInclusiveRange(2, 12));
          if (d >= 10) bigDenominator = true;
          expect(q.choices, hasLength(4));
          expect(q.choices.toSet(), hasLength(4));
          expect(q.choices, contains(q.answer));
          expect(q.answerLabel, '$n/$d');
          expect(q.answerSpeech, '$d분의 $n');
          switch (q.variant) {
            case 3: // 같은 분모 뺄셈: 문장에서 답을 다시 계산해 확인
              final match =
                  RegExp(r'^(\d+)/(\d+) - (\d+)/\d+ = \?$').firstMatch(q.prompt);
              expect(match, isNotNull, reason: q.prompt);
              expect(
                int.parse(match!.group(1)!) - int.parse(match.group(3)!),
                n,
              );
              expect(int.parse(match.group(2)!), d);
              expect(n, inInclusiveRange(1, d - 1));
            case 4: // 가분수 찾기: 정답만 분자가 분모 이상
              expect(n, greaterThanOrEqualTo(d));
              for (final c in q.choices.where((c) => c != q.answer)) {
                expect(c % 100, d);
                expect(c ~/ 100, lessThan(d));
              }
            case 5: // 대분수 → 가분수: w×d+p 확인
              final match = RegExp(r'^대분수 (\d+)[과와] (\d+)/(\d+)를 가분수로 바꾸면\?$')
                  .firstMatch(q.prompt);
              expect(match, isNotNull, reason: q.prompt);
              expect(int.parse(match!.group(3)!), d);
              expect(
                int.parse(match.group(1)!) * d + int.parse(match.group(2)!),
                n,
              );
          }
        }
      }
      expect(seenVariants, containsAll([3, 4, 5]));
      expect(bigDenominator, isTrue);
    });

    test('소수 4학년 확장: 2.0 이상 값과 뺄셈 유형이 나온다', () {
      final generator = QuestionGenerator(random: Random(33));
      var sawBig = false;
      var sawSub = false;
      for (final maxNumber in [20, 50]) {
        for (var round = 0; round < 60; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.decimal, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.decimal);
            expect(q.answer, inInclusiveRange(1, maxNumber));
            expect(q.answerLabel, (q.answer / 10).toStringAsFixed(1));
            expect(q.choices, contains(q.answer));
            expect(q.choices.toSet(), hasLength(4));
            if (q.answer >= 20) sawBig = true;
            if (q.variant == 2 || q.variant == 3) {
              final sign = q.variant == 2 ? r'\+' : '-';
              final match = RegExp('^(\\d+\\.\\d) $sign (\\d+\\.\\d) = \\?\$')
                  .firstMatch(q.prompt);
              expect(match, isNotNull, reason: q.prompt);
              final a = (double.parse(match!.group(1)!) * 10).round();
              final b = (double.parse(match.group(2)!) * 10).round();
              expect(q.answer, q.variant == 2 ? a + b : a - b);
              if (q.variant == 3) sawSub = true;
            }
          }
        }
      }
      expect(sawBig, isTrue);
      expect(sawSub, isTrue);
    });

    test('시간 계산: 분 부호화와 시각 표기가 맞는다', () {
      final generator = QuestionGenerator(random: Random(25));
      for (final maxNumber in [3, 8, 12]) {
        for (var round = 0; round < 20; round++) {
          final questions = generator.generate(
            QuizConfig(mode: QuizMode.timeCalc, maxNumber: maxNumber),
          );
          for (final q in questions) {
            expect(q.op, QuestionOp.timeCalc);
            expect(q.choices, contains(q.answer));
            expect(q.choices.toSet(), hasLength(4));
            if (q.variant == 1) {
              expect(q.answerLabel, '${q.answer}분');
            } else {
              // 시각: 12시를 넘지 않고, 정시는 'h시'·30분은 'h시 30분'
              expect(q.answer, lessThanOrEqualTo(12 * 60));
              final h = q.answer ~/ 60;
              final min = q.answer % 60;
              expect(q.answerLabel, min == 0 ? '$h시' : '$h시 $min분');
            }
          }
        }
      }
    });

    test('심화 단계도 커리큘럼에서 문제를 만들 수 있다', () {
      final generator = QuestionGenerator(random: Random(27));
      final advanced = Curriculum.categories.last;
      expect(advanced.title, '초3·4 심화');
      for (final unit in advanced.units) {
        for (var i = 0; i < Curriculum.levelsPerUnit; i++) {
          final level = Curriculum.levelAt(unit.firstLevelNumber + i);
          final questions = generator.generate(level.config);
          expect(questions, hasLength(10));
          for (var k = 1; k < questions.length; k++) {
            expect(questions[k].dedupKey, isNot(questions[k - 1].dedupKey));
          }
        }
      }
    });
  });
}
