import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/review.dart';
import 'package:preschool_math/models/stats.dart';
import 'package:preschool_math/screens/report_screen.dart';
import 'package:preschool_math/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AppMotion.loops = false;
    Profiles.activeId = 1;
  });

  testWidgets('리포트 맨 위에 이번 주 할 일(잘한 것·연습할 것·바로 한 판)', (tester) async {
    SharedPreferences.setMockInitialValues({
      'stats_add_correct_v1': 9,
      'stats_add_wrong_v1': 1,
      'stats_sub_correct_v1': 2,
      'stats_sub_wrong_v1': 4,
    });
    await tester.pumpWidget(const MaterialApp(home: ReportScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('이번 주 할 일'), findsOneWidget);
    expect(find.textContaining('덧셈 90%'), findsOneWidget);
    expect(find.textContaining('뺄셈 33%'), findsOneWidget);
    expect(find.byKey(const ValueKey('report-practice')), findsOneWidget);
  });

  test('잘하는 유형은 5문제 이상 푼 것 중 정답률이 가장 높은 것', () async {
    SharedPreferences.setMockInitialValues({
      'stats_add_correct_v1': 9,
      'stats_add_wrong_v1': 1,
      'stats_mul_correct_v1': 2, // 2문제뿐이라 제외
    });
    final best = Review.strongest(await StatsStore.load());
    expect(best?.label, '덧셈');
  });
}
