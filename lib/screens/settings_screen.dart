import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/curriculum.dart';
import '../models/premium.dart';
import '../theme.dart';
import '../models/profile.dart';
import '../services/cloud_sync.dart';
import '../services/purchases.dart';
import '../services/reminders.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/parent_gate.dart';
import 'backup_screen.dart';
import 'level_map_screen.dart';
import 'onboarding_screen.dart';
import 'pass_screen.dart';
import 'report_screen.dart';
import 'sticker_book_screen.dart';

/// 설정: 효과음·말소리(문제 읽어주기)·말 빠르기, 진도 백업 바로가기.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  /// 이 화면에 있는 동안 부모 확인은 한 번만 (처음 세팅할 때 다섯 번씩 묻지 않게).
  /// 화면을 나가면 잊는다 — 전역으로 기억하면 아이가 다음에 그냥 들어온다.
  bool _gateOk = false;

  Future<bool> _gate() async {
    if (_gateOk) return true;
    final ok = await checkParentGate(context);
    if (ok) _gateOk = true;
    return ok;
  }

  DateTime? _lastSync;
  bool _syncing = false;
  bool _reminderOn = false;

  /// 우리 아이 단계: 나이(수학 카테고리 인덱스)와 이전 단계 접기 설정
  int? _ageIndex;
  bool _foldPrevAges = true;

  @override
  void initState() {
    super.initState();
    _loadSyncTime();
    _loadReminder();
    _loadAgeFold();
  }

  Future<void> _loadAgeFold() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final idx = prefs.getInt(Profiles.scoped(OnboardingScreen.ageCategoryKey));
    setState(() {
      _ageIndex = idx != null && idx >= 0 && idx < Curriculum.categories.length
          ? idx
          : null;
      _foldPrevAges =
          prefs.getBool(Profiles.scoped(LevelMapScreen.foldPrevAgesKey)) ??
              true;
    });
  }

  /// 우리 아이 단계 시트: 나이 고르기(추천·접기 기준) + 이전 단계 접어두기.
  /// 홈 화면 구성을 바꾸는 부모의 결정이라 게이트를 거친다.
  Future<void> _openAgeSheet() async {
    final ok = await _gate();
    if (!ok || !mounted) return;
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) {
          Future<void> pickAge(int? value) async {
            if (value == null) {
              await prefs
                  .remove(Profiles.scoped(OnboardingScreen.ageCategoryKey));
            } else {
              await prefs.setInt(
                  Profiles.scoped(OnboardingScreen.ageCategoryKey), value);
            }
            if (!mounted) return;
            setState(() => _ageIndex = value);
            setSheetState(() {});
          }

          Widget ageChip(String label, int? value) {
            final selected = _ageIndex == value;
            return GestureDetector(
              onTap: () => pickAge(value),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected ? AppColors.selectedFill : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? AppColors.green : AppColors.outline,
                    width: 2.5,
                  ),
                ),
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
              ),
            );
          }

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '우리 아이 단계 맞추기',
                    textAlign: TextAlign.center,
                    style: displayStyle(fontSize: AppFont.heading),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    keepAll('나이를 고르면 홈에서 그 단계를 추천하고, '
                        '더 낮은 수학 단계는 접어둘 수 있어요'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: AppFont.small, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: [
                      for (var i = 0; i < Curriculum.categories.length; i++)
                        ageChip(Curriculum.categories[i].title, i),
                      ageChip('선택 안 함', null),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    value: _foldPrevAges,
                    onChanged: _ageIndex == null
                        ? null
                        : (value) async {
                            await prefs.setBool(
                                Profiles.scoped(LevelMapScreen.foldPrevAgesKey),
                                value);
                            if (!mounted) return;
                            setState(() => _foldPrevAges = value);
                            setSheetState(() {});
                          },
                    title: const Text(
                      '이전 단계 접어두기',
                      style: TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.bold),
                    ),
                    subtitle:
                        Text(keepAll('아이 나이보다 낮은 수학 단계를 홈에서 접어요. 기록은 그대로예요.')),
                    activeTrackColor: AppColors.green,
                  ),
                  const SizedBox(height: 6),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.green,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      '완료',
                      style: TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _loadSyncTime() async {
    final at = await CloudSync.lastSyncedAt();
    if (mounted) setState(() => _lastSync = at);
  }

  Future<void> _loadReminder() async {
    final on = await Reminders.isEnabled();
    if (mounted) setState(() => _reminderOn = on);
  }

  /// 매일 알림 토글 (부모님 메뉴라 게이트를 거친다).
  /// 리포트 화면의 토글과 같은 저장값을 읽고 쓴다.
  Future<void> _toggleReminder(bool value) async {
    final ok = await _gate();
    if (!ok || !mounted) return;
    if (value) {
      final enabled = await Reminders.enable();
      if (!mounted) return;
      setState(() => _reminderOn = enabled);
      if (!enabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 권한이 필요해요. 기기 설정에서 허용해 주세요.')),
        );
      }
    } else {
      await Reminders.disable();
      if (mounted) setState(() => _reminderOn = false);
    }
  }

  /// 클라우드 로그인: 부모 확인 → 이메일/비밀번호 입력 → 로그인 또는 가입.
  /// 로그인하면 클라우드 기록을 반영해 홈부터 다시 연다.
  Future<void> _cloudLogin() async {
    final ok = await _gate();
    if (!ok || !mounted) return;

    final emailController = TextEditingController();
    final pwController = TextEditingController();
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('☁️ 클라우드 로그인'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: emailController,
              autofocus: true,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: pwController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '비밀번호 (6자 이상)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              '처음이면 [새 계정]으로 가입하세요.\n'
              '같은 계정으로 로그인한 기기끼리 진도가 이어져요.',
              style: TextStyle(
                  fontSize: AppFont.caption, color: AppColors.inkSoft),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('signup'),
            child: const Text('새 계정'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('signin'),
            child: const Text('로그인'),
          ),
        ],
      ),
    );
    if (action == null || !mounted) return;

    setState(() => _syncing = true);
    final error = action == 'signup'
        ? await CloudSync.signUp(emailController.text, pwController.text)
        : await CloudSync.signIn(emailController.text, pwController.text);
    if (!mounted) return;
    setState(() => _syncing = false);

    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    // 클라우드 기록이 복원됐을 수 있으니 캐시를 새로 읽고 홈부터 다시 연다.
    await Profiles.init();
    await Sounds.init();
    await Speech.reloadSettings();
    await PremiumStore.init();
    await Reminders.syncWithSavedSetting();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('☁️ 클라우드와 연결됐어요!')),
    );
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LevelMapScreen()),
      (route) => false,
    );
  }

  Future<void> _cloudUpload() async {
    setState(() => _syncing = true);
    final ok = await CloudSync.uploadNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    await _loadSyncTime();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(ok ? '지금 기록을 클라우드에 올렸어요.' : '올리지 못했어요. 인터넷을 확인해 주세요.'),
    ));
  }

  Future<void> _cloudSignOut() async {
    // 로그아웃하면 다른 기기와 진도가 끊긴다 — 어른만
    final ok = await _gate();
    if (!ok || !mounted) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('이 기기의 기록은 그대로 남고,\n클라우드 저장만 멈춰요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (leave != true || !mounted) return;
    await CloudSync.signOut();
    if (mounted) setState(() {});
  }

  String _syncTimeLabel() {
    final at = _lastSync;
    if (at == null) return '아직 동기화한 적 없어요';
    return '마지막 동기화: ${at.month}/${at.day} '
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _openBackup() async {
    // 복원은 기록을 통째로 바꾸는 일이라 부모 확인을 거친다.
    final ok = await _gate();
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BackupScreen()),
    );
  }

  /// 전체 열기(가족용): 부모 확인 뒤 코드가 맞으면
  /// 모든 단계 자물쇠와 유료 과목 잠금을 푼다. 다시 누르면 잠글 수 있다.
  Future<void> _toggleAllUnlock() async {
    final ok = await _gate();
    if (!ok || !mounted) return;

    if (PremiumStore.allUnlocked) {
      final lock = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('전체 열기를 끌까요?'),
          content: const Text('다시 원래대로 앞 단계를 통과해야 다음이 열려요.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('그대로 두기'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('다시 잠그기'),
            ),
          ],
        ),
      );
      if (lock != true || !mounted) return;
      await PremiumStore.setAllUnlocked(false);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('원래대로 잠갔어요.')),
      );
      return;
    }

    final controller = TextEditingController();
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔑 전체 열기 코드'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '코드를 입력하세요',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('확인'),
          ),
        ],
      ),
    );
    if (entered == null || !mounted) return;

    if (entered.trim() == PremiumStore.unlockCode) {
      await PremiumStore.setAllUnlocked(true);
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('🎉 모든 단계와 과목이 열렸어요!')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('코드가 맞지 않아요.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('설정'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            children: [
              SwitchListTile(
                value: Sounds.enabled,
                onChanged: (value) async {
                  // 끄는 건 어른만 (켜는 건 누구나)
                  if (!value) {
                    final ok = await _gate();
                    if (!ok || !mounted) return;
                  }
                  await Sounds.setEnabled(value);
                  if (value) Sounds.pop(); // 켜졌는지 바로 들려준다
                  setState(() {});
                },
                secondary: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('🎵', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '효과음',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('정답·오답 딩동 소리'),
                activeTrackColor: AppColors.green,
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: Speech.enabled,
                onChanged: (value) async {
                  // 읽어주기는 글을 모르는 아이가 혼자 푸는 데 꼭 필요해서,
                  // 끌 때만 부모 확인을 거친다 (아이가 실수로 끄지 않게).
                  if (!value) {
                    final ok = await _gate();
                    if (!ok || !mounted) return;
                  }
                  await Speech.setEnabled(value);
                  if (value) Speech.speak('안녕하세요!');
                  setState(() {});
                },
                secondary: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('🗣️', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '문제 읽어주기',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('글을 몰라도 혼자 풀 수 있게'),
                activeTrackColor: AppColors.green,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('🐢', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '말 빠르기',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                trailing: SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(value: Speech.rateSlow, label: Text('천천히')),
                    ButtonSegment(value: Speech.rateNormal, label: Text('보통')),
                  ],
                  selected: {Speech.rate},
                  onSelectionChanged: (selection) async {
                    await Speech.setRate(selection.first);
                    Speech.speak('이 빠르기로 읽어드릴게요');
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Padding(
            padding: EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '👨‍👩‍👧 부모님 메뉴',
              style: TextStyle(
                fontSize: AppFont.small,
                fontWeight: FontWeight.bold,
                color: AppColors.inkSoft,
              ),
            ),
          ),
          _card(
            children: [
              ListTile(
                leading: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('📊', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '학습 리포트',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('이번 주 할 일·과목별 정답률'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final ok = await _gate();
                  if (!ok || !context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ReportScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('🎫', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '가족 이용권',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('모든 단계 열기 · 프로필 4명'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final ok = await _gate();
                  if (!ok || !context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PassScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('🪜', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '우리 아이 단계',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(keepAll(_ageIndex == null
                    ? '나이를 고르면 딱 맞게 보여드려요'
                    : '${Curriculum.categories[_ageIndex!].title} · '
                        '${_foldPrevAges ? '이전 단계는 접어둬요' : '모든 단계 보여요'}')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openAgeSheet,
              ),
              const Divider(height: 1),
              ListTile(
                key: const ValueKey('settings-promise'),
                leading: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('🎁', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '칭찬판 선물 약속',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('스티커 20칸을 다 채우면 줄 선물'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final ok = await _gate();
                  if (!ok || !context.mounted) return;
                  final saved = await editRewardPromise(context);
                  if (saved && context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('선물 약속을 저장했어요.')),
                    );
                  }
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _reminderOn,
                onChanged: _syncing ? null : (value) => _toggleReminder(value),
                secondary: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('⏰', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '매일 학습 알림',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                subtitle:
                    Text(_reminderOn ? '매일 켠 시각쯤 알려줘요' : '하루 한 번 학습을 잊지 않게'),
                activeTrackColor: AppColors.green,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const SizedBox(
                    width: 34,
                    child: Center(
                        child: Text('💾', style: TextStyle(fontSize: 26)))),
                title: const Text(
                  '진도 백업·옮기기',
                  style: TextStyle(
                      fontSize: AppFont.body, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('코드로 진도를 지키고 옮겨요'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openBackup,
              ),
              // 스토어에서 받은 출시 빌드(상품이 보이는 빌드)에서는 숨긴다 —
              // 가족 배포용 코드라 결제 화면 옆에 둘 이유가 없다.
              if (Purchases.product == null || PremiumStore.allUnlocked) ...[
                const Divider(height: 1),
                ListTile(
                  leading: Text(PremiumStore.allUnlocked ? '🔓' : '🔑',
                      style: const TextStyle(fontSize: 26)),
                  title: const Text(
                    '코드로 전체 열기',
                    style: TextStyle(
                        fontSize: AppFont.body, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(PremiumStore.allUnlocked
                      ? '모든 단계와 과목이 열려 있어요'
                      : '선물받은 코드가 있다면 여기에 입력해요'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _toggleAllUnlock,
                ),
              ],
            ],
          ),
          if (CloudSync.available) ...[
            const SizedBox(height: 14),
            _card(
              children: [
                if (!CloudSync.signedIn)
                  ListTile(
                    leading: const SizedBox(
                        width: 34,
                        child: Center(
                            child: Text('☁️', style: TextStyle(fontSize: 26)))),
                    title: const Text(
                      '클라우드 동기화',
                      style: TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.bold),
                    ),
                    subtitle: const Text('다른 기기와 진도가 이어져요'),
                    trailing: _syncing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: _syncing ? null : _cloudLogin,
                  )
                else ...[
                  ListTile(
                    leading: const SizedBox(
                        width: 34,
                        child: Center(
                            child: Text('☁️', style: TextStyle(fontSize: 26)))),
                    title: Text(
                      CloudSync.email ?? '클라우드 동기화',
                      style: const TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(_syncTimeLabel()),
                    trailing: _syncing
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : null,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const SizedBox(
                        width: 34,
                        child: Center(
                            child: Text('🔄', style: TextStyle(fontSize: 26)))),
                    title: const Text('지금 동기화'),
                    onTap: _syncing ? null : _cloudUpload,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const SizedBox(
                        width: 34,
                        child: Center(
                            child: Text('🚪', style: TextStyle(fontSize: 26)))),
                    title: const Text('로그아웃'),
                    onTap: _syncing ? null : _cloudSignOut,
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 14),
          _card(
            children: [
              Builder(
                builder: (context) => ListTile(
                  leading: const SizedBox(
                      width: 34,
                      child: Center(
                          child: Text('ℹ️', style: TextStyle(fontSize: 26)))),
                  title: const Text('앱 정보',
                      style: TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.bold)),
                  subtitle: const Text(
                    '쿼카 학교 v$appVersionLabel\n문의: hizorro88@gmail.com (탭하면 복사)',
                    style: TextStyle(height: 1.5),
                  ),
                  onTap: () {
                    Clipboard.setData(
                        const ClipboardData(text: 'hizorro88@gmail.com'));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('문의 이메일 주소를 복사했어요.')),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            ''
            '기록은 이 폰에 저장돼요. 클라우드에 로그인하면\n'
            '진도만 계정에 저장하고, 아이의 개인정보는 수집하지 않아요.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: AppFont.caption,
                color: AppColors.inkSoft,
                height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    // 정보 카드 = 테두리 (그림자는 누르는 카드에만)
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: AppColors.outline, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
