import 'package:flutter/material.dart';

import 'bouncy_button.dart';

/// 퀴즈 도중 나가기 전에 띄우는 "정말 그만할까요?" 확인 팝업.
/// 나가기를 골랐으면 true를 돌려준다.
Future<bool> confirmQuizExit(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('🦉',
                textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
            const SizedBox(height: 8),
            const Text(
              '정말 그만할까요?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '이번 판은 저장되지 않아요.\n다음에 처음부터 다시 할 수 있어요!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            BouncyButton(
              color: const Color(0xFF3DA35D),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: () => Navigator.of(context).pop(false),
              child: const Text(
                '계속 풀기',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            BouncyButton(
              color: Colors.white,
              shadowColor: Colors.grey.shade300,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: () => Navigator.of(context).pop(true),
              child: Text(
                '그만하기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return leave == true;
}
