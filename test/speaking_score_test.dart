import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/services/voice_input.dart';

/// 음성 인식은 발음이 조금만 달라도 다른 낱말로 적힌다.
/// 너무 엄격하면 잘 말해도 계속 틀려서 포기하게 되므로,
/// 낱말이 얼마나 겹치는지로 느슨하게 채점하는지 확인한다.
void main() {
  group('말한 문장 낱말 쪼개기', () {
    test('대소문자·문장부호를 무시한다', () {
      expect(speakingWords('Nice to meet you.'), ['nice', 'to', 'meet', 'you']);
      expect(speakingWords('WHAT TIME IS IT?'), ['what', 'time', 'is', 'it']);
    });

    test('줄임말의 아포스트로피는 남긴다', () {
      expect(speakingWords("I'm full."), ["i'm", 'full']);
    });

    test('빈 문장은 빈 목록', () {
      expect(speakingWords(''), isEmpty);
      expect(speakingWords('...'), isEmpty);
    });
  });

  group('말하기 채점', () {
    test('그대로 말하면 만점이고 통과한다', () {
      final s = scoreSpeaking('Nice to meet you.', 'nice to meet you');
      expect(s.matched, 4);
      expect(s.total, 4);
      expect(s.perfect, isTrue);
      expect(s.passed, isTrue);
    });

    test('문장부호·대소문자가 달라도 만점이다', () {
      final s = scoreSpeaking('What time is it?', 'What time is it');
      expect(s.perfect, isTrue);
    });

    test('한 낱말을 잘못 들어도 통과한다 (느슨한 기준)', () {
      final s = scoreSpeaking('Can I get a coffee?', 'can I get a copy');
      expect(s.matched, 4);
      expect(s.total, 5);
      expect(s.perfect, isFalse);
      expect(s.passed, isTrue);
    });

    test('절반도 못 맞히면 통과하지 못한다', () {
      final s = scoreSpeaking('Where is the baggage claim?', 'where is it');
      expect(s.passed, isFalse);
      expect(s.ratio, lessThan(0.6));
    });

    test('아무 말도 안 하면 0점', () {
      final s = scoreSpeaking('See you tomorrow.', '');
      expect(s.matched, 0);
      expect(s.passed, isFalse);
    });

    test('두 낱말 이하 짧은 표현은 하나만 맞아도 통과한다', () {
      // 짧은 문장은 하나만 틀려도 비율이 확 떨어져서 따로 봐준다.
      final s = scoreSpeaking('Thank you.', 'thanks you');
      expect(s.total, 2);
      expect(s.matched, 1);
      expect(s.passed, isTrue);
    });

    test('같은 낱말을 두 번 말해야 두 번 인정한다', () {
      final s = scoreSpeaking('No, no way.', 'no way');
      expect(s.total, 3); // no, no, way
      expect(s.matched, 2); // 'no' 한 번 + 'way'
      expect(s.perfect, isFalse);
    });

    test('길게 덧붙여 말해도 맞은 낱말은 인정한다', () {
      final s = scoreSpeaking('I am fine.', 'um I am fine thanks');
      expect(s.matched, 3);
      expect(s.perfect, isTrue);
      expect(s.passed, isTrue);
    });

    test('인식된 말을 그대로 보관해 화면에 보여 줄 수 있다', () {
      final s = scoreSpeaking('Let me check.', 'let me Czech');
      expect(s.heard, 'let me Czech');
    });
  });
}
