import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// 부모용 화면(결제·백업·설정 등) 앞에 두는 확인 관문.
///
/// 아이가 찍어서 통과할 수 없도록 보기 없이 **숫자 키패드로 직접 입력**한다
/// (두 자리 × 한 자리 곱셈). 3번 틀리면 30초 동안 잠긴다.
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
  late int _a, _b;
  late int _twist; // 0: 답을 거꾸로, 1: 답에 1을 더해
  String _input = '';
  int _wrongCount = 0;
  bool _shake = false;
  Timer? _ticker;

  int get _answer => _a * _b;
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
    // 거꾸로 뒤집었을 때 0으로 시작하지 않게 10의 배수는 피한다.
    do {
      _a = 12 + _random.nextInt(18); // 12..29
      _b = 3 + _random.nextInt(7); // 3..9
    } while (_a * _b % 10 == 0);
    _twist = _random.nextInt(2);
    _input = '';
  }

  /// 지시문까지 적용한 정답 (거꾸로 or +1)
  String get _expected => _twist == 0
      ? '$_answer'.split('').reversed.join()
      : '${_answer + 1}';

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
      child: Padding(
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
                  : '보호자만 들어갈 수 있어요.\n답을 눌러서 입력해 주세요.',
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
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _shake ? const Color(0xFFFFEBEB) : AppColors.cream,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    // 핵심 장치인 지시문을 문제 위에 크게 강조한다.
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF1CC),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _twist == 0
                            ? '⚠️ 답을 거꾸로 눌러 주세요'
                            : '⚠️ 답에 1을 더해 눌러 주세요',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF8A6100),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$_a × $_b = ${_input.isEmpty ? '?' : _input}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 30, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              if (_wrongCount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '앗! 위의 지시문을 다시 읽어 보세요 (${3 - _wrongCount}번 남음)',
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
