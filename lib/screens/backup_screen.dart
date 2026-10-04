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
import '../theme.dart';

/// 진도 백업·복원 화면 (부모 게이트 뒤의 리포트에서 열림).
/// 텍스트 코드 하나로 진도를 지키고, 새 폰으로 옮긴다 (로그인 없이도 된다).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  String? _code;
  final _restoreController = TextEditingController();
  bool _restoring = false;

  /// 되돌릴 수 있는 '복원 직전 기록' (마지막 복원이 있었으면)
  BackupInfo? _undo;

  @override
  void initState() {
    super.initState();
    _loadUndo();
  }

  Future<void> _loadUndo() async {
    final undo = await BackupService.undoInfo();
    if (mounted) setState(() => _undo = undo);
  }

  @override
  void dispose() {
    _restoreController.dispose();
    super.dispose();
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 2)));
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
    final now = await BackupService.currentInfo();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('이 백업으로 되돌릴까요?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _compare(now: now, backup: info),
            const SizedBox(height: 12),
            const Text(
              '지금 기기의 기록은 모두 백업 내용으로 바뀌어요.\n'
              '바뀌기 직전 기록은 자동으로 보관돼서, 이 화면에서 되돌릴 수 있어요.',
              style:
                  TextStyle(fontSize: AppFont.small, color: AppColors.inkSoft),
            ),
          ],
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

    await _apply(() => BackupService.restore(code),
        fail: '복원에 실패했어요. 코드를 다시 확인해 주세요');
  }

  /// 복원 직전 기록으로 되돌린다 (부모 화면 안이라 확인 한 번)
  Future<void> _undoRestore() async {
    final undo = _undo;
    if (undo == null) return;
    final now = await BackupService.currentInfo();
    if (!mounted) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text('복원하기 전으로 돌아갈까요?'),
        content: _compare(now: now, backup: undo, backupLabel: '복원 전'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            key: const ValueKey('undo-ok'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('되돌리기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _apply(BackupService.undoRestore, fail: '되돌리지 못했어요');
  }

  /// 저장소를 바꾸고, 메모리에 남은 설정을 다시 읽은 뒤 홈부터 다시 연다.
  Future<void> _apply(Future<bool> Function() action,
      {required String fail}) async {
    setState(() => _restoring = true);
    final done = await action();
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
      _snack(fail);
      return;
    }
    // 복원된 기록으로 처음부터 다시 연다.
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LevelMapScreen()),
      (route) => false,
    );
  }

  /// 지금 기록 vs 백업 — 무엇이 바뀌는지 숫자로 나란히
  Widget _compare({
    required BackupInfo now,
    required BackupInfo backup,
    String backupLabel = '백업',
  }) {
    String date(DateTime d) => '${d.year}.${d.month}.${d.day}';
    final rows = [
      ('📅 날짜', '오늘', date(backup.savedAt)),
      ('🧒 프로필', '${now.profiles}명', '${backup.profiles}명'),
      ('⭐ 통과 단계', '${now.clearedLevels}', '${backup.clearedLevels}'),
      ('🪙 코인', '${now.coins}', '${backup.coins}'),
    ];
    Widget cell(String text, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: AppFont.small,
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        );
    return Table(
      key: const ValueKey('backup-compare'),
      columnWidths: const {0: FlexColumnWidth(1.3)},
      border: const TableBorder(
        horizontalInside: BorderSide(color: AppColors.line, width: 1.5),
      ),
      children: [
        TableRow(children: [
          cell(''),
          cell('지금', bold: true),
          cell(backupLabel, bold: true),
        ]),
        for (final r in rows)
          TableRow(children: [
            cell(r.$1, bold: true),
            cell(r.$2),
            cell(r.$3),
          ]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('진도 백업·옮기기'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: AppColors.outline, width: 2),
            ),
            child: const Text(
              '기록은 이 폰에 저장돼요 (클라우드에 로그인하면 계정에도 저장돼요). '
              '백업 코드를 만들어 메모장이나 메신저(나에게 보내기)에 보관해 두면, '
              '앱을 지웠거나 폰을 바꿔도 코드를 붙여넣어 진도를 그대로 되살릴 수 있어요.',
              style: TextStyle(fontSize: AppFont.small, height: 1.5),
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
                  style: TextStyle(
                      fontSize: AppFont.small, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 12),
                BouncyButton(
                  color: AppColors.green,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  onTap: _makeCode,
                  child: const Text(
                    '백업 코드 만들고 복사하기',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: AppFont.body,
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
                      color: AppColors.cream,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: SelectableText(
                      _code!,
                      maxLines: 4,
                      style: const TextStyle(
                          fontSize: AppFont.caption, fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '복사되었어요. 코드가 길어도 전체를 한 번에 붙여넣으면 돼요.',
                    style: TextStyle(
                        fontSize: AppFont.caption, color: AppColors.inkSoft),
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
                  style: const TextStyle(
                      fontSize: AppFont.caption, fontFamily: 'monospace'),
                  decoration: InputDecoration(
                    hintText: 'OWL1. 로 시작하는 백업 코드를 붙여넣어 주세요',
                    hintStyle: const TextStyle(fontSize: AppFont.small),
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
                        shadowColor: AppColors.outline,
                        border: Border.all(color: AppColors.outline, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onTap: _pasteCode,
                        child: const Text(
                          '📋 붙여넣기',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Builder(builder: (context) {
                        // 붙여 넣기 전에는 누를 수 없다 (눌러도 할 일이 없으니)
                        final enabled = !_restoring &&
                            _restoreController.text.trim().isNotEmpty;
                        return BouncyButton(
                          key: const ValueKey('backup-restore'),
                          color:
                              enabled ? AppColors.green : AppColors.lockedNode,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          onTap: enabled ? _restore : null,
                          child: Text(
                            _restoring ? '복원 중…' : '✅ 복원하기',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: AppFont.body,
                              fontWeight: FontWeight.bold,
                              color: enabled ? Colors.white : AppColors.inkSoft,
                            ),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_undo != null) ...[
            const SizedBox(height: 14),
            _card(
              title: '↩️ 복원 되돌리기',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '마지막으로 복원하기 직전 기록이 보관돼 있어요 '
                    '(⭐ ${_undo!.clearedLevels} · 🪙 ${_undo!.coins}).',
                    style: const TextStyle(
                        fontSize: AppFont.small, color: AppColors.inkSoft),
                  ),
                  const SizedBox(height: 10),
                  BouncyButton(
                    key: const ValueKey('backup-undo'),
                    color: Colors.white,
                    shadowColor: AppColors.outline,
                    border: Border.all(color: AppColors.outline, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: _restoring ? null : _undoRestore,
                    child: const Text(
                      '복원하기 전으로 되돌리기',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: AppFont.body, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
                fontSize: AppFont.title, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}
