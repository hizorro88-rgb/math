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
  division('나눗셈', '➗');

  const QuizMode(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// 자유 연습에서 고르는 난이도: 답이 최대 몇까지 나오는지
enum Difficulty {
  easy('쉬워요', '5까지', 5),
  normal('보통이에요', '10까지', 10);

  const Difficulty(this.label, this.description, this.maxNumber);

  final String label;
  final String description;
  final int maxNumber;
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
