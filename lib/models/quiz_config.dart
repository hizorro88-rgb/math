/// 퀴즈 종류: 덧셈, 뺄셈, 섞어서
enum QuizMode {
  addition('덧셈', '➕'),
  subtraction('뺄셈', '➖'),
  mixed('섞어서', '🎲');

  const QuizMode(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// 난이도: 답이 최대 몇까지 나오는지
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
    required this.difficulty,
    this.questionCount = 10,
  });

  final QuizMode mode;
  final Difficulty difficulty;
  final int questionCount;
}
