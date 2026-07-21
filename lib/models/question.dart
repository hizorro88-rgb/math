import 'dart:math';

import 'quiz_config.dart';

/// 덧셈 또는 뺄셈 한 문제
class Question {
  Question({
    required this.left,
    required this.right,
    required this.isAddition,
    required this.choices,
    required this.emoji,
  });

  final int left;
  final int right;
  final bool isAddition;

  /// 정답 1개 + 오답 3개가 섞여 있는 보기 목록
  final List<int> choices;

  /// 개수 세기를 도와주는 그림 이모지 (예: 🍎)
  final String emoji;

  int get answer => isAddition ? left + right : left - right;

  String get expression => '$left ${isAddition ? '+' : '-'} $right = ?';
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
    String? previousExpression;

    for (var i = 0; i < config.questionCount; i++) {
      Question question;
      // 바로 앞 문제와 똑같은 문제는 피한다.
      do {
        question = _generateOne(config);
      } while (question.expression == previousExpression);
      previousExpression = question.expression;
      questions.add(question);
    }
    return questions;
  }

  Question _generateOne(QuizConfig config) {
    final isAddition = switch (config.mode) {
      QuizMode.addition => true,
      QuizMode.subtraction => false,
      QuizMode.mixed => _random.nextBool(),
    };

    final max = config.maxNumber;
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
