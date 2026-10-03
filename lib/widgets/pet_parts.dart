import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import 'bouncy_button.dart';
import 'pulse.dart';
import 'sparkle_burst.dart';

/// 친구(펫)를 그리는 곳은 여기 하나다 — 홈 카드·친구 방·부화 화면이 같이 쓴다.
/// 같은 친구가 화면마다 다르게 보이면 아이는 다른 친구로 안다.
///
/// - PetSprite: 친구 그림 (단계는 크기 + 종 색 덧그림, 누르면 깡충, 문지르면 💗)
/// - PetGauge: 🍚·💧 막대 (가득 찰수록 좋다 — 한 방향으로만 읽는다)
/// - PetCareButton: 밥·물 버튼 (큰 그림 + 🪙 칩 + 오늘 남은 횟수 ●●●)
/// - PetGrowth: 다음 모습 실루엣 + ⭐·🍚·💧 원 게이지
/// - showPetEvolution: 진화 연출

/// 단계별 크기 (최대 크기에 곱한다)
const _stageScale = [0.6, 0.7, 0.8, 0.9, 1.0];

// ───────────────────────── 친구 그림 ─────────────────────────

class PetSprite extends StatefulWidget {
  const PetSprite({
    super.key,
    required this.species,
    required this.stage,
    required this.size,
    this.sleepy = false,
    this.wish,
    this.interactive = true,
    this.flip = false,
  });

  final PetSpecies species;

  /// 1~5
  final int stage;

  /// 5단계(전설) 때의 크기. 어릴수록 작게 그린다.
  final double size;

  final bool sleepy;

  /// 머리 위 생각 풍선 (🍚 / 💧) — null이면 없음
  final String? wish;

  /// 누르기·문지르기 반응
  final bool interactive;

  /// 걷는 방향 (동물만 뒤집고 덧그림은 그대로)
  final bool flip;

  /// 상태에 맞는 친구 한마디 (누를 때)
  static String lineFor(PetState state) {
    if (state.sleepy) return '졸려… 밥이랑 물 줄래?';
    if (state.wantsMeal) return '배고파! 밥 먹고 싶어!';
    if (state.wantsDrink) return '목말라! 물 마시고 싶어!';
    const happy = ['좋아!', '헤헤, 같이 공부하자!', '오늘도 반가워!', '나 잘 크고 있지?'];
    return happy[math.Random().nextInt(happy.length)];
  }

  @override
  State<PetSprite> createState() => _PetSpriteState();
}

