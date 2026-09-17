import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/premium.dart';
import '../models/profile.dart';
import '../services/backup.dart';
import '../services/reminders.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/bouncy_button.dart';
import 'level_map_screen.dart';

/// 진도 백업·복원 화면 (부모 게이트 뒤의 리포트에서 열림).
/// 서버 없이 텍스트 코드 하나로 진도를 지키고, 새 폰으로 옮긴다.
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _code;
  final _restoreController = TextEditingController();
  bool _restoring = false;

  @override
  void dispose() {
    _restoreController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _makeCode() async {
    final code = await BackupService.export();
    await Clipboard.setData(ClipboardData(text: code));
    if (!mounted) return;
    setState(() => _code = code);
    _snack('📋 백업 코드를 복사했어요! 메모장·메신저에 붙여넣어 보관하세요');
  }

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      _snack('붙여넣을 내용이 없어요. 백업 코드를 먼저 복사해 주세요');
      return;
    }
    _restoreController.text = text;
    setState(() {});
  }

  Future<void> _restore() async {
    final code = _restoreController.text.trim();
    final info = BackupService.peek(code);
    if (info == null) {
      _snack('백업 코드를 읽을 수 없어요. 코드 전체가 빠짐없이 붙었는지 확인해 주세요');
      return;
    }
    final date =
        '${info.savedAt.year}년 ${info.savedAt.month}월 ${info.savedAt.day}일';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('이 백업으로 되돌릴까요?'),
        content: Text(
          '📅 $date 백업\n⭐ 통과한 단계 ${info.clearedLevels}개 · 🪙 코인 ${info.coins}\n\n'
          '지금 기기의 기록은 모두 백업 내용으로 바뀌어요.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('복원하기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _restoring = true);
    final done = await BackupService.restore(code);
    if (done) {
      // 메모리에 남아 있는 프로필·소리 설정을 복원된 값으로 다시 읽는다.
      await Profiles.init();
      await Sounds.init();
      await Speech.reloadSettings();
      await PremiumStore.init();
      // 복원된 알림 스위치 값에 실제 예약을 맞춘다 (응답은 기다리지 않음).
      await Reminders.syncWithSavedSetting();
    }
    if (!mounted) return;
    setState(() => _restoring = false);
    if (!done) {
      _snack('복원에 실패했어요. 코드를 다시 확인해 주세요');
      return;
    }
    // 복원된 기록으로 처음부터 다시 연다.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LevelMapScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFF5A78D6),
        foregroundColor: Colors.white,
        title: const Text(
          '💾 진도 백업·옮기기',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEFF),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              '이 앱은 서버 없이 모든 기록을 폰 안에만 저장해요. '
              '백업 코드를 만들어 메모장이나 메신저(나에게 보내기)에 보관해 두면, '
              '앱을 지웠거나 폰을 바꿔도 코드를 붙여넣어 진도를 그대로 되살릴 수 있어요.',
              style: TextStyle(fontSize: 13.5, height: 1.5),
            ),
          ),
          const SizedBox(height: 18),
          _card(
            title: '1️⃣ 백업 코드 만들기',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  '모든 프로필의 진도·별·코인·꾸미기가 코드 하나에 담겨요.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                BouncyButton(
                  color: const Color(0xFF5A78D6),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onTap: _makeCode,
                  child: const Text(
                    '백업 코드 만들고 복사하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_code != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: SelectableText(
                      _code!,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '복사되었어요. 코드가 길어도 전체를 한 번에 붙여넣으면 돼요.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          _card(
            title: '2️⃣ 백업 코드로 복원하기',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _restoreController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'OWL1. 로 시작하는 백업 코드를 붙여넣어 주세요',
                    hintStyle: const TextStyle(fontSize: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: BouncyButton(
                        color: Colors.white,
                        shadowColor: Colors.grey.shade300,
                        border:
                            Border.all(color: Colors.grey.shade300, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onTap: _pasteCode,
                        child: const Text(
                          '📋 붙여넣기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BouncyButton(
                        color: _restoreController.text.trim().isEmpty
                            ? Colors.grey.shade400
                            : const Color(0xFF58CC02),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onTap: _restoring ? () {} : _restore,
                        child: Text(
                          _restoring ? '복원 중…' : '✅ 복원하기',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _card({required String title, required Widget child}) {
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
}
