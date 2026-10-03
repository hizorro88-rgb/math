import 'package:flutter/material.dart';

import '../models/korean_curriculum.dart';
import '../widgets/stage_parts.dart';
import 'korean_quiz_screen.dart';

/// 한글 카테고리 상세: 묶음들과 단계 지도.
class KoreanCategoryScreen extends StatefulWidget {
  const KoreanCategoryScreen({super.key, required this.category});

  final KrCategory category;

  @override
  State<KoreanCategoryScreen> createState() => _KoreanCategoryScreenState();
}

class _KoreanCategoryScreenState extends State<KoreanCategoryScreen> {
  late Future<List<int>> _starsFuture;

  @override
  void initState() {
    super.initState();
    _starsFuture = KoreanProgressStore.load();
  }

  Future<void> _openLevel(KrLevel level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => KoreanQuizScreen(
          type: level.unit.type,
          stage: level.stage,
          level: level,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _starsFuture = KoreanProgressStore.load();
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

  final KrUnit unit;
  final List<int> stars;
  final void Function(KrLevel) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final unitLevels = KoreanCurriculum.levels
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
            unlocked: KoreanProgressStore.isUnlocked(stars, level.number),
            onTap: () => onLevelTap(level),
          ),
      ],
    );
  }
}
