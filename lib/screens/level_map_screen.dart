import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/curriculum.dart';
import '../models/daily.dart';
import '../models/english_curriculum.dart';
import '../models/korean_curriculum.dart';
import '../models/language_packs.dart';
import '../models/pet.dart';
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
import '../widgets/home_pet_card.dart';
import '../widgets/kid_notice.dart';
import '../widgets/parent_gate.dart';
import '../widgets/pet_parts.dart';
import '../widgets/pulse.dart';
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
import 'pet_intro_screen.dart';
import 'pet_room_screen.dart';
import 'practice_screen.dart';
import 'profile_screen.dart';
import 'quiz_screen.dart';
import 'result_screen.dart';
import 'settings_screen.dart';
import 'shop_screen.dart';
import 'sticker_book_screen.dart';
import 'wrong_notes_screen.dart';

/// 홈 화면: 마스코트 인사, 칭호 카드, 오늘의 미션,
/// 그리고 나이·학년별(4살~초3) 학습 카테고리.
class LevelMapScreen extends StatefulWidget {
  const LevelMapScreen({super.key, this.firstRun = false});

  /// 첫 실행에서 친구를 막 만나고 왔으면: 첫 판을 바로 열고,
  /// 돌아오면 친구에게 물을 주게 이끈다 (공부 → 코인 → 돌봄을 한 번에 겪는다).
  final bool firstRun;

  /// 아이 나이보다 앞의 수학 카테고리를 홈에서 접어둘지 (프로필 스코프, 기본 켜짐).
  /// 설정 > 부모님 메뉴 > 우리 아이 단계에서 바꾼다.
  static const foldPrevAgesKey = 'fold_prev_ages_v1';

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
    required this.foldPrevAges,
    required this.pet,
    this.grown,
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

  /// 나이보다 앞의 수학 카테고리 접기 설정 (기본 켜짐)
  final bool foldPrevAges;

  /// 홈 맨 위에서 함께 지내는 친구
  final PetState pet;

  /// 이번에 불러오면서 자란 단계 (진화 연출용, 없으면 null)
  final int? grown;
}

class _LevelMapScreenState extends State<LevelMapScreen> {
  late Future<_MapData> _dataFuture;

  /// 지금 보고 있는 과목 (0: 수학, 1: 한글, 2: 영어, 3~: 언어 팩)
  int _subject = 0;

  /// 접어둔 이전 나이 카테고리를 지금 펼쳐서 보는 중인지.
  /// 화면 상태로만 두고 저장하지 않아, 홈을 새로 열면 다시 접힌다.
  bool _prevAgesExpanded = false;

  /// 과목 탭 정보 (뒤쪽은 languagePacks 순서). 세 번째 값은 어른용 과정 표시.
  static final List<(String, String, bool)> _subjects = [
    ('🧮', '수학', false),
    ('📖', '한글', false),
    ('🔤', '영어', false),
    for (final pack in languagePacks) (pack.emoji, pack.name, pack.forAdults),
  ];
  static const _subjectKey = 'subject_v2';
  static const _subjectKeyOld = 'subject_korean_v1'; // 예전 한글/수학 토글
  static const _kidSubjectKey = 'subject_kid_v1'; // 마지막 아이 과목

  @override
  void initState() {
    super.initState();
    _dataFuture = _load();
    _dataFuture.then(_maybeEvolve);
    final subjectLoaded = _loadSubject(fresh: true);
    if (widget.firstRun) {
      _nudgeDrink = true;
      Future.wait([_dataFuture, subjectLoaded]).then((r) async {
        if (!mounted) return;
        final next = _nextUp(r[0] as _MapData);
        if (next == null) return;
        // 첫 판 결과의 주인공 버튼은 "친구한테 가기"
        ResultScreen.firstRunPending = true;
        await next.open();
        ResultScreen.firstRunPending = false;
        if (!mounted) return;
        Speech.speak('친구가 목말라요! 물을 줘 볼까?');
      });
    }
  }

  /// 첫 판 뒤 홈: 물 주기를 반짝이게 (한 번 주면 꺼진다)
  bool _nudgeDrink = false;

  /// [fresh]: 앱을 켰거나 프로필을 바꿨을 때 — 지난번에 어른 과정(영어회화)을
  /// 보다 껐어도 아이가 여는 홈은 아이 과목으로 돌아온다 (▶가 어른 과정을 열지 않게).
  Future<void> _loadSubject({bool fresh = false}) async {
    final prefs = await SharedPreferences.getInstance();
    var subject = prefs.getInt(Profiles.scoped(_subjectKey));
    subject ??=
        (prefs.getBool(Profiles.scoped(_subjectKeyOld)) ?? false) ? 1 : 0;
    if (subject >= _subjects.length) subject = 0;
    if (fresh && _subjects[subject].$3) {
      subject = prefs.getInt(Profiles.scoped(_kidSubjectKey)) ?? 0;
      await prefs.setInt(Profiles.scoped(_subjectKey), subject);
    }
    if (mounted && subject != _subject) setState(() => _subject = subject!);
  }

  Future<void> _setSubject(int subject) async {
    setState(() => _subject = subject);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(Profiles.scoped(_subjectKey), subject);
    // 마지막으로 고른 아이 과목 (어른 과정에서 돌아올 자리)
    if (!_subjects[subject].$3) {
      await prefs.setInt(Profiles.scoped(_kidSubjectKey), subject);
    }
  }

