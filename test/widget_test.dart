import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/main.dart';

void main() {
  testWidgets('홈 화면이 뜨고 시작 버튼으로 퀴즈를 시작할 수 있다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());

    expect(find.text('수학 놀이'), findsOneWidget);
    expect(find.text('시작하기 🚀'), findsOneWidget);

    // 시작을 누르면 퀴즈 화면으로 넘어간다.
    await tester.tap(find.text('시작하기 🚀'));
    await tester.pumpAndSettle();

    expect(find.textContaining('= ?'), findsOneWidget);
  });
}
