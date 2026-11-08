import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/english_curriculum.dart';
import 'package:preschool_math/models/english_question.dart';
import 'package:preschool_math/models/english_vocab.dart';

void main() {
  test('영어 낱말은 전체에서 한 번, 한 주제 안에서 뜻·그림이 겹치지 않는다', () {
    expect({for (final v in enVocab) v.word}.length, enVocab.length);
    for (final theme in enThemes.keys) {
      final words = enVocab.where((v) => v.theme == theme).toList();
      expect(words.length, greaterThanOrEqualTo(8), reason: theme);
      expect({for (final v in words) v.ko}.length, words.length, reason: theme);
      expect({for (final v in words) v.emoji}.length, words.length,
          reason: theme);
    }
    for (final v in enVocab) {
      expect(enThemes.containsKey(v.theme), isTrue, reason: v.word);
      expect(RegExp(r'^[a-z]+$').hasMatch(v.word), isTrue, reason: v.word);
    }
  });

  test('사이트 워드는 겹치지 않는다', () {
    expect(enSightWords.toSet().length, enSightWords.length);
  });

  test('단어 퀴즈 문제: 보기 4개가 서로 다르고(뜻·그림도) 정답이 들어 있다', () {
    final gen = EnglishQuestionGenerator(random: Random(11));
    const types = [
      EnQuizType.themeWord,
      EnQuizType.meaningPick,
      EnQuizType.englishPick,
      EnQuizType.missingLetter,
      EnQuizType.sightWord,
    ];
    for (final type in types) {
      for (var stage = 0; stage < 10; stage++) {
        for (final theme in [
          null,
          'color,number',
          'body,family',
          'action,feeling'
        ]) {
          if (theme != null && type != EnQuizType.themeWord) continue;
          for (final q in gen.generate(type, stage: stage, theme: theme)) {
            expect(q.choices, hasLength(4), reason: '$type');
            expect(q.choices.toSet(), hasLength(4), reason: '${q.choices}');
            expect(q.choices, contains(q.answer));
          }
        }
      }
    }
  });

  test('주제 낱말 묶음은 그 주제 낱말만 낸다', () {
    final gen = EnglishQuestionGenerator(random: Random(2));
    final allowed = {
      for (final v in enVocab)
        if (v.theme == 'color' || v.theme == 'number') ...[
          v.word,
          v.emoji,
          v.ko,
          v.shown
        ]
    };
    for (var stage = 0; stage < 10; stage++) {
      for (final q in gen.generate(EnQuizType.themeWord,
          stage: stage, theme: 'color,number')) {
        for (final c in q.choices) {
          expect(allowed, contains(c), reason: c);
        }
      }
    }
  });

  test('뜻 문제는 답한 뒤 한국어 뜻을 한국어로, 영어로 고르기는 영어로 들려준다', () {
    final gen = EnglishQuestionGenerator(random: Random(3));
    final m = gen.generate(EnQuizType.meaningPick, count: 1).first;
    expect(m.revealLang, 'ko-KR');
    expect(m.speechLang, 'en-US');
    final e = gen.generate(EnQuizType.englishPick, count: 1).first;
    expect(e.speechLang, 'ko-KR');
    expect(e.revealLang, 'en-US');
  });

  test('빠진 글자: 빈칸을 정답으로 채우면 낱말이 된다', () {
    final gen = EnglishQuestionGenerator(random: Random(4));
    for (final q
        in gen.generate(EnQuizType.missingLetter, stage: 7, count: 30)) {
      expect(q.subDisplay.replaceAll(' ', '').replaceFirst('_', q.answer),
          q.answerText);
    }
  });

  test('영어 커리큘럼에 단어 퀴즈 묶음이 있고 주제 묶음은 주제를 가진다', () {
    final cat =
        EnglishCurriculum.categories.firstWhere((c) => c.title == '단어 퀴즈');
    for (final u in cat.units.where((u) => u.type == EnQuizType.themeWord)) {
      expect(u.theme, isNotNull, reason: u.title);
      for (final t in u.theme!.split(',')) {
        expect(enThemes.containsKey(t), isTrue, reason: t);
      }
    }
  });

  test('그림이 닮은 낱말(😴·😪, 👩·👧)은 한 문제 보기에 함께 안 나온다', () {
    final groupOf = <String, String>{
      for (final v in enVocab)
        if (v.group != null) ...{v.emoji: v.group!, v.shown: v.group!}
    };
    final gen = EnglishQuestionGenerator(random: Random(21));
    for (final type in [EnQuizType.themeWord, EnQuizType.meaningPick]) {
      for (var stage = 0; stage < 10; stage++) {
        for (final q in gen.generate(type, stage: stage)) {
          final groups = [
            for (final c in q.choices)
              if (groupOf[c] != null) groupOf[c]
          ];
          expect(groups.toSet().length, groups.length, reason: '${q.choices}');
        }
      }
    }
  });

  test('한 판에 같은 낱말이 정답으로 거듭 나오지 않는다 (낱말이 충분할 때)', () {
    final gen = EnglishQuestionGenerator(random: Random(8));
    final round = gen.generate(EnQuizType.meaningPick, stage: 9);
    expect({for (final q in round) q.answerText}.length, round.length);
  });

  test('단계가 오르면 낱말 범위가 넓어진다', () {
    final gen = EnglishQuestionGenerator(random: Random(6));
    Set<String> seen(int stage) => {
          for (var i = 0; i < 40; i++)
            for (final q in gen.generate(EnQuizType.themeWord,
                stage: stage, theme: 'animal'))
              q.answerText
        };
    expect(seen(9).length, greaterThan(seen(0).length));
  });
}
