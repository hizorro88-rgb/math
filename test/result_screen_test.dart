import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/daily.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/screens/result_screen.dart';
import 'package:preschool_math/services/speech.dart';
import 'package:preschool_math/theme.dart';
import 'package:preschool_math/widgets/quiz_parts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AppMotion.loops = false;
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
    Speech.enabled = true;
  });

  Widget app(ResultScreen screen) => MaterialApp(home: screen);

  Widget retry() => const Scaffold(body: Text('retry'));

  testWidgets('🪙 총액에는 상자·미션·연속 출석 보너스까지 모두 들어간다', (tester) async {
    await tester.pumpWidget(app(ResultScreen(
      correctCount: 9,
      totalCount: 10,
      earnedPoints: 40,
      chestCoins: 30,
      milestoneDays: 3,
      milestoneCoins: 20,
      completedMissions: const [
        DailyMission(id: 'm', emoji: '🔁', title: '3판', target: 3, reward: 10),
      ],
      retryBuilder: retry,
    )));
    await tester.pumpAndSettle();

    expect(find.text('🪙 +100'), findsOneWidget);
    // 배너 대신 칩 한 줄 (그림 + 숫자)
    expect(find.text('🎁 +30'), findsOneWidget);
    expect(find.text('📋 ✓1'), findsOneWidget);
    expect(find.text('🔥 3'), findsOneWidget);
  });

  testWidgets('통과했는데 다음 단계가 막혀 있으면 주인공은 "친구한테 가기"', (tester) async {
    await tester.pumpWidget(app(ResultScreen(
      correctCount: 8,
      totalCount: 10,
      earnedPoints: 40,
      retryBuilder: retry,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-friend')), findsOneWidget);
    expect(find.text('다시 하기'), findsOneWidget); // 조용한 보조
  });

  testWidgets('첫 판이면 별이 없어도 "친구한테 가기"가 주인공', (tester) async {
    ResultScreen.firstRunPending = true;
    await tester.pumpWidget(app(ResultScreen(
      correctCount: 2,
      totalCount: 10,
      earnedPoints: 5,
      retryBuilder: retry,
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-friend')), findsOneWidget);
    expect(ResultScreen.firstRunPending, isFalse); // 한 번만 쓴다
  });

  testWidgets('결과를 한 문장으로 읽어 준다', (tester) async {
    final spoken = <String>[];
    Speech.debugOnSpeak = spoken.add;
    addTearDown(() => Speech.debugOnSpeak = null);
    await tester.pumpWidget(app(ResultScreen(
      correctCount: 10,
      totalCount: 10,
      earnedPoints: 60,
      retryBuilder: retry,
      nextLabel: '다음 단계',
      nextBuilder: retry,
    )));
    await tester.pumpAndSettle();
    expect(spoken.single, contains('별 3개'));
    expect(spoken.single, contains('다음 단계'));
  });

  testWidgets('고친 문제는 ✓ 점으로, 오답 노트 입구는 하나만', (tester) async {
    await tester.pumpWidget(app(ResultScreen(
      correctCount: 8,
      totalCount: 10,
      earnedPoints: 40,
      retryBuilder: retry,
      nextLabel: '다음 단계',
      nextBuilder: retry,
      dots: const [
        ...[
          QuizDot.correct,
          QuizDot.correct,
          QuizDot.correct,
          QuizDot.correct,
          QuizDot.correct,
          QuizDot.correct,
          QuizDot.correct,
          QuizDot.correct,
        ],
        QuizDot.fixed,
        QuizDot.missed,
      ],
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('result-wrong-notes')), findsOneWidget);
    expect(find.textContaining('틀렸던 문제'), findsOneWidget);
  });
}
