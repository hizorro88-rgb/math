import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/speech.dart';
import '../theme.dart';
import 'auto_next_bar.dart';
import 'bouncy_button.dart';
import 'quokka_avatar.dart';
import 'sparkle_burst.dart';

/// 모든 과목의 퀴즈 화면이 같이 쓰는 틀.
/// 수학·한글·영어·외국어가 같은 자리에 같은 모양으로 놓여야
/// 글을 못 읽는 아이도 한 번 익힌 동선을 어느 과목에서나 그대로 쓴다.
///
/// ┌ ✕ ●●●○○○○○○○ 🪙 ┐   ← 상단바: 글자 없이 점으로 진행
/// │ ┌──────────── 🔊┐ │   ← 문제 카드: 듣기 버튼은 늘 오른쪽 위
/// │ │   문제         │ │
/// │ └───────────────┘ │
/// │   🐹 응원          │
/// │  [보기] [보기]     │   ← 답은 엄지가 닿는 아래쪽
/// │  [보기] [보기]     │
/// └ 정답/오답 판 ─────┘

// ───────────────────────── 목소리 ─────────────────────────

/// 퀴즈 음성을 한곳에 모은다 — 과목마다 다르게 말하면 아이가 헷갈린다.
class QuizVoice {
  QuizVoice._();

  static final _random = math.Random();

  static const _correct = [
    '정답이에요!',
    '딩동댕, 맞았어요!',
    '우와, 정답!',
    '참 잘했어요!',
    '대단해요!',
    '역시 최고예요!',
  ];

  /// 맞혔을 때. 연속 정답은 그 자체가 사건이 되게 따로 읽어 준다.
  /// [say]가 있으면 먼저 읽는다 — 낱말 만들기를 끝내면 만든 낱말을 들려준 뒤 칭찬.
  static void correct(int combo, {String? say, String lang = 'ko-KR'}) {
    final praise = combo == 3
        ? '와, 3개 연속이에요!'
        : combo == 5
            ? '대단해요, 5연속!'
            : _correct[_random.nextInt(_correct.length)];
    if (say == null) {
      Speech.speak(praise);
    } else {
      Speech.speakParts([(say, lang), (praise, 'ko-KR')]);
    }
  }

  /// 틀렸을 때: 한국어로 격려하고, 정답은 그 언어 발음으로.
  static void wrong(String answer, {String lang = 'ko-KR'}) {
    if (lang == 'ko-KR') {
      Speech.speak('괜찮아요! 정답은 $answer');
    } else {
      Speech.speakParts([('괜찮아요! 정답은', 'ko-KR'), (answer, lang)]);
    }
  }

  /// 틀렸을 때(외국어): 격려한 뒤 문제 소리를 한 번 더 들려준다.
  /// 보기가 한국어 뜻일 수도 있어서 "정답은 …" 대신 소리를 다시 듣게 한다.
  static void wrongReplay(String speech, {required String lang}) {
    Speech.speakParts([('괜찮아요! 다시 들어 봐요', 'ko-KR'), (speech, lang)]);
  }

  /// 낱말 만들기 조각을 눌렀을 때 그 조각 소리
  static void tile(String text, {String lang = 'ko-KR'}) {
    Speech.speak(text, lang: lang);
  }

  /// 문제 읽기. 처음 나올 때는 한국어 과제를 먼저 읽고 소리를 읽는다.
  /// 아이가 🔊를 눌러 다시 들을 때([force])는 소리만 바로 들려준다.
  /// 다시 나온 문제는 "아까 그 문제!"로 알려 준다.
  static void question({
    required String task,
    required String speech,
    String lang = 'ko-KR',
    bool retry = false,
    bool bonus = false,
    bool force = false,
  }) {
    if (force) {
      Speech.speak(speech, lang: lang, force: true);
      return;
    }
    // 문장으로 된 음성(…일까요? / …보세요)은 그 자체가 과제라 겹쳐 읽지 않는다.
    final selfContained = lang == 'ko-KR' &&
        (speech.endsWith('?') || speech.endsWith('요') || speech.endsWith('요.'));
    Speech.speakParts([
      if (retry) ('아까 그 문제예요!', 'ko-KR'),
      if (bonus) ('보너스 문제! 맞히면 코인 두 배!', 'ko-KR'),
      if (!selfContained) (task, 'ko-KR'),
      (speech, lang),
    ]);
  }
}

