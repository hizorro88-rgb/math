import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/kid_notice.dart';
import '../widgets/pet_parts.dart';

/// 친구가 지내는 방. 돌아다니는 모습을 보고, 밥과 물을 주고, 쓰다듬는다.
///
/// 오래 머무는 놀이터가 아니라 잠깐 들러 보고 나가는 곳이다.
/// 코인을 쓰는 일은 밥·물 두 가지뿐이고, 둘 다 공부로 번 코인을 쓴다.
/// (쓰다듬기는 공짜 — 수치·코인·진화와는 무관하다)
///
/// "문제 풀러 가기"를 고르면 'play'를 돌려주고, 홈이 바로 시작을 연다.
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

  @override
  void initState() {
    super.initState();
    _reload();
    _walkTimer = startPetWalk((target) {
      final state = _state;
      if (!mounted || state == null || state.stage <= 1 || state.sleepy) {
        return;
      }
      setState(() {
        _facingRight = target > _x;
        _x = target;
      });
    });
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
    setState(() => _state = state);
    final species = state.species;
    if (grown != null && species != null) {
      await showPetEvolution(context, species: species, stage: grown);
    }
  }

  void _goPlay() => Navigator.of(context).pop('play');

  Future<void> _care({required bool meal}) async {
    final ok = await PetStore.care(meal: meal);
    if (!mounted) return;
    if (!ok) {
      final state = _state;
      final enough = state != null &&
          (meal ? state.coins >= petMealCost : state.coins >= petDrinkCost);
      final face = state?.species?.emojiAt(state.stage);
      enough
          ? showKidNotice(context,
              face: face,
              emoji: '🌙',
              text: meal ? '배불러요! 내일 또 줘요' : '물은 충분해요! 내일 또 줘요')
          : showKidNotice(context,
              face: face,
              emoji: '🪙',
              text: '코인이 모자라요. 문제 풀러 갈까?',
              action: _goPlay);
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
        centerTitle: true,
        title: Text(state?.species?.name ?? '내 친구',
            style: displayStyle(fontSize: 20, color: Colors.white)),
      ),
      body: state == null || state.species == null
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Column(
                children: [
                  _buildRoom(state),
                  Expanded(child: _buildPanel(state)),
                ],
              ),
            ),
    );
  }

  /// 방: 벽과 바닥, 그 위를 어슬렁거리는 친구
  Widget _buildRoom(PetState state) {
    final species = state.species!;
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
        const spriteBox = 110 * 1.25;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 바닥선
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
              child: Container(height: 3, color: const Color(0xFFE0C9A6)),
            ),
            // 창문 (방처럼 보이게 하는 최소한의 장식)
            Positioned(
              left: 24,
              top: 20,
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
            AnimatedPositioned(
              duration: const Duration(milliseconds: 2200),
              curve: Curves.easeInOut,
              left: (box.maxWidth - spriteBox) * _x,
              bottom: 34,
              child: PetSprite(
                species: species,
                stage: state.stage,
                size: 110,
                sleepy: state.sleepy,
                wish: state.wantsMeal
                    ? '🍚'
                    : state.wantsDrink
                        ? '💧'
                        : null,
                flip: !_facingRight,
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildPanel(PetState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                petStageNames[state.stage - 1],
                style: displayStyle(fontSize: 20),
              ),
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.rewardSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('🪙 ${state.coins}',
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          PetGauge(meal: true, value: state.fullness, height: 14),
          const SizedBox(height: 8),
          PetGauge(meal: false, value: state.hydration, height: 14),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: PetCareButton(
                  key: const ValueKey('pet-feed'),
                  meal: true,
                  state: state,
                  nudge: state.wantsMeal,
                  onTap: () => _care(meal: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PetCareButton(
                  key: const ValueKey('pet-drink'),
                  meal: false,
                  state: state,
                  nudge: state.wantsDrink,
                  onTap: () => _care(meal: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 자라기까지: ⭐·🍚·💧 원이 다 차면 → 다음 모습(❔)
          Container(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            child: PetGrowth(
              state: state,
              onStarTap: () => showKidNotice(context,
                  emoji: '⭐',
                  text: '문제를 풀면 별이 생겨!',
                  action: _goPlay),
            ),
          ),
        ],
      ),
    );
  }
}
