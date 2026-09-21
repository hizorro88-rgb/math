import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/pet.dart';
import '../theme.dart';
import 'bouncy_button.dart';

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
  });

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
  final _random = math.Random();

  @override
  void initState() {
    super.initState();
    if (AppMotion.loops) {
      _walkTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
        if (!mounted) return;
        setState(() {
          final target = 0.1 + _random.nextDouble() * 0.8;
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
          Text(
            widget.greeting,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
              height: 1.3,
            ),
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
              Text('함께 공부할 친구가 기다려요',
                  style: displayStyle(fontSize: 15)),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMiniRoom(pet),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pet.species?.name ?? '내 친구',
                    style: displayStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  _gauge('🍚', pet.fullness, const Color(0xFFFFB703)),
                  const SizedBox(height: 6),
                  _gauge('💧', pet.hydration, const Color(0xFF4D96FF)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _careButton(
                key: const ValueKey('home-feed'),
                label: '밥 주기',
                emoji: '🍚',
                cost: petMealCost,
                left: petDailyCareLimit - pet.mealsToday,
                enabled: pet.canFeed,
                onTap: () => widget.onCare(meal: true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _careButton(
                key: const ValueKey('home-drink'),
                label: '물 주기',
                emoji: '💧',
                cost: petDrinkCost,
                left: petDailyCareLimit - pet.drinksToday,
                enabled: pet.canDrink,
                onTap: () => widget.onCare(meal: false),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 친구가 어슬렁거리는 작은 방 (누르면 진짜 방으로 들어간다)
  Widget _buildMiniRoom(PetState pet) {
    return GestureDetector(
      key: const ValueKey('home-pet'),
      onTap: widget.onOpenRoom,
      child: Container(
        width: 112,
        height: 96,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFF3DC), Color(0xFFF3DFBE)],
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(builder: (context, box) {
          const petSize = 46.0;
          return Stack(
            children: [
              // 바닥선
              Positioned(
                left: 0,
                right: 0,
                bottom: 16,
                child: Container(height: 2, color: const Color(0xFFE0C9A6)),
              ),
              if (pet.sleepy)
                const Positioned(
                  right: 6,
                  top: 6,
                  child: Text('💤', style: TextStyle(fontSize: 15)),
                ),
              // 단계 표시
              Positioned(
                left: 6,
                top: 5,
                child: Text(
                  petStageNames[pet.stage - 1],
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 2200),
                curve: Curves.easeInOut,
                left: (box.maxWidth - petSize) * _x,
                bottom: 12,
                width: petSize,
                child: Transform.flip(
                  flipX: !_facingRight,
                  child: Opacity(
                    opacity: pet.sleepy ? 0.65 : 1,
                    child: Text(
                      pet.species?.emojiAt(pet.stage) ?? '🥚',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 38),
                    ),
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _gauge(String emoji, int value, Color color) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 13)),
        const SizedBox(width: 5),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value / 100,
              minHeight: 9,
              backgroundColor: const Color(0xFFF0E8DA),
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
        ),
      ],
    );
  }

  Widget _careButton({
    required Key key,
    required String label,
    required String emoji,
    required int cost,
    required int left,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    return BouncyButton(
      key: key,
      color: enabled ? const Color(0xFFFFF8ED) : const Color(0xFFF2EEE6),
      shadowColor: Colors.grey.shade300,
      border: Border.all(color: AppColors.outline, width: 2),
      borderRadius: 14,
      padding: const EdgeInsets.symmetric(vertical: 8),
      onTap: onTap,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 17)),
          const SizedBox(width: 5),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                left > 0 ? '$label 🪙$cost' : '오늘 다 줬어요',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: enabled ? AppColors.ink : AppColors.inkSoft,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
