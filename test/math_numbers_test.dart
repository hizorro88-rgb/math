import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/curriculum.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/models/question.dart';
import 'package:preschool_math/models/quiz_config.dart';

void main() {
  List<Question> gen(QuizConfig c, [int seed = 1]) =>
      QuestionGenerator(random: Random(seed)).generate(c);

  Level levelOf(String title, int i) {
    final u = Curriculum.units.firstWhere((u) => u.title == title);
    return Curriculum.levelAt(u.firstLevelNumber + i);
  }

  test('받아올림·받아내림 단원은 모든 문제에서 실제로 받아올림이 생긴다', () {
    for (final title in ['받아올림 덧셈', '받아올림 세로 덧셈']) {
      for (var i = 0; i < 10; i++) {
        for (var seed = 0; seed < 5; seed++) {
          for (final q in gen(levelOf(title, i).config, seed)) {
            expect(q.left % 10 + q.right % 10, greaterThanOrEqualTo(10),
                reason: '$title ${q.left}+${q.right}');
          }
        }
      }
    }
    for (final title in ['받아내림 뺄셈', '받아내림 세로 뺄셈']) {
      for (var i = 0; i < 10; i++) {
        for (var seed = 0; seed < 5; seed++) {
          for (final q in gen(levelOf(title, i).config, seed)) {
            expect(q.left % 10 < q.right % 10, isTrue,
                reason: '$title ${q.left}-${q.right}');
            expect(q.answer, greaterThanOrEqualTo(0));
          }
        }
      }
    }
  });

  test('자릿값: 보기 4개가 다르고 정답이 들어 있으며, 모형 수가 정답과 맞다', () {
    for (final title in ['몇십 몇', '세 자리 수']) {
      for (var i = 0; i < 10; i++) {
        for (final q in gen(levelOf(title, i).config, i)) {
          expect(q.op, QuestionOp.place);
          expect(q.choices.toSet().length, 4, reason: '${q.choices}');
          expect(q.choices, contains(q.answer));
          if (q.variant == 0) {
            final s = q.sequence;
            expect(s[0] * 100 + s[1] * 10 + s[2], q.answer);
          }
          if (q.variant == 2) {
            expect('${q.right}'.contains('${q.answer}'), isTrue);
          }
        }
      }
    }
  });

  test('나머지 나눗셈: 나머지는 나누는 수보다 작고, 식이 맞다', () {
    for (var i = 0; i < 10; i++) {
      for (final q in gen(levelOf('나머지가 있는 나눗셈', i).config, i)) {
        expect(q.op, QuestionOp.remainder);
        expect(q.choices.toSet().length, 4);
        expect(q.choices, contains(q.answer));
        final m =
            RegExp(r'(\d+) ÷ (\d+) = (\S+) … (\S+)').firstMatch(q.prompt)!;
        final total = int.parse(m.group(1)!);
        final divisor = int.parse(m.group(2)!);
        final quotient = total ~/ divisor;
        final rest = total % divisor;
        expect(rest, greaterThan(0));
        expect(q.answer, q.variant == 0 ? rest : quotient);
        if (q.variant == 0) {
          for (final c in q.choices) {
            expect(c, lessThan(divisor + 3));
          }
        }
      }
    }
  });

  test('이야기 문제: 문장 속 수로 식을 세우면 정답이 나오고, 조사가 받침에 맞다', () {
    for (final (title, ops) in [
      ('이야기 문제', {QuestionOp.add, QuestionOp.sub}),
      ('이야기 문제 도전', {QuestionOp.add, QuestionOp.sub}),
      ('곱셈 이야기', {QuestionOp.mul}),
      ('나눗셈 이야기', {QuestionOp.div}),
    ]) {
      for (var i = 0; i < 10; i++) {
        for (final q in gen(levelOf(title, i).config, i)) {
          expect(ops, contains(q.op), reason: title);
          expect(q.prompt, isNotEmpty);
          expect(q.choices, contains(q.answer));
          expect(q.answer, greaterThanOrEqualTo(0));
          if (q.op == QuestionOp.div) expect(q.left % q.right, 0);
          // 받침 있는 말 + 가/는/를, 받침 없는 말 + 이/은/을 같은 어색한 조사 없음
          for (final bad in ['사과이', '쿠키이', '연필가', '달걀가', '물고기이', '딸기이']) {
            expect(q.speechText.contains(bad), isFalse, reason: q.speechText);
          }
        }
      }
    }
  });

  test('새 묶음이 나이 순서대로 들어갔다', () {
    String catOf(String title) =>
        Curriculum.units.firstWhere((u) => u.title == title).category.title;
    expect(catOf('이야기 문제'), '7살');
    expect(catOf('몇십 몇'), '초등 1학년');
    expect(catOf('세 자리 수'), '초등 2학년');
    expect(catOf('곱셈 이야기'), '초등 2학년');
    expect(catOf('나머지가 있는 나눗셈'), '초등 3학년');
  });

  test('앞에 새 묶음이 들어와도 이미 별을 받은 단계는 열려 있다', () {
    final u = Curriculum.units.firstWhere((u) => u.title == '받아올림 덧셈');
    final stars = List.filled(Curriculum.totalLevels, 0);
    stars[u.firstLevelNumber - 1] = 3; // 예전에 깬 첫 단계
    // 바로 앞 단계(새로 들어온 묶음 쪽)는 0개여도
    expect(ProgressStore.isUnlocked(stars, u.firstLevelNumber), isTrue);
    expect(ProgressStore.isUnlocked(stars, u.firstLevelNumber + 1), isTrue);
    expect(ProgressStore.isUnlocked(stars, u.firstLevelNumber + 2), isFalse);
  });

  test('수 뒤 조사: 3은·2는·10은', () {
    expect(numJosa(3, '은', '는'), '은');
    expect(numJosa(2, '은', '는'), '는');
    expect(numJosa(10, '은', '는'), '은');
    expect(numJosa(15, '은', '는'), '는');
    final q = Question(
        op: QuestionOp.add, left: 4, right: 3, choices: [7], emoji: '');
    expect(q.speechText, '4 더하기 3은?');
  });

  test('세 자리 수 묶음은 첫 단계부터 세 자리 수', () {
    for (final q in gen(levelOf('세 자리 수', 0).config)) {
      if (q.variant != 2) expect(q.answer, greaterThanOrEqualTo(100));
    }
  });
}
