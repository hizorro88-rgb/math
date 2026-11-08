import 'package:flutter/material.dart';

import '../models/english_curriculum.dart';
import '../models/korean_curriculum.dart';
import '../models/korean_question.dart';
import '../models/language_pack.dart';
import '../models/learn_cards.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/pulse.dart';
import 'english_quiz_screen.dart';
import 'korean_quiz_screen.dart';
import 'language_quiz_screen.dart';

// 단계를 여는 곳(묶음 지도·홈 ▶·결과 화면 '다음 단계')이 모두 이 함수를 쓴다.
// 카드를 보여 줄 때는 판을 먼저 만들어 카드와 퀴즈가 같은 문제를 쓰게 한다.

/// 영어 단계 열기: [showCards]이고 미리 볼 카드가 있으면 배우기 카드부터
Widget englishLevelEntry(EnLevel l, {required bool showCards}) {
  if (!showCards) {
    return EnglishQuizScreen(type: l.unit.type, stage: l.stage, level: l);
  }
  final qs = generateEnglishRound(l.unit.type, l.stage, l);
  return _entry(
      l.unit.title,
      englishLearnCards(l.unit.type, qs),
      () => EnglishQuizScreen(
          type: l.unit.type, stage: l.stage, level: l, questions: qs));
}

/// 한글 단계 열기
Widget koreanLevelEntry(KrLevel l, {required bool showCards}) {
  if (!showCards) {
    return KoreanQuizScreen(type: l.unit.type, stage: l.stage, level: l);
  }
  final qs = KoreanQuestionGenerator().generate(l.unit.type, stage: l.stage);
  return _entry(
      l.unit.title,
      koreanLearnCards(l.unit.type, qs),
      () => KoreanQuizScreen(
          type: l.unit.type, stage: l.stage, level: l, questions: qs));
}

/// 외국어 팩 단계 열기
Widget langLevelEntry(LanguagePack pack, LangLevel l,
    {required bool showCards}) {
  LanguageQuizScreen quiz([List<LangQuestion>? qs]) => LanguageQuizScreen(
      pack: pack,
      typeIndex: l.unit.typeIndex,
      stage: l.stage,
      level: l,
      questions: qs);
  if (!showCards || langCardPool(pack, l.unit.typeIndex).isEmpty) {
    return quiz();
  }
  final qs =
      pack.generate(l.unit.typeIndex, stage: l.stage, unitIndex: l.unit.index);
  return _entry(
      l.unit.title, langLearnCards(pack, l.unit.typeIndex, qs), () => quiz(qs));
}

Widget _entry(String title, List<LearnCard> cards, Widget Function() quiz) =>
    cards.isEmpty
        ? quiz()
        : LearnCardsScreen(title: title, cards: cards, quiz: quiz);

/// 단계 열기 공용: 화면을 올리고 돌아오면 [then] (별 다시 읽기)
Future<void> pushLevel(BuildContext context, Widget screen,
    {VoidCallback? then}) async {
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  then?.call();
}

/// 배우기 카드: 문제를 풀기 전에 그림·글자·소리를 먼저 만난다.
/// 카드를 누르면 읽어 주고 ✓가 붙는다 — 다 눌러 보고 싶게.
/// [quiz]가 있으면 아래 버튼이 '문제 풀기 ▶'(같은 자리에서 퀴즈로 바뀐다 —
/// 돌아가면 지도로), 없으면 '다 봤어요'(닫기).
class LearnCardsScreen extends StatefulWidget {
  const LearnCardsScreen({
    super.key,
    required this.title,
    required this.cards,
    this.quiz,
  });

  final String title;
  final List<LearnCard> cards;
  final Widget Function()? quiz;

  @override
  State<LearnCardsScreen> createState() => _LearnCardsScreenState();
}

class _LearnCardsScreenState extends State<LearnCardsScreen> {
  final _heard = <int>{};
  Widget? _quiz;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => Speech.speak('카드를 눌러서 들어 봐요'));
  }

  void _tap(int i) {
    final card = widget.cards[i];
    Sounds.pop();
    Speech.speak(card.speech, lang: card.lang, force: true);
    setState(() => _heard.add(i));
  }

  @override
  Widget build(BuildContext context) {
    // 문제 풀기를 누르면 이 자리에서 퀴즈가 된다 (지도로 한 번 깜빡이지 않게)
    if (_quiz != null) return _quiz!;
    final cards = widget.cards;
    final allHeard = _heard.length >= cards.length;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(title: Text(widget.title)),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.15,
                ),
                itemCount: cards.length,
                itemBuilder: (context, i) => _Card(
                  card: cards[i],
                  heard: _heard.contains(i),
                  onTap: () => _tap(i),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                children: [
                  // 몇 장 들었는지 점으로 (글자 대신)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < cards.length; i++)
                        Container(
                          width: 10,
                          height: 10,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: _heard.contains(i)
                                ? AppColors.correct
                                : AppColors.line,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    // 다 들어 보면 '다음 할 일'이라 숨쉬듯 커진다 (화면에 펄스 하나)
                    child: Pulse(
                      scale: allHeard && widget.quiz != null ? 1.04 : 1.0,
                      child: BouncyButton(
                        key: const ValueKey('learn-start'),
                        color: AppColors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        onTap: () {
                          final quiz = widget.quiz;
                          if (quiz == null) {
                            Navigator.of(context).pop();
                          } else {
                            setState(() => _quiz = quiz());
                          }
                        },
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.quiz != null ? '문제 풀기' : '다 봤어요',
                              style: displayStyle(
                                  fontSize: AppFont.display,
                                  color: Colors.white),
                            ),
                            if (widget.quiz != null) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.play_arrow_rounded,
                                  color: Colors.white, size: 30),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card, required this.heard, required this.onTap});

  final LearnCard card;
  final bool heard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: card.label.isEmpty ? card.big : '${card.big} ${card.label}',
      excludeSemantics: true,
      child: PressBounce(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: heard ? AppColors.correct : AppColors.outline,
                  width: heard ? 3 : 2,
                ),
                boxShadow: const [
                  BoxShadow(color: AppColors.outline, offset: Offset(0, 3)),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child:
                          Text(card.big, style: const TextStyle(fontSize: 44)),
                    ),
                  ),
                  if (card.label.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.label,
                        style: const TextStyle(
                          fontSize: AppFont.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (card.sub.isNotEmpty)
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        card.sub,
                        style: const TextStyle(
                            fontSize: AppFont.small, color: AppColors.inkSoft),
                      ),
                    ),
                ],
              ),
            ),
            // 들어 본 카드 = 🔊 대신 ✓ (초록 = 해 봤다)
            Positioned(
              top: -6,
              right: -4,
              child: heard
                  ? const CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.correct,
                      child: Icon(Icons.check_rounded,
                          size: 16, color: Colors.white),
                    )
                  : const CircleAvatar(
                      radius: 12,
                      backgroundColor: AppColors.listen,
                      child: Icon(Icons.volume_up_rounded,
                          size: 14, color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