class _PetSpriteState extends State<PetSprite> with TickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
  );

  /// 숨쉬기·콩콩 (반복 — 테스트에서는 꺼짐)
  late final AnimationController _idle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  );

  int _hearts = 0;
  double _rubbed = 0;
  DateTime _lastGiggle = DateTime(2000);

  @override
  void initState() {
    super.initState();
    if (AppMotion.loops) _idle.repeat(reverse: true);
  }

  @override
  void dispose() {
    _hop.dispose();
    _idle.dispose();
    super.dispose();
  }

  void _tap() {
    _hop.forward(from: 0);
    setState(() => _hearts++);
    Sounds.play('correct');
    PetStore.load().then((s) => Speech.speak(PetSprite.lineFor(s)));
  }

  /// 문지르기: 💗와 웃음 — 공짜·무제한, 수치·코인·진화와는 무관하다.
  void _rub(DragUpdateDetails d) {
    _rubbed += d.delta.distance;
    if (_rubbed < 70) return;
    _rubbed = 0;
    setState(() => _hearts++);
    final now = DateTime.now();
    if (now.difference(_lastGiggle) > const Duration(milliseconds: 1800)) {
      _lastGiggle = now;
      Speech.speak('헤헤, 간지러워!');
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.size * _stageScale[(widget.stage - 1).clamp(0, 4)];
    final box = widget.size * 1.25;
    final color = widget.species.color;
    final stage = widget.stage;

    Widget body = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        // 5단계: 빛 테두리
        if (stage >= 5)
          Positioned(
            bottom: a * 0.05,
            child: Container(
              width: a * 1.15,
              height: a * 1.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  color.withValues(alpha: 0.35),
                  color.withValues(alpha: 0),
                ]),
              ),
            ),
          ),
        // 5단계: 날개
        if (stage >= 5) ...[
          Positioned(
            bottom: a * 0.35,
            left: box / 2 - a * 0.85,
            child: Transform.flip(
              flipX: true,
              child: Text('🪽', style: TextStyle(fontSize: a * 0.42)),
            ),
          ),
          Positioned(
            bottom: a * 0.35,
            right: box / 2 - a * 0.85,
            child: Text('🪽', style: TextStyle(fontSize: a * 0.42)),
          ),
        ],
        // 4~5단계: 종 색 망토 (몸 뒤)
        if (stage >= 4)
          Positioned(
            bottom: 0,
            child: CustomPaint(
              size: Size(a * 0.95, a * 0.62),
              painter: _CapePainter(color),
            ),
          ),
        // 동물
        Transform.flip(
          flipX: widget.flip,
          child: Text(
            widget.species.emojiAt(stage),
            style: TextStyle(fontSize: a * 0.82, height: 1.05),
          ),
        ),
        // 3단계: 종 색 목도리
        if (stage == 3)
          Positioned(
            bottom: a * 0.0,
            child: Container(
              width: a * 0.7,
              height: a * 0.12,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(a),
                border: Border.all(
                    color: Color.lerp(color, Colors.black, 0.2)!, width: 1.5),
              ),
            ),
          ),
        // 1단계: 알껍데기 아랫부분에 쏙
        if (stage == 1)
          Positioned(
            bottom: -a * 0.02,
            child: ClipRect(
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 0.42,
                child: PetEgg(color: color, size: a * 0.95),
              ),
            ),
          ),
        // 2단계: 머리에 껍데기 조각
        if (stage == 2)
          Positioned(
            top: -a * 0.02,
            child: ClipRect(
              child: Align(
                alignment: Alignment.topCenter,
                heightFactor: 0.38,
                child: PetEgg(color: color, size: a * 0.5),
              ),
            ),
          ),
      ],
    );

    // 숨쉬기(아기는 콩콩) + 누르면 깡충
    body = AnimatedBuilder(
      animation: Listenable.merge([_hop, _idle]),
      builder: (context, child) {
        final hop = math.sin(_hop.value * math.pi) * a * 0.35;
        final idle = widget.sleepy
            ? 0.0
            : stage == 1
                ? _idle.value * a * 0.06
                : 0.0;
        final breathe = 1 + (widget.sleepy ? 0.03 : 0.015) * _idle.value;
        return Transform.translate(
          offset: Offset(0, -hop - idle),
          child: Transform.scale(scale: breathe, child: child),
        );
      },
      child: body,
    );

    final stack = SizedBox(
      width: box,
      height: box,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          body,
          if (widget.sleepy)
            Positioned(
              top: 0,
              right: box * 0.05,
              child: AnimatedBuilder(
                animation: _idle,
                builder: (context, child) => Transform.translate(
                  offset: Offset(0, -6 * _idle.value),
                  child: child,
                ),
                child: Text('💤', style: TextStyle(fontSize: a * 0.3)),
              ),
            )
          else if (widget.wish != null)
            Positioned(
              top: -a * 0.05,
              right: 0,
              child: _WishBubble(emoji: widget.wish!, size: a * 0.32),
            ),
          // 💗 퐁퐁
          if (_hearts > 0)
            Positioned(
              top: box * 0.1,
              child: TweenAnimationBuilder<double>(
                key: ValueKey(_hearts),
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 900),
                builder: (context, t, child) => Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(math.sin(t * 6) * 6, -30 * t),
                    child: child,
                  ),
                ),
                child: Text('💗', style: TextStyle(fontSize: a * 0.3)),
              ),
            ),
        ],
      ),
    );

    if (!widget.interactive) return stack;
    return Semantics(
      button: true,
      label: widget.species.name,
      onTap: _tap,
      child: GestureDetector(
        key: const ValueKey('pet-sprite'),
        behavior: HitTestBehavior.opaque,
        onTap: _tap,
        onPanUpdate: _rub,
        child: stack,
      ),
    );
  }
}

class _WishBubble extends StatelessWidget {
  const _WishBubble({required this.emoji, required this.size});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(size * 0.25),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Text(emoji, style: TextStyle(fontSize: size)),
    );
  }
}

