import 'package:flutter/material.dart';

import '../models/language_pack.dart';
import '../widgets/stage_parts.dart';
import 'language_quiz_screen.dart';
import '../theme.dart';

/// 언어 팩 공용 카테고리 상세: 묶음들과 단계 지도.
class LanguageCategoryScreen extends StatefulWidget {
  const LanguageCategoryScreen(
      {super.key, required this.pack, required this.category});

  final LanguagePack pack;
  final LangCategory category;

  @override
  State<LanguageCategoryScreen> createState() => _LanguageCategoryScreenState();
}

class _LanguageCategoryScreenState extends State<LanguageCategoryScreen> {
  late Future<List<int>> _starsFuture;

  @override
  void initState() {
    super.initState();
    _starsFuture = LangProgressStore.load(widget.pack);
  }

  Future<void> _openLevel(LangLevel level) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LanguageQuizScreen(
          pack: widget.pack,
          typeIndex: level.unit.typeIndex,
          stage: level.stage,
          level: level,
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _starsFuture = LangProgressStore.load(widget.pack);
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
              // 설명 띠는 어른 과정(영어회화)에만 — 아이는 글 설명을 읽지 못한다
              if (widget.pack.forAdults) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: category.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      const Text('💡',
                          style: TextStyle(fontSize: AppFont.display)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          category.desc,
                          style: const TextStyle(
                            fontSize: AppFont.body,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
              // 펄스(지금 할 원)는 지도 전체에서 첫 미완료 묶음 하나에만
              for (final unit in category.units) ...[
                _UnitSection(
                  highlight: unit ==
                      category.units.firstWhere(
                          (u) => StageUnitCard.hasOpen([
                                for (final l in widget.pack.levels
                                    .where((l) => l.unit.index == u.index))
                                  (
                                    LangProgressStore.isUnlocked(
                                        widget.pack, stars, l.number),
                                    stars[l.number - 1]
                                  ),
                              ]),
                          orElse: () => category.units.first),
                  pack: widget.pack,
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
    required this.pack,
    required this.unit,
    required this.stars,
    required this.onLevelTap,
    this.highlight = true,
  });

  final bool highlight;

  final LanguagePack pack;
  final LangUnit unit;
  final List<int> stars;
  final void Function(LangLevel) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final unitLevels =
        pack.levels.where((l) => l.unit.index == unit.index).toList();
    return StageUnitCard(
      highlight: highlight,
      emoji: unit.emoji,
      title: unit.title,
      color: unit.color,
      levels: [
        for (final level in unitLevels)
          StageLevel(
            number: level.number - unit.firstLevelNumber + 1,
            stars: stars[level.number - 1],
            unlocked: LangProgressStore.isUnlocked(pack, stars, level.number),
            onTap: () => onLevelTap(level),
          ),
      ],
    );
  }
}
