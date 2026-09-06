import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/daily.dart';
import '../models/korean_curriculum.dart';
import '../models/korean_question.dart';
import '../models/premium.dart';
import '../models/progress.dart';
import '../models/stats.dart';
import '../models/stickers.dart';
import '../models/wrong_notes.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/listen_guard.dart';
import '../widgets/quiz_exit_dialog.dart';
import '../widgets/sparkle_burst.dart';
import 'result_screen.dart';

/// 한글 퀴즈 화면: 수학 퀴즈와 같은 흐름(진행 바·콤보·재출제·피드백 판)으로
/// 낱말/글자/그림 보기를 고른다. 듣기 문제는 TTS가 문제를 읽어 준다.
class KoreanQuizScreen extends StatefulWidget {
  const KoreanQuizScreen({
    super.key,
    required this.type,
    this.stage = 0,
    this.level,
  });

  final KrQuizType type;
  final int stage;

  /// 단계 도전이면 해당 단계, 아니면 null
  final KrLevel? level;

  @override
  State<KoreanQuizScreen> createState() => _KoreanQuizScreenState();
}

class _KrEntry {
  const _KrEntry(this.question, {this.isRetry = false});

  final KoreanQuestion question;
  final bool isRetry;
}

class _KoreanQuizScreenState extends State<KoreanQuizScreen> {
  late final int _baseCount;
  final List<_KrEntry> _entries = [];
  int _currentIndex = 0;
  int _correctCount = 0;

  int _combo = 0;
  int _roundPoints = 0;
  int _lastGained = 0;

  String? _selectedChoice;
  bool _finishing = false;

  /// 낱말 만들기: 지금까지 누른 타일 인덱스 (문제가 바뀌면 새로 만든다)
  List<int> _picked = [];
  int _pickedIndex = -1;

  final _random = math.Random();

  KoreanQuestion get _question => _entries[_currentIndex].question;
  bool get _isRetryQuestion => _entries[_currentIndex].isRetry;

  /// 진행 바 값: 틀린 문제가 뒤에 추가돼 분모가 늘어도 바가 뒤로 가지 않게 한다.
  double _barShown = 0;
  double get _barProgress {
    final p = (_currentIndex + (_answered ? 1 : 0)) / _entries.length;
    if (p > _barShown) _barShown = p;
    return _barShown;
  }

  bool get _answered => _selectedChoice != null;
  bool get _isCorrect => _selectedChoice == _question.answer;
  Color get _themeColor => widget.level?.unit.color ?? const Color(0xFF1CB0F6);

