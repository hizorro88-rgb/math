import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/korean_question.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/quiz_config.dart';
import 'package:preschool_math/models/review.dart';
import 'package:preschool_math/models/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<LearningStats> _statsFrom(Map<String, Object> values) async {
  SharedPreferences.setMockInitialValues(values);
  return StatsStore.load();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Profiles.activeId = 1;
  });

  test('가장 정답률이 낮은 유형을 고른다', () async {
    final stats = await _statsFrom({
      'stats_add_correct_v1': 9, 'stats_add_wrong_v1': 1, // 90%
      'stats_sub_correct_v1': 4, 'stats_sub_wrong_v1': 6, // 40% ← 최저
      'stats_kr_correct_v1': '7,0,0,0,0,0,0,0,0,0',
      'stats_kr_wrong_v1': '3,0,0,0,0,0,0,0,0,0', // 70%
    });
    final review = Review.suggest(stats)!;
    expect(review.mathMode, QuizMode.subtraction);
    expect(review.subject, '수학');
    expect(review.accuracy, 40);
  });

  test('조금만 풀어 본 유형은 복습 대상이 아니다', () async {
    final stats = await _statsFrom({
      // 7문제(기준 8개 미만)라 우연일 수 있다 → 제외
      'stats_sub_correct_v1': 1, 'stats_sub_wrong_v1': 6,
    });
    expect(Review.suggest(stats), isNull);
  });

  test('모든 유형을 잘하면 복습을 권하지 않는다', () async {
    final stats = await _statsFrom({
      'stats_add_correct_v1': 20, 'stats_add_wrong_v1': 1,
      'stats_kr_correct_v1': '18,0,0,0,0,0,0,0,0,0',
      'stats_kr_wrong_v1': '2,0,0,0,0,0,0,0,0,0', // 90%
    });
    expect(Review.suggest(stats), isNull);
  });

  test('한글·언어 팩 유형도 고를 수 있다', () async {
    final krStats = await _statsFrom({
      'stats_kr_correct_v1': '0,0,3,0,0,0,0,0,0,0',
      'stats_kr_wrong_v1': '0,0,7,0,0,0,0,0,0,0', // 모음 소리 30%
    });
    final krReview = Review.suggest(krStats)!;
    expect(krReview.krType, KrQuizType.listenVowel);
    expect(krReview.subject, '한글');

    final jaStats = await _statsFrom({
      'stats_lang_ja_correct_v1': '2,0,0,0,0,0,0,0,0',
      'stats_lang_ja_wrong_v1': '8,0,0,0,0,0,0,0,0', // 20%
    });
    final jaReview = Review.suggest(jaStats)!;
    expect(jaReview.packId, 'ja');
    expect(jaReview.langTypeIndex, 0);
    expect(jaReview.subject, '일본어');
  });
}