// ───────────────────────── 진행 점 ─────────────────────────

/// 진행 점 하나의 상태
enum QuizDot {
  /// 아직 안 푼 문제
  pending,

  /// 한 번에 맞힌 문제
  correct,

  /// 틀려서 뒤에 다시 나올 문제
  missed,

  /// 틀렸다가 다시 풀어 맞힌 문제
  fixed,
}

/// 문제마다 점 하나. 틀린 문제를 다시 풀어도 점이 늘어나지 않고
/// 그 문제의 점이 다시 반짝인다 — "문제 11/11"처럼 끝이 도망가지 않는다.
class QuizDotTracker {
  QuizDotTracker(int count)
      : dots = List.filled(count, QuizDot.pending),
        _origins = List.generate(count, (i) => i);

  final List<QuizDot> dots;

  /// 퀴즈 목록의 n번째가 원래 몇 번째 문제였는지
  final List<int> _origins;

  /// 지금 풀고 있는 퀴즈 목록 위치 → 강조할 점
  int dotFor(int entryIndex) =>
      entryIndex < _origins.length ? _origins[entryIndex] : 0;

  /// 채점 결과를 점에 남긴다. 첫 시도에 틀리면 같은 점이 뒤에 한 번 더 온다
  /// (퀴즈 화면들이 틀린 문제를 목록 끝에 다시 넣는 것과 짝을 맞춘다).
  void record(int entryIndex, {required bool correct, required bool retry}) {
    final origin = dotFor(entryIndex);
    if (retry) {
      if (correct) dots[origin] = QuizDot.fixed;
      return;
    }
    dots[origin] = correct ? QuizDot.correct : QuizDot.missed;
    if (!correct) _origins.add(origin);
  }
}

/// 상단바 가운데의 진행 점 줄
class QuizProgressDots extends StatelessWidget {
  const QuizProgressDots({
    super.key,
    required this.dots,
    required this.current,
    required this.color,
  });

  final List<QuizDot> dots;

  /// 지금 풀고 있는 점 (-1이면 없음)
  final int current;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      const gap = 4.0;
      final n = dots.length;
      final size = math
          .min(18.0, (constraints.maxWidth - gap * n - 30) / (n + 0.4))
          .clamp(6.0, 18.0);
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            _Dot(
              state: dots[i],
              active: i == current,
              size: size,
              color: color,
            ),
          ],
          // 끝이 어디인지 그림으로
          const SizedBox(width: gap + 2),
          Text('🏁', style: TextStyle(fontSize: size + 2)),
        ],
      );
    });
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.state,
    required this.active,
    required this.size,
    required this.color,
  });

  final QuizDot state;
  final bool active;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (fill, border) = switch (state) {
      QuizDot.pending => (AppColors.line, AppColors.line),
      QuizDot.correct => (AppColors.correct, AppColors.correct),
      QuizDot.missed => (const Color(0xFFFFC9A8), const Color(0xFFFFC9A8)),
      QuizDot.fixed => (AppColors.selectedFill, AppColors.correct),
    };
    final s = active ? size * 1.4 : size;
    final done = state == QuizDot.correct || state == QuizDot.fixed;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: s,
      height: s,
      decoration: BoxDecoration(
        color: active && !done ? Colors.white : fill,
        shape: BoxShape.circle,
        border: Border.all(
          color: active ? color : border,
          width: active ? 3 : (state == QuizDot.pending ? 0 : 2),
        ),
      ),
      child: done && s >= 12
          ? Icon(
              Icons.check_rounded,
              size: s * 0.7,
              color:
                  state == QuizDot.correct ? Colors.white : AppColors.correct,
            )
          : null,
    );
  }
}

// ───────────────────────── 상단바 ─────────────────────────

/// ✕ | 진행 점 | (🔥) 🪙 — 글자 없이 그림만.
/// 단원 이름·단계는 읽어주기(접근성)로만 붙인다.
class QuizTopBar extends StatelessWidget {
  const QuizTopBar({
    super.key,
    required this.onClose,
    required this.dots,
    required this.current,
    required this.coins,
    required this.color,
    this.combo = 0,
    this.leading,
    this.label,
  });

