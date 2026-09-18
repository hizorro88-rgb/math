import 'package:flutter/material.dart';

import '../theme.dart';
import 'bouncy_button.dart';

/// 동그란 단계 버튼 (모든 과목 공용).
/// - 잠김: 자물쇠 대신 조용한 점선 빈 원 — "여긴 아직"이 아니라 "다음에 올 곳"
/// - 지금 도전할 단계: 크고 컬러풀하게, 은은한 펄스로 시선 유도
/// - 통과: 과목색 그라데이션 + 별
class LevelBubble extends StatelessWidget {
  const LevelBubble({
    super.key,
    required this.number,
    required this.stars,
    required this.unlocked,
    required this.color,
    required this.onTap,
  });

  /// 카드 안에서의 번호 (1~10)
  final int number;
  final int stars;
  final bool unlocked;
  final Color color;
  final VoidCallback onTap;

  bool get _cleared => stars >= 1;
  bool get _isCurrent => unlocked && !_cleared;

  @override
  Widget build(BuildContext context) {
    if (!unlocked) {
      // 잠김: 점선 빈 원 (자물쇠 없음)
      return SizedBox(
        width: 56,
        height: 62,
        child: CustomPaint(
          painter: _DashedCirclePainter(),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 글을 몰라도 "잠김"이 읽히도록 작은 자물쇠를 함께 보여준다.
              const Icon(Icons.lock_rounded,
                  size: 13, color: Color(0xFFB3A995)),
              Text(
                '$number',
                style: displayStyle(
                  fontSize: 15,
                  color: const Color(0xFF9E9382),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final size = _isCurrent ? 66.0 : 56.0;
    final bubble = GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: _cleared
              ? LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [color, BouncyButton.darken(color, 0.08)],
                )
              : null,
          color: _cleared ? null : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 3),
          boxShadow: [
            BoxShadow(
              color: _cleared
                  ? BouncyButton.darken(color, 0.15)
                  : AppColors.outline,
              offset: const Offset(0, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '$number',
              style: displayStyle(
                fontSize: _isCurrent ? 24 : 18,
                color: _cleared ? Colors.white : color,
              ),
            ),
            if (_cleared)
              Text('⭐' * stars, style: const TextStyle(fontSize: 7)),
          ],
        ),
      ),
    );

    // 지금 도전할 단계는 숨 쉬듯 커졌다 작아지고, "여기부터!"를 달아준다.
    if (_isCurrent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Pulse(child: bubble),
          const SizedBox(height: 2),
          Text(
            '여기부터!',
            style: displayStyle(fontSize: 11, color: AppColors.green),
          ),
        ],
      );
    }
    return bubble;
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (AppMotion.loops) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: 1.07).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}

/// 잠긴 단계의 점선 원
class _DashedCirclePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFD8CFBE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final fill = Paint()..color = AppColors.lockedNode.withValues(alpha: 0.5);
    final center = Offset(size.width / 2, size.height / 2);
    final radius =
        (size.width < size.height ? size.width : size.height) / 2 - 2;
    canvas.drawCircle(center, radius, fill);
    // 점선: 짧은 호를 돌아가며 그린다
    const dashCount = 14;
    const gapRatio = 0.5;
    const sweep = 2 * 3.141592653589793 / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * (1 - gapRatio),
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
