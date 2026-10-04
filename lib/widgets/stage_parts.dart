import 'package:flutter/material.dart';

import '../theme.dart';
import 'kid_notice.dart';
import 'level_bubble.dart';

/// 단계 원 하나의 정보 (과목과 무관)
class StageLevel {
  const StageLevel({
    required this.number,
    required this.stars,
    required this.unlocked,
    required this.onTap,
  });

  /// 묶음 안에서의 번호 (1~10)
  final int number;
  final int stars;
  final bool unlocked;
  final VoidCallback onTap;
}

/// 단계 지도의 묶음 카드 — 수학·한글·영어·외국어 공용.
///
/// - 정보 카드(흰 바탕 + 테두리, 반경 22). 진행 막대·"0/10" 글자는 없다 —
///   원이 차는 것 자체가 진행이다.
/// - 아직 못 여는 묶음은 원 10개 대신 접힌 한 줄(빈 동그라미). 누르면 "앞 묶음부터!"
class StageUnitCard extends StatelessWidget {
  const StageUnitCard({
    super.key,
    required this.emoji,
    required this.title,
    required this.color,
    required this.levels,
    this.highlight = true,
  });

  /// 이 묶음에 "지금 할 원"(펄스)을 표시할지 — 지도 전체에서 첫 묶음 하나만
  final bool highlight;

  final String emoji;
  final String title;
  final Color color;
  final List<StageLevel> levels;

  bool get _locked => levels.isNotEmpty && !levels.first.unlocked;

  /// 이 묶음에서 열렸고 아직 안 깬 첫 원
  StageLevel? get _firstOpen {
    for (final l in levels) {
      if (l.unlocked && l.stars == 0) return l;
    }
    return null;
  }

  /// 열렸고 안 깬 원이 있는 묶음인지 (지도가 펄스 묶음을 고를 때)
  static bool hasOpen(Iterable<(bool unlocked, int stars)> levels) =>
      levels.any((l) => l.$1 && l.$2 == 0);

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
        const SizedBox(width: 10),
        Expanded(
            child: Text(title, style: displayStyle(fontSize: AppFont.title))),
        if (_locked)
          // 🔒(자물쇠)는 '어른이 여는 것'에만 — 진행 잠금은 빈 점선 동그라미
          const Icon(Icons.radio_button_unchecked_rounded,
              color: AppColors.inkMuted, size: 22),
      ],
    );

    if (_locked) {
      return Semantics(
        button: true,
        label: '$title (아직 잠김)',
        child: GestureDetector(
          onTap: () {
            LevelBubble.revealCurrent(context);
            showKidNotice(context,
                emoji: '👆', text: '앞 묶음부터 해요! 반짝이는 동그라미를 찾아봐');
          },
          child: Opacity(
            opacity: 0.6,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line, width: 2),
              ),
              child: header,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          header,
          const SizedBox(height: 14),
          LevelGrid(
            children: [
              for (final level in levels)
                LevelBubble(
                  number: level.number,
                  stars: level.stars,
                  unlocked: level.unlocked,
                  color: color,
                  onTap: level.onTap,
                  current: highlight && level == _firstOpen,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