  final VoidCallback onClose;
  final List<QuizDot> dots;
  final int current;

  /// 이번 판 코인 (null이면 🪙 칩을 숨긴다 — 오답 노트처럼 코인이 없는 판)
  final int? coins;
  final Color color;

  /// 연속 정답 수 (3부터 🔥가 보인다)
  final int combo;

  /// 점 앞에 붙는 그림 하나 (보스전 👑 등)
  final String? leading;

  /// 화면 읽기용 이름 (예: "수 세기 첫걸음 · 1단계")
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 8, 16, 0),
        child: Row(
          children: [
            IconButton(
              tooltip: '그만하기',
              icon: const Icon(Icons.close_rounded, size: 30),
              color: AppColors.inkMuted,
              onPressed: onClose,
            ),
            if (leading != null) ...[
              Text(leading!, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 6),
            ],
            Expanded(
              child:
                  QuizProgressDots(dots: dots, current: current, color: color),
            ),
            const SizedBox(width: 10),
            if (combo >= 3) ...[
              _Chip(text: '✨$combo', color: const Color(0xFFFFE8D2)),
              const SizedBox(width: 6),
            ],
            // 이번 판에 번 코인 (+N) — 홈·결과의 '가진 코인'과 헷갈리지 않게
            if (coins != null)
              _Chip(text: '🪙 +$coins', color: AppColors.rewardSurface),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: AppColors.ink,
        ),
      ),
    );
  }
}

// ───────────────────────── 문제 카드 ─────────────────────────

/// 듣기 버튼 — 앱 어디서나 "파란 동그라미 = 소리 듣기" 하나의 뜻.
class QuizSpeakButton extends StatelessWidget {
  const QuizSpeakButton({super.key, required this.onTap, this.size = 48});

  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '다시 듣기',
      onTap: onTap,
      excludeSemantics: true,
      child: PressBounce(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.listen,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: BouncyButton.darken(AppColors.listen),
                offset: Offset(0, size > 60 ? 6 : 3),
              ),
            ],
          ),
          child: Icon(
            Icons.volume_up_rounded,
            size: size * 0.56,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 문제 카드 위의 작은 표시 (다시 풀기 / 보너스)
class QuizBadge extends StatelessWidget {
  const QuizBadge.retry({super.key})
      : text = '🔁 한 번 더!',
        fill = AppColors.wrongSurface,
        ink = AppColors.wrongInk;

  const QuizBadge.bonus({super.key})
      : text = '⚡ 🪙×2',
        fill = AppColors.rewardSurface,
        ink = const Color(0xFF9A6A00);

  final String text;
  final Color fill;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: ink),
      ),
    );
  }
}

/// 흰 문제 카드: 윗줄 [표시 · 안내문 · 🔊], 아래에 문제.
/// 듣기 버튼이 늘 같은 자리(오른쪽 위)에 있고 글과 겹치지 않는다.
class QuizCard extends StatelessWidget {
  const QuizCard({
    super.key,
    required this.color,
    required this.child,
    this.instruction = '',
    this.onSpeak,
    this.badge,
  });

  final Color color;
  final Widget child;
  final String instruction;

  /// null이면 듣기 버튼을 숨긴다 (문제 자체가 큰 듣기 버튼일 때)
  final VoidCallback? onSpeak;
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    const side = 48.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: color.withValues(alpha: 0.35), width: 3),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.12),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(width: side),
              Expanded(
                child: Column(
                  children: [
                    if (badge != null) badge!,
                    if (badge != null && instruction.isNotEmpty)
                      const SizedBox(height: 6),
                    if (instruction.isNotEmpty)
                      Text(
                        instruction,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.inkSoft,
                        ),
                      ),
                  ],
                ),
              ),
              if (onSpeak != null)
                QuizSpeakButton(onTap: onSpeak!, size: side)
              else
                const SizedBox(width: side, height: side),
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

// ───────────────────────── 쿼카 응원 ─────────────────────────

