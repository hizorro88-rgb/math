import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// 정답 안내판 아래에 놓는 얇은 카운트다운 막대.
/// [duration] 동안 오른쪽에서 왼쪽으로 줄어들고, 다 줄어들면 [onDone]을 부른다.
/// (아이가 그 전에 계속하기를 누르면 위젯이 사라지면서 타이머도 함께 멈춘다.)
class AutoNextBar extends StatefulWidget {
  const AutoNextBar({super.key, required this.color, required this.onDone});

  static const duration = Duration(seconds: 3);

  final Color color;
  final VoidCallback onDone;

  @override
  State<AutoNextBar> createState() => _AutoNextBarState();
}

class _AutoNextBarState extends State<AutoNextBar>
    with SingleTickerProviderStateMixin {
  // 벽시계가 아니라 "실제로 화면에 그려진 시간"으로 센다.
  // 정답 소리·음성 재생으로 화면이 잠깐 멈춰도(프레임 정지) 그동안은
  // 카운트다운이 흐르지 않아, 안내판을 볼 새도 없이 넘어가는 일이 없다.
  static const _maxFrameStep = Duration(milliseconds: 100);

  late final Ticker _ticker;
  Duration _lastElapsed = Duration.zero;
  double _progress = 0; // 0(가득) → 1(다 줄어듦)
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  void _onTick(Duration elapsed) {
    var step = elapsed - _lastElapsed;
    _lastElapsed = elapsed;
    // 오래 멈췄다 재개된 프레임은 한 걸음으로만 친다.
    if (step > _maxFrameStep) step = _maxFrameStep;

    setState(() {
      _progress += step.inMicroseconds / AutoNextBar.duration.inMicroseconds;
      if (_progress >= 1) _progress = 1;
    });
    if (_progress >= 1 && !_done) {
      _done = true;
      _ticker.stop();
      widget.onDone();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: 1 - _progress,
        minHeight: 5,
        backgroundColor: Colors.white.withValues(alpha: 0.55),
        color: widget.color,
      ),
    );
  }
}
