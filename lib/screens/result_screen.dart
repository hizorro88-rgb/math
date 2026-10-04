import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/daily.dart';
import '../models/pet.dart';
import '../models/progress.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/confetti_burst.dart';
import '../widgets/pet_parts.dart';
import '../widgets/pulse.dart';
import '../widgets/quiz_parts.dart';
import '../widgets/quokka_avatar.dart';
import 'sticker_book_screen.dart';
import 'wrong_notes_screen.dart';

/// 결과 화면 — 한 판이 끝난 뒤.
///
/// 글을 못 읽어도 알 수 있게 차례로 하나씩 보여 주고(누르면 건너뜀), 한 문장으로 읽어 준다.
/// ① 진행 점이 차오르며 별이 뜬다 → ② 칭찬 한 줄 → ③ 🪙 이번 판에 늘어난 전부
/// → ④ 보상 칩 한 줄(🎁👑📋🔥🎟️) → ⑤ 친구가 깡충 → ⑥ 주인공 버튼 하나
///
/// 아이가 보는 재화는 ⭐(배움)·🪙(쓰기)·🎟️(모으기) 셋. 나머지 보상은 칩 그림으로만.
class ResultScreen extends StatefulWidget {
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
    this.dots,
  });

  /// 첫 실행의 첫 판이면 홈이 켜 둔다 — 결과의 주인공이 "🏠 친구한테 가기"가 된다.
  static bool firstRunPending = false;

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

  /// 단계 도전이면 '덧셈 첫걸음 · 2단계' 같은 안내 (어른용, 작게)
  final String? headerText;

  /// 통과하지 못한 단계 도전이면 별 1개 자리를 깜빡여 "여기까지!"를 보여 준다.
  final bool showUnlockHint;

  /// 다음 단계 버튼 (통과했고 열려 있을 때만 전달)
  final String? nextLabel;
  final Widget Function()? nextBuilder;

  /// 다시 하기를 눌렀을 때 열 퀴즈 화면
  final Widget Function() retryBuilder;

  final String homeLabel;
  final IconData homeIcon;

  /// 퀴즈 진행 점 (문제마다 하나). 없으면 맞힌 개수로 만든다.
  final List<QuizDot>? dots;

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen>
    with SingleTickerProviderStateMixin {
  /// 전체 연출 (약 3초). 화면을 누르면 끝으로 건너뛴다.
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3000),
  )..forward();

  late final bool _firstRun;

  PetState? _pet;
  int? _coinsNow;
  Rank? _rankUp;

  int get _stars => starsForScore(widget.correctCount, widget.totalCount);

  /// 이번 판에 실제로 늘어난 코인 전부 (상자·미션·연속 출석 포함)
  int get _coinTotal =>
      widget.earnedPoints +
      widget.chestCoins +
      widget.milestoneCoins +
      widget.completedMissions.fold<int>(0, (s, m) => s + m.reward);

  int get _lineIndex => (widget.correctCount * 7 + widget.totalCount) % 3;

  /// 칭찬 한 줄 ([0]은 테스트 고정점)
  static const _messages = [
    ['끝까지 풀었네!', '한 번 더 하면 늘어요!', '시작이 반이에요!'], // 0별
    ['잘했어요! 조금만 더!', '좋아요, 감 잡았어요!', '점점 잘하고 있어요!'],
    ['정말 잘했어요!', '멋져요, 별 두 개!', '거의 다 왔어요!'],
    ['와, 최고예요!', '완벽에 가까워요!', '오늘의 주인공이에요!'],
  ];

  String get _message => _messages[_stars][_lineIndex];

  bool get _hasNext => widget.nextLabel != null && widget.nextBuilder != null;

  /// 주인공 버튼: 첫 판이거나, 통과했는데 다음 단계가 막혀 있으면 "친구한테 가기"
  bool get _friendFirst => _firstRun || (_stars >= 1 && !_hasNext);

  @override
  void initState() {
    super.initState();
    _firstRun = ResultScreen.firstRunPending;
    ResultScreen.firstRunPending = false;
    _loadSide();
    _speak();
  }

  @override
  void dispose() {
    _show.dispose();
    super.dispose();
  }

  Future<void> _loadSide() async {
    final pet = await PetStore.load();
    final coins = await ProgressStore.loadCoins();
    final points = await ProgressStore.loadPoints();
    final before = rankForPoints(math.max(0, points - widget.earnedPoints));
    final after = rankForPoints(points);
    if (!mounted) return;
    setState(() {
      _pet = pet.chosen ? pet : null;
      _coinsNow = coins;
      if (after.minPoints > before.minPoints) _rankUp = after;
    });
  }

  /// 한 문장으로 읽어 준다: 칭찬 → 별 → 코인 → 다음 할 일
  void _speak() {
    final wrong = widget.totalCount - widget.correctCount;
    final parts = <String>[
      _message,
      if (_stars > 0)
        '별 $_stars개, 코인 $_coinTotal개!'
      else if (wrong > 0)
        '틀린 문제는 다시 풀어서 고쳤어. 한 번 더 해 볼까?',
      if (widget.chestCoins > 0) '보물상자도 찾았어!',
      if (_friendFirst)
        '초록 버튼 누르면 친구한테 가!'
      else if (_hasNext)
        '초록 버튼 누르면 다음 단계야!',
    ];
    Speech.speak(parts.join(' '));
  }

  void _replace(Widget Function() builder) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => builder()),
    );
  }

  void _goHome() => Navigator.of(context).popUntil((route) => route.isFirst);

  /// 연출 구간 [a, b]에서 0→1
  double _at(double a, double b) =>
      Curves.easeOutBack.transform(((_show.value - a) / (b - a)).clamp(0, 1));

  Widget _appear(double a, double b, Widget child) {
    return AnimatedBuilder(
      animation: _show,
      builder: (context, child) {
        final t = _at(a, b);
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.scale(scale: 0.7 + 0.3 * t, child: child),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final wrong = widget.totalCount - widget.correctCount;
    return Scaffold(
      body: GestureDetector(
        // 아무 데나 누르면 연출을 건너뛴다
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (_show.isAnimating) _show.value = 1;
        },
        child: Stack(
          children: [
            // 축하 무드: 상단에서 퍼지는 따뜻한 빛
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.9),
                    radius: 1.1,
                    colors: [
                      AppColors.amber
                          .withValues(alpha: _stars >= 1 ? 0.22 : 0.08),
                      AppColors.cream,
                    ],
                  ),
                ),
              ),
            ),
            if (_stars >= 1) const Positioned.fill(child: ConfettiBurst()),
            SafeArea(
              child: Column(
                children: [
                  _buildTopBar(),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) => SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: IntrinsicHeight(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const Spacer(),
                                _buildStars(),
                                const SizedBox(height: 14),
                                _appear(0.0, 0.2, _buildDots()),
                                const SizedBox(height: 6),
                                // 어른용 한 줄 (작게)
                                Text(
                                  '${widget.totalCount}문제 중에 '
                                  '${widget.correctCount}문제를 맞혔어요!',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: AppFont.small,
                                      color: AppColors.inkMuted),
                                ),
                                const SizedBox(height: 16),
                                _appear(0.35, 0.5, _buildMessage()),
                                const SizedBox(height: 16),
                                _appear(0.48, 0.62, _buildCoins()),
                                const SizedBox(height: 12),
                                _buildChips(),
                                const SizedBox(height: 14),
                                _appear(0.78, 0.92, _buildPet()),
                                if (wrong > 0) ...[
                                  const SizedBox(height: 10),
                                  Center(child: _wrongNotesChip(wrong)),
                                ],
                                const Spacer(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _buildButtons(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 퀴즈 상단바와 같은 자리: 🏠 | 단원 이름(작게) | 🪙 잔액
  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: widget.homeLabel,
            onPressed: _goHome,
            icon: Icon(widget.homeIcon, size: 30, color: AppColors.inkSoft),
          ),
          Expanded(
            child: Text(
              widget.headerText ?? '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppFont.small, color: AppColors.inkSoft),
            ),
          ),
          if (_coinsNow != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.rewardSurface,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '🪙 $_coinsNow',
                style: const TextStyle(
                    fontSize: AppFont.body, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  /// 별 세 개: 점이 차오르는 동안 하나씩 펑. 못 받은 별은 점선(진한 ☆ 대신).
  Widget _buildStars() {
    return AnimatedBuilder(
      animation: _show,
      builder: (context, _) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: i < _stars
                  ? Transform.scale(
                      scale: _at(0.12 + i * 0.07, 0.22 + i * 0.07),
                      child: const Text('⭐', style: TextStyle(fontSize: 62)),
                    )
                  : Opacity(
                      opacity: 0.35,
                      child: Text(
                        '☆',
                        style: TextStyle(
                          fontSize: 62,
                          color: AppColors.inkMuted.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
            ),
        ],
      ),
    );
  }

  /// 결과 점 줄: 한 번에 맞힌 문제가 왼쪽부터, 고친 문제(✓)가 그 뒤에.
  /// 별 1·2·3개가 되는 칸 위에 작은 ⭐ 표.
  Widget _buildDots() {
    final source = widget.dots ??
        List.generate(
          widget.totalCount,
          (i) => i < widget.correctCount ? QuizDot.correct : QuizDot.missed,
        );
    final ordered = [
      ...source.where((d) => d == QuizDot.correct),
      ...source.where((d) => d == QuizDot.fixed),
      ...source.where((d) => d == QuizDot.missed || d == QuizDot.pending),
    ];
    final n = ordered.length;
    // 별 기준(50·70·90%)에 닿는 칸 번호 (1부터)
    final marks = {
      for (final p in [0.5, 0.7, 0.9]) (n * p).ceil(),
    };
    // 아직 닿지 못한 첫 ⭐ 칸
    final nextMark = (marks.toList()..sort())
        .firstWhere((m) => m > widget.correctCount, orElse: () => -1);
    // (IntrinsicHeight 안이라 LayoutBuilder 대신 화면 너비로 계산한다)
    final width = MediaQuery.sizeOf(context).width - 48;
    final size = math.min(24.0, (width - 4.0 * n) / n);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < n; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: size * 0.8,
                  child: marks.contains(i + 1)
                      // 못 깬 판: 별 1개가 되는 칸 하나만 깜빡인다 (펄스는 화면에 하나)
                      ? (widget.showUnlockHint && i + 1 == nextMark
                          ? Pulse(
                              child: Text('⭐',
                                  style: TextStyle(fontSize: size * 0.6)))
                          : Opacity(
                              opacity: i + 1 <= widget.correctCount ? 1 : 0.35,
                              child: Text('⭐',
                                  style: TextStyle(fontSize: size * 0.6)),
                            ))
                      : null,
                ),
                _ResultDot(state: ordered[i], size: size),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMessage() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const QuokkaFace(size: 46),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            _message,
            textAlign: TextAlign.center,
            style: displayStyle(fontSize: 28),
          ),
        ),
      ],
    );
  }

  /// 🪙 이번 판에 늘어난 전부 (숫자가 올라간다)
  Widget _buildCoins() {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.rewardSurface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.amber, width: 3),
        ),
        child: AnimatedBuilder(
          animation: _show,
          builder: (context, _) => Text(
            '🪙 +${(_coinTotal * _at(0.5, 0.66).clamp(0.0, 1.0)).round()}',
            style: displayStyle(fontSize: 30, color: AppColors.rewardInk),
          ),
        ),
      ),
    );
  }

  /// 보상 칩 한 줄 — 글 없이 그림과 숫자만, 하나씩 퐁.
  Widget _buildChips() {
    final chips = <(String, String, VoidCallback?)>[
      if (widget.chestCoins > 0) ('🎁', '+${widget.chestCoins}', null),
      if (widget.bossCleared) ('👑', '+100', null),
      if (widget.completedMissions.isNotEmpty)
        ('📋', '✓${widget.completedMissions.length}', null),
      if (widget.milestoneDays > 0) ('🔥', '${widget.milestoneDays}', null),
      if (widget.stickerEarned)
        (
          '🎟️',
          '+1',
          () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StickerBookScreen()),
              ),
        ),
      if (_rankUp != null) (_rankUp!.emoji, '⬆', null),
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < chips.length; i++)
          _appear(
            0.62 + i * 0.04,
            0.74 + i * 0.04,
            GestureDetector(
              onTap: chips[i].$3,
              child: Container(
                key: ValueKey('reward-chip-${chips[i].$1}'),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppColors.outline, width: 2),
                ),
                child: Text(
                  '${chips[i].$1} ${chips[i].$2}',
                  style: const TextStyle(
                      fontSize: AppFont.title, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// 친구 반응: 깡충 + 자라기 원(⭐가 친구를 키운다)
  Widget _buildPet() {
    final pet = _pet;
    final species = pet?.species;
    if (pet == null || species == null) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 900),
          builder: (context, t, child) => Transform.translate(
            offset: Offset(0, -18 * math.sin(t * math.pi * 2).abs() * (1 - t)),
            child: child,
          ),
          child: PetSprite(
            species: species,
            stage: pet.stage,
            size: 60,
            interactive: false,
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: PetGrowth(state: pet, compact: true)),
      ],
    );
  }

  /// 오답 노트 입구 하나 (홈과 같은 📒, 이번 판 개수)
  Widget _wrongNotesChip(int wrong) {
    return TextButton(
      key: const ValueKey('result-wrong-notes'),
      style: TextButton.styleFrom(
        backgroundColor: Colors.white,
        shape: const StadiumBorder(
            side: BorderSide(color: AppColors.outline, width: 2)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const WrongNotesScreen()),
      ),
      child: Text(
        '📒 틀렸던 문제 $wrong',
        style: const TextStyle(
          fontSize: AppFont.body,
          fontWeight: FontWeight.bold,
          color: AppColors.inkSoft,
        ),
      ),
    );
  }

  /// 아래 고정 버튼: 주인공 하나 + 조용한 보조
  Widget _buildButtons() {
    Widget primary(String label, IconData icon, VoidCallback onTap,
        {String? face, Key? key}) {
      // 펄스는 화면에 하나 — 못 깬 판이면 별 칸이 깜빡이므로 버튼은 가만히
      return Pulse(
        scale: widget.showUnlockHint ? 1.0 : 1.03,
        child: BouncyButton(
          key: key,
          color: AppColors.green,
          onTap: onTap,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (face != null) ...[
                Text(face, style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontSize: AppFont.display,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, size: 28, color: Colors.white),
            ],
          ),
        ),
      );
    }

    Widget quiet(String label, IconData icon, VoidCallback onTap) {
      return TextButton.icon(
        style: TextButton.styleFrom(minimumSize: const Size(48, 44)),
        onPressed: onTap,
        icon: Icon(icon, size: 20, color: AppColors.inkSoft),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: AppFont.body,
            fontWeight: FontWeight.bold,
            color: AppColors.inkSoft,
          ),
        ),
      );
    }

    final petFace = _pet?.species?.emojiAt(_pet!.stage);
    final List<Widget> children;
    if (_friendFirst) {
      children = [
        primary('친구한테 가기', Icons.home_rounded, _goHome,
            face: petFace, key: const ValueKey('result-friend')),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_hasNext)
              quiet(widget.nextLabel!, Icons.play_arrow_rounded,
                  () => _replace(widget.nextBuilder!)),
            quiet('다시 하기', Icons.refresh_rounded,
                () => _replace(widget.retryBuilder)),
          ],
        ),
      ];
    } else if (_hasNext) {
      // 통과: 주인공은 '다음 단계' 하나. 다시 하기는 조용한 보조.
      children = [
        primary(widget.nextLabel!, Icons.play_arrow_rounded,
            () => _replace(widget.nextBuilder!)),
        const SizedBox(height: 6),
        quiet('다시 하기', Icons.refresh_rounded,
            () => _replace(widget.retryBuilder)),
      ];
    } else {
      // 미통과: 같은 자리의 주인공이 '다시 하기'가 된다.
      children = [
        primary('다시 하기', Icons.refresh_rounded,
            () => _replace(widget.retryBuilder)),
      ];
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 12),
      child: _appear(
        0.86,
        1.0,
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        ),
      ),
    );
  }
}

/// 결과 점 하나 (퀴즈 진행 점과 같은 색 뜻)
class _ResultDot extends StatelessWidget {
  const _ResultDot({required this.state, required this.size});

  final QuizDot state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (fill, check) = switch (state) {
      QuizDot.correct => (AppColors.correct, Colors.white),
      QuizDot.fixed => (AppColors.selectedFill, AppColors.correct),
      QuizDot.missed => (AppColors.missedDot, null),
      QuizDot.pending => (AppColors.line, null),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: state == QuizDot.fixed
            ? Border.all(color: AppColors.correct, width: 2)
            : null,
      ),
      child: check != null
          ? Icon(Icons.check_rounded, size: size * 0.7, color: check)
          : null,
    );
  }
}
