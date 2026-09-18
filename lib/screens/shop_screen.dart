import 'package:flutter/material.dart';

import '../models/progress.dart';
import '../models/shop.dart';
import '../services/sounds.dart';
import '../widgets/owl_avatar.dart';

/// 부엉이 꾸미기 상점: 퀴즈로 모은 코인으로 모자·안경·친구를 산다.
class ShopScreen extends StatefulWidget {
  const ShopScreen({super.key});

  @override
  State<ShopScreen> createState() => _ShopScreenState();
}

class _ShopScreenState extends State<ShopScreen> {
  int _coins = 0;
  Set<String> _owned = {};
  List<ShopItem> _equipped = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final coins = await ProgressStore.loadCoins();
    final owned = await ShopStore.loadOwned();
    final equipped = await ShopStore.loadEquipped();
    if (!mounted) return;
    setState(() {
      _coins = coins;
      _owned = owned;
      _equipped = equipped;
      _loaded = true;
    });
  }

  bool _isEquipped(ShopItem item) => _equipped.any((e) => e.id == item.id);

  Future<void> _onItemTap(ShopItem item) async {
    if (_owned.contains(item.id)) {
      // 보유 중: 착용 ↔ 벗기
      if (_isEquipped(item)) {
        await ShopStore.unequip(item);
      } else {
        await ShopStore.equip(item);
      }
      await _load();
      return;
    }

    // 구매 시도
    if (await ShopStore.buy(item)) {
      Sounds.buy(); // 효과음은 기다리지 않는다
      await _load();
      if (!mounted) return;
      // 연타해도 스낵바가 쌓이지 않게 이전 것을 지우고 띄운다.
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${item.emoji} ${item.name}을(를) 샀어요!'),
            duration: const Duration(seconds: 1),
          ),
        );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('코인이 부족해요! ${item.cost - _coins}개 더 모아요 💪'),
            duration: const Duration(seconds: 1),
          ),
        );
    }
  }

  /// 부기의 한 마디: 살 수 있는 게 없으면 가장 가까운 목표를 알려준다.
  String _cheerLine() {
    if (_equipped.isNotEmpty) return '멋지다! 아이템을 눌러 바꿔 봐요';
    final wishList = shopItems.where((i) => !_owned.contains(i.id)).toList()
      ..sort((a, b) => a.cost.compareTo(b.cost));
    if (wishList.isEmpty) return '와, 전부 다 모았어! 부엉!';
    final next = wishList.first;
    if (_coins >= next.cost) return '아이템을 사서 나를 꾸며 줘!';
    final need = next.cost - _coins;
    return '${next.emoji} ${next.name}까지 🪙 $need! 퀴즈로 모아 보자!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '꾸미기 가게',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '🪙 $_coins',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 내 부엉이 미리보기
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        offset: const Offset(0, 4),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      OwlAvatar(size: 88, equipped: _equipped),
                      const SizedBox(height: 6),
                      Text(
                        _cheerLine(),
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                for (final slot in ItemSlot.values) ...[
                  const SizedBox(height: 10),
                  Text(
                    switch (slot) {
                      ItemSlot.hat => '👒 머리에 쓰는 것',
                      ItemSlot.face => '🥸 얼굴에 쓰는 것',
                      ItemSlot.side => '🧸 같이 다니는 친구',
                      ItemSlot.bg => '🖼️ 뒤에 깔리는 배경',
                    },
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.35,
                    children: [
                      for (final item in shopItems)
                        if (item.slot == slot)
                          _ItemCard(
                            item: item,
                            owned: _owned.contains(item.id),
                            equipped: _isEquipped(item),
                            affordable: _coins >= item.cost,
                            onTap: () => _onItemTap(item),
                          ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
              ],
            ),
    );
  }
}

/// 상점 아이템 카드: 가격 / 보유 / 착용 중 상태를 보여준다.
class _ItemCard extends StatelessWidget {
  const _ItemCard({
    required this.item,
    required this.owned,
    required this.equipped,
    required this.affordable,
    required this.onTap,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool affordable;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF3DA35D);
    final dimmed = !owned && !affordable;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: equipped ? const Color(0xFFD7FFB8) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: equipped ? green : Colors.grey.shade300,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: equipped ? const Color(0xFFB5E48C) : Colors.grey.shade300,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(
              opacity: dimmed ? 0.45 : 1,
              child: Text(item.emoji, style: const TextStyle(fontSize: 36)),
            ),
            const SizedBox(height: 4),
            Text(
              item.name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: equipped
                    ? green
                    : owned
                        ? const Color(0xFFE8F5E0)
                        : dimmed
                            ? Colors.grey.shade200
                            : const Color(0xFFFFF6D8),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                equipped
                    ? '착용 중'
                    : owned
                        ? '보유 ✓'
                        : dimmed
                            ? '🪙 ${item.cost} · 부족'
                            : '🪙 ${item.cost}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: equipped
                      ? Colors.white
                      : dimmed
                          ? const Color(0xFF6B6B6B)
                          : const Color(0xFF7A6200),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
