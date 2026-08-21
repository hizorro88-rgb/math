import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 별과 반짝이가 가운데에서 사방으로 퍼지는 일회성 축하 효과
class SparkleBurst extends StatelessWidget {
  const SparkleBurst({super.key});

  static const _emojis = [
    '✨',
    '⭐',
    '🌟',
    '✨',
    '⭐',
    '✨',
    '🌟',
    '✨',
    '⭐',
    '✨',
    '🌟',
    '⭐'
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, t, _) => Stack(
        children: [
          for (var i = 0; i < _emojis.length; i++)
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(
                  math.cos(i * 2 * math.pi / _emojis.length) * 170 * t,
                  math.sin(i * 2 * math.pi / _emojis.length) * 190 * t - 60,
                ),
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + t,
                    child: Text(
                      _emojis[i],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
