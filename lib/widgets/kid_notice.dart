import 'package:flutter/material.dart';

import '../services/speech.dart';
import '../theme.dart';

/// 아이 화면용 알림: 큰 그림 하나 + 짧은 말 + 목소리.
/// 글만 있는 SnackBar는 글을 못 읽는 아이에게 아무 말도 하지 않은 것과 같다.
/// 부모 화면(설정·백업·이용권)은 SnackBar를 그대로 쓴다.
///
/// 화면 아래에서 말풍선이 올라와 2.8초 뒤 사라지고, 누르면 바로 닫힌다.
/// 한 번에 하나만 — 새 알림이 오면 이전 것은 닫힌다.
void showKidNotice(
  BuildContext context, {
  required String emoji,
  required String text,
  String? speech,
}) {
  Speech.speak(speech ?? text);
  _current?.remove();
  _current = null;
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _KidNotice(
      emoji: emoji,
      text: text,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

OverlayEntry? _current;

class _KidNotice extends StatefulWidget {
  const _KidNotice({
    required this.emoji,
    required this.text,
    required this.onDone,
  });

  final String emoji;
  final String text;
  final VoidCallback onDone;

  @override
  State<_KidNotice> createState() => _KidNoticeState();
}

class _KidNoticeState extends State<_KidNotice>
    with SingleTickerProviderStateMixin {
  // 타이머 대신 애니메이션 하나로 나타남·머무름·사라짐을 함께 센다
  // (위젯 테스트에서 남은 타이머가 생기지 않게).
  late final AnimationController _life = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2800),
  )
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom + 24;
    return Positioned(
      left: 20,
      right: 20,
      bottom: bottom,
      child: AnimatedBuilder(
        animation: _life,
        builder: (context, child) {
          final t = _life.value;
          // 0~8%: 올라오며 나타남 / 90~100%: 흐려지며 사라짐
          final inT = (t / 0.08).clamp(0.0, 1.0);
          final outT = ((1 - t) / 0.1).clamp(0.0, 1.0);
          return Opacity(
            opacity: inT * outT,
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - Curves.easeOutBack.transform(inT))),
              child: child,
            ),
          );
        },
        child: Material(
          type: MaterialType.transparency,
          child: GestureDetector(
            onTap: widget.onDone,
            child: Container(
              key: const ValueKey('kid-notice'),
              padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.outline, width: 2),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Text(widget.emoji, style: const TextStyle(fontSize: 40)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
