import 'package:flutter/material.dart';

import '../theme.dart';

/// "여기를 누르세요"를 글 없이 알려주는 숨쉬기 확대·축소.
/// 다음에 할 일 하나에만 쓴다 — 여러 개가 동시에 뛰면 뜻이 사라진다.
class Pulse extends StatefulWidget {
  const Pulse({super.key, required this.child, this.scale = 1.07});

  final Widget child;
  final double scale;

  @override
  State<Pulse> createState() => _PulseState();
}

class _PulseState extends State<Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (AppMotion.loops) _controller.repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween(begin: 1.0, end: widget.scale).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: widget.child,
    );
  }
}
