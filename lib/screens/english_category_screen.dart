import 'package:flutter/material.dart';

import '../models/english_curriculum.dart';
import '../widgets/level_bubble.dart';
import 'english_quiz_screen.dart';

/// 영어 카테고리 상세: 묶음들과 단계 지도.
class EnglishCategoryScreen extends StatefulWidget {
  const EnglishCategoryScreen({super.key, required this.category});

  final EnCategory category;

  @override
  State<EnglishCategoryScreen> createState() => _EnglishCategoryScreenState();
}

class _EnglishCategoryScreenState extends State<EnglishCategoryScreen> {
  late Future<List<int>> _starsFuture;

  @override
  void initState() {
    super.initState();
    _starsFuture = EnglishProgressStore.load();
  }

  Future<void> _openLevel(EnLevel level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EnglishQuizScreen(
          type: level.unit.type,
          stage: level.stage,
          level: level,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _starsFuture = EnglishProgressStore.load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final category = widget.category;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${category.title} · 영어',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<List<int>>(
        future: _starsFuture,
        builder: (context, snapshot) {
          final stars = snapshot.data;
          if (stars == null) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: category.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    const Text('📖', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        category.desc,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              for (final unit in category.units) ...[
                _UnitSection(
                  unit: unit,
                  stars: stars,
                  onLevelTap: _openLevel,
                ),
                const SizedBox(height: 14),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// 한 묶음(10단계)을 보여주는 카드
class _UnitSection extends StatelessWidget {
  const _UnitSection({
    required this.unit,
    required this.stars,
    required this.onLevelTap,
  });

  final EnUnit unit;
  final List<int> stars;
  final void Function(EnLevel) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final unitLevels = EnglishCurriculum.levels
        .where((l) => l.unit.index == unit.index)
        .toList();
    // 이 묶음의 첫 단계도 잠겨 있으면 아직 못 여는 묶음
    final unitLocked =
        !EnglishProgressStore.isUnlocked(stars, unitLevels.first.number);
    final clearedCount =
        unitLevels.where((l) => stars[l.number - 1] >= 1).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: unit.color.withValues(alpha: 0.15),
            offset: const Offset(0, 5),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: unit.color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(unit.emoji, style: const TextStyle(fontSize: 28)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      unit.title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: clearedCount /
                                  EnglishCurriculum.levelsPerUnit,
                              minHeight: 8,
                              backgroundColor: const Color(0xFFEBE3D2),
                              color: unit.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$clearedCount/${EnglishCurriculum.levelsPerUnit}',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (unitLocked) ...[
            const SizedBox(height: 8),
            Text(
              '🔒 앞 묶음을 다 끝내면 열려요',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade500,
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final level in unitLevels)
                LevelBubble(
                  number: level.number - unit.firstLevelNumber + 1,
                  stars: stars[level.number - 1],
                  unlocked: EnglishProgressStore.isUnlocked(stars, level.number),
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