/// 쿼카가 말풍선을 띄우는 때는 특별한 순간뿐 (다시 나온 문제·보너스·절반).
/// 매 문제 글을 띄우면 아이에게는 읽지 못하는 소음이다.
String? quizCheerLine({
  required int index,
  required bool retry,
  bool bonus = false,
}) {
  if (retry) return '아까 그 문제야! 할 수 있어!';
  if (bonus) return '⚡ 보너스! 맞히면 🪙 두 배!';
  if (index == 5) return '절반 왔어! 조금만 더!';
  return null;
}

/// 문제 카드와 보기 사이의 쿼카 선생님.
/// 말풍선은 문제를 풀 때만 — 답을 고른 뒤에는 아래 판이 말하니
/// 쿼카는 글 없이 깡충(정답) 뛰거나 끄덕(오답)인다.
class QuizCheer extends StatelessWidget {
  const QuizCheer({super.key, this.line, this.reaction});

  final String? line;

  /// null이면 가만히, true면 깡충, false면 끄덕
  final bool? reaction;

  @override
  Widget build(BuildContext context) {
    Widget face = const QuokkaFace(size: 64);
    if (reaction != null) {
      final hop = reaction!;
      face = TweenAnimationBuilder<double>(
        key: ValueKey(hop),
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 700),
        builder: (context, t, child) {
          final wave = math.sin(t * math.pi * (hop ? 2 : 3)) * (1 - t);
          return Transform.translate(
            offset: hop ? Offset(0, -18 * wave.abs()) : Offset(0, 5 * wave),
            child: child,
          );
        },
        child: face,
      );
    }
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          face,
          if (line != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.brownSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  line!,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.brown,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── 보기 ─────────────────────────

enum QuizChoiceState { idle, correct, wrong, disabled }

/// 보기 버튼 — 네 과목 모두 같은 파스텔 4색·같은 상태 색.
class QuizChoiceButton extends StatelessWidget {
  const QuizChoiceButton({
    super.key,
    required this.label,
    required this.state,
    required this.fillIndex,
    required this.onTap,
    this.fontSize = 34,
    this.long = false,
  });

  final String label;
  final QuizChoiceState state;

  /// 보기 위치(0~3)별 파스텔 색
  final int fillIndex;
  final VoidCallback onTap;
  final double fontSize;

  /// 문장처럼 긴 보기면 작은 글씨로 줄바꿈해서 보여 준다.
  final bool long;

  @override
  Widget build(BuildContext context) {
    final (background, border, textColor) = switch (state) {
      QuizChoiceState.idle => (
          AppColors.choiceFills[fillIndex % 4],
          AppColors.choiceBorders[fillIndex % 4],
          AppColors.ink,
        ),
      QuizChoiceState.correct => (
          AppColors.selectedFill,
          AppColors.correct,
          AppColors.greenPressed,
        ),
      QuizChoiceState.wrong => (
          AppColors.wrongSurface,
          AppColors.wrong,
          AppColors.wrongInk,
        ),
      QuizChoiceState.disabled => (
          AppColors.cream,
          AppColors.line,
          AppColors.inkMuted,
        ),
    };

    final text = long
        ? Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              height: 1.25,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          )
        : FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          );

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 3),
        boxShadow: state == QuizChoiceState.idle
            ? [BoxShadow(color: border, offset: const Offset(0, 4))]
            : null,
      ),
      child: Center(child: text),
    );

    // 틀린 버튼은 좌우로 도리도리 흔들린다.
    if (state == QuizChoiceState.wrong) {
      button = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: const Duration(milliseconds: 500),
        builder: (context, t, child) => Transform.translate(
          offset: Offset(math.sin(t * math.pi * 5) * 8 * (1 - t), 0),
          child: child,
        ),
        child: button,
      );
    }

    // 정답 칸에는 ✓ 하나 — 글을 못 읽어도 "이게 답"을 안다.
    if (state == QuizChoiceState.correct) {
      button = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: button),
          const Positioned(
            top: -8,
            right: -6,
            child: CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.correct,
              child: Icon(Icons.check_rounded, size: 18, color: Colors.white),
            ),
          ),
        ],
      );
    }

    return PressBounce(onTap: onTap, child: button);
  }
}

