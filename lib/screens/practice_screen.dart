import 'package:flutter/material.dart';

import '../models/quiz_config.dart';
import '../widgets/bouncy_button.dart';
import 'quiz_screen.dart';

/// 자유 연습: 퀴즈 종류와 난이도를 직접 고르고 시작한다. (단계 진행과 무관)
class PracticeScreen extends StatefulWidget {
  const PracticeScreen({super.key});

  @override
  State<PracticeScreen> createState() => _PracticeScreenState();
}

class _PracticeScreenState extends State<PracticeScreen> {
  QuizMode _mode = QuizMode.addition;
  Difficulty _difficulty = Difficulty.easy;

  void _startQuiz() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          config: QuizConfig(
            mode: _mode,
            maxNumber: _difficulty.maxNumber,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF58CC02),
        foregroundColor: Colors.white,
        title: const Text(
          '🎨 자유 연습',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      // 화면이 작으면 스크롤되고, 크면 위아래로 넉넉하게 펼쳐진다.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    const _SectionLabel('어떤 공부를 할까요?'),
                    const SizedBox(height: 8),
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 1.6,
                      children: [
                        for (final mode in QuizMode.values)
                          _ChoiceCard(
                            emoji: mode.emoji,
                            label: mode.label,
                            selected: _mode == mode,
                            onTap: () => setState(() => _mode = mode),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    const _SectionLabel('얼마나 어려울까요?'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final difficulty in Difficulty.values) ...[
                          Expanded(
                            child: _ChoiceCard(
                              emoji:
                                  difficulty == Difficulty.easy ? '🐣' : '🐥',
                              label:
                                  '${difficulty.label}\n(${difficulty.description})',
                              selected: _difficulty == difficulty,
                              onTap: () =>
                                  setState(() => _difficulty = difficulty),
                            ),
                          ),
                          if (difficulty != Difficulty.values.last)
                            const SizedBox(width: 8),
                        ],
                      ],
                    ),
                    const Spacer(),
                    BouncyButton(
                      color: const Color(0xFF58CC02),
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
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
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

/// 이모지 + 글자로 된 큰 선택 카드
class _ChoiceCard extends StatelessWidget {
  const _ChoiceCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD7FFB8) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? const Color(0xFF58CC02) : Colors.grey.shade300,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? const Color(0xFFB5E48C) : Colors.grey.shade300,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 4),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
