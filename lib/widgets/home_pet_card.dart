import 'dart:async';

import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../services/speech.dart';
import '../theme.dart';
import 'bouncy_button.dart';
import 'pet_parts.dart';
import 'quiz_parts.dart';

/// 홈 화면 맨 위에서 친구가 살아 움직이는 카드.
///
/// 방에 따로 들어가지 않아도 여기서 바로 밥과 물을 줄 수 있다.
/// 친구를 누르면 성장 조건까지 볼 수 있는 방으로 들어간다.
class HomePetCard extends StatefulWidget {
  const HomePetCard({
    super.key,
    required this.pet,
    required this.greeting,
    required this.onOpenRoom,
    required this.onMeet,
    required this.onCare,
    this.nudgeDrink = false,
  });

  /// 첫 판을 마치고 왔을 때: "목말라요!"로 물 주기를 처음 해 보게 이끈다.
  final bool nudgeDrink;

  final PetState pet;

  /// 오늘 활동에 따라 달라지는 인사말
  final String greeting;

  /// 친구를 눌렀을 때 (방으로)
  final VoidCallback onOpenRoom;

  /// 아직 친구가 없을 때 만나러 가기
  final VoidCallback onMeet;

  /// 밥·물 주기 (meal이 true면 밥)
  final Future<void> Function({required bool meal}) onCare;

  @override
  State<HomePetCard> createState() => _HomePetCardState();
}

class _HomePetCardState extends State<HomePetCard> {
  /// 방 안 가로 위치 (0.0 왼쪽 ~ 1.0 오른쪽)
  double _x = 0.5;
  bool _facingRight = true;
  Timer? _walkTimer;

  /// 앱을 켜고 홈에 처음 왔을 때 한 번만 인사를 읽어 준다
  /// (다른 화면에서 돌아올 때마다 말하면 시끄럽다).
  static bool _greeted = false;

  @override
  void initState() {
    super.initState();
    if (!_greeted) {
      _greeted = true;
      Speech.speak(_plain(widget.greeting));
    }
    _walkTimer = startPetWalk((target) {
      // 아기(1단계)·졸린 친구는 제자리에서 콩콩·새근새근
      final pet = widget.pet;
      if (!mounted || pet.stage <= 1 || pet.sleepy) return;
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

  @override
  Widget build(BuildContext context) {
    final pet = widget.pet;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              // 누가 말하는지 보이게: 친구 얼굴 + 말풍선
              if (pet.chosen) ...[
                Text(pet.species!.emojiAt(pet.stage),
                    style: const TextStyle(fontSize: 26)),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    widget.nudgeDrink && pet.chosen
                        ? '${pet.species!.name}가 목말라요! 💧\n물 주기를 눌러 봐!'
                        : widget.greeting,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.ink,
                      height: 1.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              // 글을 못 읽어도 친구가 무슨 말을 하는지 들을 수 있다.
              QuizSpeakButton(
                size: 34,
                onTap: () => Speech.speak(_plain(widget.greeting), force: true),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (pet.chosen) _buildPet(pet) else _buildInvite(),
        ],
      ),
    );
  }

  /// 아직 안 골랐으면 (예전부터 쓰던 프로필) 만나러 가자고 권한다.
  Widget _buildInvite() {
    return Row(
      children: [
        const Text('🥚', style: TextStyle(fontSize: 44)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('함께 공부할 친구가 기다려요', style: displayStyle(fontSize: 15)),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: BouncyButton(
                  key: const ValueKey('pet-meet'),
                  color: AppColors.green,
                  shadowColor: AppColors.greenPressed,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  onTap: widget.onMeet,
                  child: const Text(
                    '친구 만나러 가기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPet(PetState pet) {
    return Column(
      children: [
        Row(
          children: [
            _buildMiniRoom(pet),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(pet.species?.name ?? '내 친구',
                      style: displayStyle(fontSize: 17)),
                  const SizedBox(height: 8),
                  PetGauge(meal: true, value: pet.fullness, height: 10),
                  const SizedBox(height: 6),
                  PetGauge(meal: false, value: pet.hydration, height: 10),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: PetCareButton(
                key: const ValueKey('home-feed'),
                meal: true,
                state: pet,
                compact: true,
                nudge: pet.wantsMeal,
                onTap: () => widget.onCare(meal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: PetCareButton(
                key: const ValueKey('home-drink'),
                meal: false,
                state: pet,
                compact: true,
                nudge: widget.nudgeDrink || pet.wantsDrink,
                onTap: () => widget.onCare(meal: false),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // 자라기까지 ⭐·🍚·💧 — 누르면 친구 방으로
        Semantics(
          button: true,
          label: '친구 방',
          onTap: widget.onOpenRoom,
          child: GestureDetector(
            key: const ValueKey('home-pet'),
            onTap: widget.onOpenRoom,
            child: Container(
              padding: const EdgeInsets.fromLTRB(6, 6, 2, 6),
              decoration: BoxDecoration(
                color: AppColors.cream,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline, width: 1.5),
              ),
              child: Row(
                children: [
                  Expanded(child: PetGrowth(state: pet, compact: true)),
                  const Icon(Icons.chevron_right_rounded,
                      color: AppColors.inkMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// 친구가 어슬렁거리는 작은 방 (누르면 깡충, 문지르면 💗)
  Widget _buildMiniRoom(PetState pet) {
    final species = pet.species!;
    return Container(
      width: 120,
      height: 104,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFF3DC), Color(0xFFF3DFBE)],
        ),
      ),
      child: LayoutBuilder(builder: (context, box) {
        const spriteBox = 56 * 1.25;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            // 바닥선
            Positioned(
              left: 0,
              right: 0,
              bottom: 14,
              child: Container(height: 2, color: const Color(0xFFE0C9A6)),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 2200),
              curve: Curves.easeInOut,
              left: (box.maxWidth - spriteBox) * _x,
              bottom: 10,
              child: PetSprite(
                species: species,
                stage: pet.stage,
                size: 56,
                sleepy: pet.sleepy,
                wish: pet.wantsMeal
                    ? '🍚'
                    : pet.wantsDrink
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
}

/// 읽어 줄 때는 줄바꿈과 이모지를 뺀다.
String _plain(String text) => text
    .replaceAll('\n', ' ')
    .replaceAll(
        RegExp(r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]', unicode: true), '')
    .trim();
