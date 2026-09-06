import 'package:flutter/material.dart';

import '../models/daily.dart';
import '../models/progress.dart';
import '../widgets/bouncy_button.dart';
import 'sticker_book_screen.dart';

/// 결과 화면: 별·점수·칭호를 보여주고 다음 단계 또는 다시 도전으로 이어진다.
/// 수학·한글 어느 과목이든 쓸 수 있도록 다음/다시 화면은 빌더로 받는다.
class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.correctCount,
    required this.totalCount,
    required this.earnedPoints,
    required this.retryBuilder,
    this.chestCoins = 0,
    this.stickerEarned = false,
    this.bossCleared = false,
    this.completedMissions = const [],
    this.milestoneDays = 0,
    this.milestoneCoins = 0,
    this.headerText,
    this.showUnlockHint = false,
    this.nextLabel,
    this.nextBuilder,
    this.homeLabel = '처음으로',
    this.homeIcon = Icons.home_rounded,
  });

  final int correctCount;
  final int totalCount;

  /// 이번 판에 모은 점수 (통과 보너스 포함, 보물상자 제외)
  final int earnedPoints;

  /// 보물상자에서 나온 보너스 코인 (0이면 상자 없음)
  final int chestCoins;

  /// 이번 판을 통과해서 스티커북에 붙일 스티커 1장을 받았는지
  final bool stickerEarned;

  /// 주간 보스전을 통과했는지 (통과 보너스는 earnedPoints에 포함)
  final bool bossCleared;

  /// 이번 판으로 새로 달성한 데일리 미션들
  final List<DailyMission> completedMissions;

  /// 스트릭 마일스톤(3·7·14·30일)에 막 도달했으면 그 일수와 보너스 코인
  final int milestoneDays;
  final int milestoneCoins;

  /// 단계 도전이면 '12단계 · 🐞 덧셈 첫걸음' 같은 안내문
  final String? headerText;

  /// 통과하지 못한 단계 도전이면 잠금 해제 안내를 보여준다.
  final bool showUnlockHint;

  /// 다음 단계 버튼 (통과했을 때만 전달)
  final String? nextLabel;
  final Widget Function()? nextBuilder;

  /// 다시 하기를 눌렀을 때 열 퀴즈 화면
  final Widget Function() retryBuilder;

  final String homeLabel;
  final IconData homeIcon;

  int get _stars => starsForScore(correctCount, totalCount);

  String get _message => switch (_stars) {
        3 => '와, 최고예요! 🏆',
        2 => '정말 잘했어요! 👏',
        1 => '잘했어요! 조금만 더 힘내요 💪',
        _ => '괜찮아요! 다시 해 볼까요? 🌱',
      };

  void _replace(BuildContext context, Widget Function() builder) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => builder()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasNext = nextLabel != null && nextBuilder != null;

    return Scaffold(
      // 화면이 작으면 스크롤되고, 크면 위아래로 넉넉하게 펼쳐진다.
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints:
                  BoxConstraints(minHeight: constraints.maxHeight - 48),
              child: IntrinsicHeight(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Spacer(),
                    if (headerText != null) ...[
                      Text(
                        headerText!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < 3; i++)
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: Duration(milliseconds: 400 + i * 300),
                            curve: Curves.elasticOut,
                            builder: (context, value, child) => Transform.scale(
                              scale: value,
                              child: child,
                            ),
                            child: Text(
                              i < _stars ? '⭐' : '☆',
                              style: const TextStyle(fontSize: 64),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '$totalCount문제 중에 $correctCount문제를 맞혔어요!',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, color: Colors.grey.shade700),
                    ),
                    if (showUnlockHint) ...[
                      const SizedBox(height: 8),
                      Text(
                        '5문제 이상 맞히면 다음 단계가 열려요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 16, color: Colors.grey.shade600),
                      ),
                    ],
                    const SizedBox(height: 20),
                    _PointsCard(earnedPoints: earnedPoints),
                    if (bossCleared) ...[
                      const SizedBox(height: 12),
                      const _BossBanner(),
                    ],
                    if (chestCoins > 0) ...[
                      const SizedBox(height: 12),
                      _ChestBanner(coins: chestCoins),
                    ],
                    if (stickerEarned) ...[
                      const SizedBox(height: 12),
                      const _StickerBanner(),
                    ],
                    if (milestoneDays > 0) ...[
                      const SizedBox(height: 12),
                      _MilestoneBanner(
                          days: milestoneDays, coins: milestoneCoins),
                    ],
                    if (completedMissions.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _MissionBanner(missions: completedMissions),
                    ],
                    const Spacer(),
                    if (hasNext) ...[
                      BouncyButton(
                        color: const Color(0xFF58CC02),
                        onTap: () => _replace(context, nextBuilder!),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              nextLabel!,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.arrow_forward_rounded,
                              size: 28,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    BouncyButton(
                      color: hasNext ? Colors.white : const Color(0xFF58CC02),
                      shadowColor: hasNext ? Colors.grey.shade300 : null,
                      border: hasNext
                          ? Border.all(
                              color: const Color(0xFF58CC02), width: 2)
                          : null,
                      onTap: () => _replace(context, retryBuilder),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '다시 하기',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: hasNext
                                  ? const Color(0xFF58CC02)
                                  : Colors.white,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.refresh_rounded,
                            size: 28,
                            color: hasNext
                                ? const Color(0xFF58CC02)
                                : Colors.white,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    BouncyButton(
                      color: Colors.white,
                      shadowColor: Colors.grey.shade300,
                      border:
                          Border.all(color: const Color(0xFF58CC02), width: 2),
                      onTap: () => Navigator.of(context)
                          .popUntil((route) => route.isFirst),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            homeLabel,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF58CC02),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(homeIcon,
                              size: 28, color: const Color(0xFF58CC02)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 보물상자 보너스 배너: 통! 하고 나타나서 보너스 코인을 알려준다.
class _ChestBanner extends StatelessWidget {
  const _ChestBanner({required this.coins});

  final int coins;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFEFE3FF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFA560E8), width: 2),
        ),
        child: Text(
          '🎁 보물상자 발견! 보너스 +$coins 🪙',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF6B2FB3),
          ),
        ),
      ),
    );
  }
}

