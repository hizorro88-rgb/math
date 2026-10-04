import 'package:flutter/material.dart';

import '../models/badges.dart';
import '../models/progress.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/kid_notice.dart';

/// 배지 도감: 지금까지 모은 배지와 앞으로 모을 배지.
class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> {
  late final Future<BadgeData> _dataFuture = loadBadgeData();
  late final Future<int> _pointsFuture = ProgressStore.loadPoints();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('배지 도감'),
      ),
      body: FutureBuilder<BadgeData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final earned = [for (final b in allBadges) b.earnedBy(data)];
          final earnedCount = earned.where((e) => e).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // 내 띠: 공부할수록 띠 색이 바뀐다 (숫자 대신 막대)
              FutureBuilder<int>(
                future: _pointsFuture,
                builder: (context, snap) => _BeltCard(points: snap.data ?? 0),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.rewardSurface,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Text(
                  '지금까지 배지 $earnedCount개 / ${allBadges.length}개를 모았어요!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: AppFont.body,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.9,
                children: [
                  for (var i = 0; i < allBadges.length; i++)
                    _BadgeCard(badge: allBadges[i], earned: earned[i]),
                ],
              ),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  const _BadgeCard({required this.badge, required this.earned});

  final LearnBadge badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    return PressBounce(
      // 누르면 이름과 얻는 방법을 읽어 준다 (글을 못 읽어도 알 수 있게)
      onTap: () => showKidNotice(
        context,
        emoji: earned ? badge.emoji : '❔',
        text: earned ? '${badge.title}!' : badge.desc,
      ),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: earned ? Colors.white : AppColors.cream,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: earned ? AppColors.amber : AppColors.line,
            width: earned ? 3 : 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 못 얻은 배지는 그림자(실루엣)로 — 무엇인지 궁금하게
            earned
                ? Text(badge.emoji, style: const TextStyle(fontSize: 38))
                : ColorFiltered(
                    colorFilter: const ColorFilter.mode(
                        AppColors.silhouette, BlendMode.srcIn),
                    child:
                        Text(badge.emoji, style: const TextStyle(fontSize: 38)),
                  ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                badge.title,
                style: displayStyle(
                  fontSize: AppFont.body,
                  color: earned ? AppColors.ink : AppColors.inkMuted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 띠 카드: 지금 띠 + 다음 띠까지 막대
class _BeltCard extends StatelessWidget {
  const _BeltCard({required this.points});

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
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Row(
        children: [
          _Belt(color: rank.color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('지금 나는 ${rank.title}!',
                    style: displayStyle(fontSize: AppFont.title)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: progress.clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: AppColors.line,
                          color: AppColors
                              .amber, // 차오르는 막대 = 보상 색 (띠 색은 양 끝 그림이 보여 준다)
                        ),
                      ),
                    ),
                    if (next != null) ...[
                      const SizedBox(width: 8),
                      _Belt(color: next.color, small: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 띠 그림 (매듭이 있는 색 띠)
class _Belt extends StatelessWidget {
  const _Belt({required this.color, this.small = false});

  final Color color;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final w = small ? 34.0 : 64.0;
    final edge = Color.lerp(color, Colors.black, 0.25)!;
    return SizedBox(
      width: w,
      height: w * 0.6,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            height: w * 0.22,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: edge, width: 1.5),
            ),
          ),
          // 매듭 + 늘어진 끈
          Positioned(
            top: w * 0.12,
            child: Container(
              width: w * 0.22,
              height: w * 0.22,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: edge, width: 1.5),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: w * 0.36,
            child: Transform.rotate(
              angle: 0.35,
              child: Container(width: w * 0.1, height: w * 0.26, color: color),
            ),
          ),
          Positioned(
            bottom: 0,
            right: w * 0.36,
            child: Transform.rotate(
              angle: -0.35,
              child: Container(width: w * 0.1, height: w * 0.26, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