  /// 홈에서 바로 밥·물 주기. 못 주면 이유를 알려 준다.
  Future<void> _carePet({required bool meal}) async {
    final ok = await PetStore.care(meal: meal);
    if (!mounted) return;
    if (!ok) {
      final pet = await PetStore.load();
      if (!mounted) return;
      final enough =
          meal ? pet.coins >= petMealCost : pet.coins >= petDrinkCost;
      final face = pet.species?.emojiAt(pet.stage);
      enough
          ? showKidNotice(context,
              face: face,
              emoji: '🌙',
              text: meal ? '배불러요! 내일 또 줘요' : '물은 충분해요! 내일 또 줘요')
          : showKidNotice(context,
              face: face,
              emoji: '🪙',
              text: '코인이 모자라요. 문제 풀러 갈까?',
              action: _playNext);
      return;
    }
    Sounds.buy(); // 코인을 썼다
    Speech.speak(meal ? '냠냠 맛있어요!' : '꿀꺽꿀꺽!');
    if (!meal && _nudgeDrink) {
      _nudgeDrink = false;
      // 다음 할 일: 또 한 판 (초록 ▶)
      Future<void>.delayed(const Duration(milliseconds: 1200), () {
        if (mounted) Speech.speak('고마워! 초록 ▶ 누르면 또 놀 수 있어!');
      });
    }
    _refresh();
  }

