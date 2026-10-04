import 'package:flutter/material.dart';

import '../models/english_curriculum.dart';
import '../models/english_question.dart';
import '../models/korean_curriculum.dart';
import '../models/korean_question.dart';
import '../models/language_packs.dart';
import '../models/progress.dart';
import '../models/stats.dart';
import 'quiz_screen.dart';
import 'language_quiz_screen.dart';
import 'korean_quiz_screen.dart';
import 'english_quiz_screen.dart';
import '../models/review.dart';
import '../models/quiz_config.dart';
import '../models/profile.dart';
import '../theme.dart';

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
      appBar: AppBar(
        title: const Text('학습 리포트'),
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
              // 맨 위: 보호자가 이번 주에 할 일 하나 (잘한 것 하나 · 연습할 것 하나)
              _WeeklyTodoCard(stats: stats),
              const SizedBox(height: 14),
              _SummaryCard(stats: stats, clearedLevels: clearedLevels),
              const SizedBox(height: 14),
              _WeekCard(stats: stats),
              const SizedBox(height: 14),
              // 과목별 정답률: 기록이 있는 과목만 카드로 보여준다.
              // 아무것도 없으면 빈 카드 5장 대신 안내 1장으로 접는다.
              if (stats.totalAnswered == 0) ...[
                _reportCard(
                  title: '과목별 정답률',
                  child: const Text(
                    '첫 퀴즈를 풀면 과목별 리포트가 열려요!\n'
                    '홈에서 과목 탭을 골라 시작해 보세요.',
                    style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
                  ),
                ),
                const SizedBox(height: 14),
              ] else ...[
                if (stats.mathCorrect + stats.mathWrong > 0) ...[
                  _AccuracyCard(stats: stats),
                  const SizedBox(height: 14),
                ],
                if (stats.krTotalCorrect + stats.krTotalWrong > 0) ...[
                  _KoreanCard(stats: stats),
                  const SizedBox(height: 14),
                ],
                if (stats.enTotalCorrect + stats.enTotalWrong > 0) ...[
                  _EnglishCard(stats: stats),
                  const SizedBox(height: 14),
                ],
                for (final pack in languagePacks)
                  if (!pack.forAdults && stats.langAnswered(pack.id) > 0) ...[
                    _LangCard(pack: pack, stats: stats),
                    const SizedBox(height: 14),
                  ],
                // 어른 과정은 아이 기록과 섞지 않고 맨 아래 따로
                for (final pack in languagePacks)
                  if (pack.forAdults && stats.langAnswered(pack.id) > 0) ...[
                    const Padding(
                      padding: EdgeInsets.only(left: 4, bottom: 8),
                      child: Text('👨‍👩‍👧 어른 공부',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                    _LangCard(pack: pack, stats: stats),
                    const SizedBox(height: 14),
                  ],
              ],
              _AdviceCard(stats: stats),
              const SizedBox(height: 8),
            ],
          );
        },
      ),
    );
  }
}