class _CapePainter extends CustomPainter {
  _CapePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cape = Path()
      ..moveTo(w * 0.3, 0)
      ..lineTo(w * 0.7, 0)
      ..quadraticBezierTo(w * 0.95, h * 0.6, w, h)
      ..lineTo(0, h)
      ..quadraticBezierTo(w * 0.05, h * 0.6, w * 0.3, 0)
      ..close();
    canvas.drawPath(cape, Paint()..color = color);
    canvas.drawPath(
      cape,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Color.lerp(color, Colors.black, 0.25)!,
    );
  }

  @override
  bool shouldRepaint(covariant _CapePainter old) => old.color != color;
}

// ───────────────────────── 막대 ─────────────────────────

/// 🍚·💧 막대 — 가득 찰수록 배부르고 촉촉하다. 값이 바뀌면 차오른다.
class PetGauge extends StatelessWidget {
  const PetGauge({
    super.key,
    required this.meal,
    required this.value,
    this.height = 12,
  });

  final bool meal;
  final int value;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(meal ? '🍚' : '💧', style: TextStyle(fontSize: height + 6)),
        const SizedBox(width: 6),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: height,
                color: meal ? AppColors.amber : AppColors.petWater,
                backgroundColor: AppColors.line,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── 밥·물 버튼 ─────────────────────────

/// 밥·물 버튼 — 큰 그림 + 🪙 칩 + 오늘 남은 횟수 점(●●○).
/// 코인이 모자라면 🪙 칩이 점선으로 흐려지고, 오늘 다 줬으면 🌙.
/// (누를 수는 있다 — 누르면 화면이 이유와 다음 할 일을 말해 준다)
class PetCareButton extends StatelessWidget {
  const PetCareButton({
    super.key,
    required this.meal,
    required this.state,
    required this.onTap,
    this.compact = false,
    this.nudge = false,
  });

  final bool meal;
  final PetState state;
  final VoidCallback onTap;

  /// 홈 카드용 (가로로 낮게)
  final bool compact;

  /// 살짝 펄스 (이 버튼을 눌러 보라는 뜻)
  final bool nudge;

  @override
  Widget build(BuildContext context) {
    final cost = meal ? petMealCost : petDrinkCost;
    final left =
        petDailyCareLimit - (meal ? state.mealsToday : state.drinksToday);
    final done = left <= 0;
    final poor = state.coins < cost;
    final emoji = meal ? '🍚' : '💧';

    final chip = done
        ? const Text('🌙', style: TextStyle(fontSize: 16))
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: poor ? Colors.transparent : AppColors.rewardSurface,
              borderRadius: BorderRadius.circular(999),
              border: poor
                  ? Border.all(color: AppColors.inkMuted, width: 1.5)
                  : null,
            ),
            child: Opacity(
              opacity: poor ? 0.45 : 1,
              child: Text(
                '🪙$cost',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ),
          );

    final dots = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < petDailyCareLimit; i++)
          Container(
            width: 7,
            height: 7,
            margin: const EdgeInsets.symmetric(horizontal: 1.5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < left
                  ? (meal ? AppColors.amber : AppColors.petWater)
                  : AppColors.line,
            ),
          ),
      ],
    );

    final content = compact
        ? Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Opacity(
                opacity: done ? 0.5 : 1,
                child: Text(emoji, style: const TextStyle(fontSize: 24)),
              ),
              const SizedBox(width: 6),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [chip, const SizedBox(height: 3), dots],
              ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Opacity(
                opacity: done ? 0.5 : 1,
                child: Text(emoji, style: const TextStyle(fontSize: 34)),
              ),
              const SizedBox(height: 4),
              chip,
              const SizedBox(height: 5),
              dots,
            ],
          );

    final button = Semantics(
      button: true,
      label: meal ? '밥 주기' : '물 주기',
      child: BouncyButton(
        color: done ? AppColors.cream : Colors.white,
        shadowColor: AppColors.outline,
        border: Border.all(color: AppColors.outline, width: 2),
        borderRadius: compact ? 16 : 20,
        padding: EdgeInsets.symmetric(vertical: compact ? 7 : 12),
        onTap: onTap,
        child: content,
      ),
    );
    return nudge && !done && !poor ? Pulse(child: button) : button;
  }
}

// ───────────────────────── 성장 ─────────────────────────

