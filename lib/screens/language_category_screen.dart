import 'package:flutter/material.dart';

import '../models/language_pack.dart';
import '../widgets/bouncy_button.dart';
import 'language_quiz_screen.dart';

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
      backgroundColor: const Color(0xFFF3F7F0),
      appBar: AppBar(
        backgroundColor: category.color,
        foregroundColor: Colors.white,
        title: Text(
          '${category.emoji} ${category.title}',
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
  });

  final LanguagePack pack;
  final LangUnit unit;
  final List<int> stars;
  final void Function(LangLevel) onLevelTap;

  @override
  Widget build(BuildContext context) {
    final unitLevels =
        pack.levels.where((l) => l.unit.index == unit.index).toList();
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
                                  LanguagePack.levelsPerUnit,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              color: unit.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$clearedCount/${LanguagePack.levelsPerUnit}',
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
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final level in unitLevels)
                _LevelBubble(
                  level: level,
                  stars: stars[level.number - 1],
                  unlocked:
                      LangProgressStore.isUnlocked(pack, stars, level.number),
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

/// 동그란 3D 단계 버튼: 잠김 🔒 / 도전 가능(통통) / 통과(별 표시)
class _LevelBubble extends StatelessWidget {
  const _LevelBubble({
    required this.level,
    required this.stars,
    required this.unlocked,
    required this.color,
    required this.onTap,
  });

  final LangLevel level;
  final int stars;
  final bool unlocked;
  final Color color;
  final VoidCallback onTap;

  bool get _cleared => stars >= 1;
  bool get _isCurrent => unlocked && !_cleared;

  @override
  Widget build(BuildContext context) {
    final bubble = GestureDetector(
      onTap: unlocked ? onTap : null,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: _cleared
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, BouncyButton.darken(color, 0.08)],
                )
              : null,
          color: _cleared
              ? null
              : unlocked
                  ? Colors.white
                  : Colors.grey.shade200,
          shape: BoxShape.circle,
          border: Border.all(
            color: unlocked ? color : Colors.grey.shade300,
            width: 3,
          ),
          boxShadow: unlocked
              ? [
                  BoxShadow(
                    color: _cleared
                        ? BouncyButton.darken(color, 0.15)
                        : Colors.grey.shade300,
                    offset: const Offset(0, 3),
                    blurRadius: 0,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (!unlocked)
              const Opacity(
                opacity: 0.6,
                child: Text('🔒', style: TextStyle(fontSize: 18)),
              )
            else ...[
              Text(
                '${level.number}',
                style: TextStyle(
                  fontSize: level.number >= 100 ? 15 : 18,
                  fontWeight: FontWeight.bold,
                  color: _cleared ? Colors.white : color,
                ),
              ),
              if (_cleared)
                Text('⭐' * stars, style: const TextStyle(fontSize: 7)),
            ],
          ],
        ),
      ),
    );

    // 지금 도전할 단계는 통! 하고 커지면서 나타난다.
    if (_isCurrent) {
      return TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.6, end: 1),
        duration: const Duration(milliseconds: 700),
        curve: Curves.elasticOut,
        builder: (context, value, child) =>
            Transform.scale(scale: value, child: child),
        child: bubble,
      );
    }
    return bubble;
  }
}
