import 'package:flutter/material.dart';

import '../models/quiz_config.dart';
import 'quiz_screen.dart';

/// 시작 화면: 퀴즈 종류와 난이도를 고르고 시작한다.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  QuizMode _mode = QuizMode.addition;
  Difficulty _difficulty = Difficulty.easy;

  void _startQuiz() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          config: QuizConfig(mode: _mode, difficulty: _difficulty),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                    const Text(
                      '🦉',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 72),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '수학 놀이',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF58CC02),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '재미있게 더하기 빼기를 배워요!',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, color: Colors.grey.shade600),
                    ),
                    const Spacer(),
                    const _SectionLabel('어떤 공부를 할까요?'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final mode in QuizMode.values) ...[
                          Expanded(
                            child: _ChoiceCard(
                              emoji: mode.emoji,
                              label: mode.label,
                              selected: _mode == mode,
                              onTap: () => setState(() => _mode = mode),
                            ),
                          ),
                          if (mode != QuizMode.values.last)
                            const SizedBox(width: 8),
                        ],
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
                    ElevatedButton(
                      onPressed: _startQuiz,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF58CC02),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                      ),
                      child: const Text('시작하기 🚀'),
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
