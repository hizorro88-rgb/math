import 'curriculum.dart';
import 'daily.dart';
import 'korean_curriculum.dart';
import 'progress.dart';
import 'stats.dart';

/// 배지 판정에 쓰는 학습 기록 모음
class BadgeData {
  const BadgeData({
    required this.stats,
    required this.mathStars,
    required this.krStars,
    required this.points,
    required this.milestones,
  });

  final LearningStats stats;
  final List<int> mathStars;
  final List<int> krStars;
  final int points;

  /// 달성한 스트릭 마일스톤 일수들 (3, 7, 14, 30)
  final List<int> milestones;

  int get totalStars =>
      mathStars.fold(0, (a, b) => a + b) + krStars.fold(0, (a, b) => a + b);

  int get mathAnswered => stats.mathCorrect + stats.mathWrong;
  int get krAnswered => stats.krTotalCorrect + stats.krTotalWrong;
  int get enAnswered => stats.enTotalCorrect + stats.enTotalWrong;

  /// 모든 단계를 통과한 카테고리가 하나라도 있는지 (수학·한글)
  bool get anyCategoryCleared {
    for (final category in Curriculum.categories) {
      final levels = Curriculum.levels
          .where((l) => l.unit.category.index == category.index);
      if (levels.every((l) => mathStars[l.number - 1] >= 1)) return true;
    }
    for (final category in KoreanCurriculum.categories) {
      final levels = KoreanCurriculum.levels
          .where((l) => l.unit.category.index == category.index);
      if (levels.every((l) => krStars[l.number - 1] >= 1)) return true;
    }
    return false;
  }
}

/// 모으는 재미를 주는 배지
class LearnBadge {
  const LearnBadge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.desc,
    required this.earnedBy,
  });

  final String id;
  final String emoji;
  final String title;

  /// 어떻게 얻는지 안내 (잠긴 배지에 표시)
  final String desc;
  final bool Function(BadgeData) earnedBy;
}

final List<LearnBadge> allBadges = [
  LearnBadge(
    id: 'first_step',
    emoji: '🐣',
    title: '첫 걸음',
    desc: '문제 1개 풀기',
    earnedBy: (d) => d.stats.totalAnswered >= 1,
  ),
  LearnBadge(
    id: 'math_sprout',
    emoji: '✏️',
    title: '수학 새싹',
    desc: '수학 문제 50개 풀기',
    earnedBy: (d) => d.mathAnswered >= 50,
  ),
  LearnBadge(
    id: 'math_tree',
    emoji: '🧮',
    title: '수학 나무',
    desc: '수학 문제 300개 풀기',
    earnedBy: (d) => d.mathAnswered >= 300,
  ),
  LearnBadge(
    id: 'kr_sprout',
    emoji: '📖',
    title: '한글 새싹',
    desc: '한글 문제 50개 풀기',
    earnedBy: (d) => d.krAnswered >= 50,
  ),
  LearnBadge(
    id: 'kr_tree',
    emoji: '📚',
    title: '한글 나무',
    desc: '한글 문제 300개 풀기',
    earnedBy: (d) => d.krAnswered >= 300,
  ),
  LearnBadge(
    id: 'stars30',
    emoji: '⭐',
    title: '별 부자',
    desc: '별 30개 모으기',
    earnedBy: (d) => d.totalStars >= 30,
  ),
  LearnBadge(
    id: 'stars100',
    emoji: '🌟',
    title: '별 왕',
    desc: '별 100개 모으기',
    earnedBy: (d) => d.totalStars >= 100,
  ),
  LearnBadge(
    id: 'category_master',
    emoji: '🎓',
    title: '카테고리 정복',
    desc: '한 카테고리의 모든 단계 통과하기',
    earnedBy: (d) => d.anyCategoryCleared,
  ),
  LearnBadge(
    id: 'points1000',
    emoji: '🪙',
    title: '부자 부엉이',
    desc: '누적 점수 1000점 모으기',
    earnedBy: (d) => d.points >= 1000,
  ),
  LearnBadge(
    id: 'streak7',
    emoji: '🔥',
    title: '일주일 개근',
    desc: '7일 연속 출석하기',
    earnedBy: (d) => d.milestones.contains(7),
  ),
  LearnBadge(
    id: 'streak30',
    emoji: '🏅',
    title: '한 달 개근',
    desc: '30일 연속 출석하기',
    earnedBy: (d) => d.milestones.contains(30),
  ),
  LearnBadge(
    id: 'kr_first',
    emoji: '📝',
    title: '한글과 인사',
    desc: '한글 문제 1개 풀기',
    earnedBy: (d) => d.krAnswered >= 1,
  ),
  LearnBadge(
    id: 'en_first',
    emoji: '🔤',
    title: '영어와 인사',
    desc: '영어 문제 1개 풀기',
    earnedBy: (d) => d.enAnswered >= 1,
  ),
  LearnBadge(
    id: 'en_sprout',
    emoji: '🌍',
    title: '영어 새싹',
    desc: '영어 문제 50개 풀기',
    earnedBy: (d) => d.enAnswered >= 50,
  ),
  LearnBadge(
    id: 'ja_first',
    emoji: '🎌',
    title: '일본어와 인사',
    desc: '일본어 문제 1개 풀기',
    earnedBy: (d) => d.stats.langAnswered('ja') >= 1,
  ),
  LearnBadge(
    id: 'zh_first',
    emoji: '🀄',
    title: '중국어와 인사',
    desc: '중국어 문제 1개 풀기',
    earnedBy: (d) => d.stats.langAnswered('zh') >= 1,
  ),
  LearnBadge(
    id: 'advanced_sprout',
    emoji: '📙',
    title: '심화 새싹',
    desc: '분수·소수·시간 계산 문제 10개 풀기',
    earnedBy: (d) =>
        d.stats.fractionCorrect +
            d.stats.fractionWrong +
            d.stats.decimalCorrect +
            d.stats.decimalWrong +
            d.stats.timeCorrect +
            d.stats.timeWrong >=
        10,
  ),
];

/// 지금까지의 기록을 불러와 배지 판정에 쓴다.
Future<BadgeData> loadBadgeData() async => BadgeData(
      stats: await StatsStore.load(),
      mathStars: await ProgressStore.load(),
      krStars: await KoreanProgressStore.load(),
      points: await ProgressStore.loadPoints(),
      milestones: await DailyStore.claimedMilestones(),
    );
