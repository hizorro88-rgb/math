import 'dart:math';

import 'quiz_config.dart';

/// 문제의 연산 종류 (통계 저장 키와 이어지므로 새 값은 끝에만 추가한다)
enum QuestionOp {
  counting,
  add,
  sub,
  mul,
  div,
  compare,
  pattern,
  clock,
  shape,
  fraction,
  decimal,
  timeCalc,
}

/// 모양 세기에 쓰는 도형과 이름
const List<({String emoji, String name})> shapeKinds = [
  (emoji: '🔴', name: '동그라미'),
  (emoji: '🔺', name: '세모'),
  (emoji: '🟦', name: '네모'),
  (emoji: '⭐', name: '별'),
  (emoji: '💛', name: '하트'),
];

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
    this.shapeItems = const [],
    this.prompt = '',
    this.promptSpeech = '',
    this.variant = 0,
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

  /// 모양 세기에서 화면에 흩어 놓는 모양들 (정답 모양 left개 포함)
  final List<String> shapeItems;

  /// 정답 1개 + 오답 3개가 섞여 있는 보기 목록
  final List<int> choices;

  /// 개수 세기를 도와주는 그림 이모지 (예: 🍎)
  final String emoji;

  /// 분수·소수·시간 계산처럼 문장으로 내는 문제의 질문.
  /// 비어 있지 않으면 [expression] 대신 이 문장이 보인다.
  final String prompt;

  /// [prompt] 문제를 읽어 줄 문장 (비면 prompt를 그대로 읽는다)
  final String promptSpeech;

  /// 같은 연산 안의 세부 유형 (예: 시간 계산에서 0=몇 시, 1=몇 분)
  final int variant;

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
      QuestionOp.shape => left,
      // 심화 유형은 부호화한 정답을 left에 담는다.
      QuestionOp.fraction => left,
      QuestionOp.decimal => left,
      QuestionOp.timeCalc => left,
    };
  }

  /// 보기·정답 숫자를 화면에 보여줄 글자로 바꾼다.
  /// 분수는 분자×100+분모, 소수는 0.1 단위 개수, 시간은 분으로 부호화돼 있다.
  String labelFor(int value) => switch (op) {
        QuestionOp.fraction => '${value ~/ 100}/${value % 100}',
        QuestionOp.decimal => (value / 10).toStringAsFixed(1),
        QuestionOp.timeCalc => variant == 1
            ? '$value분'
            : value % 60 == 0
                ? '${value ~/ 60}시'
                : '${value ~/ 60}시 ${value % 60}분',
        _ => '$value',
      };

  String get answerLabel => labelFor(answer);

  /// 정답을 읽어 줄 때 쓰는 말 (분수는 "5분의 3"처럼 읽는다)
  String get answerSpeech => switch (op) {
        QuestionOp.fraction => '${answer % 100}분의 ${answer ~/ 100}',
        _ => answerLabel,
      };

  String get expression {
    if (prompt.isNotEmpty) return prompt;
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
      QuestionOp.shape => '$emoji 는 몇 개일까요?',
      QuestionOp.fraction ||
      QuestionOp.decimal ||
      QuestionOp.timeCalc =>
        prompt,
    };
  }

  /// 음성으로 읽어 줄 문장 (예: "3 더하기 2는?")
  String get speechText {
    if (prompt.isNotEmpty) {
      return promptSpeech.isNotEmpty ? promptSpeech : prompt;
    }
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
      QuestionOp.shape =>
        '${shapeKinds.firstWhere((s) => s.emoji == emoji).name}가 몇 개인지 세어 보세요',
      QuestionOp.fraction ||
      QuestionOp.decimal ||
      QuestionOp.timeCalc =>
        prompt,
    };
  }

  /// 같은 문제가 연달아 나오는지 판정할 때 쓰는 키.
  /// 화면 표기가 같아지는 유형은 내용으로 구분한다.
  String get dedupKey => switch (op) {
        QuestionOp.counting => 'counting:$left',
        QuestionOp.shape => 'shape:$emoji:$left',
        QuestionOp.compare =>
          'compare:$right:${([...choices]..sort()).join(',')}',
        QuestionOp.pattern => 'pattern:${sequence.join(',')}',
        QuestionOp.fraction ||
        QuestionOp.decimal ||
        QuestionOp.timeCalc =>
          '${op.name}:$variant:$prompt:$left',
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
      // (만들 수 있는 문제가 하나뿐이어도 멈추지 않게 시도 횟수를 제한한다)
      var attempts = 0;
      do {
        question = _generateOne(config);
      } while (question.dedupKey == previousKey && ++attempts < 30);
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

      // 모양 세기: 여러 모양이 섞인 그림에서 한 모양의 개수를 센다.
      case QuizMode.shapeCount:
        final maxCount = max < 2 ? 2 : (max > 6 ? 6 : max);
        final kinds = [...shapeKinds]..shuffle(_random);
        final target = kinds.first;
        final count = 1 + _random.nextInt(maxCount); // 1..maxCount
        final items = [
          for (var i = 0; i < count; i++) target.emoji,
          // 다른 모양 2종을 섞어 놓는다.
          for (var k = 1; k <= 2; k++)
            for (var i = 0; i < 1 + _random.nextInt(maxCount); i++)
              kinds[k].emoji,
        ]..shuffle(_random);
        return Question(
          op: QuestionOp.shape,
          left: count,
          right: 0,
          shapeItems: items,
          choices: _buildChoices(count, maxCount),
          emoji: target.emoji,
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

      // 분수: 똑같이 나누기(이름 붙이기) → 같은 분모 비교 → 같은 분모 덧셈
      case QuizMode.fraction:
        final m = max.clamp(2, 9);
        final forms = [0, if (m >= 5) 1, if (m >= 6) 2];
        switch (forms[_random.nextInt(forms.length)]) {
          // 이름 붙이기: b조각 중 한 조각 = 1/b
          // (분모가 한 종류뿐이면 연속 중복을 못 피하므로 최소 2~3은 나오게 한다)
          case 0:
            final dMax = m < 3 ? 3 : m;
            final d = 2 + _random.nextInt(dMax - 1); // 2..dMax
            final wrong = <int>{};
            while (wrong.length < 3) {
              final other = 2 + _random.nextInt(8); // 2..9
              if (other != d) wrong.add(100 + other);
            }
            return Question(
              op: QuestionOp.fraction,
              left: 100 + d,
              right: 0,
              prompt: '피자 한 판을 $d조각으로 똑같이 나눴어요.\n한 조각은 전체의 얼마일까요?',
              promptSpeech: '피자 한 판을 $d조각으로 똑같이 나누면, 한 조각은 전체의 얼마일까요?',
              choices: [100 + d, ...wrong]..shuffle(_random),
              emoji: '',
            );

          // 같은 분모 비교: 분자가 클수록 크다
          case 1:
            final d = 5 + _random.nextInt(5); // 5..9
            final numerators = <int>{};
            while (numerators.length < 4) {
              numerators.add(1 + _random.nextInt(d - 1)); // 1..d-1
            }
            final top = numerators.reduce((a, b) => a > b ? a : b);
            return Question(
              op: QuestionOp.fraction,
              variant: 1,
              left: top * 100 + d,
              right: 0,
              prompt: '가장 큰 분수는 어느 것일까요?',
              promptSpeech: '가장 큰 분수를 찾아보세요',
              choices: [for (final n in numerators) n * 100 + d]
                ..shuffle(_random),
              emoji: '',
            );

          // 같은 분모 덧셈: a/d + b/d = (a+b)/d
          // (오답 3개를 1..d-1에서 뽑으므로 분모는 5 이상이어야 한다)
          default:
            final d = 5 + _random.nextInt(5); // 5..9
            final a = 1 + _random.nextInt(d - 2); // 1..d-2
            final b = 1 + _random.nextInt(d - 1 - a); // a+b <= d-1
            final sum = a + b;
            final wrong = <int>{};
            while (wrong.length < 3) {
              final n = 1 + _random.nextInt(d - 1);
              if (n != sum) wrong.add(n * 100 + d);
            }
            return Question(
              op: QuestionOp.fraction,
              variant: 2,
              left: sum * 100 + d,
              right: 0,
              prompt: '$a/$d + $b/$d = ?',
              promptSpeech: '$d분의 $a 더하기 $d분의 $b는?',
              choices: [sum * 100 + d, ...wrong]..shuffle(_random),
              emoji: '',
            );
        }

      // 소수: 0.1 모으기 → 비교 → 덧셈 (값은 0.1 단위 개수로 부호화)
      case QuizMode.decimal:
        final upper = max.clamp(2, 19); // 최대 1.9
        final forms = [0, 1, if (upper >= 10) 2];
        switch (forms[_random.nextInt(forms.length)]) {
          // 0.1이 k개 = 0.k
          case 0:
            final k = 1 + _random.nextInt(upper.clamp(2, 9));
            final wrong = <int>{};
            while (wrong.length < 3) {
              final n = 1 + _random.nextInt(upper.clamp(4, 19));
              if (n != k) wrong.add(n);
            }
            return Question(
              op: QuestionOp.decimal,
              left: k,
              right: 0,
              prompt: '0.1이 $k개 모이면 얼마일까요?',
              promptSpeech: '영 점 일이 $k개 모이면 얼마일까요?',
              choices: [k, ...wrong]..shuffle(_random),
              emoji: '',
            );

          // 소수 비교 (서로 다른 보기 4개가 나오게 범위 하한을 보정)
          case 1:
            final range = upper.clamp(4, 19);
            final pool = <int>{};
            while (pool.length < 4) {
              pool.add(1 + _random.nextInt(range));
            }
            final top = pool.reduce((a, b) => a > b ? a : b);
            return Question(
              op: QuestionOp.decimal,
              variant: 1,
              left: top,
              right: 0,
              prompt: '가장 큰 소수는 어느 것일까요?',
              promptSpeech: '가장 큰 소수를 찾아보세요',
              choices: pool.toList()..shuffle(_random),
              emoji: '',
            );

          // 소수 덧셈: 합이 1.9 이하
          default:
            final a = 1 + _random.nextInt(9); // 0.1..0.9
            final b = 1 + _random.nextInt((upper - a).clamp(1, 9));
            final sum = a + b;
            final wrong = <int>{};
            while (wrong.length < 3) {
              final n = 1 + _random.nextInt(19);
              if (n != sum) wrong.add(n);
            }
            String lab(int v) => (v / 10).toStringAsFixed(1);
            return Question(
              op: QuestionOp.decimal,
              variant: 2,
              left: sum,
              right: 0,
              prompt: '${lab(a)} + ${lab(b)} = ?',
              promptSpeech: '${lab(a)} 더하기 ${lab(b)}는?',
              choices: [sum, ...wrong]..shuffle(_random),
              emoji: '',
            );
        }

      // 시간 계산: 몇 시간 뒤 시각 → 시간↔분 → 30분 단위 (값은 분으로 부호화)
      case QuizMode.timeCalc:
        final m = max.clamp(3, 12);
        final forms = [0, if (m >= 5) 1, if (m >= 8) 2];
        switch (forms[_random.nextInt(forms.length)]) {
          // h시에서 dur시간 뒤는? (12시를 넘지 않게)
          case 0:
            final hour = 1 + _random.nextInt(9); // 1..9
            final dur = 1 + _random.nextInt((12 - hour).clamp(1, m - 1));
            final answer = (hour + dur) * 60;
            final wrong = <int>{};
            while (wrong.length < 3) {
              final h = 1 + _random.nextInt(12);
              if (h * 60 != answer) wrong.add(h * 60);
            }
            return Question(
              op: QuestionOp.timeCalc,
              left: answer,
              right: 0,
              prompt: '시계가 $hour시예요.\n$dur시간이 지나면 몇 시일까요?',
              promptSpeech: '$hour시에서 $dur시간이 지나면 몇 시일까요?',
              choices: [answer, ...wrong]..shuffle(_random),
              emoji: '',
            );

          // 시간 → 분 환산
          case 1:
            const pairs = [
              ('1시간', 60),
              ('2시간', 120),
              ('3시간', 180),
              ('1시간 30분', 90),
              ('반 시간', 30),
            ];
            final picked = pairs[_random.nextInt(pairs.length)];
            final options = <int>{30, 60, 90, 120, 180};
            final wrong = ([
              for (final v in options)
                if (v != picked.$2) v,
            ]..shuffle(_random))
                .take(3);
            return Question(
              op: QuestionOp.timeCalc,
              variant: 1,
              left: picked.$2,
              right: 0,
              prompt: '${picked.$1}은 몇 분일까요?',
              choices: [picked.$2, ...wrong]..shuffle(_random),
              emoji: '',
            );

          // 30분 단위: h시 30분에서 dur 뒤는?
          default:
            final hour = 1 + _random.nextInt(9); // 1..9
            final start = hour * 60 + 30;
            const durations = [('30분', 30), ('1시간', 60), ('1시간 30분', 90)];
            final dur = durations[_random.nextInt(durations.length)];
            final answer = start + dur.$2;
            final wrong = <int>{};
            while (wrong.length < 3) {
              final cand = answer + (30 + _random.nextInt(3) * 30) *
                  (_random.nextBool() ? 1 : -1);
              if (cand >= 60 && cand <= 12 * 60 && cand != answer) {
                wrong.add(cand);
              }
            }
            return Question(
              op: QuestionOp.timeCalc,
              left: answer,
              right: 0,
              prompt: '$hour시 30분에서 ${dur.$1}이 지나면\n몇 시일까요?',
              promptSpeech: '$hour시 30분에서 ${dur.$1}이 지나면 몇 시일까요?',
              choices: [answer, ...wrong]..shuffle(_random),
              emoji: '',
            );
        }

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
