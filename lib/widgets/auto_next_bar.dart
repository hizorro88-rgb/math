import 'package:flutter/material.dart';

/// 정답 안내판 아래에 놓는 얇은 카운트다운 막대.
/// 2초 동안 오른쪽에서 왼쪽으로 줄어들고, 다 줄어들면 [onDone]을 부른다.
/// (아이가 그 전에 계속하기를 누르면 위젯이 사라지면서 타이머도 함께 멈춘다.)
class AutoNextBar extends StatefulWidget {
  const AutoNextBar({super.key, required this.color, required this.onDone});

  static const duration = Duration(seconds: 2);

  final Color color;
  final VoidCallback onDone;

  @override
  State<AutoNextBar> createState() => _AutoNextBarState();
}

class _AutoNextBarState extends State<AutoNextBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AutoNextBar.duration,
  )
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed) widget.onDone();
    })
    ..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: LinearProgressIndicator(
          value: 1 - _controller.value,
          minHeight: 5,
          backgroundColor: Colors.white.withValues(alpha: 0.55),
          color: widget.color,
        ),
      ),
    );
  }
}
