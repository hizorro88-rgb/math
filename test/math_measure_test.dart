import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/curriculum.dart';
import 'package:preschool_math/models/question.dart';

void main() {
  Level levelOf(String title, int i) {
    final u = Curriculum.units.firstWhere((u) => u.title == title);
    return Curriculum.levelAt(u.firstLevelNumber + i);
  }

  List<Question> round(String title, int i, [int seed = 1]) =>
      QuestionGenerator(random: Random(seed + i))
          .generate(levelOf(title, i).config);

  void basic(Question q) {
    expect(q.choices.toSet().length, 4, reason: '${q.prompt} ${q.choices}');
    expect(q.choices, contains(q.answer));
    expect(q.answer, greaterThanOrEqualTo(0));
  }

  test('몇 시 몇 분: 5분 단위부터, 뒤 단계는 1분 단위도', () {
    var oneMinute = false;
    for (var i = 0; i < 10; i++) {
      for (final q in round('몇 시 몇 분', i)) {
        basic(q);
        expect(q.op, QuestionOp.clock);
        final m = q.answer % 60;
        if (i == 0) expect(m % 5, 0);
        if (m % 5 != 0) oneMinute = true;
        expect(q.answerLabel, contains('시'));
      }
    }
    expect(oneMinute, isTrue);
  });

  test('돈: 동전 합이 정답, 거스름돈은 낸 돈 - 값', () {
    for (final title in ['동전 세기', '돈 계산']) {
      for (var i = 0; i < 10; i++) {
        for (final q in round(title, i)) {
          basic(q);
          if (q.variant == 0) {
            expect(q.sequence.fold(0, (a, b) => a + b), q.answer);
            expect(q.answerLabel, endsWith('원'));
          } else {
            expect(q.answer + q.right, q.sequence.first);
          }
        }
      }
    }
  });

  test('길이: 끝 눈금 - 시작 눈금 = 정답, 자 밖으로 안 나간다', () {
    for (var i = 0; i < 10; i++) {
      for (final q in round('길이 재기', i)) {
        basic(q);
        final s = q.sequence;
        expect(s[1] - s[0], q.answer);
        expect(s[1], lessThanOrEqualTo(s[2]));
      }
    }
  });

  test('도형: 꼭짓점 수 = 변 수 (원은 0)', () {
    for (var i = 0; i < 10; i++) {
      for (final q in round('도형의 꼭짓점과 변', i)) {
        basic(q);
        expect(q.answer, q.sequence.first);
        expect({0, 3, 4, 5, 6}, contains(q.answer));
      }
    }
  });

  test('그래프 읽기: 개수가 서로 다르고 질문에 맞는 정답', () {
    for (var i = 0; i < 10; i++) {
      for (final q in round('그래프 읽기', i)) {
        basic(q);
        final c = q.sequence;
        expect(c.toSet().length, c.length);
        expect(q.shapeItems.length, c.length);
        if (q.variant == 1) expect(q.answer, c.reduce(max));
        if (q.variant == 2) expect(q.answer, c.reduce(max) - c.reduce(min));
      }
    }
  });

  test('단위 바꾸기: 식이 맞다', () {
    for (var i = 0; i < 10; i++) {
      for (final q in round('단위 바꾸기', i)) {
        basic(q);
        final nums = RegExp(r'\d+')
            .allMatches(q.prompt)
            .map((m) => int.parse(m.group(0)!))
            .toList();
        if (q.variant == 0) {
          expect(nums[0] * q.right + nums[1], q.answer);
        } else {
          expect(q.answer * q.right + nums[1], nums[0]);
        }
      }
    }
  });
}
