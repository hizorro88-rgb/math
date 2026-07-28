import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/curriculum.dart';
import '../models/daily.dart';
import '../models/progress.dart';
import '../models/question.dart';
import '../models/quiz_config.dart';
import '../models/stats.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/bouncy_button.dart';
import 'result_screen.dart';

/// 퀴즈 화면: 문제를 하나씩 풀고, 듀오링고처럼 아래에서 정답 여부를 알려준다.
/// 정답은 +10점, 3연속 정답부터 🔥 콤보 보너스 +5점.
/// 틀린 문제는 판 끝에 한 번 더 나온다 (다시 맞히면 +5점).
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.config, this.level});

  final QuizConfig config;

  /// 단계 도전이면 해당 단계, 자유 연습이면 null
  final Level? level;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

/// 풀 문제 큐의 한 칸: 처음 나온 문제인지, 틀려서 다시 나온 문제인지
class _QuizEntry {
  const _QuizEntry(this.question, {this.isRetry = false});

  final Question question;
  final bool isRetry;
}

class _QuizScreenState extends State<QuizScreen> {
  /// 처음 출제된 문제 수 (별점 계산 기준)
  late final int _baseCount;

  /// 남은 문제 큐. 틀린 문제가 뒤에 다시 추가된다.
  final List<_QuizEntry> _entries = [];
  int _currentIndex = 0;
  int _correctCount = 0;

  /// 연속 정답 개수와 이번 판에 모은 점수
  int _combo = 0;
  int _roundPoints = 0;
  int _lastGained = 0;

  /// 아이가 고른 보기. null이면 아직 고르지 않은 상태.
  int? _selectedChoice;

  /// 마지막 문제 처리 중 중복 실행(빠른 연타) 방지
  bool _finishing = false;

  Question get _question => _entries[_currentIndex].question;
  bool get _isRetryQuestion => _entries[_currentIndex].isRetry;
  bool get _answered => _selectedChoice != null;
  bool get _isCorrect => _selectedChoice == _question.answer;
  Color get _themeColor => widget.level?.unit.color ?? const Color(0xFF58CC02);

  @override
  void initState() {
    super.initState();
    final questions = QuestionGenerator().generate(widget.config);
    _baseCount = questions.length;
    _entries.addAll(questions.map(_QuizEntry.new));
    // 첫 문제를 음성으로 읽어 준다.
    WidgetsBinding.instance.addPostFrameCallback((_) => _speakQuestion());
  }

  void _speakQuestion() => Speech.speak(_question.speechText);

  void _selectChoice(int choice) {
    if (_answered) return;
    // 첫 시도만 학습 통계에 기록한다 (재출제 풀이는 제외).
    if (!_isRetryQuestion) {
      StatsStore.recordAnswer(_question, correct: choice == _question.answer);
    }
    setState(() {
      _selectedChoice = choice;
      if (choice == _question.answer) {
        if (_isRetryQuestion) {
          // 다시 풀어서 맞힘: 보너스만 주고 별점·콤보에는 영향 없음
          _lastGained = retryPoints;
          _roundPoints += retryPoints;
        } else {
          _correctCount++;
          _combo++;
          _lastGained = pointsForAnswer(_combo);
          _roundPoints += _lastGained;
        }
      } else {
        _combo = 0;
        _lastGained = 0;
        // 처음 틀린 문제는 판 끝에 한 번 더 나온다.
        if (!_isRetryQuestion) {
          _entries.add(_QuizEntry(_question, isRetry: true));
        }
      }
    });
    if (_isCorrect) {
      Sounds.correct(_combo);
      HapticFeedback.lightImpact().ignore();
      Speech.speak('정답이에요!');
    } else {
      Sounds.wrong();
      HapticFeedback.heavyImpact().ignore();
      Speech.speak('아쉬워요. 정답은 ${_question.answer}이에요.');
    }
  }

