import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/main.dart';
import 'package:preschool_math/theme.dart';
import 'package:preschool_math/models/wrong_notes.dart';
import 'package:preschool_math/widgets/quokka_avatar.dart';
import 'package:preschool_math/models/english_data.dart';
import 'package:preschool_math/models/japanese_pack.dart';
import 'package:preschool_math/models/korean_data.dart';
import 'package:preschool_math/models/pet.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/services/sounds.dart';
import 'package:preschool_math/services/speech.dart';
import 'package:preschool_math/services/voice_input.dart';
import 'package:shared_preferences/shared_preferences.dart';


/// 부모 게이트: 한글로 쓴 세 자리 수를 읽고 키패드로 입력해 통과한다.
Future<void> passParentGate(WidgetTester tester) async {
  final hangul =
      tester.widget<Text>(find.byKey(const ValueKey('gate-question'))).data!;
  const words = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];
  int digitBefore(String marker) {
    final idx = hangul.indexOf(marker);
    if (idx == 0) return 1; // "백십…"처럼 1은 생략 표기
    final w = hangul.substring(idx - 1, idx);
    final d = words.indexOf(w);
    return d > 0 ? d : 1;
  }

  final ones = words.indexOf(hangul.substring(hangul.length - 1));
  final answer = digitBefore('백') * 100 + digitBefore('십') * 10 + ones;
  for (final ch in '$answer'.split('')) {
    await tester.ensureVisible(find.byKey(ValueKey('gate-$ch')));
    await tester.tap(find.byKey(ValueKey('gate-$ch')));
    await tester.pump();
  }
  await tester.ensureVisible(find.byKey(const ValueKey('gate-ok')));
  await tester.tap(find.byKey(const ValueKey('gate-ok')));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    AppMotion.loops = false; // pumpAndSettle이 끝나도록 반복 애니메이션 정지
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
    Sounds.enabled = true;
    Speech.enabled = true;
    Speech.rate = Speech.rateNormal;
    // 마이크는 플랫폼 채널이라 테스트에서 건드리면 멈춘다.
    VoiceInput.enabled = false;
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

    expect(find.text('쿼카 학교'), findsOneWidget);
    expect(find.text('자유 연습'), findsOneWidget);
    // 놀이판 6칸 (오늘 줄 + 모으기 줄)
    for (final tile in ['오늘의 미션', '주간 보스전', '오답 노트', '꾸미기 가게', '스티커북', '배지 도감']) {
      expect(find.bySemanticsLabel(tile), findsOneWidget, reason: tile);
    }

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
    expect(find.text('1').first, findsOneWidget);
    // 잠긴 단계는 자물쇠 대신 조용한 점선 원으로 보인다.
    expect(find.text('🔒'), findsNothing);

    await scrollAndTap(tester, find.text('1').first);
    expect(find.bySemanticsLabel(RegExp('수 세기 첫걸음 · 1단계')), findsOneWidget);
    expect(find.text('몇 개일까요?'), findsOneWidget); // 4살 첫 단계는 수 세기
    expect(find.text('🪙 0'), findsOneWidget);
  });

  testWidgets('잠긴 단계 원을 누르면 그림+말로 반짝이는 원부터 하라고 알려 준다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('4살'));
    await tester.tap(find.bySemanticsLabel('2단계 (아직 잠김)').first);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('반짝이는 동그라미부터 해요!'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('반짝이는 동그라미부터 해요!'), findsNothing);
  });

  testWidgets('통과한 기록이 있으면 다음 단계가 열리고 점수가 보인다', (tester) async {
    // 일부러 예전 v2 키로 저장해서 마이그레이션도 함께 확인한다.
    SharedPreferences.setMockInitialValues({
      'level_stars_v2': ['3', '2'],
      'total_points_v1': 250,
    });

    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 1, 2단계 통과 → 총 별 5개, 누적 점수 250점(병아리 칭호)
    expect(find.text('⭐ 5'), findsOneWidget);
    expect(find.text('🪙 250'), findsOneWidget);
    // 칭호는 띠 — 배지 도감 맨 위에서 본다 (250점 = 노랑 띠)
    await tester.tap(find.bySemanticsLabel('배지 도감'));
    await tester.pumpAndSettle();
    expect(find.text('지금 나는 노랑 띠!'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('4살'));
    expect(find.text('3').first, findsOneWidget);
    await scrollAndTap(tester, find.text('3').first);

    expect(find.bySemanticsLabel(RegExp('· 3단계')), findsOneWidget);
  });

  testWidgets('초등 2학년 곱셈 카테고리는 바로 시작할 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({'family_pass_v1': true});
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('초등 2학년'));

    // 첫 묶음(두 자리 덧셈)이 보이고, 스크롤하면 곱셈 묶음도 있다.
    expect(find.text('두 자리 덧셈'), findsOneWidget);
    await tester.dragUntilVisible(
      find.textContaining('곱셈 첫걸음'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    expect(find.textContaining('곱셈 첫걸음'), findsOneWidget);
  });

  testWidgets('퀴즈 도중 나가려면 확인 팝업을 거친다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 4살 → 1단계 입장, 아무것도 안 풀었으면 X로 바로 나간다.
    await scrollAndTap(tester, find.text('4살'));
    await scrollAndTap(tester, find.text('1').first);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.textContaining('몇 개일까요?'), findsNothing); // 지도로 돌아옴

    // 다시 들어가서 한 문제를 풀면, X를 눌렀을 때 확인 팝업이 뜬다.
    await scrollAndTap(tester, find.text('1').first);
    final choice = find.byWidgetPredicate(
      (w) => w is Text && RegExp(r'^\d+$').hasMatch(w.data ?? ''),
    );
    await tester.tap(choice.first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('정말 그만할까요?'), findsOneWidget);

    // '계속 풀기'를 누르면 퀴즈로 돌아온다.
    await tester.tap(find.text('계속 풀기'));
    await tester.pumpAndSettle();
    expect(find.text('정말 그만할까요?'), findsNothing);

    // 다시 X → '그만하기'를 누르면 지도로 나간다.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    await tester.tap(find.text('🏠 그만하기'));
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
    expect(find.textContaining('괜찮아요'), findsOneWidget);
    await tester.tap(find.text('계속하기'));
    await tester.pumpAndSettle();

    // 나머지 9문제는 전부 맞힌다. (정답이면 2초 뒤 자동으로 다음 문제로)
    for (var i = 0; i < 9; i++) {
      await answer(correct: true);
    }

    // 11번째로 틀렸던 문제가 다시 나온다.
    expect(find.text('🔁 한 번 더!'), findsOneWidget);
    expect(expr(), wrongExpr);

    // 다시 맞히면 +5점 보너스, 별점은 첫 시도 기준(9/10)
    final retryAns = answerOf(expr());
    await tester.ensureVisible(find.text('$retryAns'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('$retryAns'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('+5 🪙'), findsOneWidget);
    // 2초 막대가 다 줄면 자동으로 결과 화면으로 넘어간다.
    await tester.pumpAndSettle();
    expect(find.text('10문제 중에 9문제를 맞혔어요!'), findsOneWidget);

    // 틀렸던 연산 문제는 오답 노트에 담기고, 결과 화면이 복습을 권한다.
    expect(await WrongNoteStore.count(), 1);
    await tester.pumpAndSettle();
    expect(find.textContaining('틀렸던 문제'), findsOneWidget);
  });

  testWidgets('세로 덧셈: 키패드로 일의 자리부터 채워서 맞힌다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 자유 연습 → 세로 덧셈 모드 → 시작
    await scrollAndTap(tester, find.text('자유 연습'));
    await scrollAndTap(tester, find.text('세로 덧셈'));
    await scrollAndTap(tester, find.text('시작하기'));

    // 세로로 늘어선 숫자 칸(fontSize 34)에서 두 수를 읽는다.
    final cells = tester
        .widgetList<Text>(
            find.byWidgetPredicate((w) => w is Text && w.style?.fontSize == 34))
        .map((t) => t.data ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
    final opIndex = cells.indexWhere((s) => s == '+' || s == '−');
    final top = int.parse(cells.sublist(0, opIndex).join());
    final bottom = int.parse(cells.sublist(opIndex + 1).join());
    final answer = top + bottom;

    // 키패드(fontSize 24)로 일의 자리부터 입력한다.
    for (final ch in '$answer'.split('').reversed) {
      final keyFinder = find.byWidgetPredicate(
        (w) => w is Text && w.data == ch && w.style?.fontSize == 24,
      );
      await tester.ensureVisible(keyFinder);
      await tester.pumpAndSettle();
      await tester.tap(keyFinder);
      await tester.pump(const Duration(milliseconds: 300));
    }

    // 다 채우면 자동 채점되어 정답 피드백이 뜬다.
    expect(find.text('정답이에요! 🎉'), findsOneWidget);
    expect(find.text('계속하기'), findsOneWidget);
  });

  testWidgets('한글 탭으로 바꾸면 한글 카테고리가 보이고, 낱말→그림 퀴즈를 풀 수 있다',
      (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 헤더의 한글 과목 버튼을 누른다.
    await tester.tap(find.byKey(const ValueKey('subject-picker')));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.byKey(const ValueKey('subject-1')));
    expect(find.text('한글 첫걸음'), findsOneWidget);

    // 첫 카테고리 → 1단계 (낱말 보고 그림 찾기)
    await scrollAndTap(tester, find.text('한글 첫걸음'));
    expect(find.text('낱말 보고 그림 찾기'), findsOneWidget);
    await scrollAndTap(tester, find.text('1').first);
    expect(find.text('알맞은 그림을 찾아요'), findsOneWidget);

    // 카드에 크게 보이는 낱말(fontSize 40)을 읽고 짝이 되는 그림을 누른다.
    final wordText = tester
        .widgetList<Text>(find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontSize == 40))
        .first
        .data!;
    final answerEmoji =
        krWords2.firstWhere((w) => w.word == wordText).emoji;
    await tester.tap(find.text(answerEmoji));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('정답이에요! 🎉'), findsOneWidget);
    expect(find.text('계속하기'), findsOneWidget);
  });

  testWidgets('첫 실행: 어른 화면 한 장 → 건네주기 → 알 → 톡톡 부화 → 선물·첫 밥 → 첫 판 → 홈',
      (tester) async {
    await tester.pumpWidget(const PreschoolMathApp(showOnboarding: true));
    await tester.pumpAndSettle();

    // ① 어른 화면 한 장: 이름·얼굴·나이·소리
    await tester.enterText(find.byType(TextField), '하늘');
    await scrollAndTap(tester, find.text('🦊'));
    await scrollAndTap(tester, find.textContaining('4살'));
    await scrollAndTap(tester, find.byKey(const ValueKey('handoff-go')));

    // ② 건네주기 → 아무 데나 누르면 아이 구간
    expect(find.text('화면을 눌러 봐!'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('handoff')));
    await tester.pumpAndSettle();

    // ③ 알 고르기 → 톡톡 세 번
    expect(find.text('쿼카 박사'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('egg-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('pick-0')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byKey(const ValueKey('egg-tap')));
      await tester.pumpAndSettle();
    }
    expect((await PetStore.load()).chosen, isTrue);

    // ④ 선물 → 첫 밥 (코인 0이어도 첫 밥을 줄 수 있다)
    await tester.tap(find.byKey(const ValueKey('gift')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('first-feed')));
    await tester.pumpAndSettle();
    expect((await PetStore.load()).meals, 1);

    // ⑤ 첫 문제로 바로
    await tester.tap(find.byKey(const ValueKey('hatch-done')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('· 1단계')), findsOneWidget);

    // 그만하고 홈으로: 바뀐 프로필·나이 추천·물 주기 안내
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('쿼카 학교'), findsOneWidget);
    expect(find.text('🦊'), findsOneWidget); // 헤더 프로필 아바타
    expect(find.textContaining('목말라요'), findsOneWidget);
    await tester.ensureVisible(find.text('👍 추천'));
    expect(find.text('👍 추천'), findsOneWidget);
    expect(Sounds.enabled, isTrue);
  });

  testWidgets('소리를 끈 채 듣고 풀기에 들어가면 안내 팝업이 뜬다', (tester) async {
    Speech.enabled = false;

    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('자유 연습'));
    await scrollAndTap(tester, find.text('듣고 풀기'));
    await scrollAndTap(tester, find.text('시작하기'));

    expect(find.text('소리를 켜 볼까요?'), findsOneWidget);

    // 소리를 켜면 퀴즈가 시작된다.
    await tester.tap(find.text('소리 켜고 시작'));
    await tester.pumpAndSettle();
    expect(Speech.enabled, isTrue);
    // 듣고 풀기는 문제 자체가 커다란 듣기 버튼이다.
    expect(find.bySemanticsLabel('다시 듣기'), findsOneWidget);
  });

  testWidgets('자유 연습에서 한글 유형을 고를 수 있다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('자유 연습'));
    await scrollAndTap(tester, find.text('한글'));
    await scrollAndTap(tester, find.text('그림 보고 낱말 찾기'));
    await scrollAndTap(tester, find.text('시작하기'));

    expect(find.text('그림에 맞는 낱말은?'), findsOneWidget);
  });

  testWidgets('어려워한 유형이 있으면 홈에 맞춤 복습 카드가 뜨고 바로 풀 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'stats_sub_correct_v1': 3,
      'stats_sub_wrong_v1': 7, // 뺄셈 30% → 복습 제안
    });
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.text('수학 ➖ 뺄셈 · 조금 어려웠죠? 한 판 더!'), findsOneWidget);
    await scrollAndTap(tester, find.text('맞춤 복습'));

    // 뺄셈 연습 한 판이 바로 열린다.
    expect(find.text('🪙 0'), findsOneWidget);
    expect(find.text('맞춤 복습'), findsNothing);
  });

  testWidgets('충분히 풀지 않았으면 맞춤 복습 카드가 없다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.text('맞춤 복습'), findsNothing);
  });

  testWidgets('설정에서 읽어주기는 부모 확인 뒤에만 꺼지고, 말 빠르기를 바꾼다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    // 글을 못 읽는 아이에게 읽어주기는 생명줄 — 아이 혼자 끄지 못한다.
    await tester.tap(find.text('문제 읽어주기'));
    await tester.pumpAndSettle();
    expect(find.text('부모님 확인'), findsOneWidget);
    await passParentGate(tester);
    expect(Speech.enabled, isFalse);
    expect(Sounds.enabled, isTrue); // 효과음은 그대로

    await tester.tap(find.text('천천히'));
    await tester.pumpAndSettle();
    expect(Speech.rate, Speech.rateSlow);
  });

  testWidgets('효과음 끄기도 부모 확인 뒤에, 한 번 통과하면 그 화면에선 다시 묻지 않는다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('설정'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('효과음'));
    await tester.pumpAndSettle();
    expect(find.text('부모님 확인'), findsOneWidget);
    await passParentGate(tester);
    expect(Sounds.enabled, isFalse);

    // 같은 화면에서 읽어주기를 꺼도 다시 묻지 않는다
    await tester.tap(find.text('문제 읽어주기'));
    await tester.pumpAndSettle();
    expect(find.text('부모님 확인'), findsNothing);
    expect(Speech.enabled, isFalse);
  });

  testWidgets('홈에는 읽어주기를 끄는 소리 버튼이 없고, 🔊는 인사를 들려준다', (tester) async {
    final spoken = <String>[];
    Speech.debugOnSpeak = spoken.add;
    addTearDown(() => Speech.debugOnSpeak = null);
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.volume_off_rounded), findsNothing);
    // 파란 🔊는 끄기가 아니라 "듣기" — 눌러도 읽어주기는 켜진 그대로다.
    spoken.clear();
    await tester.tap(find.bySemanticsLabel('다시 듣기'));
    await tester.pump();
    expect(spoken, isNotEmpty);
    expect(Speech.enabled, isTrue);
  });

  testWidgets('읽어주기가 꺼져 있어도 아이가 🔊를 누르면 들린다', (tester) async {
    Speech.enabled = false;
    final spoken = <String>[];
    Speech.debugOnSpeak = spoken.add;
    addTearDown(() => Speech.debugOnSpeak = null);
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick-start')));
    await tester.pumpAndSettle();
    expect(spoken, isEmpty); // 자동 읽기는 꺼진 그대로
    await tester.tap(find.byIcon(Icons.volume_up_rounded).first);
    await tester.pump();
    expect(spoken, isNotEmpty);
  });

  testWidgets('홈의 바로 시작 버튼은 다음에 풀 단계를 바로 연다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'level_stars_v5': ['3', '2'],
    });
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('quick-start')));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel(RegExp('· 3단계')), findsOneWidget);
  });

  testWidgets('이용권이 없으면 고른 나이가 잠겨 있어도 바로 시작은 열린 곳으로 간다',
      (tester) async {
    SharedPreferences.setMockInitialValues({'age_category_v1': 3});
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 고른 나이(7살)가 잠겨 있으면 추천 표시를 붙이지 않는다 (8살에게 '4살 추천'도 이상하다).
    expect(find.text('👍 추천'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('quick-start')));
    await tester.pumpAndSettle();
    expect(find.text('부모님 확인'), findsNothing);
    expect(find.bySemanticsLabel(RegExp('· 1단계')), findsOneWidget);
  });

  testWidgets('주간 보스전에 들어가면 보스전 라벨과 문제가 보인다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('주간 보스전'));

    expect(find.text('👑'), findsOneWidget);
    // 문제 진행 바와 점수 표시가 있는 퀴즈 화면이다.
    expect(find.text('🪙 0'), findsOneWidget);

    // 시작 전이면 X로 바로 나온다.
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('주간 보스전'), findsOneWidget);
  });

  testWidgets('자유 연습에서 낱말 만들기(타일 조립) 화면이 열린다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('자유 연습'));
    await scrollAndTap(tester, find.text('한글'));
    await scrollAndTap(tester, find.text('낱말 만들기'));
    await scrollAndTap(tester, find.text('시작하기'));

    expect(find.text('글자를 순서대로 눌러 낱말을 만들어요'), findsOneWidget);
    expect(find.byIcon(Icons.backspace_rounded), findsOneWidget);
  });

  testWidgets('리포트는 설정의 부모님 메뉴에서 게이트를 풀어야 열린다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('학습 리포트'));

    expect(find.text('부모님 확인'), findsOneWidget);

    // 문제를 읽고 키패드로 정답을 입력하면 리포트가 열린다.
    await passParentGate(tester);

    expect(find.text('학습 리포트'), findsOneWidget);
    // 아직 아무것도 안 풀었으면 과목별 빈 카드 5장 대신 안내 1장으로 접힌다.
    await tester.dragUntilVisible(
      find.text('과목별 정답률'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    expect(find.textContaining('첫 퀴즈를 풀면'), findsOneWidget);
  });

  testWidgets('착용한 아이템이 꾸미기 가게의 쿼카에 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'owned_items_v1': ['ribbon', 'glasses', 'grass'],
      'equipped_items_v1': ['ribbon', 'glasses', 'grass'],
    });

    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();
    // 홈은 이제 친구(펫) 자리라, 꾸민 쿼카는 가게에서 본다.
    await scrollAndTap(tester, find.text('꾸미기 가게'));
    await tester.pumpAndSettle();

    // 쿼카 마스코트 + 리본(머리)·안경(얼굴)은 도트 그림, 풀밭(배경)은 이모지
    expect(find.byType(QuokkaAvatar), findsOneWidget);
    Finder itemImage(String id) => find.byWidgetPredicate((w) =>
        w is Image &&
        w.image is AssetImage &&
        (w.image as AssetImage).assetName == 'assets/images/items/$id.png');
    expect(itemImage('ribbon'), findsOneWidget);
    expect(itemImage('glasses'), findsOneWidget);
    expect(find.text('🌿'), findsOneWidget);
  });

  testWidgets('영어 탭에서 낱말 듣고 그림 찾기 퀴즈를 풀 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({'family_pass_v1': true});
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('subject-picker')));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.byKey(const ValueKey('subject-2')));
    expect(find.text('알파벳 첫걸음'), findsOneWidget);

    // 영어 낱말 카테고리 → 첫 단계 (낱말 듣고 그림 찾기)
    await scrollAndTap(tester, find.text('영어 낱말'));
    expect(find.text('낱말 듣고 그림 찾기'), findsOneWidget);
    await scrollAndTap(tester, find.text('1').first); // 카테고리 첫 단계
    expect(find.text('잘 듣고 알맞은 그림을 찾아요'), findsOneWidget);

    // 카드에 크게 보이는 영어 낱말로 정답 그림을 찾아 누른다.
    final wordText = tester
        .widgetList<Text>(find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontSize == 40))
        .first
        .data!;
    final answerEmoji =
        enAllWords.firstWhere((w) => w.shown == wordText).emoji;
    await tester.tap(find.text(answerEmoji));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('정답이에요! 🎉'), findsOneWidget);
  });

  testWidgets('일본어 탭에서 그림→낱말 퀴즈를 풀 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({'family_pass_v1': true});
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('subject-picker')));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.byKey(const ValueKey('subject-3')));
    expect(find.text('かな 첫걸음'), findsOneWidget);

    await scrollAndTap(tester, find.text('일본어 낱말'));
    await scrollAndTap(tester, find.text('1').first); // 낱말 듣고 그림 찾기 첫 단계
    expect(find.text('잘 듣고 알맞은 그림을 찾아요'), findsOneWidget);

    // 카드에 보이는 히라가나 낱말로 정답 그림을 찾아 누른다.
    final wordText = tester
        .widgetList<Text>(find.byWidgetPredicate(
            (w) => w is Text && w.style?.fontSize == 40))
        .first
        .data!;
    final answerEmoji =
        jaWords.firstWhere((w) => w.word == wordText).emoji;
    await tester.tap(find.text(answerEmoji));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('정답이에요! 🎉'), findsOneWidget);
  });

  testWidgets('홈에서 바로 친구에게 밥을 줄 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pet_species_v1': 'leaf',
      'coins_v1': 500,
    });
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 홈 본문에 친구가 있고, 따로 들어가지 않아도 돌볼 수 있다.
    expect(find.byKey(const ValueKey('home-pet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-feed')));
    await tester.pumpAndSettle();

    expect((await PetStore.load()).meals, 1);
  });

  testWidgets('조건을 채웠으면 친구 방에 안 들어가도 홈에서 자란다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'pet_species_v1': 'leaf',
      'pet_stage_v1': 1,
      'pet_meals_v1': 5,
      'pet_drinks_v1': 5,
      'level_stars_v5': ['3', '3', '3', '3'], // 별 12개 (10개 필요)
    });
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('자랐어요'), findsOneWidget);
    expect((await PetStore.load()).stage, 2);
    await tester.tap(find.byKey(const ValueKey('evolve-ok')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('evolve-ok')), findsNothing);
  });

  testWidgets('어른 과정(영어회화)은 과목 시트에서 부모 확인을 거쳐야 고른다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('subject-picker')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('subject-6')));
    await tester.tap(find.byKey(const ValueKey('subject-6')));
    await tester.pumpAndSettle();
    expect(find.text('부모님 확인'), findsOneWidget);
  });

  testWidgets('놀이판의 오늘의 미션을 누르면 미션 시트가 열린다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('오늘의 미션'));
    await tester.pumpAndSettle();
    expect(find.text('▶▶▶'), findsOneWidget); // 미션은 그림으로 ('퀴즈 3판')
  });

  testWidgets('어른이 영어회화를 공부해도 아이 친구 별은 늘지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'lang_enconv_stars_v1': ['3', '3', '3', '3', '3'],
    });
    expect(await PetStore.totalStars(), 0);
  });

  testWidgets('친구가 없으면 홈에서 만나러 갈 수 있다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('pet-meet')));
    await tester.pumpAndSettle();

    expect(find.text('쿼카 박사'), findsOneWidget);
    expect(find.byKey(const ValueKey('egg-0')), findsOneWidget);
  });

  testWidgets('자유 연습에서 중국어 숫자 한자를 연습할 수 있다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('자유 연습'));
    await scrollAndTap(tester, find.text('중국어'));
    await scrollAndTap(tester, find.text('숫자 한자 찾기'));
    await scrollAndTap(tester, find.text('시작하기'));

    expect(find.text('숫자에 맞는 한자는?'), findsOneWidget);
  });

  testWidgets('이용권이 없으면 두 번째 카테고리는 부모 확인 → 이용권 안내로 간다',
      (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 5살(두 번째 카테고리)은 잠겨 있다 → 아이에게는 그림 안내가 먼저 뜬다.
    await scrollAndTap(tester, find.text('5살'));
    expect(find.text('어른이랑 같이 열어요'), findsOneWidget);
    expect(find.text('부모님 확인'), findsNothing);

    // 큰 초록 버튼은 아이가 계속 노는 쪽 — 닫힌다.
    await tester.tap(find.byKey(const ValueKey('locked-back')));
    await tester.pumpAndSettle();
    expect(find.text('어른이랑 같이 열어요'), findsNothing);

    // 어른 버튼 → 부모 게이트 (같은 카드 연타 방지 시간이 지나도록 실제로 기다린다)
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 450)));
    await scrollAndTap(tester, find.text('5살'));
    await tester.tap(find.byKey(const ValueKey('locked-grownup')));
    await tester.pumpAndSettle();
    expect(find.text('부모님 확인'), findsOneWidget);

    // 곱셈 문제를 키패드로 풀면 이용권 화면이 열린다.
    await passParentGate(tester);

    expect(find.text('가족 이용권'), findsOneWidget);
    expect(find.textContaining('한 번 결제로'), findsWidgets);
  });

  testWidgets('이용권이 있으면 모든 카테고리에 바로 들어간다', (tester) async {
    SharedPreferences.setMockInitialValues({'family_pass_v1': true});
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('5살'));
    expect(find.text('부모님 확인'), findsNothing);
    expect(find.text('10까지 세기'), findsOneWidget);
  });

  testWidgets('프로필이 여럿이면 넷플릭스처럼 프로필 선택부터 시작한다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'profiles_v1': ['1|🐣|하늘', '2|🦊|바다'],
      'family_pass_v1': true,
    });

    await tester.pumpWidget(const PreschoolMathApp(showProfilePicker: true));
    await tester.pumpAndSettle();

    expect(find.text('누가 배울까요?'), findsOneWidget);
    expect(find.text('하늘'), findsOneWidget);
    expect(find.text('바다'), findsOneWidget);

    // 바다를 고르면 바다의 홈으로 들어간다.
    await scrollAndTap(tester, find.text('바다'));
    expect(find.text('쿼카 학교'), findsOneWidget);
    expect(find.text('🦊'), findsOneWidget); // 헤더 프로필 아바타
    expect(find.textContaining('바다,'), findsOneWidget); // 인사말에 이름
    expect(Profiles.activeId, 2);
  });

  testWidgets('이용권이 없으면 두 번째 프로필 만들기는 잠겨 있다', (tester) async {
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 홈 → 프로필 화면 (헤더의 프로필 칩)
    await tester.tap(find.byKey(const ValueKey('profile-chip')));
    await tester.pumpAndSettle();

    expect(find.text('새 프로필 만들기'), findsOneWidget);

    // 누르면 부모 게이트가 먼저 뜬다.
    await scrollAndTap(tester, find.text('새 프로필 만들기'));
    expect(find.text('부모님 확인'), findsOneWidget);
  });

  testWidgets('꾸미기 가게에서 코인으로 아이템을 산다', (tester) async {
    SharedPreferences.setMockInitialValues({'coins_v1': 100});

    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await scrollAndTap(tester, find.text('꾸미기 가게'));

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
    expect(find.textContaining('코인이 모자라요'), findsOneWidget);

    // 남은 스낵바 타이머를 흘려보낸다.
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
  });

  testWidgets('나이가 7살이면 이전 나이 카테고리가 접기 카드로 접힌다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'family_pass_v1': true,
      'age_category_v1': 3, // 7살
    });
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    // 4~6살 카드 대신 접기 카드 한 장, 추천 배지는 7살에
    expect(find.text('이전 단계 3개'), findsOneWidget);
    expect(find.text('4살'), findsNothing);
    expect(find.text('6살'), findsNothing);
    expect(find.text('7살'), findsOneWidget);
    expect(find.text('👍 추천'), findsOneWidget);

    // 펼치면 이전 카드가 보이고, 다시 탭하면 접힌다
    await scrollAndTap(tester, find.text('이전 단계 3개'));
    expect(find.text('이전 단계 접기'), findsOneWidget);
    expect(find.text('4살'), findsOneWidget);
    await scrollAndTap(tester, find.text('이전 단계 접기'));
    expect(find.text('4살'), findsNothing);
  });

  testWidgets('나이가 4살이면 접을 게 없어 접기 카드가 안 나온다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'family_pass_v1': true,
      'age_category_v1': 0,
    });
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('이전 단계'), findsNothing);
    expect(find.text('4살'), findsOneWidget);
  });

  testWidgets('나이를 안 골랐으면 접지 않는다', (tester) async {
    SharedPreferences.setMockInitialValues({'family_pass_v1': true});
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('이전 단계'), findsNothing);
    expect(find.text('4살'), findsOneWidget);
  });

  testWidgets('이용권이 없으면 나이가 있어도 접지 않는다', (tester) async {
    // 무료 카테고리(4살)가 유일하게 열린 곳이라 접으면 놀 데가 없다.
    SharedPreferences.setMockInitialValues({'age_category_v1': 3});
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    expect(find.textContaining('이전 단계'), findsNothing);
    expect(find.text('4살'), findsOneWidget);
  });

  testWidgets('설정 > 우리 아이 단계에서 접기를 끄면 모든 단계가 보인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'family_pass_v1': true,
      'age_category_v1': 3,
    });
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();
    expect(find.text('4살'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('우리 아이 단계'));
    await passParentGate(tester);
    expect(find.text('우리 아이 단계 맞추기'), findsOneWidget);

    // 이전 단계 접어두기 끄기 → 시트 닫기 → 설정에서 홈으로
    await tester.tap(find.text('이전 단계 접어두기'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('완료')); // 시트 닫기
    await tester.pumpAndSettle();
    expect(find.text('우리 아이 단계 맞추기'), findsNothing); // 시트 닫힘
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('쿼카 학교'), findsOneWidget); // 홈으로 복귀

    expect(find.textContaining('이전 단계'), findsNothing);
    expect(find.text('4살'), findsOneWidget);
  });

  testWidgets('새 프로필을 만들 때 나이를 고르면 그 프로필에 저장된다', (tester) async {
    SharedPreferences.setMockInitialValues({'family_pass_v1': true});
    await tester.pumpWidget(const PreschoolMathApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('profile-chip')));
    await tester.pumpAndSettle();
    await scrollAndTap(tester, find.text('새 프로필 만들기'));

    await tester.enterText(find.byType(TextField), '바다');
    await scrollAndTap(tester, find.text('6살'));
    await scrollAndTap(tester, find.text('만들기'));

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('p2_age_category_v1'), 2); // 6살 = 인덱스 2
    expect(Profiles.activeId, 2); // 만든 프로필로 바로 전환
    // 새 아이도 알 고르기부터 (첫 실행과 같은 길)
    expect(find.text('쿼카 박사'), findsOneWidget);
  });
}
