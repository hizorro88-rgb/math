import 'package:flutter/material.dart';

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