  /// 퀴즈 도중이면 확인 팝업을 띄우고, 시작 전이면 바로 나간다.
  Future<void> _confirmExit() async {
    if (!_answered && _currentIndex == 0) {
      Navigator.of(context).pop();
      return;
    }

    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🥺',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 48)),
              const SizedBox(height: 8),
              const Text(
                '정말 그만할까요?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                '지금 나가면 이번 판 점수가 사라져요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 15, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 20),
              BouncyButton(
                color: const Color(0xFF58CC02),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onTap: () => Navigator.of(context).pop(false),
                child: const Text(
                  '계속 풀기',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              BouncyButton(
                color: Colors.white,
                shadowColor: Colors.grey.shade300,
                border: Border.all(color: Colors.grey.shade300, width: 2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onTap: () => Navigator.of(context).pop(true),
                child: Text(
                  '그만하기',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _next() async {
    // 답을 고르기 전이거나(연타로 이미 넘어간 뒤), 마무리 중이면 무시
    if (!_answered || _finishing) return;
    if (_currentIndex + 1 >= _entries.length) {
      _finishing = true;
      final level = widget.level;
      final stars = starsForScore(_correctCount, _baseCount);
      final earned = _roundPoints + completionBonus(stars);
      if (stars >= 1) Sounds.complete();
      if (level != null) {
        // 결과 화면으로 넘어가기 전에 기록을 저장한다.
        await ProgressStore.saveStars(level.number, stars);
      }
      await ProgressStore.addPoints(earned);
      // 데일리 미션·출석 기록 (새로 달성한 미션은 결과 화면에서 축하)
      final completedMissions = await DailyStore.recordRound(
        correctCount: _correctCount,
        stars: stars,
      );
      // 리포트용 주간 활동 기록
      await StatsStore.recordRoundDay();
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            config: widget.config,
            level: level,
            correctCount: _correctCount,
            totalCount: _baseCount,
            earnedPoints: earned,
            completedMissions: completedMissions,
          ),
        ),
      );
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedChoice = null;
    });
    _speakQuestion();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 시스템 뒤로 가기(안드로이드)도 확인 팝업을 거치게 한다.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildTopBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 16),
                        _buildQuestionCard(),
                        const SizedBox(height: 24),
                        _buildChoices(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _buildFeedbackPanel(),
              ],
            ),
            // 5연속 정답부터 화면 가득 반짝반짝!
            if (_answered && _isCorrect && _combo >= 5)
              Positioned.fill(
                child: IgnorePointer(
                  child: _SparkleBurst(key: ValueKey('sparkle$_currentIndex')),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close, size: 28),
            color: Colors.grey,
            onPressed: _confirmExit,
          ),
          if (widget.level != null) ...[
            Text(
              '${widget.level!.number}단계',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  end: (_currentIndex + (_answered ? 1 : 0)) / _entries.length,
                ),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 14,
                  backgroundColor: Colors.grey.shade300,
                  color: _themeColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          if (_combo >= 2) ...[
            Text(
              '🔥$_combo',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFFFF7A00),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '🪙 $_roundPoints',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border:
            Border.all(color: _themeColor.withValues(alpha: 0.35), width: 3),
        boxShadow: [
          BoxShadow(
            color: _themeColor.withValues(alpha: 0.12),
            offset: const Offset(0, 6),
            blurRadius: 14,
          ),
        ],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              if (_isRetryQuestion) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFEBD6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    '🔁 다시 풀어 봐요!',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB05E00),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              // 세 자리 수처럼 긴 식은 자동으로 줄어들어 카드 안에 들어간다.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _question.expression,
                  style: TextStyle(
                    fontSize: _question.isCounting ? 38 : 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _EmojiHint(question: _question),
            ],
          ),
          // 문제를 다시 읽어 주는 버튼
          Positioned(
            top: -6,
            right: -6,
            child: IconButton(
              onPressed: _speakQuestion,
              icon: Icon(
                Icons.volume_up_rounded,
                size: 30,
                color: _themeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChoices() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 12,
      childAspectRatio: 1.75,
      children: [
        for (final choice in _question.choices)
          _ChoiceButton(
            value: choice,
            state: _choiceState(choice),
            onTap: () => _selectChoice(choice),
          ),
      ],
    );
  }

  _ChoiceState _choiceState(int choice) {
    if (!_answered) return _ChoiceState.idle;
    if (choice == _question.answer) return _ChoiceState.correct;
    if (choice == _selectedChoice) return _ChoiceState.wrong;
    return _ChoiceState.disabled;
  }

  /// 듀오링고처럼 화면 아래에서 올라오는 정답/오답 안내판
  Widget _buildFeedbackPanel() {
    if (!_answered) return const SizedBox.shrink();

    final color =
        _isCorrect ? const Color(0xFFD7FFB8) : const Color(0xFFFFDFE0);
    final textColor =
        _isCorrect ? const Color(0xFF58A700) : const Color(0xFFEA2B2B);
    final message = _isCorrect ? '정답이에요! 🎉' : '아쉬워요! 정답은 ${_question.answer}';

    final isLast = _currentIndex + 1 >= _entries.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: color,
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
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ),
                if (_isCorrect)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      !_isRetryQuestion && _combo >= 3
                          ? '+$_lastGained점 🔥'
                          : '+$_lastGained점',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            BouncyButton(
              color: _isCorrect
                  ? const Color(0xFF58CC02)
                  : const Color(0xFFEA2B2B),
              onTap: _next,
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
                  if (isLast) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.emoji_events_rounded,
                      size: 28,
                      color: Colors.white,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 별과 반짝이가 가운데에서 사방으로 퍼지는 일회성 축하 효과
class _SparkleBurst extends StatelessWidget {
  const _SparkleBurst({super.key});

  static const _emojis = [
    '✨',
    '⭐',
    '🌟',
    '✨',
    '⭐',
    '✨',
    '🌟',
    '✨',
    '⭐',
    '✨',
    '🌟',
    '⭐'
  ];

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, t, _) => Stack(
        children: [
          for (var i = 0; i < _emojis.length; i++)
            Align(
              alignment: Alignment.center,
              child: Transform.translate(
                offset: Offset(
                  math.cos(i * 2 * math.pi / _emojis.length) * 170 * t,
                  math.sin(i * 2 * math.pi / _emojis.length) * 190 * t - 60,
                ),
                child: Opacity(
                  opacity: (1 - t).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.5 + t,
                    child: Text(
                      _emojis[i],
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _ChoiceState { idle, correct, wrong, disabled }

/// 큼직한 3D 보기 버튼
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.value,
    required this.state,
    required this.onTap,
  });

  final int value;
  final _ChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border, textColor) = switch (state) {
      _ChoiceState.idle => (Colors.white, Colors.grey.shade300, Colors.black87),
      _ChoiceState.correct => (
          const Color(0xFFD7FFB8),
          const Color(0xFF58CC02),
          const Color(0xFF58A700),
        ),
      _ChoiceState.wrong => (
          const Color(0xFFFFDFE0),
          const Color(0xFFEA2B2B),
          const Color(0xFFEA2B2B),
        ),
      _ChoiceState.disabled => (
          Colors.grey.shade100,
          Colors.grey.shade300,
          Colors.grey.shade400,
        ),
    };

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 3),
        boxShadow: state == _ChoiceState.idle
            ? [
                BoxShadow(
                  color: Colors.grey.shade300,
                  offset: const Offset(0, 4),
                  blurRadius: 0,
                ),
              ]
            : null,
      ),
      child: Center(
        child: Text(
          '$value',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ),
    );

    // 틀린 버튼은 좌우로 도리도리 흔들린다.
    if (state == _ChoiceState.wrong) {
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

    return GestureDetector(onTap: onTap, child: button);
  }
}

/// 개수 세기를 도와주는 이모지 그림.
/// 덧셈: 🍎🍎🍎 ➕ 🍎🍎 / 뺄셈: 빼는 만큼 흐리게 /
/// 곱셈: 줄로 늘어놓은 묶음 / 나눗셈: 나누는 수만큼 묶어서 표시.
/// 그림이 20개를 넘으면(큰 수 문제) 힌트를 생략한다.
class _EmojiHint extends StatelessWidget {
  const _EmojiHint({required this.question});

  final Question question;

  static const _maxHintItems = 20;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 26);

    switch (question.op) {
      // 수 세기: 그림을 전부 또렷하게 보여주고 세게 한다.
      case QuestionOp.counting:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 6,
          children: [
            for (var i = 0; i < question.left; i++)
              Text(question.emoji, style: const TextStyle(fontSize: 34)),
          ],
        );

      case QuestionOp.add:
        if (question.left + question.right > _maxHintItems) {
          return const SizedBox.shrink();
        }
        return Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 2,
          runSpacing: 4,
          children: [
            for (var i = 0; i < question.left; i++)
              Text(question.emoji, style: style),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6),
              child: Text('➕', style: TextStyle(fontSize: 20)),
            ),
            for (var i = 0; i < question.right; i++)
              Text(question.emoji, style: style),
          ],
        );

      // 뺄셈: 전체 중에서 빼는 개수만큼 흐리게 보여준다.
      case QuestionOp.sub:
        if (question.left > _maxHintItems) return const SizedBox.shrink();
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 2,
          runSpacing: 4,
          children: [
            for (var i = 0; i < question.left; i++)
              Opacity(
                opacity: i < question.left - question.right ? 1.0 : 0.25,
                child: Text(question.emoji, style: style),
              ),
          ],
        );

      // 곱셈: left개씩 right줄 — "몇씩 몇 묶음"을 눈으로 보여준다.
      case QuestionOp.mul:
        if (question.left * question.right > _maxHintItems) {
          return const SizedBox.shrink();
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < question.right; row++)
              Text(
                question.emoji * question.left,
                style: const TextStyle(fontSize: 22, height: 1.2),
              ),
          ],
        );

      // 나눗셈: 전체를 나누는 수만큼씩 묶어서 보여준다.
      case QuestionOp.div:
        if (question.left > _maxHintItems) return const SizedBox.shrink();
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            for (var group = 0; group < question.answer; group++)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  question.emoji * question.right,
                  style: const TextStyle(fontSize: 20),
                ),
              ),
          ],
        );
    }
  }
}
