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

  /// 친구 물 막대 (밥 막대는 amber)
  static const petWater = Color(0xFF4DA8FF);

  /// 별·코인·보상 바탕
  static const rewardSurface = Color(0xFFFFF4D6);

  /// 흐린 글자·비활성 (차가운 회색 대신 따뜻한 회갈색)
  static const inkMuted = Color(0xFFA79A88);

  /// 구분선·비활성 테두리
  static const line = Color(0xFFEBE3D2);

  /// 보상 글자 (앰버 바탕 위 — 앰버 글자는 흰 바탕에서 안 읽혀서 진한 황토)
  static const rewardInk = Color(0xFF9A6A00);

  /// 브랜드 초록의 밝은 쪽 (홈 머리 그라데이션 위)
  static const greenLight = Color(0xFF57BE78);

  /// 단계 밖 판(자유 연습·오답 노트)의 테마색 — 단원 색이 없을 때 하나로
  static const practice = Color(0xFF8A6FD8);

  /// 마이크가 켜져 있음(듣는 중·녹음 중) — 이 뜻으로만 쓴다
  static const recording = Color(0xFFEA2B2B);
  static const recordingSurface = Color(0xFFFFE4E1);

  /// 아직 못 얻은 것의 그림자(실루엣)·점선
  static const silhouette = Color(0xFFC9BCA6);

  /// 진행 점: 틀린 문제 (코랄을 흐리게 — 꾸짖지 않는 색)
  static const missedDot = Color(0xFFFFC9A8);

  /// 그림 문제(분수 원 등)의 칠한 부분·선
  static const figureFill = Color(0xFFB59CF0);
  static const figureLine = Color(0xFF6A4FC2);

  /// 떠 있는 창(아이 알림)의 그림자, 축하 창 뒤 어둡게
  static const floatShadow = Color(0x33000000);
  static const scrim = Color(0x99000000);

  /// 축하 꽃가루 (뜻 없는 장식이라 여러 색)
  static const confetti = [
    green,
    amber,
    coral,
    Color(0xFF4D96FF),
    Color(0xFFFF6B9D),
  ];

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

/// 글자 크기 6단계 — 화면의 '글'은 이 여섯 가지만 쓴다.
/// 26 이상은 글이 아니라 그림(이모지)·문제 숫자 크기라 숫자로 자유롭게 쓴다.
/// (test/design_tokens_test.dart가 26 미만 숫자를 막는다)
class AppFont {
  AppFont._();

  /// 어른용 작은 설명·각주
  static const caption = 12.0;

  /// 보조 글·칩·부제
  static const small = 14.0;

  /// 본문·버튼 글
  static const body = 16.0;

  /// 카드·칸 제목
  static const title = 18.0;

  /// 화면 제목(앱바)·큰 버튼
  static const heading = 20.0;

  /// 큰 안내·축하 글
  static const display = 24.0;
}

/// 장면(친구 방·꾸미기 판) 배경색 — 화면마다 따로 고르지 않게 여기서만
class SceneColors {
  SceneColors._();

  static const wallTop = Color(0xFFFFF3DC);
  static const wallBottom = Color(0xFFF6E3C5);
  static const floor = Color(0xFFE0C9A6);
  static const window = Color(0xFFCDE8FF);
  static const skyTop = Color(0xFFBBE3FF);
  static const skyBottom = Color(0xFFE3F4FF);
  static const grass = Color(0xFFA5D96C);
}

/// 설정 화면에 보여줄 앱 버전 (pubspec version과 함께 올린다)
const appVersionLabel = '1.44.0';

/// 제목·버튼·숫자용 라운드 서체 (본문은 NotoSansKR)
const kDisplayFont = 'Jua';

/// 제목용 스타일 헬퍼
TextStyle displayStyle({
  double fontSize = AppFont.display,
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
