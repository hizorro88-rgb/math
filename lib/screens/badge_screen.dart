import 'package:flutter/material.dart';

import '../models/badges.dart';

/// 배지 도감: 지금까지 모은 배지와 앞으로 모을 배지.
class BadgeScreen extends StatefulWidget {
  const BadgeScreen({super.key});

  @override
  State<BadgeScreen> createState() => _BadgeScreenState();
}

class _BadgeScreenState extends State<BadgeScreen> {
  late final Future<BadgeData> _dataFuture = loadBadgeData();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '배지 도감',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFE3FF),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  '지금까지 배지 $earnedCount개 / ${allBadges.length}개를 모았어요!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF6B2FB3),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.15,
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
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: earned ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: earned ? const Color(0xFFFFD34D) : Colors.grey.shade300,
          width: 3,
        ),
        boxShadow: earned
            ? [
                BoxShadow(
                  color: const Color(0xFFFFD34D).withValues(alpha: 0.4),
                  offset: const Offset(0, 4),
                  blurRadius: 8,
                ),
              ]
            : null,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: earned ? 1 : 0.35,
            child: Text(
              earned ? badge.emoji : '🔒',
              style: const TextStyle(fontSize: 36),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            badge.title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: earned ? Colors.black87 : Colors.grey,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            badge.desc,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}
