import 'package:flutter/material.dart';

import 'kid_notice.dart';

/// 퀴즈 도중 나가기 전에 띄우는 "정말 그만할까요?" 확인 팝업.
/// 나가기를 골랐으면 true를 돌려준다.
Future<bool> confirmQuizExit(BuildContext context) => showKidConfirm(
      context,
      emoji: '🏠',
      question: '정말 그만할까요?',
      detail: '이번 판은 저장되지 않아요',
      speech: '정말 그만할까요? 초록 버튼을 누르면 계속 풀어요',
      keepLabel: '계속 풀기',
      actionLabel: '🏠 그만하기',
    );
