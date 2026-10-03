import 'package:flutter/material.dart';

import '../models/english_curriculum.dart';
import '../widgets/stage_parts.dart';
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
        title: Text(category.title),
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
    return StageUnitCard(
      emoji: unit.emoji,
      title: unit.title,
      color: unit.color,
      levels: [
        for (final level in unitLevels)
          StageLevel(
            number: level.number - unit.firstLevelNumber + 1,
            stars: stars[level.number - 1],
            unlocked: EnglishProgressStore.isUnlocked(stars, level.number),
            onTap: () => onLevelTap(level),
          ),
      ],
    );
  }
}
