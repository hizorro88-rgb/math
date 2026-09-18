import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// 결과 화면용 색종이: 위에서 흩날리며 1.6초 떨어지고 끝난다.
/// (한 번만 재생되는 유한 애니메이션이라 테스트의 pumpAndSettle과도 안전)
class ConfettiBurst extends StatelessWidget {
  const ConfettiBurst({super.key, this.pieces = 36});

  final int pieces;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeIn,
        builder: (context, t, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(t: t, pieces: pieces),
        ),
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.t, required this.pieces});

  final double t;
  final int pieces;

  static const _colors = [
    AppColors.green,
    AppColors.amber,
    AppColors.coral,
    Color(0xFF4D96FF),
    Color(0xFFFF6B9D),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t >= 1) return;
    final random = math.Random(7); // 매 프레임 같은 배치
    for (var i = 0; i < pieces; i++) {
      final x = random.nextDouble() * size.width;
      final speed = 0.6 + random.nextDouble() * 0.8;
      final sway = (random.nextDouble() - 0.5) * 60;
      final y = -20 + t * speed * (size.height + 40);
      if (y > size.height) continue;
      final paint = Paint()
        ..color = _colors[i % _colors.length]
            .withValues(alpha: (1 - t) * 0.9 + 0.1);
      canvas.save();
      canvas.translate(x + math.sin(t * math.pi * 2 + i) * sway * t, y);
      canvas.rotate(t * math.pi * 4 * (random.nextBool() ? 1 : -1));
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 6 + random.nextDouble() * 5,
            height: 9 + random.nextDouble() * 5,
          ),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _ConfettiPainter oldDelegate) =>
      oldDelegate.t != t;
}
