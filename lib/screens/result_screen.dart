import 'package:flutter/material.dart';

import '../models/curriculum.dart';
import '../models/daily.dart';
import '../models/progress.dart';
import '../models/quiz_config.dart';
import '../widgets/bouncy_button.dart';
import 'quiz_screen.dart';

/// 결과 화면: 별·점수·칭호를 보여주고 다음 단계 또는 다시 도전으로 이어진다.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.config,
    required this.correctCount,
    required this.totalCount,
    required this.earnedPoints,
    this.completedMissions = const [],
    this.level,
  });

  final QuizConfig config;
  final int correctCount;
  final int totalCount;

  /// 이번 판에 모은 점수 (통과 보너스 포함)
  final int earnedPoints;

  /// 이번 판으로 새로 달성한 데일리 미션들
  final List<DailyMission> completedMissions;

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
              const SizedBox(height: 20),
              Text(
                _message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$totalCount문제 중에 $correctCount문제를 맞혔어요!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, color: Colors.grey.shade700),
              ),
              if (level != null && !_cleared) ...[
                const SizedBox(height: 8),
                Text(
                  '5문제 이상 맞히면 다음 단계가 열려요!',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                ),
              ],
              const SizedBox(height: 20),
              _PointsCard(earnedPoints: earnedPoints),
              if (completedMissions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _MissionBanner(missions: completedMissions),
              ],
              const Spacer(),
              if (nextLevel != null) ...[
                BouncyButton(
                  color: const Color(0xFF58CC02),
                  onTap: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => QuizScreen(
                          config: nextLevel.config,
                          level: nextLevel,
                        ),
                      ),
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '다음 단계 (${nextLevel.number}단계)',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.arrow_forward_rounded,
                        size: 28,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              BouncyButton(
                color:
                    nextLevel == null ? const Color(0xFF58CC02) : Colors.white,
                shadowColor: nextLevel == null ? null : Colors.grey.shade300,
                border: nextLevel == null
                    ? null
                    : Border.all(color: const Color(0xFF58CC02), width: 2),
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder: (_) => QuizScreen(config: config, level: level),
                    ),
                  );
                },
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '다시 하기',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: nextLevel == null
                            ? Colors.white
                            : const Color(0xFF58CC02),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.refresh_rounded,
                      size: 28,
                      color: nextLevel == null
                          ? Colors.white
                          : const Color(0xFF58CC02),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              BouncyButton(
                color: Colors.white,
                shadowColor: Colors.grey.shade300,
                border: Border.all(color: const Color(0xFF58CC02), width: 2),
                onTap: () =>
                    Navigator.of(context).popUntil((route) => route.isFirst),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      level != null ? '지도로' : '처음으로',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF58CC02),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      level != null ? Icons.map_rounded : Icons.home_rounded,
                      size: 28,
                      color: const Color(0xFF58CC02),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// 이번 판으로 달성한 데일리 미션 축하 배너
class _MissionBanner extends StatelessWidget {
  const _MissionBanner({required this.missions});

  final List<DailyMission> missions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBD6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF9600), width: 2),
      ),
      child: Column(
        children: [
          const Text(
            '🎯 오늘의 미션 완료!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB05E00),
            ),
          ),
          const SizedBox(height: 4),
          for (final mission in missions)
            Text(
              '${mission.emoji} ${mission.title}  +${mission.reward} 🪙',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB05E00),
              ),
            ),
        ],
      ),
    );
  }
}

/// 이번 판 점수가 차오르고, 누적 점수와 칭호를 보여주는 카드
class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.earnedPoints});

  final int earnedPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD34D), width: 3),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: earnedPoints),
            duration: const Duration(milliseconds: 900),
            builder: (context, value, _) => Text(
              '🪙 +$value점',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB8860B),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<int>(
            future: ProgressStore.loadPoints(),
            builder: (context, snapshot) {
              final total = snapshot.data;
              if (total == null) return const SizedBox(height: 20);
              final rank = rankForPoints(total);
              final next = nextRankFor(total);
              return Column(
                children: [
                  Text(
                    '모은 점수 $total점 · ${rank.emoji} ${rank.title}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade400,
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${next.emoji} ${next.title}까지 ${next.minPoints - total}점!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown.shade300,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