/// 보기를 두 개씩 줄지어 놓는다 (홀수면 마지막은 가운데).
/// GridView 대신 Row를 써서 퀴즈 틀(IntrinsicHeight) 안에서도 그려진다.
class QuizChoiceGrid extends StatelessWidget {
  const QuizChoiceGrid({
    super.key,
    required this.children,
    this.height = 96,
  });

  final List<Widget> children;
  final double height;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += 2) {
      if (i > 0) rows.add(const SizedBox(height: 12));
      final pair = children.skip(i).take(2).toList();
      rows.add(Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: pair.length == 2
            ? [
                Expanded(child: SizedBox(height: height, child: pair[0])),
                const SizedBox(width: 12),
                Expanded(child: SizedBox(height: height, child: pair[1])),
              ]
            : [
                const Expanded(child: SizedBox()),
                Expanded(
                    flex: 2, child: SizedBox(height: height, child: pair[0])),
                const Expanded(child: SizedBox()),
              ],
      ));
    }
    return Column(children: rows);
  }
}

// ───────────────────────── 낱말 만들기 ─────────────────────────

/// 낱말 만들기의 빈 칸 하나
class QuizSlot extends StatelessWidget {
  const QuizSlot({
    super.key,
    required this.text,
    required this.active,
    required this.answered,
    required this.correct,
    required this.color,
    this.wide = false,
  });

  final String text;
  final bool active;
  final bool answered;
  final bool correct;
  final Color color;

  /// 낱말 단위 칸(영어 문장)이면 글자 수만큼 넓어진다.
  final bool wide;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: wide ? null : 46,
      constraints: wide ? const BoxConstraints(minWidth: 54) : null,
      height: 52,
      padding: wide ? const EdgeInsets.symmetric(horizontal: 10) : null,
      decoration: BoxDecoration(
        color: answered
            ? (correct ? AppColors.selectedFill : AppColors.wrongSurface)
            : active
                ? color.withValues(alpha: 0.08)
                : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: answered
              ? (correct ? AppColors.correct : AppColors.wrong)
              : active
                  ? color
                  : AppColors.outline,
          width: active && !answered ? 3 : 2,
        ),
      ),
      child: Center(
        child: Text(
          text,
          style: TextStyle(
            fontSize: wide ? 19 : 26,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
      ),
    );
  }
}

/// 낱말 만들기의 글자(낱말) 조각. [text]가 null이면 지우기 조각.
class QuizTile extends StatelessWidget {
  const QuizTile({
    super.key,
    required this.text,
    required this.onTap,
    this.used = false,
    this.wide = false,
  });

  const QuizTile.backspace({super.key, required this.onTap})
      : text = null,
        used = false,
        wide = false;

  final String? text;
  final VoidCallback? onTap;
  final bool used;
  final bool wide;

  @override
  Widget build(BuildContext context) {
    final off = used || onTap == null;
    return PressBounce(
      onTap: off ? null : onTap,
      child: Container(
        width: wide ? null : 60,
        constraints: wide ? const BoxConstraints(minWidth: 60) : null,
        padding: wide ? const EdgeInsets.symmetric(horizontal: 12) : null,
        height: 60,
        decoration: BoxDecoration(
          color: off ? AppColors.cream : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color: off ? AppColors.line : AppColors.outline, width: 2),
          boxShadow: off
              ? null
              : const [
                  BoxShadow(color: AppColors.outline, offset: Offset(0, 3)),
                ],
        ),
        child: Center(
          child: text == null
              ? Icon(
                  Icons.backspace_rounded,
                  size: 24,
                  color: off ? AppColors.line : AppColors.inkSoft,
                )
              : Text(
                  text!,
                  style: TextStyle(
                    fontSize: wide ? 20 : 26,
                    fontWeight: FontWeight.bold,
                    color: off ? AppColors.inkMuted : AppColors.ink,
                  ),
                ),
        ),
      ),
    );
  }
}

// ───────────────────────── 정답/오답 판 ─────────────────────────