/// 다음 모습(실루엣) + ⭐·🍚·💧 원 게이지. 다 찬 원에는 초록 ✓.
/// 숫자는 어른용으로 작게 — 아이는 원이 차는 것만 보면 된다.
class PetGrowth extends StatelessWidget {
  const PetGrowth({
    super.key,
    required this.state,
    this.compact = false,
    this.onStarTap,
  });

  final PetState state;
  final bool compact;

  /// ⭐ 원을 눌렀을 때 ("문제 풀면 별이 생겨!")
  final VoidCallback? onStarTap;

  @override
  Widget build(BuildContext context) {
    final rule = state.nextRule;
    final species = state.species;
    if (rule == null || species == null) {
      return Text('🏆 끝까지 다 키웠어요!',
          textAlign: TextAlign.center,
          style: displayStyle(fontSize: compact ? 15 : 18));
    }
    final ring = compact ? 34.0 : 54.0;
    Widget item(String emoji, int now, int need, {VoidCallback? onTap}) {
      final v = (now / need).clamp(0.0, 1.0);
      final full = now >= need;
      return GestureDetector(
        onTap: onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: ring,
              height: ring,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: ring,
                    height: ring,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: compact ? 4 : 6,
                      color: full ? AppColors.correct : AppColors.amber,
                      backgroundColor: AppColors.line,
                    ),
                  ),
                  Text(emoji, style: TextStyle(fontSize: ring * 0.42)),
                  if (full)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: CircleAvatar(
                        radius: ring * 0.17,
                        backgroundColor: AppColors.correct,
                        child: Icon(Icons.check_rounded,
                            size: ring * 0.24, color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            if (!compact) ...[
              const SizedBox(height: 4),
              Text(
                '${math.min(now, need)}/$need',
                style:
                    const TextStyle(fontSize: 11, color: AppColors.inkMuted),
              ),
            ],
          ],
        ),
      );
    }

    // 다음 모습 실루엣 (❔)
    final next = SizedBox(
      width: compact ? 44 : 76,
      height: compact ? 44 : 76,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 다음 모습은 그림자로만 — 자라 봐야 알 수 있다
          ColorFiltered(
            colorFilter: const ColorFilter.mode(
                Color(0xFFC9BCA6), BlendMode.srcIn),
            child: PetSprite(
              species: species,
              stage: state.stage + 1,
              size: compact ? 36 : 62,
              interactive: false,
            ),
          ),
          Text('?',
              style: displayStyle(
                  fontSize: compact ? 18 : 28, color: Colors.white)),
        ],
      ),
    );

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        item('⭐', state.stars, rule.stars, onTap: onStarTap),
        item('🍚', state.meals, rule.meals),
        item('💧', state.drinks, rule.drinks),
        Icon(Icons.arrow_forward_rounded,
            color: AppColors.inkMuted, size: compact ? 18 : 26),
        next,
      ],
    );
  }
}

// ───────────────────────── 진화 ─────────────────────────

/// 진화 연출: 옛 모습이 흔들리고 → 하얗게 번쩍 → 커진 새 모습.
/// 홈·친구 방 어디서든 같은 연출을 띄운다.
Future<void> showPetEvolution(
  BuildContext context, {
  required PetSpecies species,
  required int stage,
}) {
  Sounds.complete();
  Speech.speak('우와! ${species.name}가 ${petStageNames[stage - 1]}로 자랐어요!');
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    pageBuilder: (context, _, __) =>
        _EvolveView(species: species, stage: stage),
  );
}

class _EvolveView extends StatefulWidget {
  const _EvolveView({required this.species, required this.stage});

  final PetSpecies species;
  final int stage;

  @override
  State<_EvolveView> createState() => _EvolveViewState();
}

