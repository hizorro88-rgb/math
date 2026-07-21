import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('학습 지도가 뜨고 1단계만 열려 있다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.text('수학 놀이'), findsOneWidget);
    expect(find.text('자유 연습'), findsOneWidget);
    expect(find.textContaining('덧셈 첫걸음'), findsOneWidget);

    // 점수 0점이면 칭호는 알
    expect(find.text('지금 나는 알!'), findsOneWidget);

    // 1단계는 열려 있고, 잠긴 단계(🔒)도 보인다.
    expect(find.text('1'), findsOneWidget);
    expect(find.text('🔒'), findsWidgets);
  });

  testWidgets('1단계를 누르면 퀴즈가 시작된다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pumpAndSettle();

    expect(find.text('1단계'), findsOneWidget);
    expect(find.textContaining('= ?'), findsOneWidget);
    expect(find.text('🪙 0'), findsOneWidget);
  });

  testWidgets('통과한 기록이 있으면 다음 단계가 열리고 점수가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'level_stars_v1': ['3', '2'],
      'total_points_v1': 250,
    });

    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 1, 2단계 통과 → 총 별 5개, 누적 점수 250점(병아리 칭호)
    expect(find.text('⭐ 5'), findsOneWidget);
    expect(find.text('🪙 250'), findsOneWidget);
    expect(find.text('지금 나는 병아리!'), findsOneWidget);

    // 3단계가 열려 있다.
    expect(find.text('3'), findsOneWidget);
    await tester.tap(find.text('3'));
    await tester.pumpAndSettle();

    expect(find.text('3단계'), findsOneWidget);
    expect(find.textContaining('= ?'), findsOneWidget);
  });
}
