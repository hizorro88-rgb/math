import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/english_question.dart';
import '../models/korean_question.dart';
import '../models/language_packs.dart';
import '../models/quiz_config.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/selectable_tile.dart';
import 'english_quiz_screen.dart';
import 'korean_quiz_screen.dart';
import 'language_quiz_screen.dart';
import 'quiz_screen.dart';

/// 자유 연습: 과목(수학/한글)과 종류·난이도를 직접 고르고 시작한다. (단계 진행과 무관)
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  /// 0: 수학, 1: 한글, 2: 영어, 3~: 언어 팩
  int _subject = 0;

  static final List<(String, String)> _subjects = [
    ('🧮', '수학'),
    ('📖', '한글'),
    ('🔤', '영어'),
    // 어른 과정(영어회화)은 아이 자유 연습에서 뺀다 (맨 뒤에 있어서 번호는 그대로)
    for (final pack in languagePacks)
      if (!pack.forAdults) (pack.emoji, pack.name),
  ];

  QuizMode _mode = QuizMode.addition;
  Difficulty _difficulty = Difficulty.easy;

  KrQuizType _krType = KrQuizType.pictureToWord;
  EnQuizType _enType = EnQuizType.wordToPicture;

  /// 언어 팩별로 고른 유형 번호
  final Map<String, int> _langType = {};
  bool _langHard = false;

  void _startQuiz() {
    if (_subject == 1) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KoreanQuizScreen(
            type: _krType,
            stage: _langHard ? 9 : 0,
          ),
        ),
      );
      return;
    }
    if (_subject == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => EnglishQuizScreen(
            type: _enType,
            stage: _langHard ? 9 : 0,
          ),
        ),
      );
      return;
    }
    if (_subject >= 3) {
      final pack = languagePacks[_subject - 3];
      final picked = _langType[pack.id] ?? 0;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LanguageQuizScreen(
            pack: pack,
            // 주제 기반 팩(영어회화)은 고른 값이 유형이 아니라 주제다.
            typeIndex: pack.unitBased ? 0 : picked,
            unitIndex: pack.unitBased ? picked : -1,
            stage: _langHard ? 9 : 0,
          ),
        ),
      );
      return;
    }

    // 구구단·수 세기·심화 유형은 각자의 범위에 맞게 난이도 상한을 걸어 준다.
    var maxNumber = _difficulty.maxNumber;
    if (_mode == QuizMode.multiplication || _mode == QuizMode.division) {
      maxNumber = math.min(maxNumber, 9);
    } else if (_mode == QuizMode.counting) {
      maxNumber = math.min(maxNumber, 20);
    } else if (_mode == QuizMode.fraction) {
      maxNumber = math.min(maxNumber, 9);
    } else if (_mode == QuizMode.decimal) {
      maxNumber = math.min(maxNumber, 19);
    } else if (_mode == QuizMode.timeCalc) {
      maxNumber = math.min(maxNumber, 12);
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          config: QuizConfig(mode: _mode, maxNumber: maxNumber),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('자유 연습'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // 과목 고르기 (2열 카드)
                    ..._buildGrid(
                      [for (var i = 0; i < _subjects.length; i++) i],
                      (i) => _ChoiceCard(
                        emoji: _subjects[i].$1,
                        label: _subjects[i].$2,
                        selected: _subject == i,
                        onTap: () => setState(() => _subject = i),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const _SectionLabel('어떤 공부를 할까요?'),
                    const SizedBox(height: 8),
                    if (_subject == 1)
                      ..._buildGrid(
                        KrQuizType.values,
                        (t) => _ChoiceCard(
                          emoji: t.emoji,
                          label: t.label,
                          selected: _krType == t,
                          onTap: () => setState(() => _krType = t),
                        ),
                      )
                    else if (_subject == 2)
                      ..._buildGrid(
                        EnQuizType.values,
                        (t) => _ChoiceCard(
                          emoji: t.emoji,
                          label: t.label,
                          selected: _enType == t,
                          onTap: () => setState(() => _enType = t),
                        ),
                      )
                    else if (_subject >= 3)
                      // 주제 기반 팩(영어회화)은 유형 대신 배울 주제를 고른다.
                      ..._buildGrid(
                        [
                          for (var i = 0;
                              i <
                                  (languagePacks[_subject - 3].unitBased
                                      ? languagePacks[_subject - 3].units.length
                                      : languagePacks[_subject - 3]
                                          .types
                                          .length);
                              i++)
                            i,
                        ],
                        (i) {
                          final pack = languagePacks[_subject - 3];
                          return _ChoiceCard(
                            emoji: pack.unitBased
                                ? pack.units[i].emoji
                                : pack.types[i].emoji,
                            label: pack.unitBased
                                ? pack.units[i].title
                                : pack.types[i].label,
                            selected: (_langType[pack.id] ?? 0) == i,
                            onTap: () => setState(() => _langType[pack.id] = i),
                          );
                        },
                      )
                    else
                      ..._buildGrid(
                        QuizMode.values,
                        (m) => _ChoiceCard(
                          emoji: m.emoji,
                          label: m.label,
                          selected: _mode == m,
                          onTap: () => setState(() => _mode = m),
                        ),
                      ),
                    const SizedBox(height: 24),
                    const _SectionLabel('얼마나 어려울까요?'),
                    const SizedBox(height: 8),
                    if (_subject != 0)
                      Row(
                        children: [
                          Expanded(
                            child: _ChoiceCard(
                              emoji: '🐣',
                              label: '쉬워요',
                              selected: !_langHard,
                              onTap: () => setState(() => _langHard = false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _ChoiceCard(
                              emoji: '🦁',
                              label: '어려워요',
                              selected: _langHard,
                              onTap: () => setState(() => _langHard = true),
                            ),
                          ),
                        ],
                      )
                    else
                      ..._buildGrid(
                        Difficulty.values,
                        (d) => _ChoiceCard(
                          emoji: d.emoji,
                          label: d.label,
                          sub: d.description,
                          selected: _difficulty == d,
                          onTap: () => setState(() => _difficulty = d),
                        ),
                      ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            // 시작 버튼은 늘 아래에 보인다
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: BouncyButton(
                color: AppColors.green,
                padding: const EdgeInsets.symmetric(vertical: 20),
                onTap: _startQuiz,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '시작하기',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.play_arrow_rounded,
                      size: 32,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 목록을 3열 칸으로 배치한다 (2열이면 시작 버튼이 너무 아래로 내려간다).
  List<Widget> _buildGrid<T>(List<T> items, Widget Function(T) card) {
    const cols = 3;
    return [
      for (var row = 0; row < (items.length + cols - 1) ~/ cols; row++) ...[
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var col = 0; col < cols; col++) ...[
                Expanded(
                  child: row * cols + col < items.length
                      ? card(items[row * cols + col])
                      : const SizedBox(),
                ),
                if (col < cols - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    );
  }
}

/// 이모지 + 글자로 된 선택 칸 (앱 공용 선택 모양)
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? sub;

  @override
  Widget build(BuildContext context) => SelectableTile(
        emoji: emoji,
        label: label,
        selected: selected,
        onTap: () {
          // 글을 못 읽어도 무엇을 골랐는지 들리게 (이미 고른 칸은 조용히)
          if (!selected) Speech.speak(label.replaceAll('\n', ' '));
          onTap();
        },
        sub: sub,
      );
}
