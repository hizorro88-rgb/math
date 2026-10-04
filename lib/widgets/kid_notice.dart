import 'package:flutter/material.dart';

import '../services/speech.dart';
import '../theme.dart';
import 'bouncy_button.dart';
import 'quokka_avatar.dart';

/// 아이 화면용 알림: 큰 그림 하나 + 짧은 말 + 목소리.
/// 글만 있는 SnackBar는 글을 못 읽는 아이에게 아무 말도 하지 않은 것과 같다.
/// 부모 화면(설정·백업·이용권)은 SnackBar를 그대로 쓴다.
///
/// 화면 아래에서 말풍선이 올라와 말 길이만큼(2.8~5초) 머물다 사라지고,
/// 누르면 바로 닫힌다. 한 번에 하나만 — 새 알림이 오면 이전 것은 닫힌다.
///
/// 말하는 이는 왼쪽 얼굴: 기본은 쿼카 선생님, 홈·친구 방은 친구([face]).
/// 말투 규칙: "안 돼" 대신 다음에 할 일을 말한다. 오답음·빨강은 쓰지 않는다.
void showKidNotice(
  BuildContext context, {
  required String emoji,
  required String text,
  String? speech,
  String? face,
  VoidCallback? action,
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
      face: face,
      action: action,
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
    this.face,
    this.action,
  });

  final String emoji;
  final String text;
  final String? face;

  /// 다음 할 일 (▶ 원). 누르면 알림을 닫고 실행한다.
  final VoidCallback? action;
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
    // 읽어 주는 동안은 떠 있게: 글자 수 × 0.2초 + 1.5초 (2.8~5초)
    duration: Duration(
        milliseconds: widget.action != null
            ? 5000
            : (widget.text.length * 200 + 1500).clamp(2800, 5000)),
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
                    color: AppColors.floatShadow,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  if (widget.face != null)
                    Text(widget.face!, style: const TextStyle(fontSize: 38))
                  else
                    const QuokkaFace(size: 44),
                  const SizedBox(width: 8),
                  Text(widget.emoji, style: const TextStyle(fontSize: 34)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.text,
                      style: displayStyle(fontSize: AppFont.title)
                          .copyWith(height: 1.3),
                    ),
                  ),
                  if (widget.action != null) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      key: const ValueKey('kid-notice-go'),
                      onTap: () {
                        widget.onDone();
                        widget.action!();
                      },
                      child: Container(
                        width: 44,
                        height: 44,
                        decoration: const BoxDecoration(
                          color: AppColors.green,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow_rounded,
                            color: Colors.white, size: 30),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 아이용 확인 창: "그대로 할래"가 크고 초록(앞으로), 되돌릴 수 없는 일은 작고 흰 버튼.
/// 글을 못 읽는 아이가 눈에 띄는 버튼을 눌러도 아무것도 잃지 않게 한다.
/// 창이 뜰 때 질문을 읽어 준다. [action]을 골랐으면 true.
Future<bool> showKidConfirm(
  BuildContext context, {
  required String emoji,
  required String question,
  required String keepLabel,
  required String actionLabel,
  String? detail,
  String? speech,
}) async {
  Speech.speak(speech ?? question);
  final picked = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.cream,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const QuokkaFace(size: 60),
                const SizedBox(width: 6),
                Text(emoji, style: const TextStyle(fontSize: 44)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              question,
              textAlign: TextAlign.center,
              style: displayStyle(fontSize: AppFont.display),
            ),
            if (detail != null) ...[
              const SizedBox(height: 6),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: AppFont.small, color: AppColors.inkSoft),
              ),
            ],
            const SizedBox(height: 20),
            BouncyButton(
              key: const ValueKey('kid-confirm-keep'),
              color: AppColors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: () => Navigator.of(context).pop(false),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.play_arrow_rounded,
                      color: Colors.white, size: 28),
                  const SizedBox(width: 4),
                  Text(
                    keepLabel,
                    style: const TextStyle(
                      fontSize: AppFont.heading,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            BouncyButton(
              key: const ValueKey('kid-confirm-action'),
              color: Colors.white,
              shadowColor: AppColors.outline,
              border: Border.all(color: AppColors.outline, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 12),
              onTap: () => Navigator.of(context).pop(true),
              child: Text(
                actionLabel,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: AppFont.title,
                  fontWeight: FontWeight.bold,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
  return picked == true;
}
