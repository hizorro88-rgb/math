import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 부모용 화면(결제·백업·설정 등) 앞에 두는 확인 관문.
///
/// 아이가 찍어서 통과할 수 없도록, 한글로 쓴 세 자리 수(예: 삼백사십칠)를
/// 읽고 숫자 키패드로 직접 입력한다. 연산이 아니라 문해 기반이라
/// 보호자에게는 쉽고 아이에게는 어렵다. 3번 틀리면 30초 동안 잠긴다.
/// (구글 플레이 가족 정책의 보호자 게이트 요건 대응)
Future<bool> checkParentGate(BuildContext context) async {
  final passed = await showDialog<bool>(
    context: context,
    builder: (context) => const _ParentGateDialog(),
  );
  return passed == true;
}

class _ParentGateDialog extends StatefulWidget {
  const _ParentGateDialog();

  @override
  State<_ParentGateDialog> createState() => _ParentGateDialogState();
}

class _ParentGateDialogState extends State<_ParentGateDialog> {
  /// 연속 오답 잠금은 다이얼로그를 닫았다 열어도 유지한다.
  static DateTime? _lockedUntil;

  final _random = Random();
  late int _target;
  String _input = '';
  int _wrongCount = 0;
  bool _shake = false;
  Timer? _ticker;
  bool get _locked =>
      _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);
  int get _lockSecondsLeft =>
      _locked ? _lockedUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

  @override
  void initState() {
    super.initState();
    _newProblem();
    if (_locked) _startTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _newProblem() {
    // 읽기 쉬운 표기를 위해 모든 자리가 1~9인 세 자리 수만 낸다.
    _target = (1 + _random.nextInt(9)) * 100 +
        (1 + _random.nextInt(9)) * 10 +
        (1 + _random.nextInt(9));
    _input = '';
  }

  static const _digitWords = ['', '일', '이', '삼', '사', '오', '육', '칠', '팔', '구'];

  /// 347 → "삼백사십칠" (백·십의 1은 관례대로 생략)
  String get _hangul {
    final h = _target ~/ 100, t = (_target ~/ 10) % 10, o = _target % 10;
    return '${h == 1 ? '' : _digitWords[h]}백'
        '${t == 1 ? '' : _digitWords[t]}십'
        '${_digitWords[o]}';
  }

  String get _expected => '$_target';

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        if (!_locked) {
          _ticker?.cancel();
          _wrongCount = 0;
          _newProblem();
        }
      });
    });
  }

  void _tapDigit(int digit) {
    if (_locked || _input.length >= 3) return;
    setState(() => _input = '$_input$digit');
  }

  void _tapBackspace() {
    if (_locked || _input.isEmpty) return;
    setState(() => _input = _input.substring(0, _input.length - 1));
  }

  void _submit() {
    if (_locked || _input.isEmpty) return;
    if (_input == _expected) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() {
      _wrongCount++;
      _shake = true;
      if (_wrongCount >= 3) {
        _lockedUntil = DateTime.now().add(const Duration(seconds: 30));
        _startTicker();
      } else {
        _newProblem(); // 틀리면 다른 문제로 바꿔서 하나씩 지워가며 못 맞히게
      }
    });
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) setState(() => _shake = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 아이가 실수로 들어왔을 때의 탈출구
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                key: const ValueKey('gate-close'),
                onPressed: () => Navigator.of(context).pop(false),
                icon: const Icon(Icons.close_rounded,
                    size: 26, color: AppColors.inkSoft),
              ),
            ),
            const Icon(Icons.supervisor_account_rounded,
                size: 40, color: AppColors.brown),
            const SizedBox(height: 6),
            Text(
              '부모님 확인',
              textAlign: TextAlign.center,
              style: displayStyle(fontSize: 22),
            ),
            const SizedBox(height: 4),
            Text(
              _locked
                  ? '너무 많이 틀렸어요.\n$_lockSecondsLeft초 뒤에 다시 해 주세요.'
                  : '보호자만 들어갈 수 있어요.\n아래 문제를 풀어 주세요.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _locked ? AppColors.coral : Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 12),
            if (!_locked) ...[
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _shake ? const Color(0xFFFFEBEB) : AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1CC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '아래 한글 수를 숫자로 눌러 주세요',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8A6100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _hangul,
                      key: const ValueKey('gate-question'),
                      textAlign: TextAlign.center,
                      style: displayStyle(fontSize: 30),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _input.isEmpty ? '□ □ □' : _input,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.inkSoft),
                    ),
                  ],
                ),
              ),
              if (_wrongCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '앗, 다시 읽어 볼까요? (${3 - _wrongCount}번 남음)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppColors.coral,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              for (final row in const [
                [1, 2, 3],
                [4, 5, 6],
                [7, 8, 9],
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      for (final d in row) _digitKey(d),
                    ],
                  ),
                ),
              Row(
                children: [
                  _key(
                    key: const ValueKey('gate-back'),
                    onTap: _tapBackspace,
                    child: const Icon(Icons.backspace_outlined,
                        size: 22, color: AppColors.inkSoft),
                  ),
                  _digitKey(0),
                  _key(
                    key: const ValueKey('gate-ok'),
                    color: AppColors.green,
                    onTap: _submit,
                    child: const Text(
                      '확인',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _digitKey(int digit) => _key(
        key: ValueKey('gate-$digit'),
        onTap: () => _tapDigit(digit),
        child: Text(
          '$digit',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      );

  Widget _key({
    required Key key,
    required VoidCallback onTap,
    required Widget child,
    Color? color,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Material(
          key: key,
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 46,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: color == null
                    ? Border.all(color: AppColors.outline, width: 1.5)
                    : null,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
