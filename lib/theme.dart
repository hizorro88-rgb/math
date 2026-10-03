import 'package:flutter/material.dart';

/// "쿼카 학교" 디자인 토큰 — 따뜻한 숲 톤.
/// 색·서체·모양을 여기서만 정의하고 화면들은 이것만 가져다 쓴다.
class AppColors {
  AppColors._();

  /// 전 화면 공통 배경 (크림)
  static const cream = Color(0xFFFFF8ED);

  /// 텍스트 기본 잉크 (검정 대신 다크브라운)
  static const ink = Color(0xFF3E3226);

  /// 보조 텍스트
  static const inkSoft = Color(0xFF8A7A66);

  /// 브랜드 그린 (앱바·주 CTA)
  static const green = Color(0xFF3DA35D);
  static const greenPressed = Color(0xFF2E7D46);

  /// 쿼카 브라운 (보조)
  static const brown = Color(0xFF8C5A2B);
  static const brownSurface = Color(0xFFF3E7D3);

  /// 별·코인·보상
  static const amber = Color(0xFFFFB703);

  /// 오답·주의
  static const coral = Color(0xFFFF6B6B);

  /// 잠긴 단계 노드
  static const lockedNode = Color(0xFFE8E4DA);

  /// 카드 아웃라인
  static const outline = Color(0xFFEADFCC);

  /// ── 색의 뜻 (글을 못 읽는 아이는 색으로 판단한다 — 뜻을 바꾸지 말 것) ──
  /// 초록 = 앞으로·선택됨·정답 / 코랄 = 오답(테두리에만) / 앰버 = 별·코인·보상
  /// / 점선 회색 = 아직. 단원·보기 색에는 빨강·초록 계열을 쓰지 않는다.

  /// 정답 (테두리·글자) — 브랜드 초록과 같다
  static const correct = green;

  /// 정답 칸·선택된 칸 바탕 (라임)
  static const selectedFill = Color(0xFFD7FFB8);

  /// 오답 (고른 칸 테두리에만)
  static const wrong = coral;

  /// 틀렸을 때 아래 판 바탕 — 꾸짖는 빨강이 아니라 따뜻한 살구색
  static const wrongSurface = Color(0xFFFFF1E6);

  /// 틀렸을 때 판 글자 (갈색 — 격려하는 말투에 맞춘다)
  static const wrongInk = Color(0xFF9A5B2E);

  /// 듣기 버튼 전용 파랑 — "파란 동그라미 = 소리 듣기" 한 가지 뜻으로만 쓴다
  static const listen = Color(0xFF2B9BE0);

  /// 별·코인·보상 바탕
  static const rewardSurface = Color(0xFFFFF4D6);

  /// 흐린 글자·비활성 (차가운 회색 대신 따뜻한 회갈색)
  static const inkMuted = Color(0xFFA79A88);

  /// 구분선·비활성 테두리
  static const line = Color(0xFFEBE3D2);

  /// 퀴즈 보기 4색 (파스텔). 정답 초록과 헷갈리지 않게 초록 대신 라벤더.
  static const choiceFills = [
    Color(0xFFE3F2FF),
    Color(0xFFFFEDE3),
    Color(0xFFF1E9FF),
    Color(0xFFFFF4D6),
  ];
  static const choiceBorders = [
    Color(0xFF9CCBEF),
    Color(0xFFF0BC9C),
    Color(0xFFC9B3F0),
    Color(0xFFE8CF8B),
  ];
}

/// 설정 화면에 보여줄 앱 버전 (pubspec version과 함께 올린다)
const appVersionLabel = '1.34.0';

/// 제목·버튼·숫자용 라운드 서체 (본문은 NotoSansKR)
const kDisplayFont = 'Jua';

/// 제목용 스타일 헬퍼
TextStyle displayStyle({
  double fontSize = 22,
  Color color = AppColors.ink,
  FontWeight? weight,
}) {
  return TextStyle(
    fontFamily: kDisplayFont,
    fontFamilyFallback: const ['NotoSansKR', 'NotoColorEmoji'],
    fontSize: fontSize,
    fontWeight: weight,
    color: color,
  );
}

/// 반복(무한) 애니메이션 스위치.
/// 위젯 테스트의 pumpAndSettle이 끝나지 않는 것을 막기 위해
/// 테스트에서는 false로 끈다. 실제 앱에서는 항상 true.
class AppMotion {
  AppMotion._();

  static bool loops = true;
}

/// 한국어 어절 단위 줄바꿈: 어절(한글 연속 구간) 안에서 줄이 끊기지 않게
/// 글자 사이에 줄바꿈 금지 문자(U+2060)를 끼운다. 이모지·영문은 건드리지 않는다.
String keepAll(String text) {
  final buf = StringBuffer();
  int? prev;
  for (final r in text.runes) {
    final isHangul = r >= 0xAC00 && r <= 0xD7A3;
    final prevHangul = prev != null && prev >= 0xAC00 && prev <= 0xD7A3;
    if (isHangul && prevHangul) buf.write('\u2060');
    buf.writeCharCode(r);
    prev = r;
  }
  return buf.toString();
}
