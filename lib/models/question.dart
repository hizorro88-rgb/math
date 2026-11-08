import 'dart:math';
import 'dart:math' as math;

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

  /// 자릿값 (정답은 left, 모형 그림은 sequence = [백, 십, 일])
  place,

  /// 나머지가 있는 나눗셈 (정답은 left — 나머지 또는 몫)
  remainder,

  // ── 측정·도형·자료 (정답은 left, 그림 정보는 sequence) ──

  /// 돈 세기·거스름돈 (원). sequence = 동전·지폐 금액들
  money,

  /// 자로 길이 재기 (cm). sequence = [시작 눈금, 끝 눈금, 자 길이]
  length,

  /// 도형의 꼭짓점·변 수. sequence = [모서리 수(원은 0)]
  sides,

  /// 그림그래프 읽기. sequence = 칸별 개수, shapeItems = 칸별 그림
  graph,

  /// 단위 바꾸기 (1 m 20 cm = □ cm)
  convert,

  /// 맞을까 틀릴까 (3 + 4 = 8?) — 정답 1=맞아요 0=아니에요.
  /// sequence = [왼쪽 수, 오른쪽 수, 보여 준 답, 연산(0 덧셈·1 뺄셈·2 곱셈)]
  judge,
}

/// 모양 세기에 쓰는 도형과 이름
const List<({String emoji, String name})> shapeKinds = [
  (emoji: '🔴', name: '동그라미'),
  (emoji: '🔺', name: '세모'),
  (emoji: '🟦', name: '네모'),
  (emoji: '⭐', name: '별'),
  (emoji: '💛', name: '하트'),
];

/// 수 뒤에 붙는 조사 (3은 / 2는) — 수를 한자어로 읽을 때의 끝소리로 고른다.
/// 일의 자리가 0이면 십·백·천처럼 받침으로 끝난다.
String numJosa(int n, String withBatchim, String without) =>
    const {0, 1, 3, 6, 7, 8}.contains(n.abs() % 10) ? withBatchim : without;

/// 자릿값을 글로: '100이 2개, 10이 3개, 1이 5개인 수는?' (0개인 자리는 뺀다)
String placeValueText(List<int> hto) {
  final parts = [
    if (hto[0] > 0) '100이 ${hto[0]}개',
    if (hto[1] > 0) '10이 ${hto[1]}개',
    if (hto[2] > 0) '1이 ${hto[2]}개',
  ];
  return '${parts.join(', ')}인 수는?';
}

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

  /// 지시문 템플릿: 같은 유형 10문제가 같은 문장으로 반복되지 않게
  /// 문항 번호(variant)로 돌려 쓴다. [0]은 기존 문구(테스트 고정점).
  static const _countingExprs = [
    '몇 개일까요?',
    '모두 세어 볼까요?',
    '몇 개가 있을까요?',
    '하나, 둘, 셋… 몇 개?',
  ];
  static const _countingSpeeches = [
    '모두 몇 개일까요?',
    '손가락으로 짚으면서 세어 보세요',
    '하나씩 천천히 세어 볼까요?',
    '전부 몇 개인지 맞혀 보세요',
  ];
  static const _compareMaxExprs = ['가장 큰 수는?', '제일 큰 수를 찾아요!', '어떤 수가 가장 클까?'];
  static const _compareMinExprs = [
    '가장 작은 수는?',
    '제일 작은 수를 찾아요!',
    '어떤 수가 가장 작을까?'
  ];

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
      QuestionOp.place => left,
      QuestionOp.remainder => left,
      QuestionOp.money => left,
      QuestionOp.length => left,
      QuestionOp.sides => left,
      QuestionOp.graph => left,
      QuestionOp.convert => left,
      QuestionOp.judge => left,
    };
  }

  /// 보기·정답 숫자를 화면에 보여줄 글자로 바꾼다.
  /// 분수는 분자×100+분모, 소수는 0.1 단위 개수,
  /// 시계·시간은 분으로 부호화돼 있다.
  String labelFor(int value) => switch (op) {
        QuestionOp.fraction => '${value ~/ 100}/${value % 100}',
        QuestionOp.decimal => (value / 10).toStringAsFixed(1),
        QuestionOp.clock => value % 60 == 0
            ? '${value ~/ 60}시'
            : '${value ~/ 60}시 ${value % 60}분',
        QuestionOp.money => '$value원',
        QuestionOp.convert => '$value $emoji',
        QuestionOp.judge => value == 1 ? '👍 맞아요' : '👎 틀려요',
        QuestionOp.length => '$value cm',
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
        // 맞을까 틀릴까는 '맞아요/아니에요'가 아니라 바른 식을 들려준다
        QuestionOp.judge => '${sequence[0]} ${const [
            '더하기',
            '빼기',
            '곱하기'
          ][sequence[3]]} ${sequence[1]}${numJosa(sequence[1], '은', '는')} $judgeResult',
        _ => answerLabel,
      };

  /// 맞을까 틀릴까: 바른 계산 결과
  int get judgeResult => switch (sequence[3]) {
        0 => sequence[0] + sequence[1],
        1 => sequence[0] - sequence[1],
        _ => sequence[0] * sequence[1],
      };

  /// 맞을까 틀릴까: 바른 식 ('4 - 1 = 3') — 정답 판에 보여 준다
  String get judgeTruth => '${sequence[0]} ${const [
        '+',
        '-',
        '×'
      ][sequence[3]]} ${sequence[1]} = $judgeResult';

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
      QuestionOp.counting => _countingExprs[variant % _countingExprs.length],
      QuestionOp.add => '$left + $right = ?',
      QuestionOp.sub => '$left - $right = ?',
      QuestionOp.mul => '$left × $right = ?',
      QuestionOp.div => '$left ÷ $right = ?',
      QuestionOp.compare => right == 1
          ? _compareMaxExprs[variant % _compareMaxExprs.length]
          : _compareMinExprs[variant % _compareMinExprs.length],
      QuestionOp.pattern => '${sequence.join(', ')}, ?',
      QuestionOp.clock => '시계는 몇 시일까요?',
      QuestionOp.shape => '$emoji 몇 개일까요?',
      QuestionOp.judge => '${sequence[0]} ${const [
          '+',
          '-',
          '×'
        ][sequence[3]]} ${sequence[1]} = ${sequence[2]}',
      // 심화 유형은 항상 prompt가 있어 위에서 먼저 반환된다 (완전성 유지용).
      QuestionOp.fraction ||
      QuestionOp.decimal ||
      QuestionOp.timeCalc ||
      QuestionOp.place ||
      QuestionOp.remainder ||
      QuestionOp.money ||
      QuestionOp.length ||
      QuestionOp.sides ||
      QuestionOp.graph ||
      QuestionOp.convert =>
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
            ? '몇 더하기 $right${numJosa(right, '이면', '면')} $total일까요?'
            : '$left 더하기 몇이면 $total일까요?';
      }
      return blankSide == 1
          ? '몇 빼기 $right${numJosa(right, '이면', '면')} $total일까요?'
          : '$left 빼기 몇이면 $total일까요?';
    }
    return switch (op) {
      QuestionOp.counting =>
        _countingSpeeches[variant % _countingSpeeches.length],
      QuestionOp.add => '$left 더하기 $right${numJosa(right, '은', '는')}?',
      QuestionOp.sub => '$left 빼기 $right${numJosa(right, '은', '는')}?',
      QuestionOp.mul => '$left 곱하기 $right${numJosa(right, '은', '는')}?',
      QuestionOp.div => '$left 나누기 $right${numJosa(right, '은', '는')}?',
      QuestionOp.compare => right == 1 ? '가장 큰 수를 찾아보세요' : '가장 작은 수를 찾아보세요',
      QuestionOp.pattern => '${sequence.join(', ')}, 다음 수는?',
      QuestionOp.judge => '${sequence[0]} ${const [
          '더하기',
          '빼기',
          '곱하기'
        ][sequence[3]]} ${sequence[1]}${numJosa(sequence[1], '은', '는')} ${sequence[2]}, 맞을까요?',
      QuestionOp.clock => '시계가 가리키는 시각은 몇 시일까요?',
      QuestionOp.shape => switch (variant % 3) {
          1 =>
            '${shapeKinds.firstWhere((s) => s.emoji == emoji).name}만 골라서 세어 볼까요?',
          2 =>
            '숨어 있는 ${shapeKinds.firstWhere((s) => s.emoji == emoji).name}를 찾아 세어 보세요',
          _ =>
            '${shapeKinds.firstWhere((s) => s.emoji == emoji).name}가 몇 개인지 세어 보세요',
        },
      // 심화 유형은 항상 prompt가 있어 위에서 먼저 반환된다 (완전성 유지용).
      QuestionOp.fraction ||
      QuestionOp.decimal ||
      QuestionOp.timeCalc ||
      QuestionOp.place ||
      QuestionOp.remainder ||
      QuestionOp.money ||
      QuestionOp.length ||
      QuestionOp.sides ||
      QuestionOp.graph ||
      QuestionOp.convert =>
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
        QuestionOp.judge => 'judge:${sequence.join(',')}',
        QuestionOp.fraction ||
        QuestionOp.decimal ||
        QuestionOp.timeCalc ||
        QuestionOp.place ||
        QuestionOp.remainder ||
        QuestionOp.money ||
        QuestionOp.length ||
        QuestionOp.sides ||
        QuestionOp.graph ||
        QuestionOp.convert =>
          '${op.name}:$variant:$prompt:$left:${sequence.join(',')}',
        _ => '${op.name}:$left:$right:$blankSide',
      };
}

