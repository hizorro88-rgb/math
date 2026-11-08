import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/english_phonics.dart';
import 'package:preschool_math/models/english_question.dart';

void main() {
  const phonicsTypes = [
    EnQuizType.letterSound,
    EnQuizType.shortVowel,
    EnQuizType.decode,
    EnQuizType.rhyme,
    EnQuizType.cluster,
  ];

  test('파닉스 문제는 보기 4개가 서로 다르고 정답이 들어 있다', () {
    final gen = EnglishQuestionGenerator(random: Random(3));
    for (final type in phonicsTypes) {
      for (var stage = 0; stage < 10; stage++) {
        for (final q in gen.generate(type, stage: stage)) {
          expect(q.choices, hasLength(4), reason: '$type $stage');
          expect(q.choices.toSet(), hasLength(4), reason: '${q.choices}');
          expect(q.choices, contains(q.answer));
        }
      }
    }
  });

  test('글자 소리: 정답은 그 글자 그림, 오답은 소리가 다른 글자 그림', () {
    String letterOf(String emoji) => phonicsLetterWords.entries
        .firstWhere((e) => e.value.any((w) => w.emoji == emoji))
        .key;
    final gen = EnglishQuestionGenerator(random: Random(5));
    for (var i = 0; i < 300; i++) {
      final stage = i % 10;
      final q =
          gen.generate(EnQuizType.letterSound, stage: stage, count: 1).first;
      final letter = q.speech;
      expect(letterOf(q.answer), letter);
      for (final c in q.choices.where((c) => c != q.answer)) {
        expect(phonicsSoundGroup(letterOf(c)), isNot(phonicsSoundGroup(letter)),
            reason: '$letter vs $c');
      }
      if (stage < 5) {
        expect('CGHWAEIOUQ'.contains(letter), isFalse,
            reason: '앞 단계는 이름에 소리가 든 글자만');
      }
    }
  });

  test('첫소리 그림 낱말은 그 글자로 시작하고 그림이 겹치지 않는다', () {
    final emojis = <String>{};
    for (final e in phonicsLetterWords.entries) {
      for (final w in e.value) {
        expect(w.shown.startsWith(e.key), isTrue, reason: w.word);
        expect(emojis.add(w.emoji), isTrue, reason: '겹친 그림 ${w.emoji}');
        expect(RegExp(r'^(sh|ch|th|wh)').hasMatch(w.word), isFalse);
      }
    }
  });

  test('가운데 소리: 낱말은 짧은 모음 하나, 빈칸이 그 모음 자리다', () {
    for (final w in phonicsCvc) {
      final vowels = w.shown.split('').where(phonicsVowels.contains).length;
      expect(vowels, 1, reason: w.word);
    }
    final gen = EnglishQuestionGenerator(random: Random(1));
    for (final q in gen.generate(EnQuizType.shortVowel, count: 30)) {
      expect(q.subDisplay.replaceAll(' ', '').replaceFirst('_', q.answer),
          q.answerText);
    }
  });

  test('혼자 읽기: 보기에 같은 뜻 그림(🎩·🧢, 🥤·☕)이 함께 나오지 않는다', () {
    final gen = EnglishQuestionGenerator(random: Random(4));
    for (var stage = 0; stage < 10; stage++) {
      for (var i = 0; i < 20; i++) {
        final q = gen.generate(EnQuizType.decode, stage: stage, count: 1).first;
        expect(q.choices.toSet().containsAll(['🎩', '🧢']), isFalse);
        expect(q.choices.toSet().containsAll(['🥤', '☕']), isFalse);
      }
    }
  });

  test('끝소리 짝: 정답은 같은 모둠, 오답은 다른 모둠', () {
    String family(String word) => phonicsRhymes.entries
        .firstWhere((e) => e.value.any((w) => w.word == word))
        .key;
    final gen = EnglishQuestionGenerator(random: Random(9));
    for (var stage = 0; stage < 10; stage++) {
      for (final q in gen.generate(EnQuizType.rhyme, stage: stage)) {
        final target = family(q.speech);
        final answer = q.answer.split(' ').last.toLowerCase();
        expect(family(answer), target);
        for (final c in q.choices.where((c) => c != q.answer)) {
          final other = family(c.split(' ').last.toLowerCase());
          expect(other, isNot(target));
          expect(other[1], isNot(target[1]), reason: '모음이 같은 모둠은 오답으로 안 낸다');
        }
      }
    }
  });

  test('두 글자 소리: 빈칸을 채우면 낱말이 된다', () {
    for (final c in [...phonicsDigraphs, ...phonicsBlends]) {
      expect(c.word.toUpperCase().startsWith(c.sound), isTrue, reason: c.word);
      expect(c.blanked.startsWith('_ _ '), isTrue);
    }
  });

  test('혼자 읽기는 처음에 읽어 주지 않고, 답한 뒤에 들려준다', () {
    final q = EnglishQuestionGenerator(random: Random(2))
        .generate(EnQuizType.decode, count: 1)
        .first;
    expect(q.speech, isEmpty);
    expect(q.readAlone, isTrue);
    expect(q.revealSpeech, isNotEmpty);
  });
}
