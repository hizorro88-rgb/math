import 'dart:math';

import 'quiz_config.dart';

/// 덧셈·뺄셈 또는 수 세기 한 문제
class Question {
  Question({
    required this.left,
    required this.right,
    required this.isAddition,
    this.isCounting = false,
    required this.choices,
    required this.emoji,
  });

  final int left;
  final int right;
  final bool isAddition;

  /// 수 세기 문제: 그림이 [left]개 나오고 개수를 맞힌다.
  final bool isCounting;

  /// 정답 1개 + 오답 3개가 섞여 있는 보기 목록
  final List<int> choices;

  /// 개수 세기를 도와주는 그림 이모지 (예: 🍎)
  final String emoji;

  int get answer => isCounting
      ? left
      : isAddition
          ? left + right
          : left - right;

  String get expression =>
      isCounting ? '몇 개일까요?' : '$left ${isAddition ? '+' : '-'} $right = ?';

  /// 음성으로 읽어 줄 문장 (예: "3 더하기 2는?")
  String get speechText =>
      isCounting ? '모두 몇 개일까요?' : '$left ${isAddition ? '더하기' : '빼기'} $right는?';

  /// 같은 문제가 연달아 나오는지 판정할 때 쓰는 키.
  /// 수 세기는 표현식이 모두 같으므로 개수로 구분한다.
  String get dedupKey => isCounting ? 'counting:$left' : expression;
}

/// 설정에 맞는 문제 목록을 만들어 준다.
class QuestionGenerator {
  QuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  static const _emojis = [
    '🍎',
    '🍓',
    '🍌',
    '🐤',
    '🐶',
    '⭐',
    '🚗',
    '🎈',
    '🐟',
    '🌼'
  ];

  List<Question> generate(QuizConfig config) {
    final questions = <Question>[];
    String? previousKey;

    for (var i = 0; i < config.questionCount; i++) {
      Question question;
      // 바로 앞 문제와 똑같은 문제는 피한다.
      do {
        question = _generateOne(config);
      } while (question.dedupKey == previousKey);
      previousKey = question.dedupKey;
      questions.add(question);
    }
    return questions;
  }

  Question _generateOne(QuizConfig config) {
    final max = config.maxNumber;

    // 수 세기: 그림 1~max개를 보여주고 개수를 맞힌다.
    if (config.mode == QuizMode.counting) {
      final count = 1 + _random.nextInt(max);
      return Question(
        left: count,
        right: 0,
        isAddition: true,
        isCounting: true,
        choices: _buildChoices(count, max),
        emoji: _emojis[_random.nextInt(_emojis.length)],
      );
    }

    final isAddition = switch (config.mode) {
      QuizMode.addition => true,
      QuizMode.subtraction => false,
      QuizMode.mixed || QuizMode.counting => _random.nextBool(),
    };
    int left;
    int right;

    if (isAddition) {
      // 합이 max를 넘지 않도록 한다. (1 + 1 부터)
      final sum = 2 + _random.nextInt(max - 1); // 2..max
      left = 1 + _random.nextInt(sum - 1); // 1..sum-1
      right = sum - left;
    } else {
      // 답이 0 이상이 되도록 큰 수에서 작은 수를 뺀다.
      left = 2 + _random.nextInt(max - 1); // 2..max
      right = 1 + _random.nextInt(left); // 1..left
    }

    final answer = isAddition ? left + right : left - right;

    return Question(
      left: left,
      right: right,
      isAddition: isAddition,
      choices: _buildChoices(answer, max),
      emoji: _emojis[_random.nextInt(_emojis.length)],
    );
  }

  /// 정답 주변의 그럴듯한 오답 3개를 섞어 보기 4개를 만든다.
  List<int> _buildChoices(int answer, int max) {
    final choices = <int>{answer};
    var spread = 1;
    while (choices.length < 4) {
      final candidate = answer + (_random.nextBool() ? spread : -spread);
      if (candidate >= 0 && candidate <= max + 2) {
        choices.add(candidate);
      }
      // 가까운 수부터 시도하고, 안 되면 범위를 넓힌다.
      if (_random.nextBool()) {
        spread = spread % 3 + 1;
      }
    }
    final list = choices.toList()..shuffle(_random);
    return list;
  }
}
