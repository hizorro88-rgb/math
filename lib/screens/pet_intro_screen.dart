import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/pulse.dart';
import '../widgets/quokka_avatar.dart';
import '../widgets/sparkle_burst.dart';

/// 쿼카 박사가 알 세 개를 보여 주고 함께 공부할 친구를 고르게 한다.
///
/// 아이 혼자 끝까지 갈 수 있게 글 대신 그림·소리로 이끈다:
/// 알 고르기(색이 다른 알, 누르면 흔들리며 귀띔을 읽어 줌) → 톡톡 세 번 두드려 부화
/// → 🎁 첫 선물(코인) → 🍚 첫 밥 → ▶ (첫 실행이면 첫 판으로, 아니면 홈으로)
class PetIntroScreen extends StatefulWidget {
  const PetIntroScreen({super.key, this.firstRun = false});

  /// 첫 실행이면 마지막 버튼이 "첫 문제 풀기"가 된다.
  final bool firstRun;

  @override
  State<PetIntroScreen> createState() => _PetIntroScreenState();
}

enum _Phase { pick, crack, gift, feed, done }

class _PetIntroScreenState extends State<PetIntroScreen> {
  /// 눌러 본 알 (귀띔이 뜬다). 아직 고른 건 아니다.
  int? _peeked;
  int _wobble = 0;

  PetSpecies? _species;
  _Phase _phase = _Phase.pick;

  /// 부화까지 두드린 횟수
  int _taps = 0;
  static const _tapsToHatch = 3;

