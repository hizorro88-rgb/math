import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/japanese_pack.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/wrong_notes.dart';
import 'package:preschool_math/screens/wrong_notes_screen.dart';
import 'package:preschool_math/services/sounds.dart';
import 'package:shared_preferences/shared_preferences.dart';

WrongNote _note(String display, String answer, {String subject = 'kr'}) {
  return WrongNote(
    subject: subject,
    subjectEmoji: '📖',
    subjectName: '한글',
    instruction: '그림에 맞는 낱말은?',
    display: display,
    choices: [answer, '오리', '수박', '기차'],
    answer: answer,
    answerText: answer,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
    Sounds.enabled = true;
  });

  test('틀린 문제를 넣고, 같은 문제를 또 틀리면 횟수만 올라간다', () async {
    await WrongNoteStore.add(_note('🍎', '사과'));
    await WrongNoteStore.add(_note('🐱', '고양이'));
    await WrongNoteStore.add(_note('🍎', '사과'));

    final notes = await WrongNoteStore.load();
    expect(notes, hasLength(2));
    // 또 틀린 사과가 맨 뒤(최신)로 온다.
    expect(notes.last.display, '🍎');
    expect(notes.last.missCount, 2);
  });

  test('맞힌 문제는 지워지고, 최대 개수를 넘으면 오래된 것부터 밀려난다', () async {
    for (var i = 0; i < WrongNoteStore.maxNotes + 5; i++) {
      await WrongNoteStore.add(_note('그림$i', '답$i'));
    }
    var notes = await WrongNoteStore.load();
    expect(notes, hasLength(WrongNoteStore.maxNotes));
    expect(notes.first.display, '그림5'); // 0~4는 밀려남

    await WrongNoteStore.remove(notes.first.id);
    notes = await WrongNoteStore.load();
    expect(notes, hasLength(WrongNoteStore.maxNotes - 1));
    expect(notes.first.display, '그림6');
  });

  test('언어 팩 문제도 팩 정보(과목·발음 언어)와 함께 담긴다', () async {
    final q = japanesePack.generateOne(3, 0, Random(11));
    final note = WrongNote.fromLang(japanesePack, q);
    expect(note.subject, 'ja');
    expect(note.subjectName, '일본어');
    expect(note.speechLang, 'ja-JP');
    expect(note.answer, q.answer);
  });

  testWidgets('오답 노트에서 맞히면 노트에서 사라진다', (tester) async {
    await WrongNoteStore.add(_note('🍎', '사과'));
    await tester.pumpWidget(const MaterialApp(home: WrongNotesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('🍎'), findsOneWidget);
    await tester.tap(find.text('사과'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300)); // 자동 넘어가기
    await tester.pumpAndSettle();

    expect(find.text('1개 중 1개 통과!'), findsOneWidget);
    expect(await WrongNoteStore.count(), 0);
  });

  testWidgets('또 틀리면 노트에 남고 틀린 횟수가 올라간다', (tester) async {
    await WrongNoteStore.add(_note('🍎', '사과'));
    await tester.pumpWidget(const MaterialApp(home: WrongNotesScreen()));
    await tester.pumpAndSettle();

    await tester.tap(find.text('오리'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1300)); // 자동 넘어가기
    await tester.pumpAndSettle();

    expect(find.text('1개 중 0개 통과!'), findsOneWidget);
    final notes = await WrongNoteStore.load();
    expect(notes, hasLength(1));
    expect(notes.first.missCount, 2);
  });

  testWidgets('노트가 비어 있으면 축하 안내가 보인다', (tester) async {
    // 퀴즈를 풀어 본 사용자여야 "틀린 게 없다" 축하가 나온다.
    SharedPreferences.setMockInitialValues({
      'stats_add_correct_v1': 3,
    });
    await tester.pumpWidget(const MaterialApp(home: WrongNotesScreen()));
    await tester.pumpAndSettle();

    expect(find.text('오답 노트가 비었어요! 🎉'), findsOneWidget);
    expect(find.text('퀴즈 풀러 가기'), findsOneWidget);
  });
}