  @override
  void initState() {
    super.initState();
    final questions = KoreanQuestionGenerator()
        .generate(widget.type, stage: widget.stage);
    _baseCount = questions.length;
    _entries.addAll(questions.map(_KrEntry.new));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// 소리 찾기 유형은 소리가 있어야 풀 수 있으니 먼저 확인한다.
  Future<void> _start() async {
    final needsListening = widget.type == KrQuizType.listenVowel ||
        widget.type == KrQuizType.listenSyllable ||
        widget.type == KrQuizType.listenConsonant;
    if (needsListening) {
      final ready = await ensureListenReady(context);
      if (!ready) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }
    _speakQuestion();
  }

  void _speakQuestion() => Speech.speak(_question.speech);

  void _ensureTiles() {
    if (_pickedIndex == _currentIndex) return;
    _pickedIndex = _currentIndex;
    _picked = [];
  }

  /// 낱말 만들기: 타일을 누르면 칸이 차고, 다 차면 자동으로 채점한다.
  void _tapTile(int index) {
    if (_answered) return;
    _ensureTiles();
    if (_picked.contains(index)) return;
    setState(() => _picked.add(index));
    if (_picked.length >= _question.answer.length) {
      _selectChoice([for (final i in _picked) _question.tiles[i]].join());
    }
  }

  void _tapTileBackspace() {
    if (_answered) return;
    _ensureTiles();
    if (_picked.isEmpty) return;
    setState(() => _picked.removeLast());
  }

  void _selectChoice(String choice) {
    if (_answered) return;
    // 첫 시도만 학습 통계에 기록한다 (재출제 풀이는 제외).
    if (!_isRetryQuestion) {
      StatsStore.recordKoreanAnswer(widget.type,
          correct: choice == _question.answer);
    }
    setState(() {
      _selectedChoice = choice;
      if (choice == _question.answer) {
        if (_isRetryQuestion) {
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
        if (!_isRetryQuestion) {
          _entries.add(_KrEntry(_question, isRetry: true));
          // 보기 고르기 문제는 오답 노트에 담아 나중에 다시 푼다.
          if (_question.tiles.isEmpty) {
            WrongNoteStore.add(WrongNote.fromKorean(_question));
          }
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
      Speech.speak('아쉬워요. 정답은 ${_question.answerText}예요.');
    }
  }

  Future<void> _confirmExit() async {
    if (!_answered && _currentIndex == 0) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await confirmQuizExit(context);
    if (leave && mounted) Navigator.of(context).pop();
  }

  Future<void> _next() async {
    if (!_answered || _finishing) return;
    if (_currentIndex + 1 >= _entries.length) {
      _finishing = true;
      final level = widget.level;
      final stars = starsForScore(_correctCount, _baseCount);
      final earned = _roundPoints + completionBonus(stars);
      final chestCoins =
          _random.nextDouble() < (stars >= 3 ? 0.35 : (stars >= 1 ? 0.15 : 0))
              ? (2 + _random.nextInt(9)) * 5
              : 0;
      if (stars >= 1) Sounds.complete();
      if (level != null) {
        await KoreanProgressStore.saveStars(level.number, stars);
      }
      await ProgressStore.addPoints(earned + chestCoins);
      final rewards = await DailyStore.recordRound(
        correctCount: _correctCount,
        stars: stars,
        korean: true,
      );
      await StatsStore.recordRoundDay();
      // 통과하면 스티커북에 붙일 스티커 1장을 준다.
      if (stars >= 1) await StickerStore.addTickets(1);
      var nextLevel = (level != null &&
              stars >= 1 &&
              level.number < KoreanCurriculum.totalLevels)
          ? KoreanCurriculum.levelAt(level.number + 1)
          : null;
      // 다음 단계가 이용권으로 잠긴 카테고리면 버튼을 숨긴다
      // (홈에서 부모 확인 → 이용권 안내를 거치게 한다).
      if (nextLevel != null &&
          !PremiumStore.isCategoryFree(nextLevel.unit.category.index) &&
          !await PremiumStore.hasPass()) {
        nextLevel = null;
      }
      // 클로저 안에서 널 아님이 유지되게 final로 다시 담는다.
      final next = nextLevel;
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            correctCount: _correctCount,
            totalCount: _baseCount,
            earnedPoints: earned,
            chestCoins: chestCoins,
            stickerEarned: stars >= 1,
            completedMissions: rewards.missions,
            milestoneDays: rewards.milestoneDays,
            milestoneCoins: rewards.milestoneCoins,
            headerText: level != null
                ? '한글 ${level.number}단계 · ${level.unit.emoji} ${level.unit.title}'
                : null,
            showUnlockHint: level != null && stars < 1,
            nextLabel:
                next != null ? '다음 단계 (${next.number}단계)' : null,
            nextBuilder: next != null
                ? () => KoreanQuizScreen(
                      type: next.unit.type,
                      stage: next.stage,
                      level: next,
                    )
                : null,
            retryBuilder: () => KoreanQuizScreen(
              type: widget.type,
              stage: widget.stage,
              level: level,
            ),
            homeLabel: level != null ? '지도로' : '처음으로',
            homeIcon: level != null ? Icons.map_rounded : Icons.home_rounded,
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
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
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
                          if (_question.tiles.isNotEmpty)
                            _buildTiles()
                          else
                            _buildChoices(),
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                  _buildFeedbackPanel(),
                ],
              ),
              if (_answered && _isCorrect && _combo >= 5)
                Positioned.fill(
                  child: IgnorePointer(
                    child: SparkleBurst(key: ValueKey('sparkle$_currentIndex')),
                  ),
                ),
            ],
          ),
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
                  end: _barProgress,
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
    // 그림·🔊는 큼직하게, 낱말·글자 배열은 그보다 작게
    final displayIsText = switch (_question.type) {
      KrQuizType.wordToPicture || KrQuizType.syllableOrder => true,
      _ => false,
    };

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
              Text(
                _question.instruction,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                // 🔊 표시(듣기 문제)는 눌러서 다시 들을 수 있다.
                onTap: _question.display == '🔊' ? _speakQuestion : null,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    _question.display,
                    style: TextStyle(
                      fontSize: displayIsText ? 40 : 64,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              if (_question.subDisplay.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _question.subDisplay,
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 4,
                  ),
                ),
              ],
              // 낱말 만들기: 채워지는 글자 칸
              if (_question.tiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Builder(builder: (context) {
                  _ensureTiles();
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _question.answer.length; i++)
                        Container(
                          width: 46,
                          height: 52,
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          decoration: BoxDecoration(
                            color: _answered
                                ? (_isCorrect
                                    ? const Color(0xFFD7FFB8)
                                    : const Color(0xFFFFDFE0))
                                : i == _picked.length
                                    ? _themeColor.withValues(alpha: 0.08)
                                    : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _answered
                                  ? (_isCorrect
                                      ? const Color(0xFF58CC02)
                                      : const Color(0xFFEA2B2B))
                                  : i == _picked.length
                                      ? _themeColor
                                      : Colors.grey.shade300,
                              width: i == _picked.length && !_answered ? 3 : 2,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              i < _picked.length
                                  ? _question.tiles[_picked[i]]
                                  : '',
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                    ],
                  );
                }),
              ],
            ],
          ),
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

