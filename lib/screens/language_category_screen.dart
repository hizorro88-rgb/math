import 'package:flutter/material.dart';

import '../models/language_pack.dart';
import '../models/learn_cards.dart';
import '../widgets/stage_parts.dart';
import 'learn_cards_screen.dart';
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
    // 묶음 첫 단계·6단계를 처음 열 때는 배우기 카드부터 (그림·소리로 먼저 만나기)
    final stars = await _starsFuture;
    if (!mounted) return;
    final show = autoShowLearnCards(level.indexInUnit, stars[level.number - 1]);
    await pushLevel(
        context, langLevelEntry(widget.pack, level, showCards: show), then: () {
      if (mounted) {
        setState(() => _starsFuture = LangProgressStore.load(widget.pack));
      }
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
      // 📇 카드: 지금 할 단계(없으면 마지막 단계)의 판으로 카드를 만든다
      onLearn: langCardPool(pack, unit.typeIndex).isEmpty
          ? null
          : () {
              final l = unitLevels.firstWhere((l) => stars[l.number - 1] == 0,
                  orElse: () => unitLevels.last);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => LearnCardsScreen(
                    title: unit.title,
                    cards: langLearnCards(
                        pack,
                        unit.typeIndex,
                        pack.generate(unit.typeIndex,
                            stage: l.stage, unitIndex: unit.index))),
              ));
            },
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