/// 설정에 맞는 문제 목록을 만들어 준다.
class QuestionGenerator {
  QuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// (친구 🐸🐳🐱·얼굴·⭐·🎁처럼 앱에서 따로 뜻이 있는 그림은 넣지 않는다)
  /// 그림 테마: 판마다 하나를 뽑아 "이번 판은 과일 나라"처럼
  /// 판 단위로 그림이 바뀐다 (한 판 안에서는 테마 안에서만 회전).
  static const _emojiThemes = <String, List<String>>{
    '과일': ['🍎', '🍓', '🍌', '🍇', '🍑', '🍒', '🍉', '🍊'],
    '동물': ['🐤', '🐶', '🐰', '🐷', '🐢', '🐝', '🦋', '🐞'],
    '바다': ['🐟', '🐙', '🦀', '🐚', '🦭', '🦐', '⛵', '🦑'],
    '탈것': ['🚗', '🚌', '🚂', '🚁', '🚀', '🚲', '🚜', '🛸'],
    '간식': ['🍪', '🍩', '🧁', '🍭', '🍬', '🍦', '🍿', '🥕'],
    '반짝': ['🍀', '🎈', '🌼', '🌸', '🌻', '🎀', '🧸', '🪁'],
  };

  /// 이번 판의 그림 풀 (generate 시작 시 테마에서 뽑는다)
  List<String> _roundEmojis = _emojiThemes.values.first;

  /// 처음 두 문제는 살짝 쉬운 "워밍업"으로 내는 유형들
  static const _warmupModes = {
    QuizMode.counting,
    QuizMode.addition,
    QuizMode.subtraction,
    QuizMode.mixed,
    QuizMode.shapeCount,
  };

  List<Question> generate(QuizConfig config) {
    // 판마다 그림 테마를 하나 뽑는다.
    final themes = _emojiThemes.values.toList();
    _roundEmojis = themes[_random.nextInt(themes.length)];

    // 워밍업용: 처음 2문제는 최대값을 낮춰 리듬을 만든다.
    QuizConfig eased = config;
    if (_warmupModes.contains(config.mode) && config.maxNumber > 3) {
      final easedMax =
          ((config.maxNumber * 0.7).ceil()).clamp(2, config.maxNumber);
      eased = QuizConfig(
        mode: config.mode,
        maxNumber: easedMax,
        minNumber: config.minNumber.clamp(1, easedMax),
        questionCount: config.questionCount,
        regroup: config.regroup,
      );
    }

    final questions = <Question>[];
    String? previousKey;
    int? previousAnswer;

    for (var i = 0; i < config.questionCount; i++) {
      Question question;
      // 바로 앞 문제와 똑같은 문제, 그리고 같은 정답의 연속을 피한다.
      // (만들 수 있는 문제가 적어도 멈추지 않게 시도 횟수를 제한한다)
      var attempts = 0;
      do {
        question = _generateOne(i < 2 ? eased : config, index: i);
      } while ((question.dedupKey == previousKey ||
              question.answer == previousAnswer) &&
          ++attempts < 30);
      previousKey = question.dedupKey;
      previousAnswer = question.answer;
      questions.add(question);
    }
    return questions;
  }

