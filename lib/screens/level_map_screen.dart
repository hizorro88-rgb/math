import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/curriculum.dart';
import '../models/daily.dart';
import '../models/english_curriculum.dart';
import '../models/korean_curriculum.dart';
import '../models/language_packs.dart';
import '../models/premium.dart';
import '../models/profile.dart';
import '../models/progress.dart';
import '../models/review.dart';
import '../models/shop.dart';
import '../models/stickers.dart';
import '../models/stats.dart';
import '../models/wrong_notes.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/owl_avatar.dart';
import '../widgets/parent_gate.dart';
import '../models/boss.dart';
import '../models/quiz_config.dart';
import 'badge_screen.dart';
import 'category_screen.dart';
import 'english_category_screen.dart';
import 'english_quiz_screen.dart';
import 'korean_category_screen.dart';
import 'korean_quiz_screen.dart';
import 'language_category_screen.dart';
import 'language_quiz_screen.dart';
import 'onboarding_screen.dart';
import 'pass_screen.dart';
import 'practice_screen.dart';
import 'profile_screen.dart';
import 'quiz_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'sticker_book_screen.dart';
import 'wrong_notes_screen.dart';

/// 홈 화면: 마스코트 인사, 칭호 카드, 오늘의 미션,
/// 그리고 나이·학년별(4살~초3) 학습 카테고리.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key});

  @override
  State<LevelMapScreen> createState() => _LevelMapScreenState();
}

class _MapData {
  const _MapData({
    required this.stars,
    required this.krStars,
    required this.enStars,
    required this.langStars,
    required this.points,
    required this.coins,
    required this.equipped,
    required this.daily,
    required this.profile,
    required this.recommendedCategory,
    required this.bossCleared,
    required this.hasPass,
    required this.review,
    required this.wrongCount,
    required this.stickerTickets,
  });

  final List<int> stars;
  final List<int> krStars;
  final List<int> enStars;

  /// 언어 팩별 별 목록 (languagePacks 순서)
  final List<List<int>> langStars;
  final int points;
  final int coins;
  final List<ShopItem> equipped;
  final DailyState daily;
  final Profile profile;

  /// 온보딩에서 고른 나이에 맞는 수학 카테고리 (없으면 null)
  final int? recommendedCategory;

  /// 이번 주 보스전을 이미 클리어했는지
  final bool bossCleared;

  /// 가족 이용권 보유 여부 (없으면 각 과목 첫 카테고리만 열림)
  final bool hasPass;

  /// 요즘 어려워한 유형이 있으면 맞춤 복습 제안 (없으면 null)
  final ReviewSuggestion? review;

  /// 오답 노트에 쌓인 문제 수
  final int wrongCount;

  /// 아직 스티커북에 안 붙인 스티커 수
  final int stickerTickets;
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  late Future<_MapData> _dataFuture;

  /// 지금 보고 있는 과목 (0: 수학, 1: 한글, 2: 영어, 3~: 언어 팩)
  int _subject = 0;

