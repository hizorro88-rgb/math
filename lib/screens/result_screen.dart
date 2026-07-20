import 'package:flutter/material.dart';

import '../models/quiz_config.dart';
import 'quiz_screen.dart';

/// 결과 화면: 별과 칭찬 메시지를 보여주고 다시 도전할 수 있게 한다.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.config,
    required this.correctCount,
    required this.totalCount,
  });

  final QuizConfig config;
  final int correctCount;
  final int totalCount;

  int get _stars {
    final ratio = correctCount / totalCount;
    if (ratio >= 0.9) return 3;
    if (ratio >= 0.7) return 2;
    if (ratio >= 0.5) return 1;
    return 0;
  }

  String get _message => switch (_stars) {
        3 => '와, 최고예요! 🏆',
        2 => '정말 잘했어요! 👏',
        1 => '잘했어요! 조금만 더 힘내요 💪',
        _ => '괜찮아요! 다시 해 볼까요? 🌱',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Duration(milliseconds: 400 + i * 300),
                      curve: Curves.elasticOut,
                      builder: (context, value, child) => Transform.scale(
                        scale: value,
                        child: child,
                      ),
                      child: Text(
                        i < _stars ? '⭐' : '☆',
                        style: const TextStyle(fontSize: 64),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '$totalCount문제 중에 $correctCount문제를 맞혔어요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, color: Colors.grey.shade700),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(config: config),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF58CC02),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                ),
                child: const Text('다시 하기 🔄'),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  side: const BorderSide(color: Color(0xFF58CC02), width: 2),
                  foregroundColor: const Color(0xFF58CC02),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                child: const Text('처음으로 🏠'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
