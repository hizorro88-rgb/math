import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/english_curriculum.dart';
import 'package:preschool_math/models/english_question.dart';
import 'package:preschool_math/models/korean_curriculum.dart';
import 'package:preschool_math/models/korean_question.dart';
import 'package:preschool_math/models/language_packs.dart';
import 'package:preschool_math/models/learn_cards.dart';
import 'package:preschool_math/screens/learn_cards_screen.dart';
import 'package:preschool_math/services/sounds.dart';
import 'package:preschool_math/services/speech.dart';
import 'package:preschool_math/theme.dart';

/// 카드 하나하나가 이번 판의 어떤 문제와 같은 것인지
bool _inRound(LearnCard c, Iterable<List<String>> round) {
  final keys = c.matchKeys.map((k) => k.trim().toLowerCase()).toSet();
  return round.any((q) =>
      q.any((k) => k.isNotEmpty && keys.contains(k.trim().toLowerCase())));
}

void main() {
  test('배우기 카드는 이번 판에 나오는 것만, 8장까지 (첫 단계·6단계)', () {
    for (var rep = 0; rep < 5; rep++) {
      for (final u in EnglishCurriculum.units) {
        final levels =
            EnglishCurriculum.levels.where((l) => l.unit.index == u.index);
        for (final l in levels.where((l) => l.indexInUnit % 5 == 0)) {
          final qs = EnglishQuestionGenerator()
              .generate(u.type, stage: l.stage, theme: u.theme);
          final cards = englishLearnCards(u.type, qs);
          final keys = [
            for (final q in qs)
              [q.answer, q.answerText, q.revealSpeech, q.speech, q.display]
          ];
          if (englishCardPool(u.type).isNotEmpty) {
            expect(cards, isNotEmpty, reason: '${u.title} ${l.stage}');
          }
          expect(cards.length, lessThanOrEqualTo(learnCardLimit));
          for (final c in cards) {
            expect(c.speech, isNotEmpty);
            expect(_inRound(c, keys), isTrue, reason: '${u.title}: ${c.label}');
          }
        }
      }
      for (final u in KoreanCurriculum.units) {
        final levels =
            KoreanCurriculum.levels.where((l) => l.unit.index == u.index);
        for (final l in levels.where((l) => l.indexInUnit % 5 == 0)) {
          final qs = KoreanQuestionGenerator().generate(u.type, stage: l.stage);
          final cards = koreanLearnCards(u.type, qs);
          if (koreanCardPool(u.type).isNotEmpty) {
            expect(cards, isNotEmpty, reason: '${u.title} ${l.stage}');
          }
          expect(cards.length, lessThanOrEqualTo(learnCardLimit));
        }
      }
      final hanja = languagePacks.firstWhere((p) => p.id == 'hanja');
      for (final u in hanja.units) {
        final levels = hanja.levels.where((l) => l.unit.index == u.index);
        for (final l in levels.where((l) => l.indexInUnit % 5 == 0)) {
          final qs =
              hanja.generate(u.typeIndex, stage: l.stage, unitIndex: u.index);
          final cards = langLearnCards(hanja, u.typeIndex, qs);
          if (langCardPool(hanja, u.typeIndex).isNotEmpty) {
            expect(cards, isNotEmpty, reason: '${u.title} ${l.stage}');
          }
        }
      }
    }
  });

  test('순서·짝 맞추기처럼 미리 볼 것이 없는 유형은 카드가 없다', () {
    expect(englishCardPool(EnQuizType.alphabetOrder), isEmpty);
    expect(englishCardPool(EnQuizType.matchPairs), isEmpty);
    expect(koreanCardPool(KrQuizType.syllableOrder), isEmpty);
    expect(koreanCardPool(KrQuizType.oddOneOut), isEmpty);
  });

  test('색깔과 숫자 첫 판 카드에는 숫자도 나온다 (판과 같은 것)', () {
    final u = EnglishCurriculum.units.firstWhere((u) => u.title == '색깔과 숫자');
    var sawNumber = false;
    for (var rep = 0; rep < 10 && !sawNumber; rep++) {
      final qs =
          EnglishQuestionGenerator().generate(u.type, stage: 0, theme: u.theme);
      final labels = englishLearnCards(u.type, qs).map((c) => c.label);
      sawNumber = labels.any(
          (l) => const {'ONE', 'TWO', 'THREE', 'FOUR', 'FIVE'}.contains(l));
    }
    expect(sawNumber, isTrue);
  });

  testWidgets('카드를 누르면 읽어 주고 ✓, 문제 풀기를 누르면 그 자리에서 퀴즈가 된다', (tester) async {
    AppMotion.loops = false;
    Sounds.enabled = false;
    final spoken = <String>[];
    Speech.debugOnSpeak = spoken.add;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => LearnCardsScreen(
                title: '테스트',
                cards: const [
                  LearnCard('🐱', 'CAT', speech: 'cat', lang: 'en-US'),
                  LearnCard('🐶', 'DOG', speech: 'dog', lang: 'en-US'),
                ],
                quiz: () => const Scaffold(body: Text('퀴즈 화면')),
              ),
            )),
            child: const Text('열기'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('열기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('CAT'));
    await tester.pump();
    expect(spoken, contains('cat'));
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('learn-start')));
    await tester.pumpAndSettle();
    expect(find.text('퀴즈 화면'), findsOneWidget);
    Speech.debugOnSpeak = null;
  });
}
