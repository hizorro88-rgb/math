import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/quokka_avatar.dart';
import '../widgets/sparkle_burst.dart';

/// 쿼카 박사가 알 세 개를 보여 주고 함께 공부할 친구를 고르게 한다.
/// 고르면 알이 깨지면서 아기 친구가 태어난다.
class PetIntroScreen extends StatefulWidget {
  const PetIntroScreen({super.key});

  @override
  State<PetIntroScreen> createState() => _PetIntroScreenState();
}

class _PetIntroScreenState extends State<PetIntroScreen> {
  /// 눌러 본 알 (귀띔이 뜬다). 아직 고른 건 아니다.
  int? _peeked;

  /// 고른 알 — 부화 연출 중
  PetSpecies? _hatching;
  bool _hatched = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Speech.speak('같이 공부할 친구를 골라 볼까요?');
    });
  }

  Future<void> _choose(PetSpecies species) async {
    setState(() => _hatching = species);
    Sounds.play('combo');
    await PetStore.choose(species);
    // 흔들흔들 하다가 깨진다.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;
    Sounds.buy();
    setState(() => _hatched = true);
    Speech.speak('${species.name}가 태어났어요!');
  }

  @override
  Widget build(BuildContext context) {
    final hatching = _hatching;
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: hatching == null ? _buildPicker() : _buildHatch(hatching),
      ),
    );
  }

  Widget _buildPicker() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      child: Column(
        children: [
          // 쿼카 박사 (마스코트가 선생님 역할을 맡는다)
          const QuokkaFace(size: 96),
          const SizedBox(height: 10),
          Text('쿼카 박사', style: displayStyle(fontSize: 18)),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            child: Text(
              '반가워요!\n같이 공부할 친구를 골라 볼까요?\n알을 누르면 살짝 알려 줄게요.',
              textAlign: TextAlign.center,
              style: displayStyle(fontSize: 17),
            ),
          ),
          const SizedBox(height: 22),
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
      color: peeked ? species.color.withValues(alpha: 0.12) : Colors.white,
      shadowColor: peeked ? species.color : Colors.grey.shade300,
      border: Border.all(
        color: peeked ? species.color : AppColors.outline,
        width: peeked ? 3 : 2,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      onTap: () {
        Sounds.play('correct');
        setState(() => _peeked = index);
      },
      child: Row(
        children: [
          Text(species.egg, style: const TextStyle(fontSize: 48)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  peeked ? species.hint : '어떤 친구일까?',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: peeked ? species.color : AppColors.inkSoft,
                  ),
                ),
                if (peeked) ...[
                  const SizedBox(height: 8),
                  // 귀띔을 본 알만 고를 수 있게 해서 급하게 누르는 걸 막는다.
                  SizedBox(
                    width: double.infinity,
                    child: BouncyButton(
                      key: ValueKey('pick-$index'),
                      color: species.color,
                      shadowColor: species.color,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      onTap: () => _choose(species),
                      child: const Text(
                        '이 친구로 할래요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
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
    return Stack(
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedScale(
                  scale: _hatched ? 1.0 : 0.6,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  child: _hatched
                      ? Text(species.emojiAt(1),
                          style: const TextStyle(fontSize: 110))
                      : _ShakingEgg(emoji: species.egg),
                ),
                const SizedBox(height: 18),
                if (_hatched) ...[
                  Text(
                    '${species.name}가 태어났어요!',
                    textAlign: TextAlign.center,
                    style: displayStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '공부해서 별을 모으고 밥을 주면\n무럭무럭 자라요',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 15, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: BouncyButton(
                      key: const ValueKey('hatch-done'),
                      color: AppColors.green,
                      shadowColor: AppColors.greenPressed,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      onTap: () => Navigator.of(context).pop(true),
                      child: const Text(
                        '같이 공부하러 가기',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ] else
                  Text('알이 움직여요…', style: displayStyle(fontSize: 18)),
              ],
            ),
          ),
        ),
        if (_hatched)
          const Positioned.fill(
            child: IgnorePointer(child: SparkleBurst()),
          ),
      ],
    );
  }
}

/// 깨지기 직전의 알: 점점 크게 흔들린다.
class _ShakingEgg extends StatefulWidget {
  const _ShakingEgg({required this.emoji});

  final String emoji;

  @override
  State<_ShakingEgg> createState() => _ShakingEggState();
}

class _ShakingEggState extends State<_ShakingEgg>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    // 테스트에서는 반복 애니메이션을 끄지만, 이건 한 번만 도는 연출이라 그대로 둔다.
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // 뒤로 갈수록 크게, 빠르게 흔들린다.
        final angle = math.sin(t * math.pi * 14) * 0.18 * t;
        return Transform.rotate(angle: angle, child: child);
      },
      child: Text(widget.emoji, style: const TextStyle(fontSize: 110)),
    );
  }
}
