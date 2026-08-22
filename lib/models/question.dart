import 'dart:math';

import 'quiz_config.dart';

/// 문제의 연산 종류
enum QuestionOp { counting, add, sub, mul, div, compare, pattern, clock }

/// 사칙연산·수 세기·비교·규칙 찾기 한 문제
class Question {
  Question({
    required this.op,
    required this.left,
    required this.right,
    required this.choices,
    required this.emoji,
    this.vertical = false,
    this.blankSide = 0,
    this.listenOnly = false,
    this.sequence = const [],
  });

  final QuestionOp op;

  /// 연산 문제의 피연산자.
  /// compare/pattern 문제에서는 left에 정답을 담는다.
  final int left;
  final int right;

  /// 세로셈 표시 여부: 자리수를 맞춰 세로로 보여주고
  /// 일의 자리부터 키패드로 답을 채운다.
  final bool vertical;

  /// 빈칸 채우기: 0이면 보통 문제, 1이면 left가, 2면 right가 □로 가려진다.
  /// (덧셈·뺄셈에서만 사용. 가려진 수가 정답이 된다.)
  final int blankSide;

  /// 듣고 풀기: 식을 화면에 보여주지 않고 소리로만 들려준다.
  final bool listenOnly;

  /// 규칙 찾기에서 보여주는 수 배열 (예: [2, 4, 6] → 정답 8)
  final List<int> sequence;

  /// 정답 1개 + 오답 3개가 섞여 있는 보기 목록
  final List<int> choices;

  /// 개수 세기를 도와주는 그림 이모지 (예: 🍎)
  final String emoji;

  bool get isCounting => op == QuestionOp.counting;
  bool get isAddition => op == QuestionOp.add;

  int get answer {
    // 빈칸 문제는 가려진 수가 곧 정답
    if (blankSide == 1) return left;
    if (blankSide == 2) return right;
    return switch (op) {
      QuestionOp.counting => left,
      QuestionOp.add => left + right,
      QuestionOp.sub => left - right,
      QuestionOp.mul => left * right,
      QuestionOp.div => left ~/ right,
      QuestionOp.compare => left,
      QuestionOp.pattern => left,
      QuestionOp.clock => left,
    };
  }

  String get expression {
    if (listenOnly) return '👂 잘 들어 보세요';
    if (blankSide != 0) {
      final opSign = op == QuestionOp.add ? '+' : '-';
      final total = op == QuestionOp.add ? left + right : left - right;
      return blankSide == 1
          ? '□ $opSign $right = $total'
          : '$left $opSign □ = $total';
    }
    return switch (op) {
      QuestionOp.counting => '몇 개일까요?',
      QuestionOp.add => '$left + $right = ?',
      QuestionOp.sub => '$left - $right = ?',
      QuestionOp.mul => '$left × $right = ?',
      QuestionOp.div => '$left ÷ $right = ?',
      QuestionOp.compare => right == 1 ? '가장 큰 수는?' : '가장 작은 수는?',
      QuestionOp.pattern => '${sequence.join(', ')}, ?',
      QuestionOp.clock => '시계는 몇 시일까요?',
    };
  }

  /// 음성으로 읽어 줄 문장 (예: "3 더하기 2는?")
  String get speechText {
    if (blankSide != 0) {
      final total = op == QuestionOp.add ? left + right : left - right;
      if (op == QuestionOp.add) {
        return blankSide == 1
            ? '몇 더하기 $right이면 $total일까요?'
            : '$left 더하기 몇이면 $total일까요?';
      }
      return blankSide == 1
          ? '몇 빼기 $right이면 $total일까요?'
          : '$left 빼기 몇이면 $total일까요?';
    }
    return switch (op) {
      QuestionOp.counting => '모두 몇 개일까요?',
      QuestionOp.add => '$left 더하기 $right는?',
      QuestionOp.sub => '$left 빼기 $right는?',
      QuestionOp.mul => '$left 곱하기 $right는?',
      QuestionOp.div => '$left 나누기 $right는?',
      QuestionOp.compare => right == 1 ? '가장 큰 수를 찾아보세요' : '가장 작은 수를 찾아보세요',
      QuestionOp.pattern => '${sequence.join(', ')}, 다음 수는?',
      QuestionOp.clock => '시계가 가리키는 시각은 몇 시일까요?',
    };
  }

