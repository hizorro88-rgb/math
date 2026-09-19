import 'package:flutter/material.dart';

/// 듀오링고처럼 아래에 진한 그림자가 깔려 있고, 누르면 쏙 들어가는 버튼.
class BouncyButton extends StatefulWidget {
  const BouncyButton({
    super.key,
    required this.color,
    required this.child,
    this.onTap,
    this.borderRadius = 20,
    this.padding = const EdgeInsets.symmetric(vertical: 16),
    this.shadowColor,
    this.border,
    this.debounce = true,
  });

  final Color color;

  /// 버튼 아래 3D 그림자 색. 없으면 [color]를 어둡게 만들어 쓴다.
  final Color? shadowColor;
  final Widget child;
  final VoidCallback? onTap;
  final double borderRadius;
  final EdgeInsets padding;
  final BoxBorder? border;

  /// 연타 방지(400ms). 화면 전환 버튼은 켜 두고,
  /// 접기/펼치기처럼 같은 자리에서 반복 탭하는 토글은 끈다.
  final bool debounce;

  /// [color]를 살짝 어둡게 만든다.
  static Color darken(Color color, [double amount = 0.18]) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness((hsl.lightness - amount).clamp(0.0, 1.0))
        .toColor();
  }

  @override
  State<BouncyButton> createState() => _BouncyButtonState();
}

class _BouncyButtonState extends State<BouncyButton> {
  bool _pressed = false;

  /// 연타로 화면 전환 등이 중복 실행되는 것을 막는다.
  DateTime? _lastTapTime;

  void _handleTap() {
    final now = DateTime.now();
    if (widget.debounce &&
        _lastTapTime != null &&
        now.difference(_lastTapTime!) < const Duration(milliseconds: 400)) {
      return;
    }
    _lastTapTime = now;
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final depth = _pressed || widget.onTap == null ? 0.0 : 4.0;
    final shadow = widget.shadowColor ?? BouncyButton.darken(widget.color);

    return GestureDetector(
      onTapDown:
          widget.onTap == null ? null : (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: widget.onTap == null
          ? null
          : (_) {
              setState(() => _pressed = false);
              _handleTap();
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        margin: EdgeInsets.only(top: 4 - depth, bottom: depth),
        padding: widget.padding,
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(widget.borderRadius),
          border: widget.border,
          boxShadow: [
            BoxShadow(color: shadow, offset: Offset(0, depth), blurRadius: 0),
          ],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}

/// 아무 위젯에나 "눌리는 느낌"(살짝 줄어들었다 돌아옴)을 입히는 래퍼.
/// 색·그림자·상태 표현은 자식이 그대로 관리한다. onTap이 null이면 반응 없음.
class PressBounce extends StatefulWidget {
  const PressBounce({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<PressBounce> createState() => _PressBounceState();
}

class _PressBounceState extends State<PressBounce> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: enabled
          ? (_) {
              setState(() => _pressed = false);
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? 0.93 : 1,
        duration: const Duration(milliseconds: 90),
        child: widget.child,
      ),
    );
  }
}