  /// 과목 탭 정보 (뒤쪽은 languagePacks 순서)
  static final List<(String, String)> _subjects = [
    ('🧮', '수학'),
    ('📖', '한글'),
    ('🔤', '영어'),
    for (final pack in languagePacks) (pack.emoji, pack.name),
  ];
  static const _subjectKey = 'subject_v2';
  static const _subjectKeyOld = 'subject_korean_v1'; // 예전 한글/수학 토글

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
    _loadSubject();
  }

  Future<void> _loadSubject() async {
    final prefs = await SharedPreferences.getInstance();
    var subject = prefs.getInt(Profiles.scoped(_subjectKey));
    subject ??=
        (prefs.getBool(Profiles.scoped(_subjectKeyOld)) ?? false) ? 1 : 0;
    if (mounted && subject != _subject) setState(() => _subject = subject!);
  }

  Future<void> _setSubject(int subject) async {
    setState(() => _subject = subject);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(Profiles.scoped(_subjectKey), subject);
  }

  Future<_MapData> _load() async {
    final prefs = await SharedPreferences.getInstance();
    return _MapData(
      stars: await ProgressStore.load(),
      krStars: await KoreanProgressStore.load(),
      enStars: await EnglishProgressStore.load(),
      langStars: [
        for (final pack in languagePacks) await LangProgressStore.load(pack),
      ],
      points: await ProgressStore.loadPoints(),
      coins: await ProgressStore.loadCoins(),
      equipped: await ShopStore.loadEquipped(),
      daily: await DailyStore.load(),
      profile: await Profiles.active(),
      recommendedCategory:
          prefs.getInt(Profiles.scoped(OnboardingScreen.ageCategoryKey)),
      bossCleared: await BossStore.isClearedThisWeek(),
      hasPass: await PremiumStore.hasPass(),
      review: Review.suggest(await StatsStore.load()),
      wrongCount: await WrongNoteStore.count(),
      stickerTickets: await StickerStore.tickets(),
    );
  }

  /// 잠긴 카테고리면 부모 확인 뒤 이용권 화면을 열고 false를 돌려준다.
  Future<bool> _checkAccess(int categoryIndex) async {
    if (PremiumStore.isCategoryFree(categoryIndex)) return true;
    if (await PremiumStore.hasPass()) return true;
    if (!mounted) return false;
    final ok = await checkParentGate(context);
    if (!ok || !mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PassScreen()),
    );
    _refresh();
    return false;
  }

  Future<void> _openBoss(bool cleared) async {
    if (cleared) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(
          content: Text('이번 주 보스전은 벌써 클리어했어요! 다음 주에 또 만나요 👑'),
          duration: Duration(seconds: 2),
        ));
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const QuizScreen(
          config: QuizConfig(mode: QuizMode.mixed, maxNumber: 10),
          bossMode: true,
        ),
      ),
    );
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _dataFuture = _load();
    });
    _loadSubject(); // 프로필이 바뀌면 그 아이가 보던 과목으로
  }

  /// 맞춤 복습: 어려워한 유형의 연습 한 판을 바로 연다 (단계 진행과 무관)
  Future<void> _openReview(ReviewSuggestion review) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) {
          if (review.krType != null) {
            return KoreanQuizScreen(type: review.krType!);
          }
          if (review.enType != null) {
            return EnglishQuizScreen(type: review.enType!);
          }
          if (review.packId != null) {
            return LanguageQuizScreen(
              pack: languagePackById(review.packId!),
              typeIndex: review.langTypeIndex,
            );
          }
          final mode = review.mathMode!;
          // 구구단은 표 범위(9까지)에 맞춘다.
          final maxNumber = mode == QuizMode.multiplication ||
                  mode == QuizMode.division
              ? 9
              : 10;
          return QuizScreen(
              config: QuizConfig(mode: mode, maxNumber: maxNumber));
        },
      ),
    );
    _refresh();
  }

  Future<void> _openCategory(AgeCategory category) async {
    if (!await _checkAccess(category.index)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => CategoryScreen(category: category)),
    );
    _refresh();
  }

  Future<void> _buyFreeze() async {
    final ok = await DailyStore.buyFreeze();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(ok
            ? '🛡️ 스트릭 지킴이를 샀어요! 하루 걸러도 스트릭이 이어져요'
            : '코인이 부족하거나 이미 충분히 갖고 있어요'),
        duration: const Duration(seconds: 2),
      ));
    if (ok) _refresh();
  }

  Future<void> _openKoreanCategory(KrCategory category) async {
    if (!await _checkAccess(category.index)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => KoreanCategoryScreen(category: category)),
    );
    _refresh();
  }

  Future<void> _openEnglishCategory(EnCategory category) async {
    if (!await _checkAccess(category.index)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => EnglishCategoryScreen(category: category)),
    );
    _refresh();
  }

  Future<void> _openLangCategory(
      LanguagePack pack, LangCategory category) async {
    if (!await _checkAccess(category.index)) return;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) =>
              LanguageCategoryScreen(pack: pack, category: category)),
    );
    _refresh();
  }

  Future<void> _openPractice() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PracticeScreen()),
    );
    _refresh();
  }

  Future<void> _openShop() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ShopScreen()),
    );
    _refresh();
  }

  void _openBadges() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BadgeScreen()),
    );
  }

  Future<void> _openStickerBook() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StickerBookScreen()),
    );
    _refresh(); // 붙인 스티커·보너스 코인 반영
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
    if (mounted) setState(() {}); // 소리 설정이 바뀌었을 수 있다
  }

  Future<void> _openProfiles() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _refresh(); // 프로필이 바뀌면 진행도·코인 등을 다시 불러온다.
  }

  /// 오늘 활동에 따라 부엉이 인사말이 달라진다.
  String _greetingFor(_MapData data) {
    // 기본 이름("우리 아이")이면 호칭이 어색하지 않게 "친구"로 부른다.
    final name = data.profile.name == '우리 아이' ? '친구' : data.profile.name;
    final daily = data.daily;
    if (daily.rounds >= 3) {
      return '$name, 오늘 벌써\n${daily.rounds}판이나 풀었어! 🎉';
    }
    if (daily.rounds >= 1) {
      return '$name, 좋아!\n오늘 미션까지 가 보자 🎯';
    }
    if (daily.streak >= 3) {
      return '$name, ${daily.streak}일째\n함께라니 최고야! 🔥';
    }
    final hour = DateTime.now().hour;
    if (hour < 12) return '$name, 좋은 아침이야!\n부기랑 놀면서 배우자!';
    if (hour < 18) return '$name, 오늘도 왔구나!\n부기가 기다렸어!';
    return '$name, 자기 전에\n한 판 어때? 부엉!';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_MapData>(
        future: _dataFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          if (data == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final stars = data.stars;
          // 별 합계는 전 과목
          final totalStars = data.stars.fold<int>(0, (sum, s) => sum + s) +
              data.krStars.fold<int>(0, (sum, s) => sum + s) +
              data.enStars.fold<int>(0, (sum, s) => sum + s) +
              [for (final l in data.langStars) ...l]
                  .fold<int>(0, (sum, s) => sum + s);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                title: '부엉이 학교',
                greeting: _greetingFor(data),
                totalStars: totalStars,
                coins: data.coins,
                equipped: data.equipped,
                profile: data.profile,
                onOwlTap: _openShop,
                onProfileTap: _openProfiles,
                onSettingsTap: _openSettings,
                onSoundChanged: () => setState(() {}),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── 1. 배우기: 과목을 고르면 바로 밑 카테고리가 바뀐다 ──
                    const _SectionTitle('📚 배우기'),
                    // 과목 고르기: 탭 폭을 4.5개가 보이게 맞춰서
                    // 오른쪽에 과목이 더 있다는 것이 눈에 띄게 한다.
                    SizedBox(
                      height: 56,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final tabWidth =
                              (constraints.maxWidth - 8 * 4) / 4.5;
                          return ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _subjects.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) => SizedBox(
                              width: tabWidth,
                              child: _SubjectTab(
                                emoji: _subjects[i].$1,
                                label: _subjects[i].$2,
                                selected: _subject == i,
                                onTap: () => _setSubject(i),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 고른 과목의 카테고리를 골라 들어간다.
                    if (_subject == 1)
                      for (final category in KoreanCurriculum.categories) ...[
                        _CategoryCard(
                          emoji: category.emoji,
                          title: category.title,
                          desc: category.desc,
                          color: category.color,
                          cleared: KoreanCurriculum.levels
                              .where((l) =>
                                  l.unit.category.index == category.index &&
                                  data.krStars[l.number - 1] >= 1)
                              .length,
                          total: category.totalLevels,
                          locked: !data.hasPass && category.index > 0,
                          onTap: () => _openKoreanCategory(category),
                        ),
                        const SizedBox(height: 12),
                      ]
                    else if (_subject == 2)
                      for (final category in EnglishCurriculum.categories) ...[
                        _CategoryCard(
                          emoji: category.emoji,
                          title: category.title,
                          desc: category.desc,
                          color: category.color,
                          cleared: EnglishCurriculum.levels
                              .where((l) =>
                                  l.unit.category.index == category.index &&
                                  data.enStars[l.number - 1] >= 1)
                              .length,
                          total: category.totalLevels,
                          locked: !data.hasPass && category.index > 0,
                          onTap: () => _openEnglishCategory(category),
                        ),
                        const SizedBox(height: 12),
                      ]
                    else if (_subject >= 3)
                      for (final category
                          in languagePacks[_subject - 3].categories) ...[
                        _CategoryCard(
                          emoji: category.emoji,
                          title: category.title,
                          desc: category.desc,
                          color: category.color,
                          cleared: languagePacks[_subject - 3]
                              .levels
                              .where((l) =>
                                  l.unit.category.index == category.index &&
                                  data.langStars[_subject - 3]
                                          [l.number - 1] >=
                                      1)
                              .length,
                          total: category.totalLevels,
                          locked: !data.hasPass && category.index > 0,
                          onTap: () => _openLangCategory(
                              languagePacks[_subject - 3], category),
                        ),
                        const SizedBox(height: 12),
                      ]
                    else
                      for (final category in Curriculum.categories) ...[
                        _CategoryCard(
                          emoji: category.emoji,
                          title: category.title,
                          desc: category.desc,
                          color: category.color,
                          cleared: Curriculum.levels
                              .where((l) =>
                                  l.unit.category.index == category.index &&
                                  stars[l.number - 1] >= 1)
                              .length,
                          total: category.totalLevels,
                          recommended:
                              data.recommendedCategory == category.index,
                          locked: !data.hasPass && category.index > 0,
                          onTap: () => _openCategory(category),
                        ),
                        const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 10),
                    // ── 2. 오늘의 도전: 매일 한 번씩 들르는 것들 ──
                    const _SectionTitle('🔥 오늘의 도전'),
                    _DailyCard(
                        daily: data.daily,
                        coins: data.coins,
                        onBuyFreeze: _buyFreeze),
                    const SizedBox(height: 14),
                    // 주간 보스전
                    BouncyButton(
                      color: data.bossCleared
                          ? Colors.white
                          : const Color(0xFFFFF6D8),
                      shadowColor: data.bossCleared
                          ? Colors.grey.shade300
                          : const Color(0xFFFFD34D),
                      borderRadius: 22,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      onTap: () => _openBoss(data.bossCleared),
                      child: Row(
                        children: [
                          const Text('👑', style: TextStyle(fontSize: 30)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '주간 보스전',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  data.bossCleared
                                      ? '이번 주 클리어! 다음 주에 또 만나요 ✅'
                                      : '여러 유형 섞어 12문제 · 통과하면 +100 🪙',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 맞춤 복습: 요즘 어려워한 유형을 한 판 더
                    if (data.review != null) ...[
                      BouncyButton(
                        color: const Color(0xFFF3E8FF),
                        shadowColor: const Color(0xFFD8B4FE),
                        borderRadius: 22,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        onTap: () => _openReview(data.review!),
                        child: Row(
                          children: [
                            const Text('🩹', style: TextStyle(fontSize: 30)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    '맞춤 복습',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '${data.review!.subject} ${data.review!.emoji} '
                                    '${data.review!.label} · 조금 어려웠죠? 한 판 더!',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(Icons.chevron_right, color: Colors.grey),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    // 오답 노트: 자리를 고정해 두고(위치 기억),
                    // 틀린 게 쌓였을 때만 분홍으로 눈에 띄게 한다.
                    BouncyButton(
                      color: data.wrongCount > 0
                          ? const Color(0xFFFDE8F4)
                          : Colors.white,
                      shadowColor: data.wrongCount > 0
                          ? const Color(0xFFF2A9D4)
                          : Colors.grey.shade300,
                      borderRadius: 22,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const WrongNotesScreen()),
                        );
                        _refresh();
                      },
                      child: Row(
                        children: [
                          const Text('📒', style: TextStyle(fontSize: 30)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '오답 노트',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  data.wrongCount > 0
                                      ? '틀린 낱말 ${data.wrongCount}개 · 맞히면 노트에서 사라져요'
                                      : '지금은 비어 있어요 · 틀린 문제가 생기면 여기 모여요',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // 자유 연습: 단계와 무관한 학습이라 도전 묶음에 둔다.
                    BouncyButton(
                      color: Colors.white,
                      shadowColor: Colors.grey.shade300,
                      borderRadius: 22,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 14),
                      onTap: _openPractice,
                      child: Row(
                        children: [
                          const Text('🎨', style: TextStyle(fontSize: 30)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '자유 연습',
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  '단계와 상관없이 하고 싶은 것만 골라 연습해요',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: Colors.grey),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // ── 3. 모으기·꾸미기: 보상 구경 ──
                    const _SectionTitle('🎁 모으기·꾸미기'),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                              child: _MenuCard(
                            emoji: '🛍️',
                            title: '꾸미기 가게',
                            subtitle: '부엉이 꾸미기',
                            onTap: _openShop,
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _MenuCard(
                            emoji: '📔',
                            title: '스티커북',
                            subtitle: data.stickerTickets > 0
                                ? '🎟️ ${data.stickerTickets}장!'
                                : '골라 붙이기',
                            onTap: _openStickerBook,
                          )),
                          const SizedBox(width: 10),
                          Expanded(
                              child: _MenuCard(
                            emoji: '🏅',
                            title: '배지 도감',
                            subtitle: '모은 배지',
                            onTap: _openBadges,
                          )),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _RankCard(points: data.points),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// 초록 그라데이션 헤더: 꾸며진 부엉이가 인사하고 별·코인을 보여준다.
/// 부엉이를 누르면 꾸미기 가게로 간다.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.greeting,
    required this.totalStars,
    required this.coins,
    required this.equipped,
    required this.profile,
    required this.onOwlTap,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onSoundChanged,
  });

  final String title;
  final String greeting;
  final int totalStars;
  final int coins;
  final List<ShopItem> equipped;
  final Profile profile;
  final VoidCallback onOwlTap;
  final VoidCallback onProfileTap;
  final VoidCallback onSettingsTap;
  final VoidCallback onSoundChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF57BE78), AppColors.green],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      child: Stack(
        children: [
          // 숲속 학교 배경: 구름과 언덕
          Positioned.fill(
            child: ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(32)),
              child: CustomPaint(painter: _HeaderScenePainter()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
            child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  title,
                  style: displayStyle(fontSize: 26, color: Colors.white),
                ),
                const Spacer(),
                // 프로필 바꾸기
                GestureDetector(
                  onTap: onProfileTap,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                    child: Text(
                      '${profile.emoji} ${profile.name}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                // 한 번에 전부 끄기/켜기 (효과음+읽어주기)
                IconButton(
                  onPressed: () async {
                    final anyOn = Sounds.enabled || Speech.enabled;
                    await Sounds.setEnabled(!anyOn);
                    await Speech.setEnabled(!anyOn);
                    onSoundChanged();
                  },
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Sounds.enabled || Speech.enabled
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                IconButton(
                  onPressed: onSettingsTap,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.settings_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                GestureDetector(
                  onTap: onOwlTap,
                  child: _OwlBounce(
                    child: OwlAvatar(size: 68, equipped: equipped),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // 말풍선 꼬리
                      Positioned(
                        left: -5,
                        top: 20,
                        child: Transform.rotate(
                          angle: 0.785,
                          child: Container(
                            width: 12,
                            height: 12,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          greeting,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _StatChip(text: '⭐ $totalStars'),
                const SizedBox(width: 10),
                _StatChip(text: '🪙 $coins'),
              ],
            ),
          ],
        ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 헤더 배경: 구름 두 점과 겹친 언덕 — "부엉이 학교"의 앞마당
class _HeaderScenePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cloud = Paint()..color = Colors.white.withValues(alpha: 0.35);
    void drawCloud(double cx, double cy, double r) {
      canvas.drawCircle(Offset(cx, cy), r, cloud);
      canvas.drawCircle(Offset(cx + r * 1.1, cy + r * 0.25), r * 0.75, cloud);
      canvas.drawCircle(Offset(cx - r * 1.0, cy + r * 0.3), r * 0.65, cloud);
    }

    // 상단 버튼 줄(약 0.3h)과 겹치지 않게 아래쪽 빈 하늘에만 띄운다.
    drawCloud(size.width * 0.86, size.height * 0.48, 12);
    drawCloud(size.width * 0.64, size.height * 0.72, 9);

    // 뒷 언덕
    final back = Paint()..color = Colors.white.withValues(alpha: 0.10);
    final backPath = Path()
      ..moveTo(0, size.height)
      ..quadraticBezierTo(
          size.width * 0.3, size.height * 0.62, size.width * 0.62, size.height)
      ..close();
    canvas.drawPath(backPath, back);

    // 앞 언덕
    final front = Paint()..color = Colors.white.withValues(alpha: 0.14);
    final frontPath = Path()
      ..moveTo(size.width * 0.35, size.height)
      ..quadraticBezierTo(
          size.width * 0.75, size.height * 0.55, size.width, size.height * 0.9)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(frontPath, front);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// 부엉이가 2초 주기로 살짝 숨 쉬듯 움직인다.
class _OwlBounce extends StatefulWidget {
  const _OwlBounce({required this.child});

  final Widget child;

  @override
  State<_OwlBounce> createState() => _OwlBounceState();
}

class _OwlBounceState extends State<_OwlBounce>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  );

  @override
  void initState() {
    super.initState();
    if (AppMotion.loops) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset: Offset(0, -3 * _controller.value),
        child: child,
      ),
      child: widget.child,
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// 누적 점수로 자라는 칭호 카드
class _RankCard extends StatelessWidget {
  const _RankCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final rank = rankForPoints(points);
    final next = nextRankFor(points);
    final progress = next == null
        ? 1.0
        : (points - rank.minPoints) / (next.minPoints - rank.minPoints);

    return Container(
      padding: const EdgeInsets.all(14),
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
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFFFF6D8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(rank.emoji, style: const TextStyle(fontSize: 30)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '지금 나는 ${rank.title}!',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 10,
                    backgroundColor: const Color(0xFFF0EAD2),
                    color: const Color(0xFFFFC800),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next == null
                      ? '최고 칭호까지 다 모았어요! 🎉'
                      : '${next.emoji} ${next.title}까지 ${next.minPoints - points}코인',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 오늘의 미션 카드: 진행 바와 보상, 연속 출석 🔥, 스트릭 지킴이 🧊
class _DailyCard extends StatelessWidget {
  const _DailyCard(
      {required this.daily, required this.coins, required this.onBuyFreeze});

  final DailyState daily;
  final int coins;
  final VoidCallback onBuyFreeze;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
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
          Row(
            children: [
              const Text(
                '🎯 오늘의 미션',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFEBD6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  daily.streak > 0 ? '🔥 ${daily.streak}일 연속' : '오늘도 도전!',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFB05E00),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (final mission in daily.missions) ...[
            _MissionRow(mission: mission, daily: daily),
            if (mission != daily.missions.last) const SizedBox(height: 8),
          ],
          const SizedBox(height: 10),
          // 스트릭 지킴이: 하루 걸러도 스트릭이 이어진다.
          Row(
            children: [
              // 누르면 스트릭 지킴이가 뭔지 알려준다.
              Builder(
                builder: (context) => GestureDetector(
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('🛡️ 스트릭 지킴이: 하루 못 놀아도 연속 기록을 지켜줘요!'),
                    ),
                  ),
                  child: Text(
                    '🛡️ 스트릭 지킴이 ×${daily.freezes}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const Spacer(),
              if (daily.freezes < DailyStore.maxFreezes)
                Builder(builder: (context) {
                  // 코인이 모자라면 상태가 보이게 회색으로 가라앉힌다.
                  final affordable = coins >= DailyStore.freezeCost;
                  return GestureDetector(
                    onTap: onBuyFreeze,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: affordable
                            ? const Color(0xFFEAF4E6)
                            : const Color(0xFFF0EBE1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: affordable
                              ? AppColors.green
                              : const Color(0xFFCFC6B5),
                        ),
                      ),
                      child: Text(
                        affordable ? '받기 · 🪙 200' : '🪙 200 모이면 여기서 받아요',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: affordable
                              ? AppColors.green
                              : const Color(0xFF8F8574),
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '하루 쉬어도 연속 기록(불꽃)을 지켜 줘요',
            style: TextStyle(fontSize: 11.5, color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  const _MissionRow({required this.mission, required this.daily});

  final DailyMission mission;
  final DailyState daily;

  @override
  Widget build(BuildContext context) {
    final done = daily.isDone(mission);
    final progress = daily.progressOf(mission).clamp(0, mission.target);

    return Row(
      children: [
        Text(mission.emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / mission.target,
                  minHeight: 7,
                  backgroundColor: const Color(0xFFEBE3D2),
                  color:
                      done ? const Color(0xFF3DA35D) : const Color(0xFFFF9600),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          done ? '✅' : '$progress/${mission.target} · 🪙${mission.reward}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: done ? const Color(0xFF2E7D46) : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

/// 홈 화면 섹션 제목: 이 구역이 무엇을 하는 곳인지 한 줄로 알려준다.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 10),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade600,
          ),
        ),
      ),
    );
  }
}

/// 꾸미기 가게 / 스티커북 / 배지 도감으로 들어가는 메뉴 카드
class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      color: Colors.white,
      shadowColor: Colors.grey.shade300,
      borderRadius: 22,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      onTap: onTap,
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 32)),
          const SizedBox(height: 6),
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}

/// 과목 전환 탭 (수학 / 한글)
class _SubjectTab extends StatelessWidget {
  const _SubjectTab({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFD7FFB8) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? const Color(0xFF3DA35D) : Colors.grey.shade300,
            width: 3,
          ),
          boxShadow: [
            BoxShadow(
              color: selected ? const Color(0xFFB5E48C) : Colors.grey.shade300,
              offset: const Offset(0, 4),
              blurRadius: 0,
            ),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 카테고리 카드: 진행률과 함께 상세 화면으로 들어간다. (수학·한글 공용)
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.emoji,
    required this.title,
    required this.desc,
    required this.color,
    required this.cleared,
    required this.total,
    required this.onTap,
    this.recommended = false,
    this.locked = false,
  });

  final String emoji;
  final String title;
  final String desc;
  final Color color;
  final int cleared;
  final int total;
  final VoidCallback onTap;

  /// 온보딩에서 고른 나이에 맞는 카테고리면 추천 표시
  final bool recommended;

  /// 가족 이용권이 없어서 잠긴 카테고리 (누르면 이용권 안내로)
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      color: Colors.white,
      shadowColor: Colors.grey.shade300,
      borderRadius: 22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (locked) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.lock_rounded,
                          size: 16, color: Colors.grey.shade400),
                    ],
                    if (recommended) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6D8),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                              color: const Color(0xFFFFD34D), width: 1.5),
                        ),
                        child: const Text(
                          '👍 추천',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFB8860B),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(5),
                        child: LinearProgressIndicator(
                          value: total == 0 ? 0 : cleared / total,
                          minHeight: 8,
                          backgroundColor: const Color(0xFFEBE3D2),
                          color: color,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '$cleared/$total',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}
