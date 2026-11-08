import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/hanja_pack.dart';
import 'package:preschool_math/models/japanese_pack.dart';

void main() {
  test('8급은 50자, 글자가 겹치지 않는다', () {
    expect(hanjaGrade8, hasLength(50));
    expect({for (final c in hanjaGrade8) c.char}.length, 50);
  });

  test('한자어는 8급 글자로만, 읽기는 각 글자의 음을 이은 것', () {
    final eum = {for (final c in hanjaGrade8) c.char: c.eum};
    for (final (word, reading) in hanjaWords8) {
      final parts = word.split('');
      expect(parts.every(eum.containsKey), isTrue, reason: word);
      expect(parts.map((c) => eum[c]).join(), reading, reason: word);
    }
  });

  test('8급 문제·한자어 문제: 보기 4개가 다르고 정답이 들어 있다', () {
    final random = Random(3);
    for (final type in [5, 6, 7, 8, 9, 10]) {
      for (var stage = 0; stage < 10; stage++) {
        for (var i = 0; i < 20; i++) {
          final q = hanjaPack.generateOne!(type, stage, random);
          expect(q.typeIndex, type);
          if (type == 10) {
            expect(q.pairs, hasLength(4));
            expect({for (final p in q.pairs) p.$2}, hasLength(4));
            continue;
          }
          expect(q.choices.toSet(), hasLength(4), reason: '${q.choices}');
          expect(q.choices, contains(q.answer));
        }
      }
    }
  });

  test('8급 묶음이 천자문보다 먼저 나온다', () {
    expect(hanjaPack.categories.first.title, '8급 한자');
  });

  test('일본어 てんてん: 맑은 소리 짝이 보기에 꼭 있다', () {
    final random = Random(5);
    final ja = japanesePack;
    for (var stage = 0; stage < 10; stage++) {
      for (var i = 0; i < 20; i++) {
        final q = ja.generateOne!(9, stage, random);
        expect(q.choices.toSet(), hasLength(4));
        expect(q.choices, contains(q.answer));
        final plain = jaDakuon.firstWhere((d) => d.$1 == q.answer).$2;
        expect(q.choices, contains(plain));
      }
    }
  });
}
