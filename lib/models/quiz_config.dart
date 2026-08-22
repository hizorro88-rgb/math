/// 퀴즈 종류: 덧셈, 뺄셈, 섞어서, 수 세기, 곱셈, 나눗셈
enum QuizMode {
  addition('덧셈', '➕'),
  subtraction('뺄셈', '➖'),
  mixed('섞어서', '🎲'),

  /// 그림 개수를 세는 모드 (덧셈 이전 단계, 더 어린 아이용)
  counting('수 세기', '🔢'),

  /// 곱셈구구 (초등 2학년~)
  multiplication('곱셈', '✖️'),

  /// 곱셈구구를 거꾸로 푸는 나눗셈 (초등 3학년~)
  division('나눗셈', '➗'),

  /// 세로셈 덧셈: 일의 자리·십의 자리를 이해하며 자리마다 답을 채운다
  verticalAdd('세로 덧셈', '🧮'),

  /// 세로셈 뺄셈
  verticalSub('세로 뺄셈', '📝'),

  /// 빈칸 채우기: 3 + □ = 7 처럼 가려진 수를 찾는다 (거꾸로 연산)
  fillBlank('빈칸 채우기', '❓'),

  /// 10 만들기: 몇을 더해야 10이 되는지 찾는다 (받아올림의 준비 운동)
  makeTen('10 만들기', '🔟'),

  /// 여러 수 중에서 가장 큰(작은) 수를 고른다
  compare('큰 수 찾기', '⚖️'),

  /// 뛰어 세기 규칙을 찾아 다음 수를 고른다 (2, 4, 6, ?)
  pattern('규칙 찾기', '🧩'),

  /// 식을 보여주지 않고 소리로만 들려주는 암산 연습
  listen('듣고 풀기', '👂'),

  /// 아날로그 시계를 읽는다 (정각, 몇 시)
  clock('시계 보기', '🕒'),

  /// 섞여 있는 모양 중에서 특정 모양의 개수를 센다 (도형 구분 + 세기)
  shapeCount('모양 세기', '🔺');

  const QuizMode(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// 자유 연습에서 고르는 난이도: 답이 최대 몇까지 나오는지
enum Difficulty {
  easy('쉬워요', '5까지', 5, '🐣'),
  normal('보통이에요', '10까지', 10, '🐥'),
  hard('어려워요', '20까지', 20, '🦉'),
  expert('최고 도전', '100까지', 100, '🚀');

  const Difficulty(this.label, this.description, this.maxNumber, this.emoji);

  final String label;
  final String description;
  final int maxNumber;
  final String emoji;
}

/// 한 판의 설정
class QuizConfig {
  const QuizConfig({
    required this.mode,
    required this.maxNumber,
    this.questionCount = 10,
  });

  final QuizMode mode;

  /// 답(그리고 피연산자)이 넘지 않는 최대값
  final int maxNumber;
  final int questionCount;
}