Widget _reportCard({required String title, required Widget child}) {
  // 정보 카드 = 테두리 (앱 공용 규칙)
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(22),
      border: Border.all(color: AppColors.outline, width: 2),
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
      title: '전체 요약',
      child: Row(
        children: [
          _SummaryItem(
              icon: Icons.edit_rounded,
              value: '${stats.totalAnswered}',
              label: '푼 문제'),
          _SummaryItem(
            icon: Icons.track_changes_rounded,
            value: accuracy == null ? '없음' : '$accuracy%',
            label: '정답률',
          ),
          _SummaryItem(
              icon: Icons.flag_rounded,
              value: '$clearedLevels',
              label: '통과한 단계'),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.icon,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 26, color: AppColors.green),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: AppColors.inkSoft),
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
    final hasAny = stats.recentDays.any((d) => d.rounds > 0);

    if (!hasAny) {
      return _reportCard(
        title: '최근 7일 활동',
        child: const Text(
          '이번 주 첫 기록을 기다리고 있어요!\n퀴즈 한 판이 끝나면 막대가 자라나요.',
          style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
      );
    }

    return _reportCard(
      title: '최근 7일 활동',
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
                            color: AppColors.greenPressed,
                          ),
                        ),
                      const SizedBox(height: 2),
                      Container(
                        height: day.rounds == 0
                            ? 6
                            : 12 + 58.0 * day.rounds / maxRounds,
                        decoration: BoxDecoration(
                          color: day.rounds == 0
                              ? AppColors.line
                              : AppColors.green,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // 'MM-DD' 중 일(day)만 표시
                        day.day.substring(8),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.inkSoft,
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
      ('🍕 분수', stats.fractionCorrect, stats.fractionWrong),
      ('💧 소수', stats.decimalCorrect, stats.decimalWrong),
      ('⏱️ 시간 계산', stats.timeCorrect, stats.timeWrong),
      for (var i = 0; i < statBandNames.length; i++)
        ('📏 ${statBandNames[i]}', stats.bandCorrect[i], stats.bandWrong[i]),
    ];

    final learned = rows.where((r) => r.$2 + r.$3 > 0).toList();
    final unlearnedCount = rows.length - learned.length;

    return _reportCard(
      title: '🧮 수학 정답률',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (learned.isEmpty)
            const Text(
              '아직 수학 퀴즈를 풀지 않았어요.\n홈에서 🧮 수학 탭을 눌러 시작해 보세요!',
              style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
            )
          else
            for (final (label, correct, wrong) in learned) ...[
              _AccuracyRow(label: label, correct: correct, wrong: wrong),
              const SizedBox(height: 10),
            ],
          if (learned.isNotEmpty && unlearnedCount > 0)
            Text(
              '아직 안 배운 유형 $unlearnedCount개는 배우면 나타나요.',
              style: const TextStyle(fontSize: 12, color: AppColors.inkMuted),
            ),
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
              backgroundColor: AppColors.line,
              color: accuracy == null
                  ? AppColors.inkMuted
                  : accuracy >= 80
                      ? AppColors.green
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
                ? '미학습'
                : '$accuracy% ($correct/${correct + wrong})',
            textAlign: TextAlign.right,
            maxLines: 1,
            style: const TextStyle(fontSize: 12, color: AppColors.inkSoft),
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
        child: const Text(
          '아직 한글 퀴즈를 풀지 않았어요.\n홈에서 📖 한글 탭을 눌러 시작해 보세요!',
          style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
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
        child: const Text(
          '아직 영어 퀴즈를 풀지 않았어요.\n홈에서 🔤 영어 탭을 눌러 시작해 보세요!',
          style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
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

/// 언어 팩(일본어·중국어…) 유형별 정답률
class _LangCard extends StatelessWidget {
  const _LangCard({required this.pack, required this.stats});

  final LanguagePack pack;
  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    final correct =
        stats.langCorrect[pack.id] ?? List.filled(pack.types.length, 0);
    final wrong = stats.langWrong[pack.id] ?? List.filled(pack.types.length, 0);
    final title = '${pack.emoji} ${pack.name} 정답률';

    if (stats.langAnswered(pack.id) == 0) {
      return _reportCard(
        title: title,
        child: Text(
          '아직 ${pack.name} 퀴즈를 풀지 않았어요.\n'
          '홈에서 ${pack.emoji} ${pack.name} 탭을 눌러 시작해 보세요!',
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
      );
    }
    return _reportCard(
      title: title,
      child: Column(
        children: [
          for (var i = 0; i < pack.types.length; i++) ...[
            _AccuracyRow(
              label: '${pack.types[i].emoji} ${pack.types[i].shortLabel}',
              correct: correct[i],
              wrong: wrong[i],
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
      (
        '큰 수 찾기',
        LearningStats.accuracy(stats.compareCorrect, stats.compareWrong)
      ),
      (
        '규칙 찾기',
        LearningStats.accuracy(stats.patternCorrect, stats.patternWrong)
      ),
      ('시계 보기', LearningStats.accuracy(stats.clockCorrect, stats.clockWrong)),
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
      for (final pack in languagePacks)
        for (var i = 0; i < pack.types.length; i++)
          (
            '${pack.name} ${pack.types[i].shortLabel}',
            LearningStats.accuracy(
                (stats.langCorrect[pack.id] ?? const []).elementAtOrNull(i) ??
                    0,
                (stats.langWrong[pack.id] ?? const []).elementAtOrNull(i) ?? 0),
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

/// 이번 주 할 일 — 보호자가 리포트를 열자마자 "그래서 뭘 하면 되나"를 본다.
/// 잘한 것 하나(칭찬해 주기) + 연습할 것 하나(▶ 바로 한 판). 5문제 이상 푼 유형만.
class _WeeklyTodoCard extends StatelessWidget {
  const _WeeklyTodoCard({required this.stats});

  final LearningStats stats;

  void _practice(BuildContext context, ReviewSuggestion s) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) {
      if (s.krType != null) return KoreanQuizScreen(type: s.krType!);
      if (s.enType != null) return EnglishQuizScreen(type: s.enType!);
      if (s.packId != null) {
        return LanguageQuizScreen(
          pack: languagePackById(s.packId!),
          typeIndex: s.langTypeIndex,
        );
      }
      final mode = s.mathMode!;
      final max =
          mode == QuizMode.multiplication || mode == QuizMode.division ? 9 : 10;
      return QuizScreen(config: QuizConfig(mode: mode, maxNumber: max));
    }));
  }

  @override
  Widget build(BuildContext context) {
    final all = Review.all(stats, min: 5);
    final good = Review.strongest(stats);
    ReviewSuggestion? weak;
    for (final s in all) {
      if (s.accuracy >= 80) continue;
      if (weak == null || s.accuracy < weak.accuracy) weak = s;
    }
    return FutureBuilder<Profile>(
      future: Profiles.active(),
      builder: (context, snap) {
        final p = snap.data;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.rewardSurface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.amber, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${p == null ? '' : '${p.emoji} ${p.name} · '}이번 주 할 일',
                style: displayStyle(fontSize: 20),
              ),
              const SizedBox(height: 12),
              if (good == null && weak == null)
                const Text(
                  '아직 기록이 적어요. 하루 한 판씩 풀면 여기에 '
                  '잘한 것과 연습할 것이 나와요.',
                  style: TextStyle(fontSize: 14, color: AppColors.inkSoft),
                ),
              if (good != null)
                _line(
                    '👍 잘해요',
                    '${good.subject} ${good.emoji} ${good.label} ${good.accuracy}%'
                        ' — 칭찬해 주세요'),
              if (weak != null) ...[
                const SizedBox(height: 8),
                _line('💪 연습해요',
                    '${weak.subject} ${weak.emoji} ${weak.label} ${weak.accuracy}%'),
                const SizedBox(height: 10),
                FilledButton.icon(
                  key: const ValueKey('report-practice'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.green,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () => _practice(context, weak!),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text('${weak.label} 한 판 같이 풀기',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _line(String head, String body) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 84,
            child: Text(head,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(body,
                style: const TextStyle(fontSize: 15, color: AppColors.ink)),
          ),
        ],
      );
}
