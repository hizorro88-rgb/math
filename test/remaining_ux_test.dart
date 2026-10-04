import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/question.dart';
import 'package:preschool_math/models/quiz_config.dart';
import 'package:preschool_math/screens/pass_screen.dart';
import 'package:preschool_math/services/speech.dart';
import 'package:preschool_math/theme.dart';
import 'package:preschool_math/widgets/selectable_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AppMotion.loops = false;
    SharedPreferences.setMockInitialValues({});
    Speech.enabled = true;
  });

  test('문제 그림에는 앱에서 따로 뜻이 있는 그림(친구·얼굴·별·선물)을 쓰지 않는다', () {
    const reserved = {'🐸', '🐳', '🐱', '🐬', '⭐', '🎁'};
    for (var seed = 0; seed < 60; seed++) {
      final generator = QuestionGenerator(random: Random(seed));
      final questions = generator
          .generate(const QuizConfig(mode: QuizMode.counting, maxNumber: 5));
      for (final q in questions) {
        expect(reserved.contains(q.emoji), isFalse, reason: q.emoji);
      }
    }
  });

  test('세로 덧셈 그림은 수학 과목 그림(🧮)과 겹치지 않는다', () {
    expect(QuizMode.verticalAdd.emoji, isNot('🧮'));
  });

  testWidgets('작은 고르는 칸: 고르면 ✓가 붙는다', (tester) async {
    var picked = false;
    await tester.pumpWidget(MaterialApp(
      home: StatefulBuilder(
        builder: (context, setState) => Scaffold(
          body: Center(
            child: SelectableChip(
              selected: picked,
              onTap: () => setState(() => picked = true),
              child: const Text('🦊'),
            ),
          ),
        ),
      ),
    ));
    expect(find.byIcon(Icons.check_rounded), findsNothing);
    await tester.tap(find.text('🦊'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.check_rounded), findsOneWidget);
  });

  testWidgets('이용권: 무료·이용권 비교가 보이고, 스토어가 없으면 구매 버튼이 꺼져 있다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: PassScreen()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('pass-compare')), findsOneWidget);
    expect(find.text('무료'), findsOneWidget);
    expect(find.text('이용권'), findsOneWidget);

    await tester.ensureVisible(find.byKey(const ValueKey('pass-buy')));
    await tester.tap(find.byKey(const ValueKey('pass-buy')));
    await tester.pumpAndSettle();
    // 꺼진 버튼은 눌러도 아무 안내도 뜨지 않는다.
    expect(find.byType(SnackBar), findsNothing);
  });
}
