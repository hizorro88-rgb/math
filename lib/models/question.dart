import 'dart:math';

import 'quiz_config.dart';

/// 문제의 연산 종류
enum QuestionOp { counting, add, sub, mul, div }

/// 사칙연산 또는 수 세기 한 문제
class Question {
  Question({
    required this.op,
    required this.left,
    required this.right,
    required this.choices,
    required this.emoji,
    this.vertical = false,
  });

  final QuestionOp op;
  final int left;
  final int right;

  /// 세로셈 표시 여부: 자리수를 맞춰 세로로 보여주고
  /// 일의 자리부터 키패드로 답을 채운다.
  final bool vertical;

  /// 정답 1개 + 오답 3개가 섞여 있는 보기 목록
  final List<int> choices;

  /// 개수 세기를 도와주는 그림 이모지 (예: 🍎)
  final String emoji;

  bool get isCounting => op == QuestionOp.counting;
  bool get isAddition => op == QuestionOp.add;

  int get answer => switch (op) {
        QuestionOp.counting => left,
        QuestionOp.add => left + right,
        QuestionOp.sub => left - right,
        QuestionOp.mul => left * right,
        QuestionOp.div => left ~/ right,
      };

  String get expression => switch (op) {
        QuestionOp.counting => '몇 개일까요?',
        QuestionOp.add => '$left + $right = ?',
        QuestionOp.sub => '$left - $right = ?',
        QuestionOp.mul => '$left × $right = ?',
        QuestionOp.div => '$left ÷ $right = ?',
      };

  /// 음성으로 읽어 줄 문장 (예: "3 더하기 2는?")
  String get speechText => switch (op) {
        QuestionOp.counting => '모두 몇 개일까요?',
        QuestionOp.add => '$left 더하기 $right는?',
        QuestionOp.sub => '$left 빼기 $right는?',
        QuestionOp.mul => '$left 곱하기 $right는?',
        QuestionOp.div => '$left 나누기 $right는?',
      };

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

  String get _emoji => _emojis[_random.nextInt(_emojis.length)];

  Question _generateOne(QuizConfig config) {
    final max = config.maxNumber;

    switch (config.mode) {
      // 수 세기: 그림 1~max개를 보여주고 개수를 맞힌다.
      case QuizMode.counting:
        final count = 1 + _random.nextInt(max);
        return Question(
          op: QuestionOp.counting,
          left: count,
          right: 0,
          choices: _buildChoices(count, max),
          emoji: _emoji,
        );

      // 곱셈: max단까지의 구구단. (2~max) × (1~9)
      case QuizMode.multiplication:
        final table = 2 + _random.nextInt(max - 1); // 2..max
        final times = 1 + _random.nextInt(9); // 1..9
        final answer = table * times;
        return Question(
          op: QuestionOp.mul,
          left: table,
          right: times,
          choices: _buildChoices(answer, answer + 2),
          emoji: _emoji,
        );

      // 나눗셈: 곱셈구구를 거꾸로. (나누는 수 2~min(max,9), 몫 1~9)
      case QuizMode.division:
        final divisor = 2 + _random.nextInt((max < 9 ? max : 9) - 1);
        final quotient = 1 + _random.nextInt(9);
        return Question(
          op: QuestionOp.div,
          left: divisor * quotient,
          right: divisor,
          choices: _buildChoices(quotient, quotient + 2),
          emoji: _emoji,
        );

      // 세로 덧셈: 두 자리 수 중심으로 자리수 계산을 연습한다.
      case QuizMode.verticalAdd:
        final m = max < 20 ? 20 : max;
        final sum = 11 + _random.nextInt(m - 10); // 11..m
        final left = 10 + _random.nextInt(sum - 10); // 10..sum-1
        return Question(
          op: QuestionOp.add,
          vertical: true,
          left: left,
          right: sum - left,
          choices: _buildChoices(sum, m),
          emoji: _emoji,
        );

      // 세로 뺄셈: 두 자리 수에서 빼기 (답은 0 이상)
      case QuizMode.verticalSub:
        final m = max < 20 ? 20 : max;
        final left = 11 + _random.nextInt(m - 10); // 11..m
        final right = 1 + _random.nextInt(left); // 1..left
        return Question(
          op: QuestionOp.sub,
          vertical: true,
          left: left,
          right: right,
          choices: _buildChoices(left - right, m),
          emoji: _emoji,
        );

      case QuizMode.addition:
      case QuizMode.subtraction:
      case QuizMode.mixed:
        final isAddition = switch (config.mode) {
          QuizMode.addition => true,
          QuizMode.subtraction => false,
          _ => _random.nextBool(),
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
          op: isAddition ? QuestionOp.add : QuestionOp.sub,
          left: left,
          right: right,
          choices: _buildChoices(answer, max),
          emoji: _emoji,
        );
    }
  }

  /// 정답 주변의 그럴듯한 오답 3개를 섞어 보기 4개를 만든다.
  /// 보기는 0 이상 [upper]+2 이하에서 고른다.
  List<int> _buildChoices(int answer, int upper) {
    final choices = <int>{answer};
    var spread = 1;
    while (choices.length < 4) {
      final candidate = answer + (_random.nextBool() ? spread : -spread);
      if (candidate >= 0 && candidate <= upper + 2) {
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