/// 스티커 획득 배너: 누르면 스티커북으로 가서 직접 골라 붙인다
class _StickerBanner extends StatelessWidget {
  const _StickerBanner();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const StickerBookScreen()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFFFDE8F4),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFF2A9D4), width: 2),
        ),
        child: Row(
          children: [
            const Text('🎟️', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                '스티커 1장을 받았어요!\n스티커북에서 골라 붙여 보세요',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  height: 1.3,
                  color: Color(0xFFC2185B),
                ),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFEC7CA5),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                '붙이러 가기',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 주간 보스전 클리어 축하 배너
class _BossBanner extends StatelessWidget {
  const _BossBanner();

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF6D8),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFB8860B), width: 2),
        ),
        child: const Text(
          '👑 주간 보스전 클리어! 보너스 +100 🪙',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFF8B6F1F),
          ),
        ),
      ),
    );
  }
}

/// 스트릭 마일스톤(3·7·14·30일 연속 출석) 축하 배너
class _MilestoneBanner extends StatelessWidget {
  const _MilestoneBanner({required this.days, required this.coins});

  final int days;
  final int coins;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.4, end: 1),
      duration: const Duration(milliseconds: 700),
      curve: Curves.elasticOut,
      builder: (context, value, child) =>
          Transform.scale(scale: value, child: child),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFE9E0),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF7A00), width: 2),
        ),
        child: Text(
          '🔥 $days일 연속 출석 달성! 보너스 +$coins 🪙',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: Color(0xFFC24A00),
          ),
        ),
      ),
    );
  }
}

/// 이번 판으로 달성한 데일리 미션 축하 배너
class _MissionBanner extends StatelessWidget {
  const _MissionBanner({required this.missions});

  final List<DailyMission> missions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFEBD6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF9600), width: 2),
      ),
      child: Column(
        children: [
          const Text(
            '🎯 오늘의 미션 완료!',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Color(0xFFB05E00),
            ),
          ),
          const SizedBox(height: 4),
          for (final mission in missions)
            Text(
              '${mission.emoji} ${mission.title}  +${mission.reward} 🪙',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB05E00),
              ),
            ),
        ],
      ),
    );
  }
}

/// 이번 판 점수가 차오르고, 누적 점수와 칭호를 보여주는 카드
class _PointsCard extends StatelessWidget {
  const _PointsCard({required this.earnedPoints});

  final int earnedPoints;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF6D8),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFFFD34D), width: 3),
      ),
      child: Column(
        children: [
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: earnedPoints),
            duration: const Duration(milliseconds: 900),
            builder: (context, value, _) => Text(
              '🪙 +$value점',
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB8860B),
              ),
            ),
          ),
          const SizedBox(height: 6),
          FutureBuilder<int>(
            future: ProgressStore.loadPoints(),
            builder: (context, snapshot) {
              final total = snapshot.data;
              if (total == null) return const SizedBox(height: 20);
              final rank = rankForPoints(total);
              final next = nextRankFor(total);
              return Column(
                children: [
                  Text(
                    '모은 점수 $total점 · ${rank.emoji} ${rank.title}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.brown.shade400,
                    ),
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${next.emoji} ${next.title}까지 ${next.minPoints - total}점!',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.brown.shade300,
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
