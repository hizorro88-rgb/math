import 'english_question.dart';
import 'korean_question.dart';
import 'language_packs.dart';
import 'quiz_config.dart';
import 'stats.dart';

/// 맞춤 복습 제안: 통계에서 가장 어려워한 유형 하나를 골라
/// 홈 배너에서 바로 한 판 풀 수 있게 한다.
class ReviewSuggestion {
  const ReviewSuggestion({
    required this.emoji,
    required this.label,
    required this.subject,
    required this.accuracy,
    this.mathMode,
    this.krType,
    this.enType,
    this.packId,
    this.langTypeIndex = 0,
  });

  final String emoji;
  final String label;

  /// '수학' 같은 과목 이름 (배너 문구용)
  final String subject;
  final int accuracy;

  /// 아래 중 하나만 채워진다 — 어느 화면으로 보낼지 결정
  final QuizMode? mathMode;
  final KrQuizType? krType;
  final EnQuizType? enType;
  final String? packId;
  final int langTypeIndex;
}

class Review {
  /// 이만큼은 풀어 봐야 복습 대상으로 본다 (한두 판의 우연 제외)
  static const minAnswered = 8;

  /// 정답률이 이보다 높으면 굳이 복습을 권하지 않는다
  static const maxAccuracy = 79;

  /// 모든 과목·유형 중 가장 정답률이 낮은 하나를 고른다. 없으면 null.
  static ReviewSuggestion? suggest(LearningStats stats) {
    ReviewSuggestion? best;
    var bestAccuracy = maxAccuracy + 1;

    void consider(
        int correct, int wrong, ReviewSuggestion Function(int) make) {
      final total = correct + wrong;
      if (total < minAnswered) return;
      final accuracy = correct * 100 ~/ total;
      if (accuracy < bestAccuracy) {
        bestAccuracy = accuracy;
        best = make(accuracy);
      }
    }

    // 수학: 유형별 저장 칸이 있는 연산들
    final mathBuckets = <(int, int, QuizMode)>[
      (stats.addCorrect, stats.addWrong, QuizMode.addition),
      (stats.subCorrect, stats.subWrong, QuizMode.subtraction),
      (stats.countCorrect, stats.countWrong, QuizMode.counting),
      (stats.mulCorrect, stats.mulWrong, QuizMode.multiplication),
      (stats.divCorrect, stats.divWrong, QuizMode.division),
      (stats.compareCorrect, stats.compareWrong, QuizMode.compare),
      (stats.patternCorrect, stats.patternWrong, QuizMode.pattern),
      (stats.clockCorrect, stats.clockWrong, QuizMode.clock),
      (stats.fractionCorrect, stats.fractionWrong, QuizMode.fraction),
      (stats.decimalCorrect, stats.decimalWrong, QuizMode.decimal),
      (stats.timeCorrect, stats.timeWrong, QuizMode.timeCalc),
    ];
    for (final (correct, wrong, mode) in mathBuckets) {
      consider(
        correct,
        wrong,
        (acc) => ReviewSuggestion(
          emoji: mode.emoji,
          label: mode.label,
          subject: '수학',
          accuracy: acc,
          mathMode: mode,
        ),
      );
    }

    for (final type in KrQuizType.values) {
      consider(
        stats.krCorrect[type.index],
        stats.krWrong[type.index],
        (acc) => ReviewSuggestion(
          emoji: type.emoji,
          label: type.label,
          subject: '한글',
          accuracy: acc,
          krType: type,
        ),
      );
    }

    for (final type in EnQuizType.values) {
      consider(
        stats.enCorrect[type.index],
        stats.enWrong[type.index],
        (acc) => ReviewSuggestion(
          emoji: type.emoji,
          label: type.label,
          subject: '영어',
          accuracy: acc,
          enType: type,
        ),
      );
    }

    for (final pack in languagePacks) {
      final correct = stats.langCorrect[pack.id];
      final wrong = stats.langWrong[pack.id];
      if (correct == null || wrong == null) continue;
      for (var i = 0; i < pack.types.length; i++) {
        if (i >= correct.length || i >= wrong.length) continue;
        final type = pack.types[i];
        final typeIndex = i;
        consider(
          correct[i],
          wrong[i],
          (acc) => ReviewSuggestion(
            emoji: type.emoji,
            label: type.label,
            subject: pack.name,
            accuracy: acc,
            packId: pack.id,
            langTypeIndex: typeIndex,
          ),
        );
      }
    }

    return best;
  }
}
