import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/korean_data.dart';
import 'package:preschool_math/models/korean_question.dart';

void main() {
  group('KoreanQuestionGenerator', () {
    test('그림→낱말: 그림에 맞는 낱말이 정답이다', () {
      final generator = KoreanQuestionGenerator(random: Random(1));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(KrQuizType.pictureToWord);
        expect(questions, hasLength(10));
        for (final q in questions) {
          final word = krWords2.firstWhere((w) => w.emoji == q.display);
          expect(q.answer, word.word);
          expect(q.choices, hasLength(4));
          expect(q.choices.toSet(), hasLength(4));
          expect(q.choices, contains(q.answer));
        }
      }
    });

    test('긴 낱말 도전: 세 글자 낱말이 나온다', () {
      final generator = KoreanQuestionGenerator(random: Random(2));
      final questions = generator.generate(KrQuizType.longWord);
      for (final q in questions) {
        expect(q.answer.length, 3);
        expect(krWords3.any((w) => w.word == q.answer), isTrue);
      }
    });

    test('낱말→그림: 낱말에 맞는 그림이 정답이다', () {
      final generator = KoreanQuestionGenerator(random: Random(3));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(KrQuizType.wordToPicture);
        for (final q in questions) {
          final word = krAllWords.firstWhere((w) => w.word == q.display);
          expect(q.answer, word.emoji);
          expect(q.emojiChoices, isTrue);
          expect(q.choices, contains(q.answer));
        }
      }
    });

    test('첫소리 찾기: 낱말의 초성이 정답이고 기본 자음만 나온다', () {
      final generator = KoreanQuestionGenerator(random: Random(5));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(KrQuizType.firstConsonant);
        for (final q in questions) {
          expect(q.answer, krFirstConsonant(q.subDisplay));
          expect(krBasicConsonants, contains(q.answer));
          for (final choice in q.choices) {
            expect(krBasicConsonants, contains(choice));
          }
        }
      }
    });

    test('빈칸 채우기: 정답을 넣으면 원래 낱말이 되고, 오답으로는 낱말이 안 된다', () {
      final generator = KoreanQuestionGenerator(random: Random(7));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(KrQuizType.fillBlank, stage: 7);
        for (final q in questions) {
          expect(q.subDisplay, contains('□'));
          final restored = q.subDisplay.replaceFirst('□', q.answer);
          final word = krAllWords.firstWhere((w) => w.word == restored);
          expect(word.emoji, q.display);
          // 오답을 넣으면 낱말 사전에 없는 말이어야 한다.
          for (final choice in q.choices.where((c) => c != q.answer)) {
            final wrongWord = q.subDisplay.replaceFirst('□', choice);
            expect(krAllWords.any((w) => w.word == wrongWord), isFalse,
                reason: '$wrongWord도 말이 되면 정답이 두 개가 된다');
          }
        }
      }
    });

    test('가나다 순서: 보여준 세 글자의 다음 글자가 정답이다', () {
      final generator = KoreanQuestionGenerator(random: Random(9));
      for (var round = 0; round < 30; round++) {
        final questions = generator.generate(KrQuizType.syllableOrder);
        for (final q in questions) {
          final shown =
              q.display.replaceAll('?', '').trim().split(RegExp(r'\s+'));
          expect(shown, hasLength(3));
          final start = krSyllablesA.indexOf(shown.first);
          expect(start, greaterThanOrEqualTo(0));
          expect(shown, krSyllablesA.sublist(start, start + 3));
          expect(q.answer, krSyllablesA[start + 3]);
          expect(q.choices, contains(q.answer));
        }
      }
    });

    test('듣기 문제: 소리가 있고 정답이 보기에 있다', () {
      final generator = KoreanQuestionGenerator(random: Random(11));
      for (final type in [KrQuizType.listenVowel, KrQuizType.listenSyllable]) {
        for (final stage in [0, 9]) {
          final questions = generator.generate(type, stage: stage);
          for (final q in questions) {
            expect(q.display, '🔊');
            expect(q.speech, isNotEmpty);
            expect(q.choices, hasLength(4));
            expect(q.choices.toSet(), hasLength(4));
            expect(q.choices, contains(q.answer));
          }
        }
      }
    });

    test('같은 문제가 연달아 나오지 않는다', () {
      final generator = KoreanQuestionGenerator(random: Random(13));
      for (final type in KrQuizType.values) {
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
