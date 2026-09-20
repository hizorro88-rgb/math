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

  /// 과목 포인트색 (앱바가 아니라 칩·카드 액센트에만 쓴다)
  static const math = Color(0xFF3DA35D);
  static const korean = Color(0xFFFF8B5C);
  static const english = Color(0xFF4D96FF);
  static const japanese = Color(0xFFFF6B9D);
  static const chinese = Color(0xFFF4B740);

  /// 퀴즈 보기 4색 (파스텔)
  static const choiceFills = [
    Color(0xFFE3F2FF),
    Color(0xFFFFEDE3),
    Color(0xFFEAF9E6),
    Color(0xFFFFF4D6),
  ];
  static const choiceBorders = [
    Color(0xFF9CCBEF),
    Color(0xFFF0BC9C),
    Color(0xFFA8D89A),
    Color(0xFFE8CF8B),
  ];
}

/// 설정 화면에 보여줄 앱 버전 (pubspec version과 함께 올린다)
const appVersionLabel = '1.31.0';

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