  int _fullness = petStartGauge;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Speech.speak('알을 눌러 봐! 어떤 친구가 들어 있을까?');
    });
  }

  void _peek(int index, PetSpecies species) {
    Sounds.play('correct');
    Speech.speak(species.hint);
    setState(() {
      _peeked = index;
      _wobble++;
    });
  }

  Future<void> _choose(PetSpecies species) async {
    await PetStore.choose(species);
    if (!mounted) return;
    setState(() {
      _species = species;
      _phase = _Phase.crack;
    });
    Speech.speak('알을 톡톡 두드려 봐!');
  }

  void _tapEgg() {
    if (_phase != _Phase.crack) return;
    setState(() => _taps++);
    if (_taps < _tapsToHatch) {
      Sounds.play('combo');
      return;
    }
    Sounds.buy();
    setState(() => _phase = _Phase.gift);
    Speech.speak('${_species!.name}가 태어났어요! 선물을 열어 봐!');
  }

  Future<void> _openGift() async {
    await PetStore.giveHatchGift();
    if (!mounted) return;
    Sounds.complete();
    setState(() => _phase = _Phase.feed);
    Speech.speak('코인 $petHatchGift개! ${_species!.name}가 배고프대. 밥을 줘 볼까?');
  }

  Future<void> _feed() async {
    final ok = await PetStore.care(meal: true);
    if (!mounted) return;
    final state = await PetStore.load();
    if (!mounted) return;
    Sounds.play('correct');
    setState(() {
      _fullness = state.fullness;
      _phase = _Phase.done;
    });
    Speech.speak(ok
        ? (widget.firstRun ? '냠냠, 고마워! 이제 같이 문제 풀자!' : '냠냠, 고마워!')
        : '고마워!');
  }

  @override
  Widget build(BuildContext context) {
    final species = _species;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: species == null ? _buildPicker() : _buildHatch(species),
      ),
    );
  }

  Widget _buildPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        children: [
          // 쿼카 박사 (마스코트가 선생님 역할을 맡는다)
          const QuokkaFace(size: 84),
          const SizedBox(height: 6),
          Text('쿼카 박사', style: displayStyle(fontSize: 16)),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            child: Text(
              '알을 눌러 봐!',
              textAlign: TextAlign.center,
              style: displayStyle(fontSize: 20),
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < petSpeciesList.length; i++) ...[
            _eggCard(i, petSpeciesList[i]),
            if (i != petSpeciesList.length - 1) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }

  Widget _eggCard(int index, PetSpecies species) {
    final peeked = _peeked == index;
    return BouncyButton(
      key: ValueKey('egg-$index'),
      color: Colors.white,
      shadowColor: peeked ? species.color : AppColors.outline,
      border: Border.all(
        color: peeked ? species.color : AppColors.outline,
        width: peeked ? 3 : 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      onTap: () => _peek(index, species),
      child: Row(
        children: [
          _Wobble(
            key: ValueKey('wobble-$index-${peeked ? _wobble : 0}'),
            active: peeked,
            child: PetEgg(color: species.color, size: 64),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peeked ? species.hint : '❔',
                  style: displayStyle(
                    fontSize: peeked ? 18 : 26,
                    color: AppColors.ink,
                  ),
                ),
                if (peeked) ...[
                  const SizedBox(height: 8),
                  // 귀띔을 들은 알만 고를 수 있게 해서 급하게 누르는 걸 막는다.
                  SizedBox(
                    width: double.infinity,
                    child: BouncyButton(
                      key: ValueKey('pick-$index'),
                      color: AppColors.green,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onTap: () => _choose(species),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '이 친구!',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.play_arrow_rounded,
                              color: Colors.white, size: 24),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHatch(PetSpecies species) {
    final hatched = _phase != _Phase.crack;
    return Stack(
      children: [
        Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!hatched) ...[
                  Text('톡톡 두드려 봐!', style: displayStyle(fontSize: 26)),
                  const SizedBox(height: 20),
                  GestureDetector(
                    key: const ValueKey('egg-tap'),
                    onTap: _tapEgg,
                    child: _Wobble(
                      key: ValueKey('crack-$_taps'),
                      active: true,
                      strength: 0.06 + _taps * 0.05,
                      child: PetEgg(
                        color: species.color,
                        size: 170,
                        cracks: _taps,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 몇 번 남았는지 그림으로 (👆👆👆)
                  Text(
                    '👆' * (_tapsToHatch - _taps),
                    style: const TextStyle(fontSize: 30),
                  ),
                ] else ...[
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.4, end: 1),
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                    builder: (context, t, child) =>
                        Transform.scale(scale: t, child: child),
                    child: Text(species.emojiAt(1),
                        style: const TextStyle(fontSize: 110)),
                  ),
                  const SizedBox(height: 8),
                  Text('${species.name} 탄생!',
                      style: displayStyle(fontSize: 26)),
                  const SizedBox(height: 18),
                  _buildStepAction(species),
                ],
              ],
            ),
          ),
        ),
        if (_phase == _Phase.gift)
          const Positioned.fill(
            child: IgnorePointer(child: SparkleBurst()),
          ),
      ],
    );
  }

  /// 부화 뒤 한 번에 하나씩: 🎁 선물 → 🍚 밥 → ▶ 다음
  Widget _buildStepAction(PetSpecies species) {
    switch (_phase) {
      case _Phase.gift:
        return Pulse(
          child: GestureDetector(
            key: const ValueKey('gift'),
            onTap: _openGift,
            child: const Text('🎁', style: TextStyle(fontSize: 96)),
          ),
        );
      case _Phase.feed:
        return Column(
          children: [
            Text('🪙 +$petHatchGift', style: displayStyle(fontSize: 26)),
            const SizedBox(height: 12),
            _Gauge(value: _fullness, color: AppColors.amber, emoji: '🍚'),
            const SizedBox(height: 16),
            Pulse(
              child: BouncyButton(
                key: const ValueKey('first-feed'),
                color: AppColors.green,
                padding:
                    const EdgeInsets.symmetric(horizontal: 36, vertical: 14),
                onTap: _feed,
                child: Text(
                  '🍚 밥 주기',
                  style: displayStyle(fontSize: 22, color: Colors.white),
                ),
              ),
            ),
          ],
        );
      case _Phase.done:
        return Column(
          children: [
            _Gauge(value: _fullness, color: AppColors.amber, emoji: '🍚'),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: Pulse(
                scale: 1.04,
                child: BouncyButton(
                  key: const ValueKey('hatch-done'),
                  color: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  onTap: () => Navigator.of(context).pop(true),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        widget.firstRun ? '첫 문제 풀기' : '같이 놀기',
                        style: displayStyle(fontSize: 22, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.play_arrow_rounded,
                          color: Colors.white, size: 32),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      case _Phase.pick:
      case _Phase.crack:
        return const SizedBox.shrink();
    }
  }
}

/// 배부름 막대 (밥을 주면 차오르는 게 눈에 보이게)
class _Gauge extends StatelessWidget {
  const _Gauge({required this.value, required this.color, required this.emoji});

  final int value;
  final Color color;
  final String emoji;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 26)),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: value / 100),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 18,
                color: color,
                backgroundColor: AppColors.line,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// 한 번 도리도리 흔들리는 연출 (키가 바뀌면 다시 흔들린다)
class _Wobble extends StatelessWidget {
  const _Wobble({
    super.key,
    required this.child,
    required this.active,
    this.strength = 0.12,
  });

  final Widget child;
  final bool active;
  final double strength;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      builder: (context, t, child) => Transform.rotate(
        angle: math.sin(t * math.pi * 6) * strength * (1 - t),
        child: child,
      ),
      child: child,
    );
  }
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
      ..cubicTo(w * 0.95, 0, w, h * 0.62, w / 2, h)
      ..cubicTo(0, h * 0.62, w * 0.05, 0, w / 2, 0)
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
