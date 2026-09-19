import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../models/shop.dart';
import '../theme.dart';

/// 꾸미기 없이 쿼카 얼굴만 보여줄 때 (응원 말풍선·팝업·빈 화면 등)
class QuokkaFace extends StatelessWidget {
  const QuokkaFace({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/quokka.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // 픽셀아트는 보간 없이 또렷하게 (도트 뭉개짐 방지)
      filterQuality: FilterQuality.none,
    );
  }
}

/// 산 아이템을 걸친 쿼카 마스코트.
/// 본체는 오리지널 에셋(assets/images/quokka.png)이고 2.6~4.6초마다
/// 눈을 깜빡인다. 머리 위 모자, 얼굴 앞 안경, 옆에는 친구가 붙는다.
class QuokkaAvatar extends StatefulWidget {
  const QuokkaAvatar({super.key, this.size = 52, this.equipped = const []});

  final double size;
  final List<ShopItem> equipped;

  @override
  State<QuokkaAvatar> createState() => _QuokkaAvatarState();
}

class _QuokkaAvatarState extends State<QuokkaAvatar> {
  final _random = Random();
  Timer? _timer;
  bool _blink = false;

  @override
  void initState() {
    super.initState();
    // 위젯 테스트의 pumpAndSettle이 끝나도록 반복 타이머는 AppMotion으로 끈다.
    if (AppMotion.loops) _scheduleBlink();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleBlink() {
    _timer = Timer(
      Duration(milliseconds: 2600 + _random.nextInt(2000)),
      () {
        if (!mounted) return;
        setState(() => _blink = true);
        _timer = Timer(const Duration(milliseconds: 140), () {
          if (!mounted) return;
          setState(() => _blink = false);
          _scheduleBlink();
        });
      },
    );
  }

  ShopItem? _bySlot(ItemSlot slot) {
    for (final item in widget.equipped) {
      if (item.slot == slot) return item;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
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
          // 배경은 쿼카 뒤에 은은하게 깔린다.
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
            child: Image.asset(
              _blink
                  ? 'assets/images/quokka_blink.png'
                  : 'assets/images/quokka.png',
              width: size * 1.2,
              height: size * 1.2,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.none, // 도트 뭉개짐 방지
              gaplessPlayback: true, // 프레임 전환 시 깜빡이는 공백 방지
            ),
          ),
          // 도트 아이템은 쿼카와 같은 128px 캔버스에 위치까지 맞춰 그려져 있어
          // 본체와 같은 크기로 겹치면 정확히 착용된다.
          for (final item in [hat, face])
            if (item != null && item.pixel)
              Positioned(
                bottom: 0,
                child: Image.asset(
                  'assets/images/items/${item.id}.png',
                  width: size * 1.2,
                  height: size * 1.2,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.none,
                  gaplessPlayback: true,
                ),
              ),
          if (hat != null && !hat.pixel)
            Positioned(
              bottom: size * 0.98,
              child: Text(hat.emoji, style: TextStyle(fontSize: size * 0.5)),
            ),
          if (face != null && !face.pixel)
            Positioned(
              bottom: size * 0.56,
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
