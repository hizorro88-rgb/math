import 'package:flutter/material.dart';

import '../services/speech.dart';
import 'bouncy_button.dart';

/// 듣기 유형(소리로 문제를 내는 퀴즈)에 들어갈 수 있는지 확인한다.
/// - 기기에 한국어 음성이 없으면: 안내 후 false (풀 수 없음)
/// - 소리가 꺼져 있으면: "소리 켜고 시작" 팝업을 띄우고 선택을 따른다
/// true를 돌려주면 퀴즈를 진행해도 된다.
Future<bool> ensureListenReady(BuildContext context) async {
  if (!Speech.available) {
    await showDialog<void>(
      context: context,
      builder: (context) => _guardDialog(
        context,
        emoji: '🙉',
        title: '음성을 쓸 수 없어요',
        message: '이 기기에는 한국어 읽어주기 음성이 없어서\n듣기 문제를 풀 수 없어요.\n'
            '기기 설정에서 한국어 TTS를 설치해 주세요.',
        buttons: [
          BouncyButton(
            color: const Color(0xFF58CC02),
            padding: const EdgeInsets.symmetric(vertical: 14),
            onTap: () => Navigator.of(context).pop(),
            child: const Text(
              '알겠어요',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
    return false;
  }

  if (Speech.enabled) return true;

  final turnOn = await showDialog<bool>(
    context: context,
    builder: (context) => _guardDialog(
      context,
      emoji: '🔊',
      title: '소리를 켜 볼까요?',
      message: '이 문제는 소리를 듣고 풀어요.\n소리를 켜야 시작할 수 있어요!',
      buttons: [
        BouncyButton(
          color: const Color(0xFF58CC02),
          padding: const EdgeInsets.symmetric(vertical: 14),
          onTap: () => Navigator.of(context).pop(true),
          child: const Text(
            '소리 켜고 시작',
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
          onTap: () => Navigator.of(context).pop(false),
          child: Text(
            '다음에 할래요',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    ),
  );
  if (turnOn == true) {
    await Speech.setEnabled(true);
    return true;
  }
  return false;
}

Widget _guardDialog(
  BuildContext context, {
  required String emoji,
  required String title,
  required String message,
  required List<Widget> buttons,
}) {
  return Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(emoji,
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 48)),
          const SizedBox(height: 8),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 15, color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 20),
          ...buttons,
        ],
      ),
    ),
  );
}
