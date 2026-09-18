import 'package:flutter/material.dart';

import '../models/premium.dart';
import '../theme.dart';
import '../models/profile.dart';
import '../services/cloud_sync.dart';
import '../services/reminders.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/parent_gate.dart';
import 'backup_screen.dart';
import 'level_map_screen.dart';
import 'pass_screen.dart';

/// 설정: 효과음·말소리(문제 읽어주기)·말 빠르기, 진도 백업 바로가기.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  DateTime? _lastSync;
  bool _syncing = false;
  bool _reminderOn = false;

  @override
  void initState() {
    super.initState();
    _loadSyncTime();
    _loadReminder();
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
    final ok = await checkParentGate(context);
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
    final ok = await checkParentGate(context);
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
            Text(
              '처음이면 [새 계정]으로 가입하세요.\n'
              '같은 계정으로 로그인한 기기끼리 진도가 이어져요.',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
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
    final ok = await checkParentGate(context);
    if (!ok || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const BackupScreen()),
    );
  }

  /// 전체 열기(가족용): 부모 확인 뒤 코드가 맞으면
  /// 모든 단계 자물쇠와 유료 과목 잠금을 푼다. 다시 누르면 잠글 수 있다.
  Future<void> _toggleAllUnlock() async {
    final ok = await checkParentGate(context);
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
        title: const Text(
          '설정',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card(
            children: [
              SwitchListTile(
                value: Sounds.enabled,
                onChanged: (value) async {
                  await Sounds.setEnabled(value);
                  if (value) Sounds.correct(1); // 켜졌는지 바로 들려준다
                  setState(() {});
                },
                secondary: const Text('🔔', style: TextStyle(fontSize: 26)),
                title: const Text(
                  '효과음',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('정답·오답 딩동 소리'),
                activeTrackColor: const Color(0xFF3DA35D),
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: Speech.enabled,
                onChanged: (value) async {
                  await Speech.setEnabled(value);
                  if (value) Speech.speak('안녕하세요!');
                  setState(() {});
                },
                secondary: const Text('🗣️', style: TextStyle(fontSize: 26)),
                title: const Text(
                  '문제 읽어주기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(keepAll('글을 몰라도 풀 수 있게 문제·정답을 읽어줘요')),
                activeTrackColor: const Color(0xFF3DA35D),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Text('🐢', style: TextStyle(fontSize: 26)),
                title: const Text(
                  '말 빠르기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                trailing: SegmentedButton<double>(
                  segments: const [
                    ButtonSegment(
                        value: Speech.rateSlow, label: Text('천천히')),
                    ButtonSegment(
                        value: Speech.rateNormal, label: Text('보통')),
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
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Text(
              '🔒 부모님 메뉴',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          _card(
            children: [
              ListTile(
                leading: const Icon(Icons.family_restroom_rounded,
                    color: Color(0xFF8C5A2B)),
                title: const Text(
                  '가족 이용권',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('모든 단계 열기 · 프로필 4명'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  final ok = await checkParentGate(context);
                  if (!ok || !context.mounted) return;
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const PassScreen()),
                  );
                },
              ),
              const Divider(height: 1),
              SwitchListTile(
                value: _reminderOn,
                onChanged: _syncing ? null : (value) => _toggleReminder(value),
                secondary: const Icon(Icons.notifications_rounded,
                    color: Color(0xFFF4B740)),
                title: const Text(
                  '매일 학습 알림',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(keepAll('저녁마다 오늘의 퀴즈를 잊지 않게 알려줘요')),
                activeTrackColor: const Color(0xFF3DA35D),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Text('💾', style: TextStyle(fontSize: 26)),
                title: const Text(
                  '진도 백업·옮기기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(keepAll('부모 확인 뒤 백업 코드로 진도를 지키고 옮겨요')),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Text(PremiumStore.allUnlocked ? '🔓' : '🔑',
                    style: const TextStyle(fontSize: 26)),
                title: const Text(
                  '코드로 전체 열기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(PremiumStore.allUnlocked
                    ? '모든 단계와 과목이 열려 있어요'
                    : '선물받은 코드가 있다면 여기에 입력해요'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _toggleAllUnlock,
              ),
            ],
          ),
          if (CloudSync.available) ...[
            const SizedBox(height: 14),
            _card(
              children: [
                if (!CloudSync.signedIn)
                  ListTile(
                    leading: const Text('☁️', style: TextStyle(fontSize: 26)),
                    title: const Text(
                      '클라우드 동기화',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(keepAll('로그인하면 다른 기기와 진도가 이어져요')),
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
                    leading: const Text('☁️', style: TextStyle(fontSize: 26)),
                    title: Text(
                      CloudSync.email ?? '클라우드 동기화',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
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
                    leading: const Icon(Icons.cloud_upload_rounded,
                        color: Color(0xFF1CB0F6)),
                    title: const Text('지금 동기화'),
                    onTap: _syncing ? null : _cloudUpload,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.logout_rounded,
                        color: Colors.grey),
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
              const ListTile(
                leading: Icon(Icons.info_outline_rounded, color: Colors.grey),
                title: Text('앱 정보',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                subtitle: Text(
                  '부엉이 학교 v$appVersionLabel\n문의: hizorro88@gmail.com',
                  style: TextStyle(height: 1.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            ''
            '이 앱은 서버 없이 모든 기록을 폰 안에만 저장하고,\n'
            '아이의 개인정보를 수집하지 않아요.',
            textAlign: TextAlign.center,
            style: TextStyle(
                fontSize: 12.5, color: Colors.grey.shade600, height: 1.6),
          ),
        ],
      ),
    );
  }

  Widget _card({required List<Widget> children}) {
    return Material(
      color: Colors.white,
      elevation: 1.5,
      shadowColor: Colors.black.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}
