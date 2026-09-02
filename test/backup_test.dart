import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/screens/backup_screen.dart';
import 'package:preschool_math/services/backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('백업 코드 왕복: 모든 타입이 그대로 복원된다', () async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done_v1': true,
      'coins_v1': 830,
      'total_points_v1': 1250,
      'streak_last_day_v1': '2026-08-30',
      'level_stars_v4': ['3', '2', '0'],
      'p2_coins_v1': 40,
    });
    final code = await BackupService.export();
    expect(code, startsWith('OWL1.'));

    // 다른 기기(빈 저장소)라고 가정하고 복원한다.
    SharedPreferences.setMockInitialValues({'coins_v1': 999});
    expect(await BackupService.restore(code), isTrue);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_done_v1'), isTrue);
    expect(prefs.getInt('coins_v1'), 830);
    expect(prefs.getInt('total_points_v1'), 1250);
    expect(prefs.getString('streak_last_day_v1'), '2026-08-30');
    expect(prefs.getStringList('level_stars_v4'), ['3', '2', '0']);
    expect(prefs.getInt('p2_coins_v1'), 40);
  });

  test('미리보기: 날짜·통과 단계·코인을 알려준다', () async {
    SharedPreferences.setMockInitialValues({
      'coins_v1': 100,
      'p2_coins_v1': 50,
      'level_stars_v4': ['3', '1', '0'],
      'lang_ja_stars_v1': ['2', '0'],
    });
    final code =
        await BackupService.export(now: DateTime(2026, 9, 2, 10, 30));
    final info = BackupService.peek(code);
    expect(info, isNotNull);
    expect(info!.savedAt, DateTime(2026, 9, 2, 10, 30));
    expect(info.clearedLevels, 3); // 수학 2 + 일본어 1
    expect(info.coins, 150);
  });

  test('망가진 코드는 거부한다', () async {
    SharedPreferences.setMockInitialValues({'coins_v1': 10});
    final code = await BackupService.export();

    expect(BackupService.peek('아무말'), isNull);
    expect(BackupService.peek(''), isNull);
    // 중간이 잘리면 검증 값이 어긋난다.
    final cut = code.substring(0, code.length ~/ 2);
    expect(BackupService.peek(cut), isNull);
    // 내용이 한 글자라도 바뀌면 거부한다.
    final tampered = code.replaceRange(10, 11, code[10] == 'A' ? 'B' : 'A');
    expect(BackupService.peek(tampered), isNull);
    expect(await BackupService.restore(tampered), isFalse);

    // 원본은 그대로 통과한다.
    expect(BackupService.peek(code), isNotNull);
  });

  test('복원하면 기존 기록은 지워지고 백업 내용만 남는다', () async {
    SharedPreferences.setMockInitialValues({'coins_v1': 77});
    final code = await BackupService.export();

    SharedPreferences.setMockInitialValues({
      'coins_v1': 5,
      'old_only_key': 'x',
    });
    await BackupService.restore(code);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('coins_v1'), 77);
    expect(prefs.containsKey('old_only_key'), isFalse);
  });

  test('앞뒤 공백이 붙어도 복원된다 (메신저 복사 대비)', () async {
    SharedPreferences.setMockInitialValues({'coins_v1': 12});
    final code = await BackupService.export();
    expect(BackupService.peek('  $code\n'), isNotNull);
    expect(await BackupService.restore(' $code '), isTrue);
  });

  testWidgets('백업 화면에서 코드를 만들면 화면에 나타난다', (tester) async {
    SharedPreferences.setMockInitialValues({'coins_v1': 42});
    await tester.pumpWidget(const MaterialApp(home: BackupScreen()));

    await tester.tap(find.text('백업 코드 만들고 복사하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('OWL1.'), findsWidgets);
  });

  testWidgets('잘못된 코드로 복원하면 오류 안내가 뜬다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: BackupScreen()));

    await tester.enterText(find.byType(TextField), '잘못된코드');
    await tester.pump();
    await tester.tap(find.text('✅ 복원하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('읽을 수 없어요'), findsOneWidget);
  });

  testWidgets('올바른 코드로 복원하면 확인 팝업 뒤 홈으로 돌아간다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'onboarding_done_v1': true,
      'coins_v1': 77,
      'level_stars_v4': ['3', '0'],
    });
    final code = await BackupService.export();

    SharedPreferences.setMockInitialValues({'onboarding_done_v1': true});
    await tester.pumpWidget(const MaterialApp(home: BackupScreen()));
    await tester.enterText(find.byType(TextField), code);
    await tester.pump();
    await tester.tap(find.text('✅ 복원하기'));
    await tester.pumpAndSettle();

    expect(find.text('이 백업으로 되돌릴까요?'), findsOneWidget);
    await tester.tap(find.text('복원하기'));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('coins_v1'), 77);
    // 홈(학습 지도)으로 돌아갔다.
    expect(find.byType(BackupScreen), findsNothing);
  });
}
