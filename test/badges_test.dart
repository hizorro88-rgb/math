import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/badges.dart';
import 'package:preschool_math/models/curriculum.dart';
import 'package:preschool_math/models/daily.dart';
import 'package:preschool_math/models/english_question.dart';
import 'package:preschool_math/models/korean_curriculum.dart';
import 'package:preschool_math/models/korean_question.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/stats.dart';
import 'package:shared_preferences/shared_preferences.dart';

LearningStats _stats(
        {int addCorrect = 0, List<int>? krCorrect, List<int>? enCorrect}) =>
    LearningStats(
      addCorrect: addCorrect,
      addWrong: 0,
      subCorrect: 0,
      subWrong: 0,
      countCorrect: 0,
      countWrong: 0,
      mulCorrect: 0,
      mulWrong: 0,
      divCorrect: 0,
      divWrong: 0,
      compareCorrect: 0,
      compareWrong: 0,
      patternCorrect: 0,
      patternWrong: 0,
      clockCorrect: 0,
      clockWrong: 0,
      bandCorrect: const [0, 0, 0, 0],
      bandWrong: const [0, 0, 0, 0],
      krCorrect:
          krCorrect ?? List.filled(KrQuizType.values.length, 0),
      krWrong: List.filled(KrQuizType.values.length, 0),
      enCorrect:
          enCorrect ?? List.filled(EnQuizType.values.length, 0),
      enWrong: List.filled(EnQuizType.values.length, 0),
      recentDays: const [],
    );

BadgeData _data({
  LearningStats? stats,
  List<int>? mathStars,
  List<int>? krStars,
  int points = 0,
  List<int> milestones = const [],
}) =>
    BadgeData(
      stats: stats ?? _stats(),
      mathStars: mathStars ?? List.filled(Curriculum.totalLevels, 0),
      krStars: krStars ?? List.filled(KoreanCurriculum.totalLevels, 0),
      points: points,
      milestones: milestones,
    );

LearnBadge _badge(String id) => allBadges.firstWhere((b) => b.id == id);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  group('배지 판정', () {
    test('아무 기록이 없으면 배지가 없다', () {
      final data = _data();
      for (final badge in allBadges) {
        expect(badge.earnedBy(data), isFalse, reason: badge.id);
      }
    });

    test('문제 풀이·별·점수 배지', () {
      expect(_badge('first_step').earnedBy(_data(stats: _stats(addCorrect: 1))),
          isTrue);
      expect(_badge('math_sprout').earnedBy(_data(stats: _stats(addCorrect: 50))),
          isTrue);
      expect(
        _badge('kr_first').earnedBy(_data(
            stats: _stats(
                krCorrect: [1, ...List.filled(KrQuizType.values.length - 1, 0)]))),
        isTrue,
      );
      expect(
        _badge('en_first').earnedBy(_data(
            stats: _stats(
                enCorrect: [1, ...List.filled(EnQuizType.values.length - 1, 0)]))),
        isTrue,
      );
      final stars = List.filled(Curriculum.totalLevels, 0);
      for (var i = 0; i < 10; i++) {
        stars[i] = 3;
      }
      expect(_badge('stars30').earnedBy(_data(mathStars: stars)), isTrue);
      expect(_badge('points1000').earnedBy(_data(points: 1200)), isTrue);
      expect(_badge('streak7').earnedBy(_data(milestones: [3, 7])), isTrue);
      expect(_badge('streak30').earnedBy(_data(milestones: [3, 7])), isFalse);
    });

    test('카테고리 정복: 한 카테고리의 모든 단계를 통과하면 얻는다', () {
      final stars = List.filled(Curriculum.totalLevels, 0);
      final firstCategory = Curriculum.categories.first;
      for (final level in Curriculum.levels) {
        if (level.unit.category.index == firstCategory.index) {
          stars[level.number - 1] = 1;
        }
      }
      expect(_badge('category_master').earnedBy(_data(mathStars: stars)),
          isTrue);
      // 하나라도 빠지면 아직
      stars[firstCategory.firstLevelNumber - 1] = 0;
      expect(_badge('category_master').earnedBy(_data(mathStars: stars)),
          isFalse);
    });

    test('실제 기록에서 배지 데이터를 불러온다 (마일스톤 포함)', () async {
      // 3일 연속 출석해 마일스톤 3을 만든다.
      final day1 = DateTime(2026, 7, 26, 10);
      for (var i = 0; i < 3; i++) {
        await DailyStore.recordRound(
            correctCount: 1, stars: 0, now: day1.add(Duration(days: i)));
      }
      final data = await loadBadgeData();
      expect(data.milestones, contains(3));
    });
  });
}
