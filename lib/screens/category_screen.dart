import 'package:flutter/material.dart';

import '../models/curriculum.dart';
import '../models/progress.dart';
import '../widgets/stage_parts.dart';
import 'quiz_screen.dart';

/// 연령/학년 카테고리 상세: 그 나이에 배우는 묶음들과 단계 지도.
class CategoryScreen extends StatefulWidget {
  const CategoryScreen({super.key, required this.category});

  final AgeCategory category;

  @override
  State<CategoryScreen> createState() => _CategoryScreenState();
}

class _CategoryScreenState extends State<CategoryScreen> {
  late Future<List<int>> _starsFuture;

  @override
  void initState() {
    super.initState();
    _starsFuture = ProgressStore.load();
  }

  Future<void> _openLevel(Level level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(config: level.config, level: level),
      ),
    );
    if (!mounted) return;
    setState(() {
      _starsFuture = ProgressStore.load();
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

  final Unit unit;
  final List<int> stars;
  final void Function(Level) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final unitLevels =
        Curriculum.levels.where((l) => l.unit.index == unit.index).toList();
    return StageUnitCard(
      emoji: unit.emoji,
      title: unit.title,
      color: unit.color,
      levels: [
        for (final level in unitLevels)
          StageLevel(
            number: level.number - unit.firstLevelNumber + 1,
            stars: stars[level.number - 1],
            unlocked: ProgressStore.isUnlocked(stars, level.number),
            onTap: () => onLevelTap(level),
          ),
      ],
    );
  }
}
