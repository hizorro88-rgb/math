import 'package:flutter/material.dart';

import '../models/curriculum.dart';
import '../models/progress.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';

/// 홈 화면: 10단계씩 10묶음, 총 100단계의 학습 지도.
/// 앞 단계를 통과(별 1개 이상)해야 다음 단계가 열린다.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  late Future<List<int>> _starsFuture;

  @override
  void initState() {
    super.initState();
    _starsFuture = ProgressStore.load();
  }

  void _refresh() {
    setState(() => _starsFuture = ProgressStore.load());
  }

  Future<void> _openLevel(Level level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(config: level.config, level: level),
      ),
    );
    _refresh();
  }

  Future<void> _openPractice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF58CC02),
        foregroundColor: Colors.white,
        title: const Text(
          '🦉 수학 놀이',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          FutureBuilder<List<int>>(
            future: _starsFuture,
            builder: (context, snapshot) {
              final total =
                  snapshot.data?.fold<int>(0, (sum, s) => sum + s) ?? 0;
              return Padding(
                padding: const EdgeInsets.only(right: 16),
                child: Center(
                  child: Text(
                    '⭐ $total',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<int>>(
        future: _starsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final stars = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _PracticeCard(onTap: _openPractice),
              const SizedBox(height: 16),
              for (final unit in Curriculum.units) ...[
                _UnitSection(
                  unit: unit,
                  stars: stars,
                  onLevelTap: _openLevel,
                ),
                const SizedBox(height: 16),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 자유 연습으로 들어가는 카드
class _PracticeCard extends StatelessWidget {
  const _PracticeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300, width: 2),
        ),
        child: const Row(
          children: [
            Text('🎨', style: TextStyle(fontSize: 32)),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '자유 연습',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '원하는 방식으로 자유롭게 연습해요',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}

/// 한 묶음(10단계)을 보여주는 구역
class _UnitSection extends StatelessWidget {
  const _UnitSection({
    required this.unit,
    required this.stars,
    required this.onLevelTap,
  });

  final Unit unit;
  final List<int> stars;
  final void Function(Level) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final unitLevels =
        Curriculum.levels.where((l) => l.unit.index == unit.index).toList();
    final clearedCount =
        unitLevels.where((l) => stars[l.number - 1] >= 1).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: unit.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: unit.color.withValues(alpha: 0.4), width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(unit.emoji, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${unit.index + 1}묶음 · ${unit.title}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${unit.mode.label} · ${unit.endMax}까지 · '
                      '$clearedCount/${Curriculum.levelsPerUnit} 통과',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final level in unitLevels)
                _LevelBubble(
                  level: level,
                  stars: stars[level.number - 1],
                  unlocked: ProgressStore.isUnlocked(stars, level.number),
                  color: unit.color,
                  onTap: () => onLevelTap(level),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 동그란 단계 버튼: 잠김 🔒 / 도전 가능 / 통과(별 표시)
class _LevelBubble extends StatelessWidget {
  const _LevelBubble({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.color,
    required this.onTap,
  });

  final Level level;
  final int stars;
  final bool unlocked;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cleared = stars >= 1;
    final background = !unlocked
        ? Colors.grey.shade200
        : cleared
            ? color
            : Colors.white;
    final foreground = !unlocked
        ? Colors.grey.shade400
        : cleared
            ? Colors.white
            : color;

    return GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: background,
          shape: BoxShape.circle,
          border: Border.all(
            color: unlocked ? color : Colors.grey.shade300,
            width: 3,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!unlocked)
              const Text('🔒', style: TextStyle(fontSize: 18))
            else ...[
              Text(
                '${level.number}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: foreground,
                ),
              ),
              if (cleared)
                Text('⭐' * stars, style: const TextStyle(fontSize: 7)),
            ],
          ],
        ),
      ),
    );
  }
}
