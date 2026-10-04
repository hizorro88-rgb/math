import 'package:flutter/material.dart';

import '../theme.dart';
import 'bouncy_button.dart';

/// 고르는 칸 — 앱 전체의 "선택됨" 모양은 이것 하나다.
/// 라임 바탕 + 초록 테두리 3 + 오른쪽 위 ✓ (초록 = 선택됨·앞으로).
/// 연습 유형·과목·난이도·얼굴·나이처럼 여럿 중 하나를 고르는 곳에 쓴다.
class SelectableTile extends StatelessWidget {
  const SelectableTile({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
    this.sub,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// 작은 보조 글 (어른용, 선택)
  final String? sub;

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: selected ? AppColors.selectedFill : Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? AppColors.correct : AppColors.outline,
          width: selected ? 3 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: selected ? AppColors.correct : AppColors.outline,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
          if (sub != null)
            Text(
              sub!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
            ),
        ],
      ),
    );
    return PressBounce(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          tile,
          if (selected)
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
}

/// 작은 고르는 칸 (얼굴 동그라미·나이 칩처럼 한 줄에 여럿 놓이는 것).
/// [SelectableTile]과 같은 모양 규칙: 라임 바탕 + 초록 테두리 + ✓.
class SelectableChip extends StatelessWidget {
  const SelectableChip({
    super.key,
    required this.child,
    required this.selected,
    required this.onTap,
    this.circle = false,
    this.size,
    this.semanticLabel,
  });

  final Widget child;
  final bool selected;
  final VoidCallback onTap;

  /// 얼굴처럼 동그란 칸
  final bool circle;

  /// 동그란 칸의 지름
  final double? size;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final box = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: circle ? size ?? 64 : null,
      height: circle ? size ?? 64 : null,
      padding: circle
          ? null
          : const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      alignment: circle ? Alignment.center : null,
      decoration: BoxDecoration(
        color: selected ? AppColors.selectedFill : Colors.white,
        shape: circle ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circle ? null : BorderRadius.circular(14),
        border: Border.all(
          color: selected ? AppColors.correct : AppColors.outline,
          width: selected ? 3 : 2,
        ),
      ),
      child: child,
    );
    return Semantics(
      button: true,
      selected: selected,
      label: semanticLabel,
      child: PressBounce(
        onTap: onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            box,
            if (selected)
              const Positioned(
                top: -6,
                right: -6,
                child: CircleAvatar(
                  radius: 11,
                  backgroundColor: AppColors.correct,
                  child:
                      Icon(Icons.check_rounded, size: 15, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
