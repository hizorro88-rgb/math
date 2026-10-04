import 'package:flutter/material.dart';

import '../models/progress.dart';
import '../models/shop.dart';
import '../theme.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/kid_notice.dart';
import '../widgets/quokka_avatar.dart';

/// 쿼카 꾸미기 상점: 퀴즈로 모은 코인으로 모자·안경·친구를 산다.
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
      // 소리 없이 바뀌면 아이는 눌린 줄 모른다 — 딩동 + 한마디.
      if (_isEquipped(item)) {
        await ShopStore.unequip(item);
        Speech.speak('${item.name} 벗었어요');
      } else {
        await ShopStore.equip(item);
        Sounds.pop();
        Speech.speak('${item.name} 멋져요!');
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
      showKidNotice(context, emoji: item.emoji, text: '${item.name} 샀어요!');
    } else {
      if (!mounted) return;
      showKidNotice(context,
          emoji: '🪙', text: '코인이 모자라요. ${item.cost - _coins}개 더 모아요!');
    }
  }

  /// 쿼카의 한 마디: 살 수 있는 게 없으면 가장 가까운 목표를 알려준다.
  String _cheerLine() {
    if (_equipped.isNotEmpty) return '멋지다! 아이템을 눌러 바꿔 봐요';
    final wishList = shopItems.where((i) => !_owned.contains(i.id)).toList()
      ..sort((a, b) => a.cost.compareTo(b.cost));
    if (wishList.isEmpty) return '와, 전부 다 모았어! 신난다!';
    final next = wishList.first;
    if (_coins >= next.cost) return '아이템을 사서 나를 꾸며 줘!';
    final need = next.cost - _coins;
    return '${next.emoji} ${next.name}까지 🪙 $need! 퀴즈로 모아 보자!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('꾸미기 가게'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '🪙 $_coins',
                style: const TextStyle(
                  fontSize: AppFont.heading,
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
                // 내 쿼카 미리보기
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.outline, width: 2),
                  ),
                  child: Column(
                    children: [
                      QuokkaAvatar(size: 108, equipped: _equipped),
                      const SizedBox(height: 6),
                      Text(
                        _cheerLine(),
                        style: const TextStyle(
                          fontSize: AppFont.body,
                          color: AppColors.inkSoft,
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
                      fontSize: AppFont.title,
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
                            remaining: item.cost - _coins,
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
    required this.remaining,
    required this.onTap,
  });

  final ShopItem item;
  final bool owned;
  final bool equipped;
  final bool affordable;

  /// 이 아이템까지 더 모아야 하는 코인 수 (부족할 때만 의미)
  final int remaining;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dimmed = !owned && !affordable;
    // 아직 못 사는 물건: 얼마나 모았는지 앰버 막대로 (글 대신 그림)
    final saved = item.cost == 0 ? 1.0 : 1 - remaining / item.cost;

    final Widget status;
    if (equipped) {
      status = _pill('착용 중', AppColors.correct, Colors.white);
    } else if (owned) {
      status = _pill('👕 입기', AppColors.selectedFill, AppColors.greenPressed);
    } else if (affordable) {
      status = _pill('🪙 ${item.cost}', AppColors.amber, AppColors.ink);
    } else {
      status = Column(
        children: [
          Text('🪙 ${item.cost}',
              style: const TextStyle(
                  fontSize: AppFont.small,
                  fontWeight: FontWeight.bold,
                  color: AppColors.inkMuted)),
          const SizedBox(height: 3),
          SizedBox(
            width: 70,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: saved.clamp(0.0, 1.0),
                minHeight: 7,
                color: AppColors.amber,
                backgroundColor: AppColors.line,
              ),
            ),
          ),
        ],
      );
    }

    return PressBounce(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                color: equipped ? AppColors.selectedFill : Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: equipped ? AppColors.correct : AppColors.outline,
                  width: equipped ? 3 : 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: equipped ? AppColors.correct : AppColors.outline,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Opacity(
                    opacity: dimmed ? 0.45 : 1,
                    child:
                        Text(item.emoji, style: const TextStyle(fontSize: 36)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.name,
                    style: const TextStyle(
                        fontSize: AppFont.body, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  status,
                ],
              ),
            ),
          ),
          if (equipped)
            const Positioned(
              top: -6,
              right: -4,
              child: CircleAvatar(
                radius: 12,
                backgroundColor: AppColors.correct,
                child: Icon(Icons.check_rounded, size: 16, color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  Widget _pill(String text, Color fill, Color ink) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          text,
          style: TextStyle(
              fontSize: AppFont.small, fontWeight: FontWeight.bold, color: ink),
        ),
      );
}
