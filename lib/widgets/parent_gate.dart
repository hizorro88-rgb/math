import 'dart:math';

import 'package:flutter/material.dart';

/// 부모용 화면(리포트 등) 앞에 두는 간단한 확인 관문.
/// 곱셈 문제를 맞히면 true를 돌려준다. (어린이 카테고리 심사 대응)
Future<bool> checkParentGate(BuildContext context) async {
  final random = Random();
  final a = 3 + random.nextInt(7); // 3..9
  final b = 3 + random.nextInt(7);
  final answer = a * b;
  final choices = <int>{answer};
  while (choices.length < 4) {
    final candidate = answer + (random.nextInt(13) - 6);
    if (candidate > 0) choices.add(candidate);
  }
  final shuffled = choices.toList()..shuffle(random);

  final passed = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('👨‍👩‍👧',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 44)),
            const SizedBox(height: 8),
            const Text(
              '부모님 확인',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '이 화면은 부모님을 위한 곳이에요.\n아래 문제를 풀어 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),
            Text(
              '$a × $b = ?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            for (final choice in shuffled) ...[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(context).pop(choice == answer),
                child: Text(
                  '$choice',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    ),
  );
  return passed == true;
}