/// 화면 아래에서 올라오는 판. 맞으면 라임+초록, 틀리면 살구색+갈색(꾸짖지 않는다).
/// 틀렸을 때는 정답을 큰 칩으로 보여 줘서 글을 못 읽어도 "이게 답"이 보인다.
class QuizFeedbackPanel extends StatelessWidget {
  const QuizFeedbackPanel({
    super.key,
    required this.correct,
    required this.answerText,
    required this.isLast,
    required this.onNext,
    required this.autoNextKey,
    this.correctMessage = '정답이에요! 🎉',
    this.gained = 0,
    this.fire = false,
    this.autoNext = true,
  });

  final bool correct;
  final String answerText;
  final bool isLast;
  final VoidCallback onNext;
  final Key autoNextKey;
  final String correctMessage;

  /// 이번 문제로 얻은 코인
  final int gained;

  /// 연속 정답 보너스(🔥)가 붙었는지
  final bool fire;

  /// 맞혔을 때 3초 뒤 자동으로 넘어갈지
  final bool autoNext;

  @override
  Widget build(BuildContext context) {
    final ink = correct ? AppColors.greenPressed : AppColors.wrongInk;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        color: correct ? AppColors.selectedFill : AppColors.wrongSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: correct ? AppColors.correct : Colors.white,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: correct
                      ? const Icon(Icons.check_rounded,
                          size: 30, color: Colors.white)
                      : const Text('💡', style: TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: correct
                      ? Text(
                          correctMessage,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: ink,
                          ),
                        )
                      : Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Text(
                              '괜찮아요! 정답은',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: ink,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                    color: AppColors.correct, width: 2),
                              ),
                              child: Text(
                                answerText,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
                if (correct && gained > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      fire ? '+$gained 🪙✨' : '+$gained 🪙',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: ink,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 14),
            BouncyButton(
              color: AppColors.green,
              onTap: onNext,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isLast ? '결과 보기' : '계속하기',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isLast
                        ? Icons.emoji_events_rounded
                        : Icons.play_arrow_rounded,
                    size: 28,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
            if (correct && autoNext) ...[
              const SizedBox(height: 10),
              // 3초 동안 줄어드는 막대: 다 줄면 자동으로 다음 문제로
              AutoNextBar(
                key: autoNextKey,
                color: AppColors.green,
                onDone: onNext,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── 화면 틀 ─────────────────────────

/// 퀴즈 화면 틀: 문제는 위, 답은 엄지가 닿는 아래쪽.
/// 화면이 작으면 스크롤되고, 크면 답이 바닥에 붙는다.
class QuizScaffold extends StatefulWidget {
  const QuizScaffold({
    super.key,
    required this.topBar,
    required this.card,
    required this.answers,
    this.cheer,
    this.feedback,
    this.sparkle = false,
    this.sparkleKey,
  });

  final Widget topBar;
  final Widget card;
  final Widget answers;
  final Widget? cheer;
  final Widget? feedback;

  /// 연속 정답 반짝반짝
  final bool sparkle;
  final Key? sparkleKey;

  @override
  State<QuizScaffold> createState() => _QuizScaffoldState();
}

class _QuizScaffoldState extends State<QuizScaffold> {
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(covariant QuizScaffold old) {
    super.didUpdateWidget(old);
    // 정답/오답 판이 올라오면 화면이 줄어든다 — 보기(정답 칸)가 가려지지 않게
    // 맨 아래(보기 쪽)로 굴린다.
    if (old.feedback == null && widget.feedback != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_scroll.hasClients) return;
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                widget.topBar,
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
                      controller: _scroll,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: ConstrainedBox(
                        constraints:
                            BoxConstraints(minHeight: constraints.maxHeight),
                        child: IntrinsicHeight(
                          child: Column(
                            children: [
                              const SizedBox(height: 12),
                              widget.card,
                              const Spacer(),
                              if (widget.cheer != null) ...[
                                const SizedBox(height: 12),
                                widget.cheer!,
                              ],
                              const SizedBox(height: 16),
                              const Spacer(),
                              widget.answers,
                              const SizedBox(height: 16),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                if (widget.feedback != null) widget.feedback!,
              ],
            ),
            if (widget.sparkle)
              Positioned.fill(
                child:
                    IgnorePointer(child: SparkleBurst(key: widget.sparkleKey)),
              ),
          ],
        ),
      ),
    );
  }
}
