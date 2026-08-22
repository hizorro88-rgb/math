import 'package:flutter/material.dart';

import '../services/reminders.dart';

import '../models/english_curriculum.dart';
import '../models/english_question.dart';
import '../models/korean_curriculum.dart';
import '../models/korean_question.dart';
import '../models/progress.dart';
import '../models/stats.dart';

/// 부모용 학습 리포트: 이번 주 활동, 유형·수 범위별 정답률, 연습 추천.
class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  late final Future<(LearningStats, List<int>, List<int>, List<int>)>
      _dataFuture = _loadData();

  static Future<(LearningStats, List<int>, List<int>, List<int>)>
      _loadData() async => (
            await StatsStore.load(),
            await ProgressStore.load(),
            await KoreanProgressStore.load(),
            await EnglishProgressStore.load(),
          );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2EC4B6),
        foregroundColor: Colors.white,
        title: const Text(
          '학습 리포트',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder<(LearningStats, List<int>, List<int>, List<int>)>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final (stats, levelStars, krStars, enStars) = data;
          // 통과한 단계는 수학 + 한글 + 영어 합계
          final clearedLevels = levelStars.where((s) => s >= 1).length +
              krStars.where((s) => s >= 1).length +
              enStars.where((s) => s >= 1).length;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(stats: stats, clearedLevels: clearedLevels),
              const SizedBox(height: 14),
              _WeekCard(stats: stats),
              const SizedBox(height: 14),
              _AccuracyCard(stats: stats),
              const SizedBox(height: 14),
              _KoreanCard(stats: stats),
              const SizedBox(height: 14),
              _EnglishCard(stats: stats),
              const SizedBox(height: 14),
              _AdviceCard(stats: stats),
              const SizedBox(height: 14),
              const _ReminderCard(),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

Widget _reportCard({required String title, required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          offset: const Offset(0, 4),
          blurRadius: 10,
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

/// 전체 요약: 푼 문제 수, 전체 정답률, 통과한 단계 수
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.stats, required this.clearedLevels});

  final LearningStats stats;
  final int clearedLevels;

  @override
  Widget build(BuildContext context) {
    final accuracy =
        LearningStats.accuracy(stats.totalCorrect, stats.totalWrong);

    return _reportCard(
      title: '📋 전체 요약',
      child: Row(
        children: [
          _SummaryItem(
              emoji: '✏️', value: '${stats.totalAnswered}', label: '푼 문제'),
          _SummaryItem(
            emoji: '🎯',
            value: accuracy == null ? '-' : '$accuracy%',
            label: '정답률',
          ),
          _SummaryItem(emoji: '🗺️', value: '$clearedLevels', label: '통과한 단계'),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.emoji,
    required this.value,
    required this.label,
  });

  final String emoji;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 24)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

/// 최근 7일 동안 하루에 몇 판 풀었는지 막대로 보여준다.
class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.stats});

  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    final maxRounds = stats.recentDays
        .map((d) => d.rounds)
        .fold<int>(1, (m, r) => r > m ? r : m);

    return _reportCard(
      title: '📅 최근 7일 활동',
      child: SizedBox(
        height: 110,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final day in stats.recentDays)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (day.rounds > 0)
                        Text(
                          '${day.rounds}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF58A700),
                          ),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: day.rounds == 0
                            ? 6
                            : 12 + 58.0 * day.rounds / maxRounds,
                        decoration: BoxDecoration(
                          color: day.rounds == 0
                              ? Colors.grey.shade200
                              : const Color(0xFF58CC02),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // 'MM-DD' 중 일(day)만 표시
                        day.day.substring(8),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 덧셈/뺄셈, 수 범위별 정답률 막대
class _AccuracyCard extends StatelessWidget {
  const _AccuracyCard({required this.stats});

  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    final rows = <(String, int, int)>[
      ('➕ 덧셈', stats.addCorrect, stats.addWrong),
      ('➖ 뺄셈', stats.subCorrect, stats.subWrong),
      ('🔢 수 세기', stats.countCorrect, stats.countWrong),
      ('✖️ 곱셈', stats.mulCorrect, stats.mulWrong),
      ('➗ 나눗셈', stats.divCorrect, stats.divWrong),
      ('⚖️ 큰 수', stats.compareCorrect, stats.compareWrong),
      ('🧩 규칙', stats.patternCorrect, stats.patternWrong),
      ('🕒 시계', stats.clockCorrect, stats.clockWrong),
      for (var i = 0; i < statBandNames.length; i++)
        ('📏 ${statBandNames[i]}', stats.bandCorrect[i], stats.bandWrong[i]),
    ];

    return _reportCard(
      title: '🧮 수학 정답률',
      child: Column(
        children: [
          for (final (label, correct, wrong) in rows) ...[
            _AccuracyRow(label: label, correct: correct, wrong: wrong),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _AccuracyRow extends StatelessWidget {
  const _AccuracyRow({
    required this.label,
    required this.correct,
    required this.wrong,
  });

  final String label;
  final int correct;
  final int wrong;

  @override
  Widget build(BuildContext context) {
    final accuracy = LearningStats.accuracy(correct, wrong);

    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: accuracy == null ? 0 : accuracy / 100,
              minHeight: 10,
              backgroundColor: Colors.grey.shade200,
              color: accuracy == null
                  ? Colors.grey
                  : accuracy >= 80
                      ? const Color(0xFF58CC02)
                      : accuracy >= 50
                          ? const Color(0xFFFF9600)
                          : const Color(0xFFFF4B4B),
            ),
          ),
        ),
        SizedBox(
          width: 84,
          child: Text(
            accuracy == null
                ? '아직 안 풀었어요'
                : '$accuracy% ($correct/${correct + wrong})',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
        ),
      ],
    );
  }
}

/// 한글 유형별 정답률
class _KoreanCard extends StatelessWidget {
  const _KoreanCard({required this.stats});

  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.krTotalCorrect + stats.krTotalWrong == 0) {
      return _reportCard(
        title: '📖 한글 정답률',
        child: Text(
          '아직 한글 퀴즈를 풀지 않았어요.\n홈에서 📖 한글 탭을 눌러 시작해 보세요!',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      );
    }
    return _reportCard(
      title: '📖 한글 정답률',
      child: Column(
        children: [
          for (final type in KrQuizType.values) ...[
            _AccuracyRow(
              label: '${type.emoji} ${type.shortLabel}',
              correct: stats.krCorrect[type.index],
              wrong: stats.krWrong[type.index],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// 영어 유형별 정답률
class _EnglishCard extends StatelessWidget {
  const _EnglishCard({required this.stats});

  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    if (stats.enTotalCorrect + stats.enTotalWrong == 0) {
      return _reportCard(
        title: '🔤 영어 정답률',
        child: Text(
          '아직 영어 퀴즈를 풀지 않았어요.\n홈에서 🔤 영어 탭을 눌러 시작해 보세요!',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
      );
    }
    return _reportCard(
      title: '🔤 영어 정답률',
      child: Column(
        children: [
          for (final type in EnQuizType.values) ...[
            _AccuracyRow(
              label: '${type.emoji} ${type.shortLabel}',
              correct: stats.enCorrect[type.index],
              wrong: stats.enWrong[type.index],
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

/// 정답률이 가장 낮은 영역을 찾아 연습을 추천한다.
class _AdviceCard extends StatelessWidget {
  const _AdviceCard({required this.stats});

  final LearningStats stats;

  String get _advice {
    if (stats.totalAnswered < 10) {
      return '아직 데이터가 부족해요. 퀴즈를 몇 판 더 풀면 맞춤 추천을 드릴게요!';
    }

    final candidates = <(String, int?)>[
      ('덧셈', LearningStats.accuracy(stats.addCorrect, stats.addWrong)),
      ('뺄셈', LearningStats.accuracy(stats.subCorrect, stats.subWrong)),
      ('수 세기', LearningStats.accuracy(stats.countCorrect, stats.countWrong)),
      ('곱셈', LearningStats.accuracy(stats.mulCorrect, stats.mulWrong)),
      ('나눗셈', LearningStats.accuracy(stats.divCorrect, stats.divWrong)),
      ('큰 수 찾기',
          LearningStats.accuracy(stats.compareCorrect, stats.compareWrong)),
      ('규칙 찾기',
          LearningStats.accuracy(stats.patternCorrect, stats.patternWrong)),
      ('시계 보기',
          LearningStats.accuracy(stats.clockCorrect, stats.clockWrong)),
      for (var i = 0; i < statBandNames.length; i++)
        (
          '${statBandNames[i]} 수',
          LearningStats.accuracy(stats.bandCorrect[i], stats.bandWrong[i]),
        ),
      for (final type in KrQuizType.values)
        (
          '한글 ${type.shortLabel}',
          LearningStats.accuracy(
              stats.krCorrect[type.index], stats.krWrong[type.index]),
        ),
      for (final type in EnQuizType.values)
        (
          '영어 ${type.shortLabel}',
          LearningStats.accuracy(
              stats.enCorrect[type.index], stats.enWrong[type.index]),
        ),
    ];
    (String, int)? weakest;
    for (final (name, acc) in candidates) {
      if (acc == null) continue;
      if (weakest == null || acc < weakest.$2) weakest = (name, acc);
    }
    if (weakest == null) return '꾸준히 잘하고 있어요!';
    if (weakest.$2 >= 85) {
      return '전체적으로 아주 잘하고 있어요! 다음 단계에 도전해 보세요 👏';
    }
    return '${weakest.$1} 문제가 조금 어려운가 봐요 (정답률 ${weakest.$2}%). '
        '자유 연습에서 ${weakest.$1} 위주로 연습해 보면 좋아요!';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F7F5),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF2EC4B6), width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _advice,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0B7A70),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 매일 학습 알림 켜고 끄기 (부모 설정)
class _ReminderCard extends StatefulWidget {
  const _ReminderCard();

  @override
  State<_ReminderCard> createState() => _ReminderCardState();
}

class _ReminderCardState extends State<_ReminderCard> {
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    Reminders.isEnabled().then((value) {
      if (mounted) setState(() => _enabled = value);
    });
  }

  Future<void> _toggle(bool value) async {
    if (value) {
      final ok = await Reminders.enable();
      if (!mounted) return;
      setState(() => _enabled = ok);
      if (!ok) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('알림 권한이 필요해요. 기기 설정에서 허용해 주세요.'),
            duration: Duration(seconds: 2),
          ));
      }
    } else {
      await Reminders.disable();
      if (mounted) setState(() => _enabled = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Row(
        children: [
          const Text('🔔', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '매일 학습 알림',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  '켠 시각쯤에 하루 한 번 "부엉이가 기다려요"',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          Switch(
            value: _enabled,
            activeTrackColor: const Color(0xFF58CC02),
            onChanged: _toggle,
          ),
        ],
      ),
    );
  }
}
