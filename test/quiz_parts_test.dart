import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/services/speech.dart';
import 'package:preschool_math/widgets/quiz_parts.dart';

void main() {
  group('진행 점', () {
    test('틀린 문제를 다시 풀어도 점 수는 늘지 않고 그 점으로 돌아간다', () {
      final t = QuizDotTracker(3);
      t.record(0, correct: true, retry: false);
      t.record(1, correct: false, retry: false); // 1번이 뒤(목록 3번)에 다시 온다
      t.record(2, correct: true, retry: false);
      expect(t.dots.length, 3);
      expect(t.dots,
          [QuizDot.correct, QuizDot.missed, QuizDot.correct]);
      // 다시 나온 문제(목록 3번)는 원래 1번 점을 가리킨다.
      expect(t.dotFor(3), 1);
      t.record(3, correct: true, retry: true);
      expect(t.dots[1], QuizDot.fixed);
    });

    test('다시 풀어서 또 틀리면 점은 틀린 채로 남는다', () {
      final t = QuizDotTracker(2);
      t.record(0, correct: false, retry: false);
      t.record(1, correct: true, retry: false);
      t.record(2, correct: false, retry: true);
      expect(t.dots, [QuizDot.missed, QuizDot.correct]);
    });
  });

  group('퀴즈 목소리', () {
    late List<String> spoken;
    setUp(() {
      Speech.enabled = true;
      spoken = [];
      Speech.debugOnSpeak = spoken.add;
    });
    tearDown(() => Speech.debugOnSpeak = null);

    test('처음 나온 외국어 문제는 한국어 과제부터 읽는다', () {
      QuizVoice.question(
          task: '짝이 되는 소문자를 찾아요', speech: 'A', lang: 'en-US');
      expect(spoken.first, '짝이 되는 소문자를 찾아요');
    });

    test('다시 나온 문제는 "아까 그 문제"로 알려 준다', () {
      QuizVoice.question(task: '알맞은 그림을 찾아요', speech: '과자', retry: true);
      expect(spoken.first, '아까 그 문제예요!');
    });

    test('아이가 🔊를 누르면 소리만 바로 (읽어주기가 꺼져 있어도)', () {
      Speech.enabled = false;
      QuizVoice.question(
          task: '짝이 되는 소문자를 찾아요', speech: 'A', lang: 'en-US', force: true);
      expect(spoken, ['A']);
    });

    test('문장으로 된 음성은 과제를 겹쳐 읽지 않는다', () {
      QuizVoice.question(task: '몇 개일까요?', speech: '사과가 몇 개일까요?');
      expect(spoken.first, '사과가 몇 개일까요?');
    });
  });
}