  /// 같은 문제가 연달아 나오는지 판정할 때 쓰는 키.
  /// 화면 표기가 같아지는 유형은 내용으로 구분한다.
  String get dedupKey => switch (op) {
        QuestionOp.counting => 'counting:$left',
        QuestionOp.compare =>
          'compare:$right:${([...choices]..sort()).join(',')}',
        QuestionOp.pattern => 'pattern:${sequence.join(',')}',
        _ => '${op.name}:$left:$right:$blankSide',
      };
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

      // 빈칸 채우기: 덧셈·뺄셈 식에서 피연산자 하나를 □로 가린다.
      case QuizMode.fillBlank:
        final base = _addSub(QuizMode.mixed, max);
        final blankSide = 1 + _random.nextInt(2);
        final hidden = blankSide == 1 ? base.left : base.right;
        return Question(
          op: base.op,
          left: base.left,
          right: base.right,
          blankSide: blankSide,
          choices: _buildChoices(hidden, max),
          emoji: _emoji,
        );

      // 10 만들기: left + □ = 10 (10의 보수 익히기)
      case QuizMode.makeTen:
        final left = 1 + _random.nextInt(9); // 1..9
        return Question(
          op: QuestionOp.add,
          left: left,
          right: 10 - left,
          blankSide: 2,
          choices: _buildChoices(10 - left, 10),
          emoji: _emoji,
        );

      // 큰 수 찾기: 서로 다른 수 4개 중 가장 큰(작은) 수를 고른다.
      case QuizMode.compare:
        final upper = max < 4 ? 4 : max;
        final pool = <int>{};
        while (pool.length < 4) {
          pool.add(1 + _random.nextInt(upper));
        }
        final choices = pool.toList()..shuffle(_random);
        final findMax = _random.nextBool();
        final answer = findMax
            ? choices.reduce((a, b) => a > b ? a : b)
            : choices.reduce((a, b) => a < b ? a : b);
        return Question(
          op: QuestionOp.compare,
          left: answer,
          right: findMax ? 1 : 0,
          choices: choices,
          emoji: _emoji,
        );

      // 규칙 찾기: step씩 커지는 수 배열의 다음 수를 찾는다.
      case QuizMode.pattern:
        final maxStep = max < 1 ? 1 : (max > 9 ? 9 : max);
        final step = 1 + _random.nextInt(maxStep);
        final start = 1 + _random.nextInt(10);
        final sequence = [start, start + step, start + 2 * step];
        final answer = start + 3 * step;
        return Question(
          op: QuestionOp.pattern,
          left: answer,
          right: step,
          sequence: sequence,
          choices: _buildChoices(answer, answer + 2),
          emoji: _emoji,
        );

      // 시계 보기: 몇 시(정각)를 맞힌다. (난이도 값은 쓰지 않는다)
      case QuizMode.clock:
        final hour = 1 + _random.nextInt(12); // 1..12
        final choices = <int>{hour};
        while (choices.length < 4) {
          choices.add(1 + _random.nextInt(12));
        }
        return Question(
          op: QuestionOp.clock,
          left: hour,
          right: 0,
          choices: choices.toList()..shuffle(_random),
          emoji: _emoji,
        );

      // 듣고 풀기: 덧셈·뺄셈을 소리로만 들려준다 (암산 연습).
      case QuizMode.listen:
        final base = _addSub(QuizMode.mixed, max);
        return Question(
          op: base.op,
          left: base.left,
          right: base.right,
          listenOnly: true,
          choices: base.choices,
          emoji: base.emoji,
        );

      case QuizMode.addition:
      case QuizMode.subtraction:
      case QuizMode.mixed:
        return _addSub(config.mode, max);
    }
  }

  /// 덧셈/뺄셈/섞어서 문제 하나를 만든다.
  Question _addSub(QuizMode mode, int max) {
    final isAddition = switch (mode) {
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
