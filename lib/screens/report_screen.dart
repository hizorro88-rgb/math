import 'package:flutter/material.dart';


import '../models/english_curriculum.dart';
import '../models/english_question.dart';
import '../models/korean_curriculum.dart';
import '../models/korean_question.dart';
import '../models/language_packs.dart';
import '../models/progress.dart';
import '../models/stats.dart';
import 'backup_screen.dart';
import 'settings_screen.dart';

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
              // 과목별 정답률: 기록이 있는 과목만 카드로 보여준다.
              // 아무것도 없으면 빈 카드 5장 대신 안내 1장으로 접는다.
              if (stats.totalAnswered == 0) ...[
                _reportCard(
                  title: '과목별 정답률',
                  child: Text(
                    '첫 퀴즈를 풀면 과목별 리포트가 열려요!\n'
                    '홈에서 과목 탭을 골라 시작해 보세요.',
                    style:
                        TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                  if (stats.langAnswered(pack.id) > 0) ...[
                    _LangCard(pack: pack, stats: stats),
                    const SizedBox(height: 14),
                  ],
              ],
              _AdviceCard(stats: stats),
              const SizedBox(height: 14),
              const _ReminderCard(),
              const SizedBox(height: 14),
              const _BackupCard(),
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
          Icon(icon, size: 26, color: const Color(0xFF3DA35D)),
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
    final hasAny = stats.recentDays.any((d) => d.rounds > 0);

    if (!hasAny) {
      return _reportCard(
        title: '최근 7일 활동',
        child: Text(
          '이번 주 첫 기록을 기다리고 있어요!\n퀴즈 한 판이 끝나면 막대가 자라나요.',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
                            color: Color(0xFF2E7D46),
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
                              : const Color(0xFF3DA35D),
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
            Text(
              '아직 수학 퀴즈를 풀지 않았어요.\n홈에서 🧮 수학 탭을 눌러 시작해 보세요!',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            )
          else
            for (final (label, correct, wrong) in learned) ...[
              _AccuracyRow(label: label, correct: correct, wrong: wrong),
              const SizedBox(height: 10),
            ],
          if (learned.isNotEmpty && unlearnedCount > 0)
            Text(
              '아직 안 배운 유형 $unlearnedCount개는 배우면 나타나요.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
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
              backgroundColor: Colors.grey.shade200,
              color: accuracy == null
                  ? Colors.grey
                  : accuracy >= 80
                      ? const Color(0xFF3DA35D)
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

/// 언어 팩(일본어·중국어…) 유형별 정답률
class _LangCard extends StatelessWidget {
  const _LangCard({required this.pack, required this.stats});

  final LanguagePack pack;
  final LearningStats stats;

  @override
  Widget build(BuildContext context) {
    final correct = stats.langCorrect[pack.id] ??
        List.filled(pack.types.length, 0);
    final wrong =
        stats.langWrong[pack.id] ?? List.filled(pack.types.length, 0);
    final title = '${pack.emoji} ${pack.name} 정답률';

    if (stats.langAnswered(pack.id) == 0) {
      return _reportCard(
        title: title,
        child: Text(
          '아직 ${pack.name} 퀴즈를 풀지 않았어요.\n'
          '홈에서 ${pack.emoji} ${pack.name} 탭을 눌러 시작해 보세요!',
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
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
      for (final pack in languagePacks)
        for (var i = 0; i < pack.types.length; i++)
          (
            '${pack.name} ${pack.types[i].shortLabel}',
            LearningStats.accuracy(
                (stats.langCorrect[pack.id] ?? const [])
                    .elementAtOrNull(i) ??
                    0,
                (stats.langWrong[pack.id] ?? const []).elementAtOrNull(i) ??
                    0),
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

/// 매일 학습 알림: 켜고 끄기는 설정 화면 한 곳에서만 (중복 토글 방지)
class _ReminderCard extends StatelessWidget {
  const _ReminderCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        leading: const Text('🔔', style: TextStyle(fontSize: 26)),
        title: const Text(
          '매일 학습 알림',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '설정 → 부모님 메뉴에서 켜고 꺼요',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        ),
      ),
    );
  }
}

/// 진도 백업/// 진도 백업·복원 안내 카드 → 백업 화면으로 이동
class _BackupCard extends StatelessWidget {
  const _BackupCard();

  @override
  Widget build(BuildContext context) {
    return _reportCard(
      title: '💾 진도 백업·옮기기',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '백업 코드를 만들어 두면 앱을 지웠거나 폰을 바꿔도\n진도·별·코인을 그대로 되살릴 수 있어요.',
            style: TextStyle(fontSize: 13.5, height: 1.5, color: Colors.black54),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF3DA35D),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const BackupScreen()),
              ),
              child: const Text(
                '백업 화면 열기',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