  /// 내 친구 방으로. 아직 안 골랐으면 쿼카 박사가 먼저 고르게 한다.
  Future<void> _openPet() async {
    final pet = await PetStore.load();
    if (!mounted) return;
    if (!pet.chosen) {
      // 처음 만나는 거면 부화·첫 밥까지 하고 홈으로 돌아온다 (방으로 바로 가지 않는다).
      await Navigator.of(context).push<bool>(
        MaterialPageRoute(builder: (_) => const PetIntroScreen()),
      );
      _refresh();
      return;
    }
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const PetRoomScreen()),
    );
    if (!mounted) return;
    _refresh();
    // 방에서 "문제 풀러 가기 ▶"를 골랐으면 바로 다음 판으로
    if (result == 'play') _playNext();
  }

  Future<void> _openWrongNotes() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const WrongNotesScreen()),
    );
    _refresh();
  }

  /// 오늘의 미션 시트: 그림 줄 + 진행 막대, 읽어 준다. 🛡️ 지킴이도 여기서.
  Future<void> _openMissions(_MapData data) async {
    final daily = data.daily;
    final left = daily.missions.where((m) => !daily.isDone(m)).length;
    Speech.speak(
        left == 0 ? '오늘의 미션을 다 했어요! 최고!' : '오늘의 미션이 $left개 남았어요. 문제를 풀면 채워져요!');
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
          child: _DailyCard(
            daily: daily,
            coins: data.coins,
            onBuyFreeze: () {
              Navigator.of(context).pop();
              _buyFreeze();
            },
          ),
        ),
      ),
    );
  }

  /// 홈의 "바로 시작"과 같은 판을 연다 (알림의 ▶에서도 쓴다).
  Future<void> _playNext() async {
    final data = await _dataFuture;
    if (!mounted) return;
    await _nextUp(data)?.open();
  }

  /// 공부·돌봄으로 조건을 넘겼으면 홈에서도 바로 자란다 (방에 들어가지 않아도).
  Future<void> _maybeEvolve(_MapData data) async {
    final grown = data.grown;
    final species = data.pet.species;
    if (grown == null || species == null || !mounted) return;
    await showPetEvolution(context, species: species, stage: grown);
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
      foldPrevAges:
          prefs.getBool(Profiles.scoped(LevelMapScreen.foldPrevAgesKey)) ??
              true,
      grown: await PetStore.evolveIfReady(),
      pet: await PetStore.load(),
    );
  }

  /// 잠긴 카테고리면 부모 확인 뒤 이용권 화면을 열고 false를 돌려준다.
  Future<bool> _checkAccess(int categoryIndex) async {
    if (PremiumStore.isCategoryFree(categoryIndex)) return true;
    if (await PremiumStore.hasPass()) return true;
    if (!mounted) return false;
    // 아이가 먼저 보는 건 부모 문제(곱셈)가 아니라 그림 한 장 + 목소리.
    final grownUp = await _showLockedSheet();
    if (grownUp != true || !mounted) return false;
    final ok = await checkParentGate(context);
    if (!ok || !mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PassScreen()),
    );
    _refresh();
    return false;
  }

  /// 잠긴 카드를 아이가 눌렀을 때: 🔒 그림과 음성으로 "어른이랑 열어요".
  /// 큰 초록 버튼은 아이가 계속 놀 수 있는 쪽(닫기), 어른 버튼은 작게.
  /// true면 어른이 열겠다고 고른 것.
  Future<bool?> _showLockedSheet() {
    Speech.speak('여기는 어른이랑 같이 열어요');
    return showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppColors.cream,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🔒',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 64)),
              const SizedBox(height: 6),
              Text('어른이랑 같이 열어요',
                  textAlign: TextAlign.center,
                  style: displayStyle(fontSize: AppFont.display)),
              const SizedBox(height: 20),
              BouncyButton(
                key: const ValueKey('locked-back'),
                color: AppColors.green,
                onTap: () => Navigator.of(context).pop(false),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 30),
                    SizedBox(width: 4),
                    Text('열린 곳에서 놀기',
                        style: TextStyle(
                            fontSize: AppFont.title,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                key: const ValueKey('locked-grownup'),
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('👨‍👩‍👧 어른이 열기',
                    style: TextStyle(
                        fontSize: AppFont.body, color: AppColors.inkSoft)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openBoss(bool cleared, int? age) async {
    if (cleared) {
      showKidNotice(context, emoji: '👑', text: '이번 주 보스는 이겼어요! 다음 주에 또 만나요');
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuizScreen(
          config: const QuizConfig(mode: QuizMode.mixed, maxNumber: 10),
          bossMode: true,
          bossAge: age,
        ),
      ),
    );
    _refresh();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _dataFuture = _load();
      _dataFuture.then(_maybeEvolve);
      _prevAgesExpanded = false; // 기본은 정돈된(접힌) 화면
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
          final maxNumber =
              mode == QuizMode.multiplication || mode == QuizMode.division
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
    final had = (await DailyStore.load()).freezes;
    final ok = await DailyStore.buyFreeze();
    if (!mounted) return;
    if (!ok && had >= DailyStore.maxFreezes) {
      showKidNotice(context, emoji: '🛡️', text: '지킴이는 벌써 넉넉해요!');
      return;
    }
    ok
        ? showKidNotice(context,
            emoji: '🛡️', text: '지킴이가 생겼어요! 하루 쉬어도 불꽃이 안 꺼져요')
        : showKidNotice(context, emoji: '🪙', text: '코인이 모자라요. 문제를 풀면 생겨요!');
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
    _refresh(); // 소리·나이·접기 설정이 바뀌었을 수 있다
  }

  Future<void> _openProfiles() async {
    final before = Profiles.activeId;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
    _refresh(); // 프로필이 바뀌면 진행도·코인 등을 다시 불러온다.
    if (Profiles.activeId != before) _loadSubject(fresh: true);
  }

  /// 과목 고르기 창: 아이 과목은 2열 큰 칸, 어른 과정(영어회화)은
  /// 구분선 아래 조용한 줄 — 아이가 실수로 들어가지 않게 부모 확인을 거친다.
  Future<void> _openSubjectPicker() async {
    Speech.speak('어떤 과목을 배울까?');
    final kids = [
      for (var i = 0; i < _subjects.length; i++)
        if (!_subjects[i].$3) i,
    ];
    final adults = [
      for (var i = 0; i < _subjects.length; i++)
        if (_subjects[i].$3) i,
    ];
    Widget kidTile(BuildContext context, int i) {
      final selected = i == _subject;
      return BouncyButton(
        key: ValueKey('subject-$i'),
        color: selected ? AppColors.selectedFill : Colors.white,
        shadowColor: selected ? AppColors.correct : AppColors.outline,
        border: Border.all(
          color: selected ? AppColors.correct : AppColors.outline,
          width: selected ? 3 : 2,
        ),
        borderRadius: 22,
        padding: const EdgeInsets.symmetric(vertical: 12),
        onTap: () => Navigator.of(context).pop(i),
        child: Column(
          children: [
            Text(_subjects[i].$1, style: const TextStyle(fontSize: 34)),
            const SizedBox(height: 2),
            Text(_subjects[i].$2, style: displayStyle(fontSize: AppFont.title)),
          ],
        ),
      );
    }

    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: AppColors.cream,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '어떤 과목을 배울까?',
                textAlign: TextAlign.center,
                style: displayStyle(fontSize: AppFont.heading),
              ),
              const SizedBox(height: 14),
              for (var r = 0; r < kids.length; r += 2) ...[
                if (r > 0) const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: kidTile(context, kids[r])),
                    const SizedBox(width: 10),
                    Expanded(
                      child: r + 1 < kids.length
                          ? kidTile(context, kids[r + 1])
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ],
              if (adults.isNotEmpty) ...[
                const SizedBox(height: 18),
                const Divider(color: AppColors.line, thickness: 2),
                for (final i in adults)
                  TextButton(
                    key: ValueKey('subject-$i'),
                    onPressed: () => Navigator.of(context).pop(i),
                    child: Text(
                      '👨‍👩‍👧 어른 공부 · ${_subjects[i].$1} ${_subjects[i].$2}'
                      '${i == _subject ? ' ✓' : ''}',
                      style: const TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.bold,
                        color: AppColors.inkSoft,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    // 어른 과정은 부모 확인 뒤에 (이미 그 과목이면 다시 묻지 않는다)
    if (_subjects[picked].$3 && picked != _subject) {
      final ok = await checkParentGate(context);
      if (!ok || !mounted) return;
    }
    _setSubject(picked);
    // 글을 못 읽어도 무엇을 골랐는지 들리게
    if (!_subjects[picked].$3) Speech.speak(_subjects[picked].$2);
  }

  /// 수학 카테고리 카드 목록. 아이 나이(추천 카테고리)보다 앞의 단계는
  /// 접기 카드 한 장으로 접어둔다 — 기록은 그대로 두고 표시만 접는다.
  /// 이용권이 없으면 무료 카테고리(4살)가 유일하게 놀 수 있는 곳이라 접지 않는다.
  List<Widget> _mathCategoryCards(_MapData data) {
    final age = data.recommendedCategory;
    final foldCount =
        data.foldPrevAges && age != null && age > 0 && data.hasPass ? age : 0;

    Widget cardFor(AgeCategory category) => _CategoryCard(
          emoji: category.emoji,
          title: category.title,
          desc: category.desc,
          color: category.color,
          cleared: Curriculum.levels
              .where((l) =>
                  l.unit.category.index == category.index &&
                  data.stars[l.number - 1] >= 1)
              .length,
          total: category.totalLevels,
          // 잠긴 카드를 추천하면 아이가 부모 확인 창에 막힌다 — 놀 수 있는 곳만.
          recommended: data.recommendedCategory != null &&
              _mathStartCategory(data) == data.recommendedCategory &&
              data.recommendedCategory == category.index,
          locked: !data.hasPass && category.index > 0,
          onTap: () => _openCategory(category),
        );

    final folded = Curriculum.categories.take(foldCount).toList();
    var foldedStars = 0;
    for (final c in folded) {
      for (var n = c.firstLevelNumber; n <= c.lastLevelNumber; n++) {
        foldedStars += data.stars[n - 1];
      }
    }

    return [
      if (foldCount > 0) ...[
        _FoldCard(
          expanded: _prevAgesExpanded,
          count: foldCount,
          rangeLabel: foldCount == 1
              ? folded.first.title
              : '${folded.first.title}~${folded.last.title}',
          stars: foldedStars,
          onTap: () => setState(() => _prevAgesExpanded = !_prevAgesExpanded),
        ),
        const SizedBox(height: 12),
        if (_prevAgesExpanded)
          for (final category in folded) ...[
            cardFor(category),
            const SizedBox(height: 12),
          ],
      ],
      for (final category in Curriculum.categories.skip(foldCount)) ...[
        cardFor(category),
        const SizedBox(height: 12),
      ],
    ];
  }

  /// 수학에서 아이가 시작할 카테고리: 고른 나이가 열려 있으면 그 나이,
  /// 이용권이 없어 잠겨 있으면 무료 카테고리.
  int _mathStartCategory(_MapData data) {
    final age = data.recommendedCategory ?? 0;
    return data.hasPass || PremiumStore.isCategoryFree(age) ? age : 0;
  }

  /// 홈의 "▶ 바로 시작": 지금 과목에서 다음에 풀 단계 하나.
  /// 안 푼 단계 → 별이 덜 찬 단계 순으로 찾고, 잠긴 카테고리는 건너뛴다.
  _NextUp? _nextUp(_MapData data) {
    bool playable(int category) =>
        data.hasPass || PremiumStore.isCategoryFree(category);

    int? pick(List<int> categories, List<int> stars,
        bool Function(int number) unlocked, int startCategory) {
      for (final want in [0, 1, 2]) {
        for (final from in [startCategory, 0]) {
          for (var i = 0; i < categories.length; i++) {
            if (categories[i] < from || !playable(categories[i])) continue;
            if (stars[i] == want && unlocked(i + 1)) return i;
          }
        }
      }
      return null;
    }

    Future<void> go(Widget screen) async {
      await Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => screen));
      _refresh();
    }

    switch (_subject) {
      case 0:
        final levels = Curriculum.levels;
        final i = pick(
            [for (final l in levels) l.unit.category.index],
            data.stars,
            (n) => ProgressStore.isUnlocked(data.stars, n),
            _mathStartCategory(data));
        if (i == null) return null;
        final l = levels[i];
        return _NextUp(l.unit.emoji, l.unit.title, l.unit.category.color,
            () => go(QuizScreen(config: l.config, level: l)));
      case 1:
        final levels = KoreanCurriculum.levels;
        final i = pick(
            [for (final l in levels) l.unit.category.index],
            data.krStars,
            (n) => KoreanProgressStore.isUnlocked(data.krStars, n),
            0);
        if (i == null) return null;
        final l = levels[i];
        return _NextUp(
            l.unit.emoji,
            l.unit.title,
            l.unit.category.color,
            () => go(
                KoreanQuizScreen(type: l.unit.type, stage: l.stage, level: l)));
      case 2:
        final levels = EnglishCurriculum.levels;
        final i = pick(
            [for (final l in levels) l.unit.category.index],
            data.enStars,
            (n) => EnglishProgressStore.isUnlocked(data.enStars, n),
            0);
        if (i == null) return null;
        final l = levels[i];
        return _NextUp(
            l.unit.emoji,
            l.unit.title,
            l.unit.category.color,
            () => go(EnglishQuizScreen(
                type: l.unit.type, stage: l.stage, level: l)));
      default:
        final pack = languagePacks[_subject - 3];
        final stars = data.langStars[_subject - 3];
        final levels = pack.levels;
        final i = pick([for (final l in levels) l.unit.category.index], stars,
            (n) => LangProgressStore.isUnlocked(pack, stars, n), 0);
        if (i == null) return null;
        final l = levels[i];
        return _NextUp(
            l.unit.emoji,
            l.unit.title,
            l.unit.category.color,
            () => go(LanguageQuizScreen(
                pack: pack,
                typeIndex: l.unit.typeIndex,
                stage: l.stage,
                level: l)));
    }
  }

  /// 오늘 활동에 따라 친구의 인사말이 달라진다.
  String _greetingFor(_MapData data) {
    // 이름을 안 정했으면 이름 없이 부른다 ("친구"는 펫을 뜻하는 말이라 쓰지 않는다).
    final hasName = data.profile.name != '우리 아이';
    final to = hasName ? '${data.profile.name}, ' : '';
    final daily = data.daily;
    if (daily.rounds >= 3) {
      return '$to오늘 벌써\n${daily.rounds}판이나 풀었어! 🎉';
    }
    if (daily.rounds >= 1) {
      return '$to좋아!\n오늘 미션까지 가 보자 📋';
    }
    if (daily.streak >= 3) {
      return '$to${daily.streak}일째\n함께라니 최고야! 🔥';
    }
    // 오늘 첫 방문: 다음에 할 일(초록 ▶)을 말로 알려 준다.
    final hour = DateTime.now().hour;
    final hello = hour < 12
        ? '좋은 아침이야!'
        : hour < 18
            ? '안녕, 반가워!'
            : '자기 전에 한 판 어때?';
    return '$to$hello\n초록 ▶ 누르면 시작이야!';
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
          // 별 합계는 전 과목
          final totalStars = data.stars.fold<int>(0, (sum, s) => sum + s) +
              data.krStars.fold<int>(0, (sum, s) => sum + s) +
              data.enStars.fold<int>(0, (sum, s) => sum + s) +
              [
                for (var i = 0; i < languagePacks.length; i++)
                  // 어른 과정(영어회화) 별은 아이 별에 섞지 않는다
                  if (!languagePacks[i].forAdults) ...data.langStars[i]
              ].fold<int>(0, (sum, s) => sum + s);

          return ListView(
            padding: EdgeInsets.zero,
            children: [
              _Header(
                title: '쿼카 학교',
                greeting: _greetingFor(data),
                coins: data.coins,
                equipped: data.equipped,
                profile: data.profile,
                onOwlTap: _openShop,
                onProfileTap: _openProfiles,
                onPetTap: _openPet,
                onPetCare: _carePet,
                nudgeDrink: _nudgeDrink,
                pet: data.pet,
                onSettingsTap: _openSettings,
                subjectEmojis: [for (final s in _subjects) s.$1],
                subjectLabels: [for (final s in _subjects) s.$2],
                subject: _subject,
                onSubjectPickerTap: _openSubjectPicker,
                beltColor: rankForPoints(data.points).color,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // ── 0. 바로 시작: 글을 못 읽어도 ▶ 하나면 다음 판이 열린다 ──
                    if (_nextUp(data) case final next?) ...[
                      // 첫 판 뒤 물 주기를 안내할 때는 ▶ 대신 물 주기가 깜빡인다
                      _QuickStartButton(next: next, pulse: !_nudgeDrink),
                      const SizedBox(height: 18),
                    ],
                    // 맞춤 복습: 있을 때만 ▶ 밑에 얇은 줄로
                    if (data.review != null) ...[
                      _ReviewStrip(
                        review: data.review!,
                        onTap: () => _openReview(data.review!),
                      ),
                      const SizedBox(height: 14),
                    ],
                    // ── 1. 놀이판: 오늘 줄 + 모으기 줄 (자리 고정, 글 없이 그림 칸) ──
                    _PlayBoard(
                      daily: data.daily,
                      bossCleared: data.bossCleared,
                      wrongCount: data.wrongCount,
                      stickerTickets: data.stickerTickets,
                      onMissions: () => _openMissions(data),
                      onBoss: () =>
                          _openBoss(data.bossCleared, data.recommendedCategory),
                      // 다 고쳤으면 빈 화면 대신 그림+목소리로 칭찬
                      onWrongNotes: data.wrongCount == 0
                          ? () => showKidNotice(context,
                              emoji: '✅', text: '틀린 문제를 다 고쳤어! 최고!')
                          : _openWrongNotes,
                      onShop: _openShop,
                      onStickers: _openStickerBook,
                      onBadges: _openBadges,
                    ),
                    const SizedBox(height: 22),
                    // ── 2. 배우기 (과목은 상단 헤더의 과목 칩으로 바꾼다) ──
                    // ── 1. 배우기 (과목은 상단 헤더의 이모지 버튼으로 바꾼다) ──
                    _SectionTitle('📚 배우기', trailing: '⭐ $totalStars'),
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
                                  data.langStars[_subject - 3][l.number - 1] >=
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
                      ..._mathCategoryCards(data),
                    const SizedBox(height: 4),
                    // 자유 연습: 단계와 상관없는 놀이라 배우기 목록 끝에
                    BouncyButton(
                      color: Colors.white,
                      shadowColor: AppColors.outline,
                      borderRadius: 22,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      onTap: _openPractice,
                      child: Row(
                        children: [
                          const Text('🎠', style: TextStyle(fontSize: 30)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('자유 연습',
                                style: displayStyle(fontSize: AppFont.title)),
                          ),
                          const Icon(Icons.chevron_right_rounded,
                              color: AppColors.inkMuted),
                        ],
                      ),
                    ),
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

/// 초록 그라데이션 헤더: 꾸며진 쿼카가 인사하고 별·코인을 보여준다.
/// 쿼카를 누르면 꾸미기 가게로 간다.
class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.greeting,
    required this.coins,
    required this.equipped,
    required this.profile,
    required this.onOwlTap,
    required this.onProfileTap,
    required this.onPetTap,
    required this.onPetCare,
    this.nudgeDrink = false,
    required this.pet,
    required this.onSettingsTap,
    required this.subjectEmojis,
    required this.subjectLabels,
    required this.subject,
    required this.onSubjectPickerTap,
    required this.beltColor,
  });

  /// 칭호(띠) 색 — 프로필 얼굴 고리
  final Color beltColor;

  final String title;
  final String greeting;
  final int coins;
  final List<ShopItem> equipped;
  final Profile profile;
  final VoidCallback onOwlTap;
  final VoidCallback onProfileTap;

  /// 내 친구(펫) 방 열기. 아직 안 골랐으면 고르는 화면이 뜬다.
  final VoidCallback onPetTap;

  /// 홈에서 바로 돌보기 (밥·물)
  final Future<void> Function({required bool meal}) onPetCare;
  final bool nudgeDrink;

  /// 지금 친구 상태
  final PetState pet;
  final VoidCallback onSettingsTap;

  /// 현재 과목 표시용 (이모지·이름). 칩을 누르면 과목 고르기 창이 뜬다.
  final List<String> subjectEmojis;
  final List<String> subjectLabels;
  final int subject;
  final VoidCallback onSubjectPickerTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.greenLight, AppColors.green],
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
                        style: displayStyle(
                            fontSize: AppFont.display, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      // 좁은 화면에서도 넘치지 않게 오른쪽 묶음 전체를 축소한다.
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Row(
                            children: [
                              // 현재 과목 하나만 보여주고, 누르면 고르기 창이 뜬다.
                              GestureDetector(
                                key: const ValueKey('subject-picker'),
                                behavior: HitTestBehavior.opaque,
                                onTap: onSubjectPickerTap,
                                child: Container(
                                  height: 38,
                                  padding:
                                      const EdgeInsets.only(left: 11, right: 4),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(999),
                                    color: Colors.white,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        subjectEmojis[subject],
                                        style: const TextStyle(
                                            fontSize: AppFont.body),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        subjectLabels[subject],
                                        style: const TextStyle(
                                          fontSize: AppFont.small,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.ink,
                                        ),
                                      ),
                                      const Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 24,
                                        color: AppColors.inkSoft,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 🪙 잔액 (퀴즈·결과와 같은 자리·같은 모양) — 누르면 꾸미기 가게
                              GestureDetector(
                                onTap: onOwlTap,
                                child: Container(
                                  height: 34,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    '🪙 $coins',
                                    style: const TextStyle(
                                      fontSize: AppFont.body,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // 프로필 바꾸기 (아바타만 — 이름은 아래 인사말에 나온다)
                              Semantics(
                                button: true,
                                label: '프로필 바꾸기',
                                child: GestureDetector(
                                  key: const ValueKey('profile-chip'),
                                  onTap: onProfileTap,
                                  child: Container(
                                    width: 34,
                                    height: 34,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color:
                                          Colors.white.withValues(alpha: 0.25),
                                      // 띠 색 고리 — 공부할수록 색이 바뀐다
                                      border: Border.all(
                                          color: beltColor, width: 3),
                                    ),
                                    child: Center(
                                      child: Text(
                                        profile.emoji,
                                        style: const TextStyle(
                                            fontSize: AppFont.title),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 3),
                              // 설정은 어른 것이라 살짝 흐리게
                              Semantics(
                                button: true,
                                label: '설정',
                                child: GestureDetector(
                                  onTap: onSettingsTap,
                                  child: Padding(
                                    padding: const EdgeInsets.all(5),
                                    child: Icon(
                                      Icons.settings_rounded,
                                      color:
                                          Colors.white.withValues(alpha: 0.7),
                                      size: 24,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // 다마고치처럼 홈에서 바로 친구를 돌본다.
                  HomePetCard(
                    pet: pet,
                    greeting: greeting,
                    onOpenRoom: onPetTap,
                    onMeet: onPetTap,
                    onCare: onPetCare,
                    nudgeDrink: nudgeDrink,
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

/// 헤더 배경: 구름 두 점과 겹친 언덕 — "쿼카 학교"의 앞마당
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
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                '📋 오늘의 미션',
                style: TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.rewardSurface,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  daily.streak > 0 ? '🔥 ${daily.streak}일 연속' : '오늘도 도전!',
                  style: const TextStyle(
                    fontSize: AppFont.small,
                    fontWeight: FontWeight.bold,
                    color: AppColors.rewardInk,
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
                  onTap: () => showKidNotice(context,
                      emoji: '🛡️', text: '지킴이가 있으면 하루 쉬어도 불꽃이 안 꺼져요'),
                  child: Text(
                    '🛡️ 스트릭 지킴이 ×${daily.freezes}',
                    style: const TextStyle(
                      fontSize: AppFont.small,
                      fontWeight: FontWeight.bold,
                      color: AppColors.inkSoft,
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
                            ? AppColors.selectedFill
                            : AppColors.lockedNode,
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color:
                              affordable ? AppColors.correct : AppColors.line,
                        ),
                      ),
                      child: Text(
                        affordable ? '받기 · 🪙 200' : '🪙 200 모이면 여기서 받아요',
                        style: TextStyle(
                          fontSize: AppFont.caption,
                          fontWeight: FontWeight.bold,
                          color: affordable
                              ? AppColors.greenPressed
                              : AppColors.inkMuted,
                        ),
                      ),
                    ),
                  );
                }),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '하루 쉬어도 연속 기록(불꽃)을 지켜 줘요',
            style:
                TextStyle(fontSize: AppFont.caption, color: AppColors.inkMuted),
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
        Text(mission.emoji, style: const TextStyle(fontSize: AppFont.heading)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                mission.title,
                style: const TextStyle(
                  fontSize: AppFont.small,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress / mission.target,
                  minHeight: 7,
                  backgroundColor: AppColors.line,
                  color: done ? AppColors.correct : AppColors.amber,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          done ? '✅' : '$progress/${mission.target} · 🪙${mission.reward}',
          style: TextStyle(
            fontSize: AppFont.small,
            fontWeight: FontWeight.bold,
            color: done ? AppColors.greenPressed : AppColors.inkSoft,
          ),
        ),
      ],
    );
  }
}

/// 접어둔 이전 나이 단계 묶음 카드. 탭하면 그 자리에서 펼쳤다 접는다.
/// 더 쉬운 콘텐츠를 보여줄 뿐이라 부모 관문 없이 아이도 열 수 있다.
class _FoldCard extends StatelessWidget {
  const _FoldCard({
    required this.expanded,
    required this.count,
    required this.rangeLabel,
    required this.stars,
    required this.onTap,
  });

  final bool expanded;
  final int count;

  /// 접힌 범위 표시용 (예: "4살~6살")
  final String rangeLabel;

  /// 접힌 카테고리 안에 모아 둔 별 합계 (기록이 사라진 게 아님을 보여준다)
  final int stars;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // 학습 카드보다 눈에 덜 띄어야 해서 한 줄짜리 얇은 카드로 둔다.
    return BouncyButton(
      color: Colors.white,
      shadowColor: AppColors.outline,
      borderRadius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      debounce: false, // 접었다 폈다 반복 탭이 자연스러워야 한다
      onTap: onTap,
      child: Row(
        children: [
          const Text('✅', style: TextStyle(fontSize: AppFont.title)),
          const SizedBox(width: 8),
          Text(
            expanded ? '이전 단계 접기' : '이전 단계 $count개',
            style: const TextStyle(
              fontSize: AppFont.small,
              fontWeight: FontWeight.bold,
              color: AppColors.inkSoft,
            ),
          ),
          const Spacer(),
          Text(
            expanded
                ? ''
                : stars > 0
                    ? '⭐ $stars'
                    : rangeLabel,
            style: const TextStyle(
                fontSize: AppFont.caption, color: AppColors.inkMuted),
          ),
          const SizedBox(width: 2),
          Icon(
            expanded
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_down_rounded,
            size: 24,
            color: AppColors.inkSoft,
          ),
        ],
      ),
    );
  }
}

/// 홈 화면 섹션 제목: 이 구역이 무엇을 하는 곳인지 한 줄로 알려준다.
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text, {this.trailing});

  final String text;

  /// 오른쪽 끝의 작은 표시 (예: '⭐ 73')
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, right: 6, bottom: 10),
      child: Row(
        children: [
          Text(text, style: displayStyle(fontSize: AppFont.title)),
          const Spacer(),
          if (trailing != null)
            Text(
              trailing!,
              style: const TextStyle(
                fontSize: AppFont.body,
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
        ],
      ),
    );
  }
}

/// 맞춤 복습: 요즘 어려워한 유형 — ▶ 밑의 얇은 보조 줄 (있을 때만)
class _ReviewStrip extends StatelessWidget {
  const _ReviewStrip({required this.review, required this.onTap});

  final ReviewSuggestion review;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BouncyButton(
      color: Colors.white,
      shadowColor: AppColors.outline,
      borderRadius: 999,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      onTap: onTap,
      child: Row(
        children: [
          const Text('🩹', style: TextStyle(fontSize: AppFont.display)),
          const SizedBox(width: 8),
          Text('맞춤 복습', style: displayStyle(fontSize: AppFont.body)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${review.subject} ${review.emoji} '
              '${review.label} · 조금 어려웠죠? 한 판 더!',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: AppFont.caption, color: AppColors.inkSoft),
            ),
          ),
          const Icon(Icons.play_arrow_rounded, color: AppColors.green),
        ],
      ),
    );
  }
}

/// 놀이판 6칸: 오늘 줄(미션·보스·오답) + 모으기 줄(가게·스티커·배지).
/// 자리는 늘 고정 — 숨기지 않고, 다 한 칸은 ✅ 도장을 찍고 흐리게 한다.
/// 칸마다 배지는 하나만 (🔥N · 숫자 · 🎟️N). 펄스는 ▶에만 쓰므로 여기엔 없다.
class _PlayBoard extends StatelessWidget {
  const _PlayBoard({
    required this.daily,
    required this.bossCleared,
    required this.wrongCount,
    required this.stickerTickets,
    required this.onMissions,
    required this.onBoss,
    required this.onWrongNotes,
    required this.onShop,
    required this.onStickers,
    required this.onBadges,
  });

  final DailyState daily;
  final bool bossCleared;
  final int wrongCount;
  final int stickerTickets;
  final VoidCallback onMissions;
  final VoidCallback onBoss;
  final VoidCallback onWrongNotes;
  final VoidCallback onShop;
  final VoidCallback onStickers;
  final VoidCallback onBadges;

  @override
  Widget build(BuildContext context) {
    final missionsDone = daily.missions.every(daily.isDone);
    Widget row(List<Widget> tiles) => Row(
          children: [
            for (var i = 0; i < tiles.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              Expanded(child: tiles[i]),
            ],
          ],
        );
    return Column(
      children: [
        row([
          _HomeTile(
            emoji: '📋',
            title: '오늘의 미션',
            badge: daily.streak > 0 ? '🔥${daily.streak}' : null,
            done: missionsDone,
            onTap: onMissions,
          ),
          _HomeTile(
            emoji: '👑',
            title: '주간 보스전',
            done: bossCleared,
            onTap: onBoss,
          ),
          _HomeTile(
            emoji: '📒',
            title: '오답 노트',
            badge: wrongCount > 0 ? '$wrongCount' : null,
            done: wrongCount == 0,
            onTap: onWrongNotes,
          ),
        ]),
        const SizedBox(height: 10),
        row([
          _HomeTile(emoji: '🛍️', title: '꾸미기 가게', onTap: onShop),
          _HomeTile(
            emoji: '📔',
            title: '스티커북',
            badge: stickerTickets > 0 ? '🎟️$stickerTickets' : null,
            onTap: onStickers,
          ),
          _HomeTile(emoji: '🏅', title: '배지 도감', onTap: onBadges),
        ]),
      ],
    );
  }
}

/// 놀이판 한 칸: 큰 그림 + 이름 한 줄 + (배지 하나 / ✅ 도장)
class _HomeTile extends StatelessWidget {
  const _HomeTile({
    required this.emoji,
    required this.title,
    required this.onTap,
    this.badge,
    this.done = false,
  });

  final String emoji;
  final String title;
  final VoidCallback onTap;
  final String? badge;

  /// 오늘 할 건 다 한 칸 (✅ 도장 + 살짝 흐리게)
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: title,
      onTap: onTap,
      excludeSemantics: true,
      child: BouncyButton(
        color: Colors.white,
        shadowColor: AppColors.outline,
        borderRadius: 22,
        padding: EdgeInsets.zero,
        onTap: onTap,
        child: SizedBox(
          height: 104,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Center(
                child: Opacity(
                  opacity: done ? 0.55 : 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 38)),
                      const SizedBox(height: 4),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(title,
                              style: displayStyle(fontSize: AppFont.body)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (done)
                const Positioned(
                  top: 6,
                  right: 8,
                  child: Text('✅', style: TextStyle(fontSize: AppFont.title)),
                )
              else if (badge != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.amber,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        fontSize: AppFont.caption,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                  ),
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
      shadowColor: AppColors.outline,
      borderRadius: 22,
      padding: const EdgeInsets.all(14),
      onTap: onTap,
      child: Opacity(
        opacity: locked ? 0.62 : 1,
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
                          fontSize: AppFont.title,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.lock_rounded,
                            size: 16, color: AppColors.inkMuted),
                      ],
                      if (recommended) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.rewardSurface,
                            borderRadius: BorderRadius.circular(999),
                            border:
                                Border.all(color: AppColors.amber, width: 1.5),
                          ),
                          child: const Text(
                            '👍 추천',
                            style: TextStyle(
                              fontSize: AppFont.caption,
                              fontWeight: FontWeight.bold,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  // 글 설명·숫자 대신 막대 하나 (시작했을 때만) — 설명은 어른용이라 뺐다
                  if (cleared > 0) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: LinearProgressIndicator(
                        value: total == 0 ? 0 : cleared / total,
                        minHeight: 8,
                        backgroundColor: AppColors.line,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // 잠긴 카드는 "눌러도 열리는 것"처럼 보이지 않게 화살표 대신 자물쇠
            locked
                ? const Icon(Icons.lock_rounded, color: AppColors.inkMuted)
                : const Icon(Icons.chevron_right, color: AppColors.inkMuted),
          ],
        ),
      ),
    );
  }
}

/// 홈에서 바로 열 다음 단계
class _NextUp {
  const _NextUp(this.emoji, this.title, this.color, this.open);

  final String emoji;
  final String title;
  final Color color;
  final Future<void> Function() open;
}

/// 홈의 가장 큰 초록 버튼 — 누르면 다음 판이 바로 열린다.
/// 초록 = 앞으로. 숨쉬듯 커졌다 작아져 "여기"를 글 없이 알려준다.
class _QuickStartButton extends StatelessWidget {
  const _QuickStartButton({required this.next, this.pulse = true});

  final _NextUp next;
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '바로 시작 ${next.title}',
      // 자식 버튼의 탭이 접근성 트리에서 빠지므로 여기서 다시 단다.
      onTap: next.open,
      excludeSemantics: true,
      child: Pulse(
        scale: pulse ? 1.03 : 1.0,
        child: BouncyButton(
          key: const ValueKey('quick-start'),
          color: AppColors.green,
          borderRadius: 24,
          padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
          onTap: next.open,
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                // 단원색 원 — ➖ 같은 회색 기호도 또렷하게 보이게
                decoration: BoxDecoration(
                  color: Color.lerp(next.color, Colors.white, 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                alignment: Alignment.center,
                child: Text(next.emoji, style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('바로 시작',
                        style: displayStyle(
                            fontSize: AppFont.display, color: Colors.white)),
                    Text(
                      next.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: AppFont.small,
                        fontWeight: FontWeight.bold,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.play_circle_fill_rounded,
                  size: 48, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