  /// 낱말 만들기용 글자 타일 (누른 타일은 비활성화, 지우기 포함)
  Widget _buildTiles() {
    _ensureTiles();
    Widget tile(int index) {
      final used = _picked.contains(index);
      return GestureDetector(
        onTap: _answered || used ? null : () => _tapTile(index),
        child: Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            color: used || _answered ? Colors.grey.shade100 : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade300, width: 2),
            boxShadow: used || _answered
                ? null
                : [
                    BoxShadow(
                      color: Colors.grey.shade300,
                      offset: const Offset(0, 3),
                      blurRadius: 0,
                    ),
                  ],
          ),
          child: Center(
            child: Text(
              _question.tiles[index],
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: used || _answered
                    ? Colors.grey.shade400
                    : Colors.black87,
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < _question.tiles.length; i++) tile(i),
            GestureDetector(
              onTap: _answered ? null : _tapTileBackspace,
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                ),
                child: Icon(
                  Icons.backspace_outlined,
                  size: 24,
                  color: _answered
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
                ),
              ),
            ),
          ],
        ),
      ],
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
          _KrChoiceButton(
            value: choice,
            emoji: _question.emojiChoices,
            state: _choiceState(choice),
            onTap: () => _selectChoice(choice),
          ),
      ],
    );
  }

  _KrChoiceState _choiceState(String choice) {
    if (!_answered) return _KrChoiceState.idle;
    if (choice == _question.answer) return _KrChoiceState.correct;
    if (choice == _selectedChoice) return _KrChoiceState.wrong;
    return _KrChoiceState.disabled;
  }

  Widget _buildFeedbackPanel() {
    if (!_answered) return const SizedBox.shrink();

    final color =
        _isCorrect ? const Color(0xFFD7FFB8) : const Color(0xFFFFDFE0);
    final textColor =
        _isCorrect ? const Color(0xFF58A700) : const Color(0xFFEA2B2B);
    final message =
        _isCorrect ? '정답이에요! 🎉' : '아쉬워요! 정답은 ${_question.answerText}';

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
                      fontSize: 22,
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

enum _KrChoiceState { idle, correct, wrong, disabled }

/// 낱말/글자/그림 보기 버튼
class _KrChoiceButton extends StatelessWidget {
  const _KrChoiceButton({
    required this.value,
    required this.emoji,
    required this.state,
    required this.onTap,
  });

  final String value;

  /// 그림(이모지) 보기면 더 크게 그린다.
  final bool emoji;
  final _KrChoiceState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border, textColor) = switch (state) {
      _KrChoiceState.idle =>
        (Colors.white, Colors.grey.shade300, Colors.black87),
      _KrChoiceState.correct => (
          const Color(0xFFD7FFB8),
          const Color(0xFF58CC02),
          const Color(0xFF58A700),
        ),
      _KrChoiceState.wrong => (
          const Color(0xFFFFDFE0),
          const Color(0xFFEA2B2B),
          const Color(0xFFEA2B2B),
        ),
      _KrChoiceState.disabled => (
          Colors.grey.shade100,
          Colors.grey.shade300,
          Colors.grey.shade400,
        ),
    };

    Widget button = AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 3),
        boxShadow: state == _KrChoiceState.idle
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
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: TextStyle(
              fontSize: emoji ? 44 : 30,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
      ),
    );

    if (state == _KrChoiceState.wrong) {
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
