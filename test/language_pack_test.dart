import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/language_packs.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  group('언어 팩 공통', () {
    test('팩 id는 중복이 없고, 단계 번호가 1부터 이어진다', () {
      expect(
        languagePacks.map((p) => p.id).toSet(),
        hasLength(languagePacks.length),
      );
      for (final pack in languagePacks) {
        expect(pack.totalLevels,
            pack.units.length * LanguagePack.levelsPerUnit);
        for (var i = 0; i < pack.totalLevels; i++) {
          expect(pack.levels[i].number, i + 1);
          expect(pack.levelAt(i + 1).number, i + 1);
        }
        // 모든 유닛의 typeIndex가 유효하다.
        for (final unit in pack.units) {
          expect(unit.typeIndex, lessThan(pack.types.length));
        }
      }
    });

    test('모든 단계에서 문제를 만들 수 있다 (보기·타일 규칙)', () {
      for (final pack in languagePacks) {
        final random = Random(7);
        for (final level in pack.levels) {
          final questions = pack.generate(level.unit.typeIndex,
              stage: level.stage, random: random);
          expect(questions, hasLength(10));
          for (final q in questions) {
            if (pack.types[q.typeIndex].speaking) {
              // 말하기 문제는 보기 없이 마이크로 푼다.
              expect(q.choices, isEmpty, reason: pack.id);
              expect(q.answer, isNotEmpty, reason: pack.id);
            } else if (q.tiles.isNotEmpty) {
              // 글자 단위(일본어)든 단어 단위(영어회화)든 타일만으로 정답을 만든다.
              final remaining = [...q.tiles];
              final pieces = q.tileJoin.isEmpty
                  ? q.answer.split('')
                  : q.answer.split(q.tileJoin);
              expect(pieces, hasLength(q.slotCount), reason: pack.id);
              for (final piece in pieces) {
                expect(remaining.remove(piece), isTrue,
                    reason: '${pack.id}: $piece가 타일에 부족 (${q.answer})');
              }
            } else {
              expect(q.choices, hasLength(4), reason: pack.id);
              expect(q.choices.toSet(), hasLength(4), reason: pack.id);
              expect(q.choices, contains(q.answer), reason: pack.id);
            }
            expect(q.speech, isNotEmpty);
          }
          // 연속 중복 없음
          for (var i = 1; i < questions.length; i++) {
            expect(questions[i].dedupKey, isNot(questions[i - 1].dedupKey));
          }
        }
      }
    });

    test('별 저장·잠금 해제가 팩마다 분리된다', () async {
      await LangProgressStore.saveStars(japanesePack, 1, 3);
      expect((await LangProgressStore.load(japanesePack))[0], 3);
      expect((await LangProgressStore.load(chinesePack))[0], 0);

      final zeros = List.filled(japanesePack.totalLevels, 0);
      for (final category in japanesePack.categories) {
        expect(
          LangProgressStore.isUnlocked(
              japanesePack, zeros, category.firstLevelNumber),
          isTrue,
        );
      }
      expect(LangProgressStore.isUnlocked(japanesePack, zeros, 2), isFalse);
    });

    test('유형별 통계가 팩 id로 분리 저장된다', () async {
      await StatsStore.recordLangAnswer(japanesePack, 0, correct: true);
      await StatsStore.recordLangAnswer(japanesePack, 0, correct: true);
      await StatsStore.recordLangAnswer(chinesePack, 4, correct: false);

      final stats = await StatsStore.load();
      expect(stats.langCorrect['ja']![0], 2);
      expect(stats.langWrong['zh']![4], 1);
      expect(stats.langAnswered('ja'), 2);
      expect(stats.langAnswered('zh'), 1);
      expect(stats.totalAnswered, 3);
    });
  });

  group('일본어 팩 — 가타카나', () {
    test('히라가나·가타카나 목록이 같은 순서로 짝을 이룬다', () {
      expect(jaKatakana, hasLength(jaKana.length));
    });

    test('짝 맞추기: 보여준 글자와 정답이 같은 자리의 짝이다', () {
      final random = Random(31);
      for (final stage in [0, 9]) {
        for (var round = 0; round < 40; round++) {
          final q = japanesePack.generateOne!(7, stage, random);
          final hiraIndex = jaKana.indexOf(q.display);
          final kataIndex = jaKatakana.indexOf(q.display);
          if (hiraIndex >= 0) {
            expect(q.answer, jaKatakana[hiraIndex]);
          } else {
            expect(kataIndex, greaterThanOrEqualTo(0));
            expect(q.answer, jaKana[kataIndex]);
          }
          expect(q.choices, contains(q.answer));
        }
      }
    });

    test('가타카나 낱말: 그림에 맞는 낱말이 정답이다', () {
      final random = Random(33);
      for (var round = 0; round < 30; round++) {
        final q = japanesePack.generateOne!(8, 0, random);
        final word = jaKataWords.firstWhere((w) => w.emoji == q.display);
        expect(q.answer, word.word);
      }
    });
  });

  group('중국어 팩 — 한자 박사', () {
    test('듣고 한자 찾기: 들려준 한자가 정답이다', () {
      final random = Random(35);
      for (final stage in [0, 9]) {
        final q = chinesePack.generateOne!(5, stage, random);
        expect(q.display, '🔊');
        expect(q.speech, q.answer);
        expect(q.choices, contains(q.answer));
      }
    });

    test('한자 뜻 찾기: 우리말 뜻이 정답이다', () {
      final random = Random(37);
      for (var round = 0; round < 40; round++) {
        final q = chinesePack.generateOne!(6, 0, random);
        expect(q.answer, zhMeanings[q.display]);
        expect(q.choices, contains(q.answer));
        expect(q.choices.toSet(), hasLength(4));
      }
    });
  });

  group('일본어 팩', () {
    test('첫 글자 찾기·낱말 문제가 규칙에 맞는다', () {
      final random = Random(5);
      for (var round = 0; round < 30; round++) {
        final q = japanesePack.generateOne!(4, 0, random); // 첫 글자 찾기
        expect(q.answer, q.subDisplay[0]);
        final word = jaWords.firstWhere((w) => w.word == q.subDisplay);
        expect(word.emoji, q.display);
      }
      for (var round = 0; round < 30; round++) {
        final q = japanesePack.generateOne!(3, 9, random); // 그림→낱말
        final word = jaWords.firstWhere((w) => w.emoji == q.display);
        expect(q.answer, word.word);
      }
    });
  });

  group('중국어 팩', () {
    test('숫자 한자·숫자 소리가 규칙에 맞는다', () {
      final random = Random(9);
      for (var round = 0; round < 30; round++) {
        final q = chinesePack.generateOne!(4, 9, random); // 3 → 三
        final digit = int.parse(q.display);
        expect(q.answer, zhNumbers[digit - 1]);
        expect(q.choices, contains(q.answer));
      }
      for (var round = 0; round < 30; round++) {
        final q = chinesePack.generateOne!(1, 9, random); // 소리 → 숫자
        final digit = int.parse(q.answer);
        expect(q.speech, zhNumbers[digit - 1]);
      }
    });
  });

  group('한자 팩 (천자문)', () {
    test('훈음·구절 완성이 규칙에 맞는다', () {
      final random = Random(11);
      for (var round = 0; round < 30; round++) {
        final q = hanjaPack.generateOne!(1, 0, random); // 한자 → 훈음
        final c = hanjaChars.firstWhere((h) => h.char == q.display);
        expect(q.answer, c.reading);
        expect(q.choices, contains(q.answer));
        expect(q.choices.toSet(), hasLength(4));
      }
      for (var round = 0; round < 30; round++) {
        final q = hanjaPack.generateOne!(2, 9, random); // 훈음 → 한자
        final c = hanjaChars.firstWhere((h) => h.reading == q.display);
        expect(q.answer, c.char);
      }
      for (var round = 0; round < 30; round++) {
        final q = hanjaPack.generateOne!(4, 0, random); // 구절 완성 (앞 단계)
        expect(q.display, contains('□'));
        // 가린 글자를 채우면 천자문 구절이 된다.
        final filled = q.display.replaceAll(' ', '').replaceFirst('□', q.answer);
        expect(
          hanjaPhrases.map((p) => p.map((c) => c.char).join()),
          contains(filled),
        );
        expect(q.choices, contains(q.answer));
      }
      for (var round = 0; round < 30; round++) {
        final q = hanjaPack.generateOne!(3, 9, random); // 그림 → 한자
        final c = hanjaChars.firstWhere((h) => h.emoji == q.display);
        expect(q.answer, c.char);
      }
    });

    test('훈음이 같은 글자(집 우·집 주)는 서로 오답으로 안 나온다', () {
      final random = Random(13);
      for (var round = 0; round < 200; round++) {
        final q = hanjaPack.generateOne!(0, 9, random);
        final readings = [
          for (final ch in q.choices)
            hanjaChars.firstWhere((h) => h.char == ch).reading,
        ];
        expect(readings.toSet(), hasLength(4));
      }
    });
  });
}
