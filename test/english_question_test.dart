import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/english_data.dart';
import 'package:preschool_math/models/english_question.dart';

void main() {
  group('EnglishQuestionGenerator', () {
    test('낱말 듣기: 낱말에 맞는 그림이 정답이고 발음은 영어다', () {
      final generator = EnglishQuestionGenerator(random: Random(1));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(EnQuizType.wordToPicture);
        for (final q in questions) {
          final word = enAllWords.firstWhere((w) => w.shown == q.display);
          expect(q.answer, word.emoji);
          expect(q.speech, word.word);
          expect(q.speechLang, 'en-US');
          expect(q.emojiChoices, isTrue);
          expect(q.choices, contains(q.answer));
        }
      }
    });

    test('그림→낱말: 그림에 맞는 대문자 낱말이 정답이다', () {
      final generator = EnglishQuestionGenerator(random: Random(3));
      for (final type in [EnQuizType.pictureToWord, EnQuizType.longWord]) {
        final questions = generator.generate(type, stage: 9);
        for (final q in questions) {
          final word = enAllWords.firstWhere((w) => w.emoji == q.display);
          expect(q.answer, word.shown);
          expect(q.answer, q.answer.toUpperCase());
          expect(q.choices, contains(q.answer));
          expect(q.choices.toSet(), hasLength(4));
        }
      }
    });

    test('알파벳 소리·대소문자 짝·순서가 규칙에 맞는다', () {
      final generator = EnglishQuestionGenerator(random: Random(5));
      for (final stage in [0, 9]) {
        for (final q in generator.generate(EnQuizType.listenLetter,
            stage: stage)) {
          expect(q.display, '🔊');
          expect(enAlphabet, contains(q.answer));
          expect(q.choices, contains(q.answer));
        }
        for (final q
            in generator.generate(EnQuizType.caseMatch, stage: stage)) {
          // 보여준 글자와 정답은 같은 알파벳의 다른 케이스다.
          expect(q.display.toUpperCase(), q.answer.toUpperCase());
          expect(q.display, isNot(q.answer));
          expect(q.choices, contains(q.answer));
        }
        for (final q
            in generator.generate(EnQuizType.alphabetOrder, stage: stage)) {
          final shown =
              q.display.replaceAll('?', '').trim().split(RegExp(r'\s+'));
          final start = enAlphabet.indexOf(shown.first);
          expect(shown, enAlphabet.sublist(start, start + 3));
          expect(q.answer, enAlphabet[start + 3]);
        }
      }
    });

    test('첫 글자 찾기: 낱말의 첫 알파벳이 정답이다', () {
      final generator = EnglishQuestionGenerator(random: Random(7));
      for (final q in generator.generate(EnQuizType.firstLetter, stage: 9)) {
        expect(q.answer, q.subDisplay[0]);
        expect(q.choices, contains(q.answer));
      }
    });

    test('낱말 만들기: 타일로 낱말을 조립할 수 있다', () {
      final generator = EnglishQuestionGenerator(random: Random(9));
      for (final stage in [0, 9]) {
        for (final q
            in generator.generate(EnQuizType.wordBuild, stage: stage)) {
          expect(q.tiles, hasLength(q.answer.length + 2));
          final remaining = [...q.tiles];
          for (final ch in q.answer.split('')) {
            expect(remaining.remove(ch), isTrue,
                reason: '$ch가 타일에 부족함 (${q.answer})');
          }
        }
      }
    });

    test('같은 문제가 연달아 나오지 않는다', () {
      final generator = EnglishQuestionGenerator(random: Random(11));
      for (final type in EnQuizType.values) {
        for (var round = 0; round < 10; round++) {
          final questions = generator.generate(type);
          for (var i = 1; i < questions.length; i++) {
            expect(questions[i].dedupKey, isNot(questions[i - 1].dedupKey));
          }
        }
      }
    });
  });
}
