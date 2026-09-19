import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/main.dart';
import 'package:preschool_math/theme.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/services/sounds.dart';
import 'package:preschool_math/services/speech.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// '다음 단계'로 이어서 깬 판의 별도 저장되는지 (사용자 제보 회귀 테스트)
void main() {
  setUp(() {
    AppMotion.loops = false;
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
    Sounds.enabled = true;
    Speech.enabled = true;
    Speech.rate = Speech.rateNormal;
  });

  Future<void> scrollAndTap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  testWidgets('다음 단계로 이어 깬 판도 저장된다', (tester) async {
    // 덧셈 첫걸음(51단계)까지 열어 둔다: 앞 50단계 클리어 + 이용권
    SharedPreferences.setMockInitialValues({
      'family_pass_v1': true,
      'level_stars_v4': [for (var i = 0; i < 420; i++) i < 50 ? '1' : '0'],
    });
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('5살'));
    await tester.dragUntilVisible(
      find.text('여기부터!'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    // 현재 단계 버블(덧셈 첫걸음의 '1' — 트리상 마지막 '1')을 연다
    await tester.tap(find.text('1').last);
    await tester.pumpAndSettle();

    String expr() => tester.widget<Text>(find.textContaining('= ?')).data!;
    int answerOf(String e) {
      final m = RegExp(r'(\d+) ([+-]) (\d+)').firstMatch(e)!;
      final a = int.parse(m.group(1)!);
      final b = int.parse(m.group(3)!);
      return m.group(2) == '+' ? a + b : a - b;
    }

    Future<void> solveRound() async {
      for (var i = 0; i < 10; i++) {
        final ans = answerOf(expr());
        await tester.ensureVisible(find.text('$ans').last);
        await tester.pumpAndSettle();
        await tester.tap(find.text('$ans').last);
        await tester.pumpAndSettle();
        // 정답 → 자동 진행 대신 계속하기/다음 버튼
        final cont = find.text('계속하기');
        if (cont.evaluate().isNotEmpty) {
          await tester.tap(cont);
          await tester.pumpAndSettle();
        }
      }
    }

    await solveRound();
    expect(find.text('다음 단계'), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    var stars = prefs.getStringList('level_stars_v4')!;
    expect(int.parse(stars[50]), greaterThanOrEqualTo(1), reason: '51단계 저장');

    await scrollAndTap(tester, find.text('다음 단계'));
    await solveRound();

    stars = prefs.getStringList('level_stars_v4')!;
    expect(int.parse(stars[51]), greaterThanOrEqualTo(1),
        reason: '다음 단계로 이어 깬 52단계도 저장돼야 한다');
  });
}