class _EvolveViewState extends State<_EvolveView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final showNew = t >= 0.55;
            // 0~45%: 옛 모습 흔들림 / 45~60%: 번쩍 / 60~100%: 새 모습 등장
            final shake = t < 0.45 ? math.sin(t * 80) * 0.12 * (t / 0.45) : 0.0;
            final flash = t >= 0.45 && t < 0.7
                ? 1 - ((t - 0.45) / 0.25 - 0.4).abs() / 0.6
                : 0.0;
            final grow = showNew
                ? Curves.elasticOut.transform(((t - 0.55) / 0.45).clamp(0, 1))
                : 1.0;
            return Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('✨ 자랐어요! ✨',
                        style: displayStyle(fontSize: 28, color: Colors.white)),
                    const SizedBox(height: 16),
                    Transform.rotate(
                      angle: shake,
                      child: Transform.scale(
                        scale: showNew ? 0.6 + 0.4 * grow : 1,
                        child: PetSprite(
                          species: widget.species,
                          stage: showNew ? widget.stage : widget.stage - 1,
                          size: 150,
                          interactive: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${widget.species.name} · ${petStageNames[widget.stage - 1]}',
                      style: displayStyle(fontSize: 22, color: Colors.white),
                    ),
                    const SizedBox(height: 24),
                    Opacity(
                      opacity: showNew ? 1 : 0,
                      child: BouncyButton(
                        key: const ValueKey('evolve-ok'),
                        color: AppColors.green,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 40, vertical: 12),
                        onTap: () => Navigator.of(context).pop(),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('좋아!',
                                style: displayStyle(
                                    fontSize: 22, color: Colors.white)),
                            const SizedBox(width: 4),
                            const Icon(Icons.play_arrow_rounded,
                                color: Colors.white, size: 28),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                if (flash > 0)
                  IgnorePointer(
                    child: Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: flash.clamp(0, 1)),
                      ),
                    ),
                  ),
                if (showNew)
                  const IgnorePointer(
                    child: SizedBox(width: 320, height: 320, child: SparkleBurst()),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 걷는 친구용 공용 타이머 주기 (홈·방 같게)
const petWalkPeriod = Duration(milliseconds: 2400);

/// 걷기: 일정 주기로 새 위치를 고른다. 졸리거나 아기 단계면 제자리.
Timer? startPetWalk(void Function(double target) onMove) {
  if (!AppMotion.loops) return null;
  final random = math.Random();
  return Timer.periodic(petWalkPeriod, (_) {
    onMove(0.1 + random.nextDouble() * 0.8);
  });
}

/// 친구마다 색이 다른 알. 글을 못 읽어도 색으로 고를 수 있다.
/// [cracks]만큼 금이 간다 (톡톡 두드리기).
class PetEgg extends StatelessWidget {
  const PetEgg({
    super.key,
    required this.color,
    this.size = 64,
    this.cracks = 0,
  });

  final Color color;
  final double size;
  final int cracks;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size * 0.8,
      height: size,
      child: CustomPaint(painter: _EggPainter(color, cracks)),
    );
  }
}

class _EggPainter extends CustomPainter {
  _EggPainter(this.color, this.cracks);

  final Color color;
  final int cracks;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // 위가 좁고 아래가 넓은 알 모양
    final egg = Path()
      ..moveTo(w / 2, 0)
      ..cubicTo(w * 0.85, 0, w, h * 0.45, w, h * 0.63)
      ..cubicTo(w, h * 0.88, w * 0.78, h, w / 2, h)
      ..cubicTo(w * 0.22, h, 0, h * 0.88, 0, h * 0.63)
      ..cubicTo(0, h * 0.45, w * 0.15, 0, w / 2, 0)
      ..close();
    final light = Color.lerp(color, Colors.white, 0.55)!;
    canvas.drawPath(
      egg,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [light, color],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      egg,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(2, w * 0.03)
        ..color = Color.lerp(color, Colors.black, 0.2)!,
    );
    // 점무늬
    final dot = Paint()..color = Colors.white.withValues(alpha: 0.7);
    canvas.drawCircle(Offset(w * 0.35, h * 0.42), w * 0.08, dot);
    canvas.drawCircle(Offset(w * 0.64, h * 0.58), w * 0.06, dot);
    canvas.drawCircle(Offset(w * 0.45, h * 0.74), w * 0.05, dot);
    // 금: 두드릴수록 늘어난다
    final crack = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, w * 0.025)
      ..strokeCap = StrokeCap.round
      ..color = Color.lerp(color, Colors.black, 0.45)!;
    for (var c = 0; c < cracks; c++) {
      final y = h * (0.38 + c * 0.1);
      final zig = Path()..moveTo(w * 0.2, y);
      for (var i = 1; i <= 6; i++) {
        zig.lineTo(w * (0.2 + i * 0.1), y + (i.isOdd ? -h * 0.04 : h * 0.03));
      }
      canvas.drawPath(zig, crack);
    }
  }

  @override
  bool shouldRepaint(covariant _EggPainter old) =>
      old.color != color || old.cracks != cracks;
}
