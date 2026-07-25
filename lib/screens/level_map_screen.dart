import 'package:flutter/material.dart';

import '../models/curriculum.dart';
import '../models/progress.dart';
import '../models/shop.dart';
import '../services/sounds.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/owl_avatar.dart';
import 'practice_screen.dart';
import 'quiz_screen.dart';
import 'shop_screen.dart';

/// 홈 화면: 마스코트 인사, 칭호 카드, 그리고 100단계 학습 지도.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _MapData {
  const _MapData({
    required this.stars,
    required this.points,
    required this.coins,
    required this.equipped,
  });

  final List<int> stars;
  final int points;
  final int coins;
  final List<ShopItem> equipped;
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  late Future<_MapData> _dataFuture;

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
  }

  Future<_MapData> _load() async => _MapData(
        stars: await ProgressStore.load(),
        points: await ProgressStore.loadPoints(),
        coins: await ProgressStore.loadCoins(),
        equipped: await ShopStore.loadEquipped(),
      );

  void _refresh() {
    if (!mounted) return;
    setState(() => _dataFuture = _load());
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
    _refresh();
  }

  Future<void> _openShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F0),
      body: FutureBuilder<_MapData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final stars = data.stars;
          final totalStars = stars.fold<int>(0, (sum, s) => sum + s);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                totalStars: totalStars,
                coins: data.coins,
                equipped: data.equipped,
                onOwlTap: _openShop,
                onSoundChanged: () => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _RankCard(points: data.points),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                            child: _MenuCard(
                          emoji: '🛍️',
                          title: '꾸미기 가게',
                          subtitle: '코인으로 부엉이 꾸미기',
                          onTap: _openShop,
                        )),
                        const SizedBox(width: 12),
                        Expanded(
                            child: _MenuCard(
                          emoji: '🎨',
                          title: '자유 연습',
                          subtitle: '원하는 방식으로 연습',
                          onTap: _openPractice,
                        )),
                      ],
                    ),
                    const SizedBox(height: 14),
                    for (final unit in Curriculum.units) ...[
                      _UnitSection(
                        unit: unit,
                        stars: stars,
                        onLevelTap: _openLevel,
                      ),
                      const SizedBox(height: 14),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 초록 그라데이션 헤더: 꾸며진 부엉이가 인사하고 별·코인을 보여준다.
/// 부엉이를 누르면 꾸미기 가게로 간다.
class _Header extends StatelessWidget {
  const _Header({
    required this.totalStars,
    required this.coins,
    required this.equipped,
    required this.onOwlTap,
    required this.onSoundChanged,
  });

  final int totalStars;
  final int coins;
  final List<ShopItem> equipped;
  final VoidCallback onOwlTap;
  final VoidCallback onSoundChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF58CC02), Color(0xFF2EC4B6)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  '수학 놀이',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    await Sounds.setEnabled(!Sounds.enabled);
                    onSoundChanged();
                  },
                  icon: Icon(
                    Sounds.enabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                GestureDetector(
                  onTap: onOwlTap,
                  child: OwlAvatar(size: 52, equipped: equipped),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      '오늘도 신나게\n수학 놀이 하자!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B4B4B),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatChip(text: '⭐ $totalStars'),
                const SizedBox(width: 10),
                _StatChip(text: '🪙 $coins'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 누적 점수로 자라는 칭호 카드
class _RankCard extends StatelessWidget {
  const _RankCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final rank = rankForPoints(points);
    final next = nextRankFor(points);
    final progress = next == null
        ? 1.0
        : (points - rank.minPoints) / (next.minPoints - rank.minPoints);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6D8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(rank.emoji, style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금 나는 ${rank.title}!',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFF0EAD2),
                    color: const Color(0xFFFFC800),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next == null
                      ? '최고 칭호까지 다 모았어요! 🎉'
                      : '${next.emoji} ${next.title}까지 ${next.minPoints - points}점',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 꾸미기 가게 / 자유 연습으로 들어가는 메뉴 카드
class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      color: Colors.white,
      shadowColor: Colors.grey.shade300,
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      onTap: onTap,
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
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
                      '${unit.index + 1}묶음 · ${unit.title}',
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
                              value: clearedCount / Curriculum.levelsPerUnit,
                              minHeight: 8,
                              backgroundColor: Colors.grey.shade200,
                              color: unit.color,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$clearedCount/${Curriculum.levelsPerUnit}',
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

/// 동그란 3D 단계 버튼: 잠김 🔒 / 도전 가능(통통) / 통과(별 표시)
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
                  fontSize: 18,
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
