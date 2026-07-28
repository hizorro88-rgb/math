import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/main.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  /// 화면 밖에 있을 수 있는 위젯을 스크롤로 보이게 한 뒤 탭한다.
  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('홈에 나이·학년 카테고리가 보인다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.text('수학 놀이'), findsOneWidget);
    expect(find.text('자유 연습'), findsOneWidget);
    expect(find.text('지금 나는 알!'), findsOneWidget);

    // 7개 카테고리
    for (final title in ['4살', '5살', '6살', '7살']) {
      expect(find.text(title), findsOneWidget);
    }
    await tester.ensureVisible(find.text('초등 3학년'));
    expect(find.text('초등 2학년'), findsOneWidget);
    expect(find.text('초등 3학년'), findsOneWidget);
  });

  testWidgets('4살 카테고리에서 1단계만 열려 있고, 누르면 수 세기 퀴즈가 시작된다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('4살'));
    expect(find.text('수 세기 첫걸음'), findsOneWidget);
    expect(find.text('1'), findsOneWidget);
    expect(find.text('🔒'), findsWidgets);

    await scrollAndTap(tester, find.text('1'));
    expect(find.text('1단계'), findsOneWidget);
    expect(find.text('몇 개일까요?'), findsOneWidget); // 4살 첫 단계는 수 세기
    expect(find.text('🪙 0'), findsOneWidget);
  });

  testWidgets('통과한 기록이 있으면 다음 단계가 열리고 점수가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'level_stars_v2': ['3', '2'],
      'total_points_v1': 250,
    });

    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 1, 2단계 통과 → 총 별 5개, 누적 점수 250점(병아리 칭호)
    expect(find.text('⭐ 5'), findsOneWidget);
    expect(find.text('🪙 250'), findsOneWidget);
    expect(find.text('지금 나는 병아리!'), findsOneWidget);

    await scrollAndTap(tester, find.text('4살'));
    expect(find.text('3'), findsOneWidget);
    await scrollAndTap(tester, find.text('3'));

    expect(find.text('3단계'), findsOneWidget);
  });

  testWidgets('초등 2학년 곱셈 카테고리는 바로 시작할 수 있다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('초등 2학년'));
    expect(find.textContaining('곱셈 첫걸음'), findsOneWidget);

    // 카테고리 첫 단계(두 자리 덧셈 1단계)는 앞 카테고리를 안 깨도 열려 있다.
    await scrollAndTap(tester, find.text('두 자리 덧셈'));
    // 첫 단계 버블 탭 (카테고리 첫 단계 번호)
  });

  testWidgets('퀴즈 도중 나가려면 확인 팝업을 거친다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 4살 → 1단계 입장, 아무것도 안 풀었으면 X로 바로 나간다.
    await scrollAndTap(tester, find.text('4살'));
    await scrollAndTap(tester, find.text('1'));
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.textContaining('몇 개일까요?'), findsNothing); // 지도로 돌아옴

    // 다시 들어가서 한 문제를 풀면, X를 눌렀을 때 확인 팝업이 뜬다.
    await scrollAndTap(tester, find.text('1'));
    final choice = find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^\d+$').hasMatch(w.data ?? ''),
    );
    await tester.tap(choice.first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.text('정말 그만할까요?'), findsOneWidget);

    // '계속 풀기'를 누르면 퀴즈로 돌아온다.
    await tester.tap(find.text('계속 풀기'));
    await tester.pumpAndSettle();
    expect(find.text('정말 그만할까요?'), findsNothing);

    // 다시 X → '그만하기'를 누르면 지도로 나간다.
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    await tester.tap(find.text('그만하기'));
    await tester.pumpAndSettle();
    expect(find.text('몇 개일까요?'), findsNothing);
  });

  testWidgets('틀린 문제는 판 끝에 다시 나오고, 다시 맞히면 +5점 (자유 연습)', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 자유 연습 → 덧셈(기본)으로 시작
    await scrollAndTap(tester, find.text('자유 연습'));
    await scrollAndTap(tester, find.text('시작하기'));

    String expr() => tester.widget<Text>(find.textContaining('= ?')).data!;
    int answerOf(String e) {
      final m = RegExp(r'(\d+) ([+-]) (\d+)').firstMatch(e)!;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(3)!);
      return m.group(2) == '+' ? a + b : a - b;
    }

    Future<void> answer({required bool correct}) async {
      final ans = answerOf(expr());
      final choices = find
          .byWidgetPredicate(
              (w) => w is Text && RegExp(r'^\d+$').hasMatch(w.data ?? ''))
          .evaluate()
          .map((e) => (e.widget as Text).data!)
          .toList();
      final target = correct ? '$ans' : choices.firstWhere((c) => c != '$ans');
      await tester.ensureVisible(find.text(target));
      await tester.pumpAndSettle();
      await tester.tap(find.text(target));
      await tester.pumpAndSettle();
    }

    // 1번 문제를 일부러 틀린다.
    final wrongExpr = expr();
    await answer(correct: false);
    expect(find.textContaining('아쉬워요'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();

    // 나머지 9문제는 전부 맞힌다.
    for (var i = 0; i < 9; i++) {
      await answer(correct: true);
      await tester.tap(find.text('계속하기'));
      await tester.pumpAndSettle();
    }

    // 11번째로 틀렸던 문제가 다시 나온다.
    expect(find.text('🔁 다시 풀어 봐요!'), findsOneWidget);
    expect(expr(), wrongExpr);

    // 다시 맞히면 +5점 보너스, 별점은 첫 시도 기준(9/10)
    await answer(correct: true);
    expect(find.text('+5점'), findsOneWidget);
    await tester.tap(find.text('결과 보기'));
    await tester.pumpAndSettle();
    expect(find.text('10문제 중에 9문제를 맞혔어요!'), findsOneWidget);
  });

  testWidgets('꾸미기 가게에서 코인으로 아이템을 산다', (tester) async {
    SharedPreferences.setMockInitialValues({'coins_v1': 100});

    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('꾸미기 가게'));
    await tester.pumpAndSettle();

    expect(find.text('🪙 100'), findsOneWidget);
    expect(find.text('리본'), findsOneWidget);

    // 리본(80코인) 구매 → 코인 차감 + 착용
    await tester.ensureVisible(find.text('리본'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('리본'));
    await tester.pumpAndSettle();

    expect(find.text('🪙 20'), findsOneWidget);
    expect(find.text('착용 중'), findsOneWidget);

    // 구매 축하 스낵바가 사라질 때까지 기다린다.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    // 왕관(600코인)은 못 산다
    await tester.ensureVisible(find.text('왕관'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('왕관'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.textContaining('코인이 부족해요'), findsOneWidget);

    // 남은 스낵바 타이머를 흘려보낸다.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });
}
