import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/sparkle_burst.dart';

/// 친구가 지내는 방. 좌우로 돌아다니는 모습을 보고, 밥과 물을 준다.
///
/// 오래 머무는 놀이터가 아니라 잠깐 들러 보고 나가는 곳이다.
/// 할 수 있는 일은 밥·물 두 가지뿐이고, 둘 다 공부로 번 코인을 쓴다.
class PetRoomScreen extends StatefulWidget {
  const PetRoomScreen({super.key});

  @override
  State<PetRoomScreen> createState() => _PetRoomScreenState();
}

class _PetRoomScreenState extends State<PetRoomScreen> {
  PetState? _state;

  /// 방 안에서의 가로 위치 (0.0 왼쪽 끝 ~ 1.0 오른쪽 끝)
  double _x = 0.5;
  bool _facingRight = true;
  Timer? _walkTimer;

  /// 진화 축하 연출 중인 단계 (null이면 연출 없음)
  int? _celebrating;

  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    _reload();
    if (AppMotion.loops) {
      // 몇 초에 한 번 방향을 바꿔 가며 어슬렁거린다.
      _walkTimer = Timer.periodic(const Duration(milliseconds: 2200), (_) {
        if (!mounted) return;
        setState(() {
          final target = 0.12 + _random.nextDouble() * 0.76;
          _facingRight = target > _x;
          _x = target;
        });
      });
    }
  }

  @override
  void dispose() {
    _walkTimer?.cancel();
    super.dispose();
  }

  Future<void> _reload() async {
    // 조건을 넘겼으면 먼저 자라게 하고, 자랐으면 축하 연출을 띄운다.
    final grown = await PetStore.evolveIfReady();
    final state = await PetStore.load();
    if (!mounted) return;
    setState(() {
      _state = state;
      if (grown != null) _celebrating = grown;
    });
    if (grown != null) {
      Sounds.complete();
      Speech.speak('축하해요! ${state.species?.name ?? '친구'}가 자랐어요!');
    }
  }

  Future<void> _care({required bool meal}) async {
    final ok = await PetStore.care(meal: meal);
    if (!mounted) return;
    if (!ok) {
      final state = _state;
      final enough = state != null &&
          (meal ? state.coins >= petMealCost : state.coins >= petDrinkCost);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(enough ? '오늘은 충분히 줬어요. 내일 또 줄까요?' : '코인이 모자라요. 문제를 풀어 볼까요?'),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }
    Sounds.play('correct');
    Speech.speak(meal ? '냠냠 맛있어요!' : '꿀꺽꿀꺽!');
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        title: Text(state?.species?.name ?? '내 친구',
            style: displayStyle(fontSize: 20, color: Colors.white)),
        backgroundColor: state?.species?.color ?? AppColors.green,
        foregroundColor: Colors.white,
      ),
      body: state == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                SafeArea(
                  child: Column(
                    children: [
                      _buildRoom(state),
                      Expanded(child: _buildPanel(state)),
                    ],
                  ),
                ),
                if (_celebrating != null) _buildCelebration(state),
              ],
            ),
    );
  }

  /// 방: 벽과 바닥, 그 위를 어슬렁거리는 친구
  Widget _buildRoom(PetState state) {
    final species = state.species;
    return Container(
      height: 240,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3DC), Color(0xFFF6E3C5)],
        ),
      ),
      // 친구의 가로 위치를 방 너비에서 계산해야 해서 LayoutBuilder가 Stack을 감싼다
      // (AnimatedPositioned는 Stack의 직접 자식이어야 한다).
      child: LayoutBuilder(builder: (context, box) {
        const petSize = 92.0;
        return Stack(
          children: [
            // 바닥선
            Positioned(
              left: 0,
              right: 0,
              bottom: 46,
              child: Container(height: 3, color: const Color(0xFFE0C9A6)),
            ),
            // 창문 (방처럼 보이게 하는 최소한의 장식)
            Positioned(
              left: 24,
              top: 24,
              child: Container(
                width: 62,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFCDE8FF),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFFE0C9A6), width: 3),
                ),
              ),
            ),
            // 친구
            AnimatedPositioned(
              duration: const Duration(milliseconds: 2000),
              curve: Curves.easeInOut,
              left: (box.maxWidth - petSize) * _x,
              bottom: 40,
              width: petSize,
              child: Transform.flip(
                flipX: !_facingRight,
                child: Opacity(
                  // 배도 고프고 목도 마르면 살짝 흐리게 — 아프다는 뜻이 아니라
                  // 졸려 보인다는 표현일 뿐이다.
                  opacity: state.sleepy ? 0.65 : 1,
                  child: Text(
                    species?.emojiAt(state.stage) ?? '🥚',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 76),
                  ),
                ),
              ),
            ),
            if (state.sleepy)
              const Positioned(
                right: 24,
                top: 24,
                child: Text('💤', style: TextStyle(fontSize: 30)),
              ),
          ],
        );
      }),
    );
  }

  Widget _buildPanel(PetState state) {
    final rule = state.nextRule;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${petStageNames[state.stage - 1]} 단계',
                style: displayStyle(fontSize: 20),
              ),
              const SizedBox(width: 8),
              Text('🪙 ${state.coins}',
                  style:
                      const TextStyle(fontSize: 15, color: AppColors.inkSoft)),
            ],
          ),
          const SizedBox(height: 14),
          _gauge('배부름', state.fullness, const Color(0xFFFFB703)),
          const SizedBox(height: 8),
          _gauge('목마름', state.hydration, const Color(0xFF4D96FF)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _careButton(
                  key: const ValueKey('pet-feed'),
                  emoji: '🍚',
                  label: '밥 주기',
                  cost: petMealCost,
                  left: petDailyCareLimit - state.mealsToday,
                  enabled: state.canFeed,
                  onTap: () => _care(meal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _careButton(
                  key: const ValueKey('pet-drink'),
                  emoji: '💧',
                  label: '물 주기',
                  cost: petDrinkCost,
                  left: petDailyCareLimit - state.drinksToday,
                  enabled: state.canDrink,
                  onTap: () => _care(meal: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (rule == null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF4D6),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Text(
                '🏆 끝까지 다 키웠어요!\n정말 대단해요',
                textAlign: TextAlign.center,
                style: displayStyle(fontSize: 17),
              ),
            )
          else
            _buildGrowthCard(state, rule),
        ],
      ),
    );
  }

  Widget _buildGrowthCard(PetState state, PetStageRule rule) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${petStageNames[state.stage]} 단계까지',
            style: displayStyle(fontSize: 17),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: state.progress,
              minHeight: 12,
              backgroundColor: const Color(0xFFEFE7D8),
              valueColor: AlwaysStoppedAnimation(
                  state.species?.color ?? AppColors.green),
            ),
          ),
          const SizedBox(height: 14),
          _need('⭐ 별 모으기', state.stars, rule.stars),
          _need('🍚 밥 주기', state.meals, rule.meals),
          _need('💧 물 주기', state.drinks, rule.drinks),
          const SizedBox(height: 6),
          const Text(
            '별은 문제를 풀면 모여요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  Widget _need(String label, int now, int need) {
    final done = now >= need;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 15)),
          ),
          Text(
            done ? '완료!' : '${math.min(now, need)} / $need',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: done ? AppColors.green : AppColors.inkSoft,
            ),
          ),
        ],
      ),
    );
  }

  Widget _gauge(String label, int value, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 54,
          child: Text(label, style: const TextStyle(fontSize: 14)),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 14,
              backgroundColor: const Color(0xFFEFE7D8),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _careButton({
    required Key key,
    required String emoji,
    required String label,
    required int cost,
    required int left,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      key: key,
      color: enabled ? Colors.white : const Color(0xFFF2EEE6),
      shadowColor: Colors.grey.shade300,
      border: Border.all(color: AppColors.outline, width: 2),
      padding: const EdgeInsets.symmetric(vertical: 12),
      onTap: onTap,
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 30)),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: enabled ? AppColors.ink : AppColors.inkSoft,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            left > 0 ? '🪙 $cost · 오늘 $left번' : '오늘은 다 줬어요',
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
          ),
        ],
      ),
    );
  }

  /// 진화 축하: 하얗게 번쩍이며 새 모습이 드러난다.
  Widget _buildCelebration(PetState state) {
    final stage = _celebrating!;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.55),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('✨ 축하해요! ✨',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const SizedBox(height: 16),
                Text(state.species?.emojiAt(stage) ?? '🌟',
                    style: const TextStyle(fontSize: 110)),
                const SizedBox(height: 16),
                Text(
                  '${state.species?.name ?? '친구'}가\n${petStageNames[stage - 1]} 단계가 되었어요!',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white),
                ),
                const SizedBox(height: 28),
                BouncyButton(
                  key: const ValueKey('evolve-ok'),
                  color: AppColors.green,
                  shadowColor: AppColors.greenPressed,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 36, vertical: 12),
                  onTap: () => setState(() => _celebrating = null),
                  child: const Text('좋아요!',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 90, child: SparkleBurst()),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
