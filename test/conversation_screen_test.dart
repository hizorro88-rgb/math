import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/conversation_pack.dart';
import 'package:preschool_math/models/language_pack.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/screens/language_quiz_screen.dart';
import 'package:preschool_math/services/sounds.dart';
import 'package:preschool_math/services/speech.dart';
import 'package:preschool_math/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 영어회화는 문장이 길어서 보기·타일이 화면을 넘치기 쉽다.
/// 화면을 실제로 그려 보고 넘침(overflow)이 없는지 확인한다.
void main() {
  setUp(() {
    AppMotion.loops = false;
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
    Sounds.enabled = false;
    // 듣기 가드가 TTS 설치를 물어보지 않도록 음성을 꺼 둔다.
    Speech.enabled = false;
  });

  Future<void> openLevel(WidgetTester tester, int unitIndex, int stage) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LanguageQuizScreen(
          pack: conversationPack,
          typeIndex: 0,
          unitIndex: unitIndex,
          stage: stage,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('첫 단계 화면이 넘침 없이 그려진다', (tester) async {
    await openLevel(tester, 0, 0);
    expect(find.byType(LanguageQuizScreen), findsOneWidget);
    // 문제 카드의 지시문이 보인다 (유형에 따라 달라진다)
    expect(find.textContaining('요'), findsWidgets);
  });

  testWidgets('문장이 가장 긴 마지막 단계도 넘치지 않는다', (tester) async {
    // 주제를 바꿔 가며 마지막 단계(가장 어려운 표현)를 그려 본다.
    for (final unit in [0, 12, 25, 29]) {
      await openLevel(tester, unit, LanguagePack.levelsPerUnit - 1);
      expect(find.byType(LanguageQuizScreen), findsOneWidget);
    }
  });

  testWidgets('작은 화면(360x640)에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final stage in [0, 5, 9]) {
      await openLevel(tester, 13, stage);
      expect(find.byType(LanguageQuizScreen), findsOneWidget);
    }
  });
}
