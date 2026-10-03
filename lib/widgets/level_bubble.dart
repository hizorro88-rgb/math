import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';
import 'bouncy_button.dart';
import 'kid_notice.dart';
import 'pulse.dart';

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
    this.current,
  });

  /// 지금 도전할 원인지 (펄스 + '여기부터!'). null이면 열렸고 안 깬 원.
  /// 펄스는 화면에 하나만 — 지도가 첫 미완료 원 하나만 true로 준다.
  final bool? current;

  /// 카드 안에서의 번호 (1~10)
  final int number;
  final int stars;
  final bool unlocked;
  final Color color;
  final VoidCallback onTap;

  bool get _cleared => stars >= 1;
  bool get _isCurrent => current ?? (unlocked && !_cleared);

  @override
  Widget build(BuildContext context) {
    if (!unlocked) return _LockedBubble(number: number);

    final size = _isCurrent ? 66.0 : 56.0;
    final bubble = Semantics(
      button: true,
      label: '$number단계',
      onTap: onTap,
      excludeSemantics: true,
      child: PressBounce(
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
            ],
          ),
        ),
      ),
    );

    // 지금 도전할 단계는 숨 쉬듯 커졌다 작아지고, "여기부터!"를 달아준다.
    if (_isCurrent) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Pulse(child: bubble),
          const SizedBox(height: 6),
          // 초록 알약 = "여기부터" (초록은 앞으로)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.green,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '여기부터!',
              style: displayStyle(fontSize: 12, color: Colors.white),
            ),
          ),
        ],
      );
    }
    // 통과한 원: 별은 원 밖 아래에 읽을 수 있는 크기로
    if (_cleared) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          bubble,
          const SizedBox(height: 3),
          Text(
            '⭐' * stars + '☆' * (3 - stars),
            style: const TextStyle(fontSize: 11, color: AppColors.inkMuted),
          ),
        ],
      );
    }
    return bubble;
  }
}

/// 잠김: 점선 빈 원. 눌러도 가만히 있으면 아이는 "고장"으로 안다 —
/// 도리도리 흔들고, 반짝이는 원부터 하라고 그림+목소리로 알려 준다.
class _LockedBubble extends StatefulWidget {
  const _LockedBubble({required this.number});

  final int number;

  @override
  State<_LockedBubble> createState() => _LockedBubbleState();
}

class _LockedBubbleState extends State<_LockedBubble>
    with SingleTickerProviderStateMixin {
  late final AnimationController _shake = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  @override
  void dispose() {
    _shake.dispose();
    super.dispose();
  }

  void _tap() {
    _shake.forward(from: 0);
    showKidNotice(context, emoji: '👆', text: '반짝이는 동그라미부터 해요!');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${widget.number}단계 (아직 잠김)',
      onTap: _tap,
      excludeSemantics: true,
      child: GestureDetector(
        onTap: _tap,
        child: AnimatedBuilder(
          animation: _shake,
          builder: (context, child) => Transform.translate(
            offset: Offset(
                math.sin(_shake.value * math.pi * 6) * 6 * (1 - _shake.value),
                0),
            child: child,
          ),
          child: SizedBox(
            width: 56,
            height: 62,
            child: CustomPaint(
              painter: _DashedCirclePainter(),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${widget.number}',
                    style: displayStyle(
                      fontSize: 15,
                      color: const Color(0xFF9E9382),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
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

/// 단계 원들을 한 줄에 5개씩, 열 위치를 맞춰 배치하는 그리드.
/// 원 크기가 상태(현재·잠김)마다 달라도 각 칸의 가운데에 정렬돼
/// 위아래 줄의 1~5·6~10 위치가 서로 맞는다.
class LevelGrid extends StatelessWidget {
  const LevelGrid({super.key, required this.children, this.perRow = 5});

  final List<Widget> children;
  final int perRow;

  @override
  Widget build(BuildContext context) {
    const gap = 8.0;
    final rows = (children.length + perRow - 1) ~/ perRow;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = (constraints.maxWidth - gap * (perRow - 1)) / perRow;
        return Column(
          children: [
            for (var r = 0; r < rows; r++) ...[
              if (r > 0) const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < perRow; i++) ...[
                    if (i > 0) const SizedBox(width: gap),
                    SizedBox(
                      width: cell,
                      child: r * perRow + i < children.length
                          ? Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: children[r * perRow + i],
                              ),
                            )
                          : null,
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}