  String get _emoji => _roundEmojis[_random.nextInt(_roundEmojis.length)];

  Question _generateOne(QuizConfig config, {int index = 0}) {
    final max = config.maxNumber;

    switch (config.mode) {
      // 수 세기: 그림 1~max개를 보여주고 개수를 맞힌다.
      case QuizMode.counting:
        final count = 1 + _random.nextInt(max);
        return Question(
          op: QuestionOp.counting,
          left: count,
          right: 0,
          variant: index, // 문항마다 지시문이 조금씩 달라진다
          // 그림이 하나라도 있으니 0은 보기에 넣지 않는다
          choices: _buildChoices(count, max, lower: 1),
          emoji: _emoji,
        );

      // 곱셈: 시작 단부터 max단까지. (min~max) × (1~9)
      case QuizMode.multiplication:
        final lowTable = config.minNumber.clamp(2, max);
        final table = lowTable + _random.nextInt(max - lowTable + 1);
        final times = 1 + _random.nextInt(9); // 1..9
        final answer = table * times;
        return Question(
          op: QuestionOp.mul,
          left: table,
          right: times,
          choices: _buildChoices(answer, answer + 2),
          emoji: _emoji,
        );

      // 나눗셈: 곱셈구구를 거꾸로. (나누는 수 min~min(max,9), 몫 1~9)
      case QuizMode.division:
        final divisorMax = max < 9 ? max : 9;
        final divisorMin = config.minNumber.clamp(2, divisorMax);
        final divisor =
            divisorMin + _random.nextInt(divisorMax - divisorMin + 1);
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
        final sumMin = config.minNumber < 11 ? 11 : config.minNumber;
        var sum = sumMin + _random.nextInt(m - sumMin + 1); // sumMin..m
        var left = 10 + _random.nextInt(sum - 10); // 10..sum-1
        // 받아올림 세로 덧셈: 일의 자리 합이 10을 넘을 때까지 다시 뽑는다
        for (var t = 0;
            config.regroup && !_regroups(true, left, sum - left) && t < 200;
            t++) {
          sum = sumMin + _random.nextInt(m - sumMin + 1);
          left = 10 + _random.nextInt(sum - 10);
        }
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
        final leftMin = config.minNumber < 11 ? 11 : config.minNumber;
        var left = leftMin + _random.nextInt(m - leftMin + 1); // leftMin..m
        var right = 1 + _random.nextInt(left); // 1..left
        // 받아내림 세로 뺄셈: 일의 자리에서 빌려 와야 하는 문제만
        for (var t = 0;
            config.regroup && !_regroups(false, left, right) && t < 200;
            t++) {
          left = leftMin + _random.nextInt(m - leftMin + 1);
          right = 1 + _random.nextInt(left);
        }
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
        final base = _addSub(QuizMode.mixed, max, min: config.minNumber);
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
          variant: index,
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
          variant: index,
          shapeItems: items,
          choices: _buildChoices(count, maxCount),
          emoji: target.emoji,
        );

      // 시계 보기: 몇 시(정각), 기준값이 18 이상이면 몇 시 반도 섞는다.
      // 값은 분으로 부호화한다 (3시 = 180, 3시 30분 = 210).
      case QuizMode.clock:
        // 정각 → (18부터) 30분 → (30부터) 5분 단위 → (50부터) 1분 단위
        int pickMinute() {
          if (max >= 50 && _random.nextBool()) return _random.nextInt(60);
          if (max >= 30) return 5 * _random.nextInt(12);
          return max >= 18 && _random.nextBool() ? 30 : 0;
        }
        final hour = 1 + _random.nextInt(12); // 1..12
        final minute = pickMinute();
        final answer = hour * 60 + minute;
        final choices = <int>{answer};
        // 헷갈리는 보기: 시침·분침을 바꿔 읽은 시각, 한 시간 차이, 5분 차이
        if (max >= 30) {
          final swapped =
              (minute ~/ 5 == 0 ? 12 : minute ~/ 5) * 60 + (hour % 12) * 5;
          for (final c in [
            // 분침이 가리키는 숫자를 그대로 분으로 읽는 실수 (3시 40분 → 3시 8분)
            if (minute % 5 == 0 && minute >= 10) hour * 60 + minute ~/ 5,
            // 시침이 다음 숫자 가까이 가면 다음 시로 읽는 실수 (30분 이후만)
            if (minute >= 30) (hour % 12 + 1) * 60 + minute,
            swapped,
            // 5분 차이 (55분이면 5분 앞으로)
            hour * 60 + (minute >= 55 ? minute - 5 : minute + 5),
          ]) {
            if (choices.length < 4 && c >= 60 && c < 13 * 60) choices.add(c);
          }
        }
        while (choices.length < 4) {
          final h = 1 + _random.nextInt(12);
          choices.add(h * 60 + pickMinute());
        }
        // 분까지 읽는 단계는 '몇 시 몇 분', 앞 단계는 '몇 시'로 묻는다
        final withMinutes = max >= 30;
        return Question(
          op: QuestionOp.clock,
          left: answer,
          right: 0,
          prompt: withMinutes ? '몇 시 몇 분일까요?' : '',
          promptSpeech: withMinutes ? '시계가 가리키는 시각은 몇 시 몇 분일까요?' : '',
          choices: choices.toList()..shuffle(_random),
          emoji: _emoji,
        );

      // 듣고 풀기: 덧셈·뺄셈을 소리로만 들려준다 (암산 연습).
      case QuizMode.listen:
        final base = _addSub(QuizMode.mixed, max, min: config.minNumber);
        return Question(
          op: base.op,
          left: base.left,
          right: base.right,
          listenOnly: true,
          choices: base.choices,
          emoji: base.emoji,
        );

      // 분수: 똑같이 나누기(이름 붙이기) → 같은 분모 비교 → 같은 분모 덧셈
      // → (4학년, max 10부터) 같은 분모 뺄셈 · 가분수 찾기 · 대분수→가분수
      case QuizMode.fraction:
        final m = max.clamp(2, 12);
        final forms = [
          0,
          if (m >= 5) 1,
          if (m >= 6) 2,
          if (m >= 10) 3,
          if (m >= 10) 4,
          if (m >= 10) 5,
        ];
        switch (forms[_random.nextInt(forms.length)]) {
          // 이름 붙이기: b조각 중 한 조각 = 1/b
          // (분모가 한 종류뿐이면 연속 중복을 못 피하므로 최소 2~3은 나오게 한다)
          case 0:
            final dMax = m < 3 ? 3 : m;
            final d = 2 + _random.nextInt(dMax - 1); // 2..dMax
            final wrong = <int>{};
            while (wrong.length < 3) {
              final other = 2 + _random.nextInt((dMax - 1).clamp(8, 11));
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
            final d = 5 + _random.nextInt(m - 4); // 5..m
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
          case 2:
            final d = 5 + _random.nextInt(m - 4); // 5..m
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

          // 같은 분모 뺄셈: a/d - b/d = (a-b)/d
          case 3:
            final d = 5 + _random.nextInt(m - 4); // 5..m
            final a = 2 + _random.nextInt(d - 2); // 2..d-1
            final b = 1 + _random.nextInt(a - 1); // 1..a-1
            final diff = a - b;
            final wrong = <int>{};
            while (wrong.length < 3) {
              final n = 1 + _random.nextInt(d - 1);
              if (n != diff) wrong.add(n * 100 + d);
            }
            return Question(
              op: QuestionOp.fraction,
              variant: 3,
              left: diff * 100 + d,
              right: 0,
              prompt: '$a/$d - $b/$d = ?',
              promptSpeech: '$d분의 $a 빼기 $d분의 $b는?',
              choices: [diff * 100 + d, ...wrong]..shuffle(_random),
              emoji: '',
            );

          // 가분수 찾기: 분자가 분모와 같거나 큰 분수를 고른다
          case 4:
            final d = 4 + _random.nextInt(m - 3); // 4..m
            final n = d + _random.nextInt(4); // d..d+3 (가분수)
            final wrong = <int>{};
            while (wrong.length < 3) {
              final p = 1 + _random.nextInt(d - 1); // 진분수
              wrong.add(p * 100 + d);
            }
            return Question(
              op: QuestionOp.fraction,
              variant: 4,
              left: n * 100 + d,
              right: 0,
              prompt: '가분수는 어느 것일까요?',
              promptSpeech: '분자가 분모와 같거나 더 큰 가분수를 찾아보세요',
              choices: [n * 100 + d, ...wrong]..shuffle(_random),
              emoji: '',
            );

          // 대분수 → 가분수: w와 p/d = (w×d+p)/d
          default:
            final d = 4 + _random.nextInt(m - 3); // 4..m
            final w = 1 + _random.nextInt(3); // 1..3
            final p = 1 + _random.nextInt(d - 1); // 1..d-1
            final n = w * d + p;
            final wrong = <int>{};
            while (wrong.length < 3) {
              final k = d + _random.nextInt(3 * d); // d..4d-1 (가분수)
              if (k != n) wrong.add(k * 100 + d);
            }
            final josa = w == 2 ? '와' : '과';
            return Question(
              op: QuestionOp.fraction,
              variant: 5,
              left: n * 100 + d,
              right: 0,
              prompt: '대분수 $w$josa $p/$d를 가분수로 바꾸면?',
              promptSpeech: '대분수 $w$josa $d분의 $p를 가분수로 바꾸면?',
              choices: [n * 100 + d, ...wrong]..shuffle(_random),
              emoji: '',
            );
        }

      // 소수: 0.1 모으기 → 비교 → 덧셈 → (max 10부터) 뺄셈
      // (값은 0.1 단위 개수로 부호화, 4학년 확장으로 5.0까지)
      case QuizMode.decimal:
        final upper = max.clamp(2, 50); // 최대 5.0
        final forms = [0, 1, if (upper >= 10) 2, if (upper >= 10) 3];
        switch (forms[_random.nextInt(forms.length)]) {
          // 0.1이 k개 = 0.k (2.0 넘게도 모아 본다)
          case 0:
            final k = 1 + _random.nextInt(upper.clamp(2, 29));
            final wrong = <int>{};
            while (wrong.length < 3) {
              final n = 1 + _random.nextInt(upper.clamp(4, 29));
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
            final range = upper.clamp(4, 50);
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

          // 소수 덧셈: 합이 상한 이하 (상한이 2.0 이상이면 큰 소수끼리도 더한다)
          case 2:
            final aMax = upper >= 20 ? (upper - 2).clamp(1, 29) : 9;
            final a = 1 + _random.nextInt(aMax);
            final b =
                1 + _random.nextInt((upper - a).clamp(1, upper >= 20 ? 20 : 9));
            final sum = a + b;
            final wrong = <int>{};
            while (wrong.length < 3) {
              final n = 1 + _random.nextInt(upper.clamp(19, 50));
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

          // 소수 뺄셈: a - b (답은 0.1 이상)
          default:
            final a = 2 + _random.nextInt((upper - 1).clamp(1, 48)); // 2..upper
            final b = 1 + _random.nextInt(a - 1); // 1..a-1
            final diff = a - b;
            final wrong = <int>{};
            while (wrong.length < 3) {
              final n = 1 + _random.nextInt(upper.clamp(19, 50));
              if (n != diff) wrong.add(n);
            }
            String lab(int v) => (v / 10).toStringAsFixed(1);
            return Question(
              op: QuestionOp.decimal,
              variant: 3,
              left: diff,
              right: 0,
              prompt: '${lab(a)} - ${lab(b)} = ?',
              promptSpeech: '${lab(a)} 빼기 ${lab(b)}는?',
              choices: [diff, ...wrong]..shuffle(_random),
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
              final cand = answer +
                  (30 + _random.nextInt(3) * 30) *
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
        return _addSub(config.mode, max,
            min: config.minNumber, regroup: config.regroup);

      case QuizMode.placeValue:
        return _placeValue(max, config.minNumber, index);

      case QuizMode.divRemainder:
        final divisorMax = max.clamp(2, 9);
        final divisorMin = config.minNumber.clamp(2, divisorMax);
        final divisor =
            divisorMin + _random.nextInt(divisorMax - divisorMin + 1);
        final quotient = 1 + _random.nextInt(9);
        final rest = 1 + _random.nextInt(divisor - 1); // 1..divisor-1
        final total = divisor * quotient + rest;
        // 앞 단계는 나머지만, 뒤 단계는 몫을 묻기도 한다
        final askQuotient = max >= 6 && _random.nextInt(3) == 0;
        final answer = askQuotient ? quotient : rest;
        return Question(
          op: QuestionOp.remainder,
          left: answer,
          right: divisor,
          variant: askQuotient ? 1 : 0,
          prompt: askQuotient
              ? '$total ÷ $divisor = □ … $rest'
              : '$total ÷ $divisor = $quotient … □',
          promptSpeech: askQuotient
              ? '$total 나누기 $divisor, 나머지가 $rest일 때 몫은 얼마일까요?'
              : '$total 나누기 $divisor, 몫이 $quotient일 때 나머지는 얼마일까요?',
          choices: askQuotient
              ? _buildChoices(quotient, quotient + 2)
              : _buildRemainderChoices(rest, divisor),
          emoji: _emoji,
        );

      case QuizMode.storyAddSub:
        return _storyAddSub(max, config.minNumber, index);

      case QuizMode.storyMul:
        final lowTable = config.minNumber.clamp(2, max.clamp(2, 9));
        final table =
            lowTable + _random.nextInt(max.clamp(2, 9) - lowTable + 1);
        final times = 2 + _random.nextInt(8); // 2..9
        final item = _storyItem();
        final form = index % 2;
        return Question(
          op: QuestionOp.mul,
          left: table,
          right: times,
          variant: form,
          prompt: form == 0
              ? '${item.box} $times개에 ${item.emoji} ${item.name}${_josa(item.name, '이', '가')}\n$table개씩 들어 있어요.\n모두 몇 개일까요?'
              : '${item.emoji} ${item.name}${_josa(item.name, '을', '를')} $table개씩\n${_nativeNums[times]} 줄 놓았어요.\n모두 몇 개일까요?',
          promptSpeech: form == 0
              ? '${item.box} $times개에 ${item.name}${_josa(item.name, '이', '가')} $table개씩 들어 있어요. ${item.name}${_josa(item.name, '은', '는')} 모두 몇 개일까요?'
              : '${item.name}${_josa(item.name, '을', '를')} $table개씩 ${_nativeNums[times]} 줄 놓았어요. 모두 몇 개일까요?',
          choices: _buildChoices(table * times, table * times + 2),
          emoji: item.emoji,
        );

      case QuizMode.judge:
        return _judge(max, index, min: config.minNumber);

      case QuizMode.money:
        return _money(max, index);

      case QuizMode.length:
        return _length(max, index);

      case QuizMode.shapeSides:
        // 세모 → 네모 → 오각형·육각형, 원(꼭짓점 0개)도 섞는다
        final kinds = [0, 3, 4, if (max >= 5) 5, if (max >= 6) 6];
        final corners = kinds[_random.nextInt(kinds.length)];
        final askSides = _random.nextBool();
        final what = askSides ? '변' : '꼭짓점';
        return Question(
          op: QuestionOp.sides,
          left: corners,
          right: askSides ? 1 : 0,
          variant: askSides ? 1 : 0,
          sequence: [corners],
          prompt: '$what은 몇 개일까요?',
          promptSpeech: '이 도형의 $what은 몇 개일까요?',
          choices: _buildChoices(corners, 7),
          emoji: '',
        );

      case QuizMode.picGraph:
        return _picGraph(max, index);

      case QuizMode.unitConvert:
        return _unitConvert(max, index);

      case QuizMode.storyDiv:
        final divisorMax = max.clamp(2, 9);
        final divisorMin = config.minNumber.clamp(2, divisorMax);
        final divisor =
            divisorMin + _random.nextInt(divisorMax - divisorMin + 1);
        final quotient = 2 + _random.nextInt(8); // 2..9
        final total = divisor * quotient;
        final item = _storyItem();
        final share = index % 2 == 0; // 똑같이 나누기 ↔ 몇 개씩 묶기
        return Question(
          op: QuestionOp.div,
          left: total,
          right: divisor,
          variant: share ? 0 : 1,
          prompt: share
              ? '${item.emoji} ${item.name} $total개를\n친구 $divisor명이 똑같이 나누어 가지면\n한 명이 몇 개씩 가질까요?'
              : '${item.emoji} ${item.name} $total개를\n한 ${item.box}에 $divisor개씩 담으면\n${item.box}${_josa(item.box, '이', '가')} 몇 개 필요할까요?',
          promptSpeech: share
              ? '${item.name} $total개를 친구 $divisor명이 똑같이 나누어 가지면 한 명이 몇 개씩 가질까요?'
              : '${item.name} $total개를 한 ${item.box}에 $divisor개씩 담으면 ${item.box}${_josa(item.box, '이', '가')} 몇 개 필요할까요?',
          choices: _buildChoices(quotient, quotient + 2),
          emoji: item.emoji,
        );
    }
  }

  /// 돈: 동전(10·50·100·500원)과 지폐(1000원)를 세거나 거스름돈을 구한다
  Question _money(int max, int index) {
    final units = [10, 50, 100, if (max > 300) 500, if (max > 1000) 1000];
    // 거스름돈 문제는 큰 금액 묶음의 절반쯤
    if (max > 1000 && index.isOdd) {
      final paid = max > 1500 ? 2000 : 1000;
      final price = 100 * (1 + _random.nextInt(paid ~/ 100 - 1));
      final item = _storyItem();
      return Question(
        op: QuestionOp.money,
        left: paid - price,
        right: price,
        variant: 1,
        sequence: [paid],
        prompt:
            '${item.emoji} ${item.name} 값은 $price원이에요.\n$paid원을 내면\n거스름돈은 얼마일까요?',
        promptSpeech: '${item.name} 값은 $price원이에요. $paid원을 내면 거스름돈은 얼마일까요?',
        choices: _moneyChoices(paid - price, price: price),
        emoji: '',
      );
    }
    final coins = <int>[];
    var total = 0;
    final count = 2 + _random.nextInt(4); // 2..5개
    for (var i = 0; i < count; i++) {
      final fit = [
        for (final u in units)
          if (total + u <= max) u
      ];
      if (fit.isEmpty) break;
      final c = fit[_random.nextInt(fit.length)];
      coins.add(c);
      total += c;
    }
    coins.sort((a, b) => b.compareTo(a)); // 큰 돈부터 놓아야 세기 쉽다
    return Question(
      op: QuestionOp.money,
      left: total,
      right: 0,
      variant: 0,
      sequence: coins,
      prompt: '모두 얼마일까요?',
      promptSpeech: '돈을 모두 세면 얼마일까요?',
      choices: _moneyChoices(total),
      emoji: '',
    );
  }

  /// 맞을까 틀릴까: 20까지는 덧셈·뺄셈, 그 위는 곱셈구구 식을 보여 주고
  /// 맞는지 고른다. 틀린 식은 1~2 차이(덧뺄셈)나 한 단 차이(곱셈)로 그럴듯하게.
  Question _judge(int max, int index, {int min = 1}) {
    int a;
    int b;
    int op;
    int result;
    if (max > 20) {
      final top = (max ~/ 9).clamp(2, 9);
      a = 2 + _random.nextInt(top - 1);
      b = 1 + _random.nextInt(9);
      op = 2;
      result = a * b;
    } else {
      final base = _addSub(QuizMode.mixed, max, min: min);
      a = base.left;
      b = base.right;
      op = base.op == QuestionOp.add ? 0 : 1;
      result = base.answer;
    }
    final truth = _random.nextBool();
    var shown = result;
    if (!truth) {
      final deltas = op == 2 ? [a, -a, 1, -1] : [1, -1, 2, -2];
      final ok = [
        for (final d in deltas)
          if (result + d >= 0) result + d
      ];
      shown = ok[_random.nextInt(ok.length)];
    }
    return Question(
      op: QuestionOp.judge,
      left: truth ? 1 : 0,
      right: 0,
      variant: index,
      sequence: [a, b, shown, op],
      choices: [1, 0],
      emoji: '',
    );
  }

  /// 정답 + 일부러 고른 헷갈리는 오답들 (겹치거나 0 미만이면 가까운 수로 채움)
  List<int> _withDistractors(int answer, List<int> candidates) {
    final set = <int>{answer};
    for (final c in candidates) {
      if (set.length == 4) break;
      if (c >= 0) set.add(c);
    }
    var spread = 1;
    while (set.length < 4) {
      for (final c in [answer + spread, answer - spread]) {
        if (set.length < 4 && c >= 0) set.add(c);
      }
      spread++;
    }
    return set.toList()..shuffle(_random);
  }

  /// 돈 보기: 10원·50원·100원 차이처럼 실제로 헷갈리는 금액
  List<int> _moneyChoices(int answer, {int? price}) =>
      _withDistractors(answer, [
        // 값을 그대로 답하는 실수가 가장 흔하다
        if (price != null) price,
        for (final d in [10, -10, 50, -50, 100, -100, 500]..shuffle(_random))
          if (answer + d > 0 && d.abs() <= math.max(100, answer)) answer + d
      ]);

  /// 길이: 자 위의 막대 길이를 읽는다. 뒤 단계는 0이 아닌 눈금에서 시작한다.
  Question _length(int max, int index) {
    final rulerLength = max.clamp(5, 15);
    final len = 2 + _random.nextInt(rulerLength - 2); // 2..ruler-1
    final shifted = max >= 10 && index.isOdd;
    final start = shifted ? 1 + _random.nextInt(rulerLength - len) : 0;
    return Question(
      op: QuestionOp.length,
      left: len,
      right: start,
      variant: shifted ? 1 : 0,
      sequence: [start, start + len, rulerLength],
      prompt: '막대의 길이는 몇 cm일까요?',
      promptSpeech:
          shifted ? '막대가 0이 아닌 곳에서 시작해요. 길이는 몇 센티미터일까요?' : '막대의 길이는 몇 센티미터일까요?',
      // 끝 눈금을 그대로 읽는 실수(start+len)를 보기에 넣는다
      choices: shifted
          ? _withDistractors(len, [start + len, len + 1, len - 1])
          : _buildChoices(len, rulerLength),
      emoji: '',
    );
  }

  /// 그림그래프: 칸마다 그림 개수를 읽고, 가장 많은 것·차이를 구한다
  Question _picGraph(int max, int index) {
    final kinds = [..._storyItems]..shuffle(_random);
    final rows = max >= 7 ? 4 : 3;
    final top = max.clamp(4, 9);
    final counts = <int>[];
    while (counts.length < rows) {
      final c = 1 + _random.nextInt(top);
      if (!counts.contains(c)) counts.add(c); // 같은 개수가 없어야 '가장 많은'이 하나
    }
    final picked = kinds.take(rows).toList();
    final form = max >= 6 ? index % 3 : index % 2;
    int answer;
    String text;
    String speech;
    switch (form) {
      case 0:
        final i = _random.nextInt(rows);
        answer = counts[i];
        text =
            '${picked[i].emoji} ${picked[i].name}${_josa(picked[i].name, '은', '는')} 몇 개일까요?';
        speech = '${picked[i].name}${_josa(picked[i].name, '은', '는')} 몇 개일까요?';
      case 1:
        answer = counts.reduce(math.max);
        text = '가장 많은 것은 몇 개일까요?';
        speech = text;
      default:
        final big = counts.indexOf(counts.reduce(math.max));
        final small = counts.indexOf(counts.reduce(math.min));
        answer = counts[big] - counts[small];
        text =
            '${picked[big].name}${_josa(picked[big].name, '은', '는')} ${picked[small].name}보다\n몇 개 더 많을까요?';
        speech =
            '${picked[big].name}${_josa(picked[big].name, '은', '는')} ${picked[small].name}보다 몇 개 더 많을까요?';
    }
    return Question(
      op: QuestionOp.graph,
      left: answer,
      right: 0,
      variant: form,
      sequence: counts,
      shapeItems: [for (final p in picked) p.emoji],
      prompt: text, promptSpeech: speech.replaceAll('\n', ' '),
      // 차이 문제는 두 칸의 개수 자체를 답하는 실수를 보기에 넣는다
      choices: form == 2
          ? _withDistractors(
              answer, [counts.reduce(math.max), counts.reduce(math.min)])
          : _buildChoices(answer, top + 1),
      emoji: '',
    );
  }

  /// 단위 바꾸기 (초3·4): cm↔m, mm↔cm, g↔kg, mL↔L
  Question _unitConvert(int max, int index) {
    final kinds = [
      ('m', 'cm', 100, '미터', '센티미터'),
      ('cm', 'mm', 10, '센티미터', '밀리미터'),
      if (max >= 4) ('kg', 'g', 1000, '킬로그램', '그램'),
      if (max >= 6) ('L', 'mL', 1000, '리터', '밀리리터'),
    ];
    final k = kinds[_random.nextInt(kinds.length)];
    final big = 1 +
        _random.nextInt(math.min(
            max, 9)); // m·cm는 1~99 cm (1 m 5 cm처럼 한 자리도), mm는 1~9, g·mL는 100 단위
    final small = k.$3 == 10
        ? 1 + _random.nextInt(9)
        : k.$3 == 100
            ? 1 + _random.nextInt(99)
            : 100 * (1 + _random.nextInt(9));
    final total = big * k.$3 + small;
    final toSmall = max < 5 || index.isEven;
    final answer = toSmall ? total : big;
    return Question(
      op: QuestionOp.convert,
      left: answer,
      right: k.$3,
      variant: toSmall ? 0 : 1,
      prompt: toSmall
          ? '$big ${k.$1} $small ${k.$2}\n= □ ${k.$2}'
          : '$total ${k.$2}\n= □ ${k.$1} $small ${k.$2}',
      promptSpeech: toSmall
          ? '$big ${k.$4} $small ${k.$5}${_josa(k.$5, '은', '는')} 몇 ${k.$5}일까요?'
          : '$total ${k.$5}${_josa(k.$5, '은', '는')} 몇 ${k.$4} $small ${k.$5}일까요?',
      // 단위를 잘못 바꾼 수(× 10)를 보기에 넣는다
      choices: toSmall // 숫자를 이어 붙이는 실수(1 m 5 cm → 15), 자리를 잘못 맞춘 수, 그냥 더한 수
          ? _withDistractors(total, [
              int.parse('$big$small'),
              big * k.$3 * 10 + small,
              big + small,
              total + k.$3,
            ])
          : _buildChoices(big, 11),
      // 보기 뒤에 붙일 단위 (labelFor가 쓴다)
      emoji: toSmall ? k.$2 : k.$1,
    );
  }

  /// 이야기 문제에 나오는 물건 (그림·이름·담는 그릇)
  /// 모두 '개'로 세는 물건만 (물고기는 마리, 연필은 자루라 뺐다)
  static const _storyItems = [
    (emoji: '🍎', name: '사과', box: '바구니'),
    (emoji: '🍊', name: '귤', box: '바구니'),
    (emoji: '🍪', name: '쿠키', box: '접시'),
    (emoji: '🍬', name: '사탕', box: '봉지'),
    (emoji: '🍙', name: '주먹밥', box: '도시락'),
    (emoji: '🍩', name: '도넛', box: '상자'),
    (emoji: '🥚', name: '달걀', box: '상자'),
    (emoji: '🍓', name: '딸기', box: '접시'),
  ];

  /// 고유어 수 (두 줄, 세 줄 — '2줄'은 이 줄로 읽힌다)
  static const _nativeNums = [
    '',
    '한',
    '두',
    '세',
    '네',
    '다섯',
    '여섯',
    '일곱',
    '여덟',
    '아홉'
  ];

  ({String emoji, String name, String box}) _storyItem() =>
      _storyItems[_random.nextInt(_storyItems.length)];

  /// 받침에 맞는 조사 (사과가 / 연필이)
  static String _josa(String word, String withBatchim, String without) {
    final code = word.codeUnitAt(word.length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return without;
    return (code - 0xAC00) % 28 != 0 ? withBatchim : without;
  }

  static const _storyNames = ['하늘', '바다', '민준', '서연', '지우', '도윤'];

  /// 이야기 덧셈·뺄셈: 더 받기·모두·먹고 남기·더 많기
  Question _storyAddSub(int max, int min, int index) {
    final item = _storyItem();
    final name = _storyNames[_random.nextInt(_storyNames.length)];
    final who = '$name${_josa(name, '이는', '는')}';
    final n = item.name;
    final e = item.emoji;
    final low = min.clamp(2, max);
    final total = low + _random.nextInt(max - low + 1);
    // 판마다 순서가 달라야 '3번은 빼기'처럼 순서로 외우지 않는다
    final form = _random.nextInt(4);
    switch (form) {
      case 0: // 더 받기
        final a = 1 + _random.nextInt(total - 1);
        final b = total - a;
        return Question(
          op: QuestionOp.add,
          left: a,
          right: b,
          variant: form,
          prompt: '$who $e $a개를 가지고 있어요.\n$b개를 더 받았어요.\n모두 몇 개일까요?',
          promptSpeech:
              '$who $n${_josa(n, '을', '를')} $a개 가지고 있어요. $b개를 더 받았어요. 모두 몇 개일까요?',
          choices: _buildChoices(total, max),
          emoji: e,
        );
      case 1: // 둘을 모으기
        final a = 1 + _random.nextInt(total - 1);
        final b = total - a;
        return Question(
          op: QuestionOp.add,
          left: a,
          right: b,
          variant: form,
          prompt: '$e 바구니 하나에 $a개,\n다른 바구니에 $b개 있어요.\n모두 몇 개일까요?',
          promptSpeech:
              '$n${_josa(n, '이', '가')} 바구니 하나에 $a개, 다른 바구니에 $b개 있어요. 모두 몇 개일까요?',
          choices: _buildChoices(total, max),
          emoji: e,
        );
      case 2: // 먹고(주고) 남기
        final b = 1 + _random.nextInt(total - 1);
        return Question(
          op: QuestionOp.sub,
          left: total,
          right: b,
          variant: form,
          prompt: '$e $total개가 있었어요.\n친구에게 $b개를 주었어요.\n남은 것은 몇 개일까요?',
          promptSpeech:
              '$n${_josa(n, '이', '가')} $total개 있었어요. 친구에게 $b개를 주었어요. 남은 것은 몇 개일까요?',
          choices: _buildChoices(total - b, max),
          emoji: e,
        );
      default: // 몇 개 더 많을까 (비교)
        final b = 1 + _random.nextInt(total - 1);
        final others = [..._storyNames]
          ..remove(name)
          ..shuffle(_random);
        final other = others.first;
        return Question(
          op: QuestionOp.sub,
          left: total,
          right: b,
          variant: form,
          prompt:
              '$who $e $total개, $other${_josa(other, '이는', '는')} $b개 있어요.\n$name${_josa(name, '이가', '가')} 몇 개 더 많을까요?',
          promptSpeech:
              '$who $n $total개, $other${_josa(other, '이는', '는')} $b개 있어요. $name${_josa(name, '이가', '가')} 몇 개 더 많을까요?',
          choices: _buildChoices(total - b, max),
          emoji: e,
        );
    }
  }

  /// 자릿값: 모형 보고 수 쓰기 · 10이 몇 개 1이 몇 개 · 자리 숫자 찾기
  Question _placeValue(int max, int min, int index) {
    // 세 자리 묶음은 처음부터 세 자리 수만 (min이 55처럼 두 자리로 내려가지 않게)
    final low = max >= 100 ? min.clamp(100, max) : min.clamp(10, max);
    final n = low + _random.nextInt(max - low + 1);
    final h = n ~/ 100;
    final t = (n ~/ 10) % 10;
    final o = n % 10;
    final threeDigit = n >= 100;
    final form = index % 3;
    // 헷갈리기 쉬운 보기: 자리를 바꾼 수, 10 차이, 1 차이
    List<int> numberChoices() {
      final set = <int>{n};
      final swapped = threeDigit ? h * 100 + o * 10 + t : o * 10 + t;
      for (final c in [
        swapped,
        n + 10,
        n - 10,
        n + 1,
        n - 1,
        n + 100,
        n - 100
      ]) {
        if (set.length == 4) break;
        if (c > 0 && c != n && c < 1000) set.add(c);
      }
      return set.toList()..shuffle(_random);
    }

    switch (form) {
      case 0: // 모형 보고 수
        return Question(
          op: QuestionOp.place,
          left: n,
          right: 0,
          variant: 0,
          sequence: [h, t, o],
          prompt: '모두 얼마일까요?',
          promptSpeech: threeDigit
              ? '백 모형, 십 모형, 일 모형을 세어 보세요. 모두 얼마일까요?'
              : '십 모형과 일 모형을 세어 보세요. 모두 얼마일까요?',
          choices: numberChoices(),
          emoji: '',
        );
      case 1: // 10이 몇 개, 1이 몇 개
        // 화면은 '10이 3개', 읽기는 교과서 말투로 — '10이'는 '십이(12)'로 들린다
        final spoken = [
          if (h > 0) '백 모형 $h개',
          if (t > 0) threeDigit ? '십 모형 $t개' : '10개씩 묶음 $t개',
          if (o > 0) threeDigit ? '일 모형 $o개' : '낱개 $o개',
        ];
        return Question(
          op: QuestionOp.place,
          left: n,
          right: 0,
          variant: 1,
          prompt: placeValueText([h, t, o]).replaceFirst(', 1이', ',\n1이'),
          promptSpeech: '${spoken.join(', ')}${o > 0 ? '는' : '은'} 얼마일까요?',
          choices: numberChoices(),
          emoji: '',
        );
      default: // 자리 숫자 찾기
        final places = [
          if (threeDigit) ('백', h),
          ('십', t),
          ('일', o),
        ];
        final pick = places[_random.nextInt(places.length)];
        final digits = <int>{pick.$2, h, t, o}..removeWhere((d) => d < 0);
        while (digits.length < 4) {
          digits.add(_random.nextInt(10));
        }
        return Question(
          op: QuestionOp.place,
          left: pick.$2,
          right: n,
          variant: 2,
          prompt: '$n에서\n${pick.$1}의 자리 숫자는?',
          promptSpeech: '$n에서 ${pick.$1}의 자리 숫자는 무엇일까요?',
          choices: digits.take(4).toList()..shuffle(_random),
          emoji: '',
        );
    }
  }

  /// 나머지 보기: 나머지는 나누는 수보다 작다 — 0~divisor-1에서 고른다
  List<int> _buildRemainderChoices(int rest, int divisor) {
    final set = <int>{rest};
    final pool = [for (var i = 0; i < divisor; i++) i]..shuffle(_random);
    for (final c in pool) {
      if (set.length == 4) break;
      set.add(c);
    }
    var extra = divisor;
    while (set.length < 4) {
      set.add(extra++);
    }
    return set.toList()..shuffle(_random);
  }

  /// 덧셈/뺄셈/섞어서 문제 하나를 만든다.
  /// [min]은 난이도 하한: 덧셈의 합과 뺄셈의 처음 수가 이 값 아래로
  /// 내려가지 않아 뒤 단계에서 갑자기 쉬운 문제가 나오지 않는다.
  Question _addSub(QuizMode mode, int max,
      {int min = 1, bool regroup = false}) {
    final isAddition = switch (mode) {
      QuizMode.addition => true,
      QuizMode.subtraction => false,
      _ => _random.nextBool(),
    };

    final low = min.clamp(2, max);
    int left;
    int right;
    var tries = 0;
    do {
      if (isAddition) {
        // 합이 low..max 범위에 들어오게 한다.
        final sum = low + _random.nextInt(max - low + 1);
        left = 1 + _random.nextInt(sum - 1); // 1..sum-1
        right = sum - left;
      } else {
        // 처음 수를 low..max에서 뽑고, 답이 0 이상이 되게 뺀다.
        left = low + _random.nextInt(max - low + 1);
        right = 1 + _random.nextInt(left); // 1..left
      }
      // 받아올림 단원은 일의 자리끼리 10을 넘는(빌려 오는) 문제만
    } while (regroup && !_regroups(isAddition, left, right) && ++tries < 200);

    final answer = isAddition ? left + right : left - right;
    return Question(
      op: isAddition ? QuestionOp.add : QuestionOp.sub,
      left: left,
      right: right,
      choices: _buildChoices(answer, max),
      emoji: _emoji,
    );
  }

  /// 일의 자리에서 받아올림(덧셈)·받아내림(뺄셈)이 생기는지
  static bool _regroups(bool add, int left, int right) =>
      add ? left % 10 + right % 10 >= 10 : left % 10 < right % 10 && left >= 10;

  /// 정답 주변의 그럴듯한 오답 3개를 섞어 보기 4개를 만든다.
  /// 보기는 0 이상 [upper]+2 이하에서 고른다.
  List<int> _buildChoices(int answer, int upper, {int lower = 0}) {
    final choices = <int>{answer};
    var spread = 1;
    while (choices.length < 4) {
      final candidate = answer + (_random.nextBool() ? spread : -spread);
      if (candidate >= lower && candidate <= upper + 2) {
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
