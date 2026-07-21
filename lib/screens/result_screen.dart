import 'package:flutter/material.dart';

import '../models/curriculum.dart';
import '../models/progress.dart';
import '../models/quiz_config.dart';
import 'quiz_screen.dart';

/// 결과 화면: 별과 칭찬 메시지를 보여주고 다음 단계 또는 다시 도전으로 이어진다.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.config,
    required this.correctCount,
    required this.totalCount,
    this.level,
  });

  final QuizConfig config;
  final int correctCount;
  final int totalCount;

  /// 단계 도전이면 해당 단계, 자유 연습이면 null
  final Level? level;

  int get _stars => starsForScore(correctCount, totalCount);

  bool get _cleared => _stars >= 1;

  Level? get _nextLevel {
    final current = level;
    if (current == null || !_cleared) return null;
    if (current.number >= Curriculum.totalLevels) return null;
    return Curriculum.levelAt(current.number + 1);
  }

  String get _message => switch (_stars) {
        3 => '와, 최고예요! 🏆',
        2 => '정말 잘했어요! 👏',
        1 => '잘했어요! 조금만 더 힘내요 💪',
        _ => '괜찮아요! 다시 해 볼까요? 🌱',
      };

  @override
  Widget build(BuildContext context) {
    final nextLevel = _nextLevel;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              if (level != null) ...[
                Text(
                  '${level!.number}단계 · ${level!.unit.emoji} ${level!.unit.title}',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 12),
              ],
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
              if (level != null && !_cleared) ...[
                const SizedBox(height: 8),
                Text(
                  '5문제 이상 맞히면 다음 단계가 열려요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
              const Spacer(),
              if (nextLevel != null) ...[
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          config: nextLevel.config,
                          level: nextLevel,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF58CC02),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                  ),
                  child: Text('다음 단계 (${nextLevel.number}단계) ➡️'),
                ),
                const SizedBox(height: 12),
              ],
              _SecondaryButton(
                label: '다시 하기 🔄',
                filled: nextLevel == null,
                onPressed: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(config: config, level: level),
                    ),
                  );
                },
              ),
              const SizedBox(height: 12),
              _SecondaryButton(
                label: level != null ? '지도로 🗺️' : '처음으로 🏠',
                filled: false,
                onPressed: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// 초록색 채움/테두리 버튼
class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    required this.filled,
    required this.onPressed,
  });

  final String label;
  final bool filled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF58CC02),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 20),
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        side: const BorderSide(color: Color(0xFF58CC02), width: 2),
        foregroundColor: const Color(0xFF58CC02),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
      child: Text(label),
    );
  }
}
