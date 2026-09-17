import 'package:flutter/material.dart';

import '../models/premium.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/parent_gate.dart';
import 'backup_screen.dart';

/// 설정: 효과음·말소리(문제 읽어주기)·말 빠르기, 진도 백업 바로가기.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
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
      backgroundColor: const Color(0xFFF3F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF6B7280),
        foregroundColor: Colors.white,
        title: const Text(
          '⚙️ 설정',
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
                activeTrackColor: const Color(0xFF58CC02),
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
                subtitle: const Text('글을 몰라도 풀 수 있게 문제·정답을 읽어줘요'),
                activeTrackColor: const Color(0xFF58CC02),
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
          const SizedBox(height: 14),
          _card(
            children: [
              ListTile(
                leading: const Text('💾', style: TextStyle(fontSize: 26)),
                title: const Text(
                  '진도 백업·옮기기',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: const Text('부모 확인 뒤 백업 코드로 진도를 지키고 옮겨요'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openBackup,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Text(PremiumStore.allUnlocked ? '🔓' : '🔑',
                    style: const TextStyle(fontSize: 26)),
                title: const Text(
                  '전체 열기 (가족용)',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                subtitle: Text(PremiumStore.allUnlocked
                    ? '모든 단계와 과목이 열려 있어요'
                    : '코드를 입력하면 모든 잠금이 열려요'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _toggleAllUnlock,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '매일 학습 알림은 리포트 화면에서 켤 수 있어요.\n'
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
