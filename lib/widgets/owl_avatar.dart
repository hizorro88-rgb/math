import 'package:flutter/material.dart';

import '../models/shop.dart';

/// 산 아이템을 걸친 부엉이 마스코트.
/// 머리 위 모자, 얼굴 앞 안경, 옆에는 친구(풍선·인형 등)가 붙는다.
class OwlAvatar extends StatelessWidget {
  const OwlAvatar({super.key, this.size = 52, this.equipped = const []});

  final double size;
  final List<ShopItem> equipped;

  ShopItem? _bySlot(ItemSlot slot) {
    for (final item in equipped) {
      if (item.slot == slot) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final hat = _bySlot(ItemSlot.hat);
    final face = _bySlot(ItemSlot.face);
    final side = _bySlot(ItemSlot.side);
    final bg = _bySlot(ItemSlot.bg);

    return SizedBox(
      width: size * 1.5,
      height: size * 1.45,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          // 배경은 부엉이 뒤에 은은하게 깔린다.
          if (bg != null)
            Positioned(
              bottom: size * 0.18,
              child: Opacity(
                opacity: 0.55,
                child: Text(bg.emoji, style: TextStyle(fontSize: size * 1.05)),
              ),
            ),
          Positioned(
            bottom: 0,
            child: Text('🦉', style: TextStyle(fontSize: size)),
          ),
          if (hat != null)
            Positioned(
              bottom: size * 0.92,
              child: Text(hat.emoji, style: TextStyle(fontSize: size * 0.5)),
            ),
          if (face != null)
            Positioned(
              bottom: size * 0.52,
              child: Text(face.emoji, style: TextStyle(fontSize: size * 0.38)),
            ),
          if (side != null)
            Positioned(
              bottom: 0,
              right: -size * 0.1,
              child: Text(side.emoji, style: TextStyle(fontSize: size * 0.55)),
            ),
        ],
      ),
    );
  }
}
