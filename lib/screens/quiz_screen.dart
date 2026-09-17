import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/boss.dart';
import '../models/curriculum.dart';
import '../models/daily.dart';
import '../models/premium.dart';
import '../models/progress.dart';
import '../models/question.dart';
import '../models/quiz_config.dart';
import '../models/stats.dart';
import '../models/stickers.dart';
import '../models/wrong_notes.dart';
import '../services/cloud_sync.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/auto_next_bar.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/listen_guard.dart';
import '../widgets/quiz_exit_dialog.dart';
import '../widgets/sparkle_burst.dart';
import 'result_screen.dart';

/// 퀴즈 화면: 문제를 하나씩 풀고, 듀오링고처럼 아래에서 정답 여부를 알려준다.
/// 정답은 +10점, 3연속 정답부터 🔥 콤보 보너스 +5점.
/// 틀린 문제는 판 끝에 한 번 더 나온다 (다시 맞히면 +5점).
class QuizScreen extends StatefulWidget {
  const QuizScreen({
    super.key,
    required this.config,
    this.level,
    this.bossMode = false,
  });

  final QuizConfig config;

  /// 단계 도전이면 해당 단계, 자유 연습이면 null
  final Level? level;

  /// 주간 보스전: 여러 유형을 섞은 12문제, 통과하면 보너스 코인
  final bool bossMode;

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

  /// 세로셈 자리 입력값 (인덱스 0 = 일의 자리). 문제가 바뀌면 새로 만든다.
  List<int?> _slots = [];
  int _slotsIndex = -1;

  /// 마지막 문제 처리 중 중복 실행(빠른 연타) 방지
  bool _finishing = false;

  /// 보물상자 추첨용
  final _random = math.Random();

  Question get _question => _entries[_currentIndex].question;
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
  Color get _themeColor => widget.level?.unit.color ?? const Color(0xFF58CC02);

  @override
  void initState() {
    super.initState();
    final questions = widget.bossMode
        ? BossStore.buildQuestions()
        : QuestionGenerator().generate(widget.config);
    _baseCount = questions.length;
    _entries.addAll(questions.map(_QuizEntry.new));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// 듣고 풀기는 소리가 있어야 풀 수 있으니 먼저 확인하고,
  /// 준비가 되면 첫 문제를 음성으로 읽어 준다.
  Future<void> _start() async {
    if (widget.config.mode == QuizMode.listen) {
      final ready = await ensureListenReady(context);
      if (!ready) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }
    _speakQuestion();
  }

  void _speakQuestion() => Speech.speak(_question.speechText);

  /// 세로셈: 현재 문제에 맞는 자리 칸을 준비한다 (정답 자리수만큼).
  void _ensureSlots() {
    if (_slotsIndex == _currentIndex) return;
    _slotsIndex = _currentIndex;
    _slots = List<int?>.filled('${_question.answer}'.length, null);
  }

  /// 세로셈 키패드: 일의 자리부터 채우고, 다 채우면 자동으로 채점한다.
  void _tapDigit(int digit) {
    if (_answered) return;
    _ensureSlots();
    final index = _slots.indexOf(null);
    if (index == -1) return;
    setState(() => _slots[index] = digit);

    if (!_slots.contains(null)) {
      var value = 0;
      var place = 1;
      for (final d in _slots) {
        value += d! * place;
        place *= 10;
      }
      _selectChoice(value);
    }
  }

  void _tapBackspace() {
    if (_answered) return;
    _ensureSlots();
    final firstNull = _slots.indexOf(null);
    final last = firstNull == -1 ? _slots.length - 1 : firstNull - 1;
    if (last < 0) return;
    setState(() => _slots[last] = null);
  }

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
          // 글로 다시 보여줄 수 있는 문제는 오답 노트에도 담는다.
          // (그림·소리로만 내는 세기/모양/시계/듣기 유형은 제외)
          const noteOps = {
            QuestionOp.add,
            QuestionOp.sub,
            QuestionOp.mul,
            QuestionOp.div,
            QuestionOp.pattern,
            QuestionOp.compare,
          };
          if (_question.prompt.isNotEmpty ||
              (!_question.listenOnly && noteOps.contains(_question.op))) {
            WrongNoteStore.add(WrongNote(
              subject: 'math',
              subjectEmoji: '🧮',
              subjectName: '수학',
              instruction: _question.expression.replaceAll('\n', ' '),
              display: '',
              choices: [
                for (final c in _question.choices) _question.labelFor(c),
              ],
              answer: _question.answerLabel,
              // 다시 풀 때 정답을 읽어 주는 문장 ("5분의 3"처럼)
              answerText: _question.answerSpeech,
              speech: _question.speechText,
            ));
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
      Speech.speak('아쉬워요. 정답은 ${_question.answerSpeech}이에요.');
    }
  }

  /// 퀴즈 도중이면 확인 팝업을 띄우고, 시작 전이면 바로 나간다.
  Future<void> _confirmExit() async {
    if (!_answered && _currentIndex == 0) {
      Navigator.of(context).pop();
      return;
    }
    final leave = await confirmQuizExit(context);
    if (leave && mounted) Navigator.of(context).pop();
  }

  Future<void> _next() async {
    // 답을 고르기 전이거나(연타로 이미 넘어간 뒤), 마무리 중이면 무시
    if (!_answered || _finishing) return;
    if (_currentIndex + 1 >= _entries.length) {
      _finishing = true;
      final level = widget.level;
      final stars = starsForScore(_correctCount, _baseCount);
      // 보스전을 통과하면 큰 보너스가 붙고, 이번 주는 잠긴다.
      // 이미 이번 주에 클리어했으면 (결과 화면의 '다시 하기' 등) 보상을 또 주지 않는다.
      final bossCleared = widget.bossMode &&
          stars >= 1 &&
          !await BossStore.isClearedThisWeek();
      final earned = _roundPoints +
          completionBonus(stars) +
          (bossCleared ? BossStore.reward : 0);
      // 통과하면 가끔 보물상자가 나온다 (3별이면 확률 업, 보너스 10~50코인)
      final chestCoins =
          _random.nextDouble() < (stars >= 3 ? 0.35 : (stars >= 1 ? 0.15 : 0))
              ? (2 + _random.nextInt(9)) * 5
              : 0;
      if (bossCleared) await BossStore.markCleared();
      if (stars >= 1) Sounds.complete();
      if (level != null) {
        // 결과 화면으로 넘어가기 전에 기록을 저장한다.
        await ProgressStore.saveStars(level.number, stars);
      }
      await ProgressStore.addPoints(earned + chestCoins);
      // 데일리 미션·출석 기록 (새로 달성한 미션은 결과 화면에서 축하)
      final rewards = await DailyStore.recordRound(
        correctCount: _correctCount,
        stars: stars,
      );
      // 리포트용 주간 활동 기록
      await StatsStore.recordRoundDay();
      CloudSync.scheduleUpload(); // 로그인돼 있으면 잠시 뒤 클라우드에 저장
      // 통과하면 스티커북에 붙일 스티커 1장을 준다.
      if (stars >= 1) await StickerStore.addTickets(1);
      var nextLevel =
          (level != null && stars >= 1 && level.number < Curriculum.totalLevels)
              ? Curriculum.levelAt(level.number + 1)
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
            bossCleared: bossCleared,
            completedMissions: rewards.missions,
            milestoneDays: rewards.milestoneDays,
            milestoneCoins: rewards.milestoneCoins,
            headerText: widget.bossMode
                ? '👑 주간 보스전'
                : level != null
                    ? '${level.number}단계 · ${level.unit.emoji} ${level.unit.title}'
                    : null,
            showUnlockHint: level != null && stars < 1,
            nextLabel:
                next != null ? '다음 단계 (${next.number}단계)' : null,
            nextBuilder: next != null
                ? () => QuizScreen(config: next.config, level: next)
                : null,
            retryBuilder: () => QuizScreen(
                config: widget.config,
                level: level,
                bossMode: widget.bossMode),
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
                        if (_question.vertical)
                          _buildKeypad()
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
            // 5연속 정답부터 화면 가득 반짝반짝!
            if (_answered && _isCorrect && _combo >= 5)
              Positioned.fill(
                child: IgnorePointer(
                  child: SparkleBurst(key: ValueKey('sparkle$_currentIndex')),
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
          if (widget.bossMode) ...[
            const Text(
              '👑 보스전',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB8860B),
              ),
            ),
            const SizedBox(width: 8),
          ],
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
              if (_question.vertical) ...[
                // 세로셈: 자리수를 맞춰 세로로 보여주고 자리마다 답 칸을 채운다.
                Builder(builder: (context) {
                  _ensureSlots();
                  return _VerticalProblem(
                    question: _question,
                    slots: _slots,
                    answered: _answered,
                    correct: _isCorrect,
                    themeColor: _themeColor,
                  );
                }),
              ] else if (_question.prompt.isNotEmpty) ...[
                // 문장 문제(분수·소수·시간)는 여러 줄 그대로 보여준다.
                // (오른쪽 여백은 다시 듣기 버튼 자리)
                Padding(
                  padding: const EdgeInsets.only(right: 30),
                  child: Text(
                    _question.expression,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _EmojiHint(question: _question),
              ] else ...[
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

  /// 세로셈용 숫자 키패드 (0~9 + 지우기)
  Widget _buildKeypad() {
    Widget key({required Widget child, VoidCallback? onTap}) {
      return Expanded(
        child: GestureDetector(
          onTap: _answered ? null : onTap,
          child: Container(
            height: 56,
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: _answered ? Colors.grey.shade100 : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade300, width: 2),
              boxShadow: _answered
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.grey.shade300,
                        offset: const Offset(0, 3),
                        blurRadius: 0,
                      ),
                    ],
            ),
            child: Center(child: child),
          ),
        ),
      );
    }

    Widget digitKey(int digit) => key(
          onTap: () => _tapDigit(digit),
          child: Text(
            '$digit',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _answered ? Colors.grey.shade400 : Colors.black87,
            ),
          ),
        );

    return Column(
      children: [
        Row(children: [for (var d = 1; d <= 5; d++) digitKey(d)]),
        Row(
          children: [
            for (var d = 6; d <= 9; d++) digitKey(d),
            digitKey(0),
          ],
        ),
        Row(
          children: [
            key(
              onTap: _tapBackspace,
              child: Icon(
                Icons.backspace_outlined,
                size: 24,
                color: _answered ? Colors.grey.shade400 : Colors.grey.shade600,
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
          _ChoiceButton(
            label: _question.labelFor(choice),
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
    final message =
        _isCorrect ? '정답이에요! 🎉' : '아쉬워요! 정답은 ${_question.answerLabel}';

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
            if (_isCorrect) ...[
              const SizedBox(height: 10),
              // 2초 동안 줄어드는 막대: 다 줄면 자동으로 다음 문제로
              AutoNextBar(
                key: ValueKey('auto-next-$_currentIndex'),
                color: const Color(0xFF58CC02),
                onDone: _next,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// 세로셈 표시: 자리수를 맞춰 세로로 늘어놓고,
/// 답은 자리마다 칸([])을 일의 자리부터 채운다.
class _VerticalProblem extends StatelessWidget {
  const _VerticalProblem({
    required this.question,
    required this.slots,
    required this.answered,
    required this.correct,
    required this.themeColor,
  });

  final Question question;
  final List<int?> slots;
  final bool answered;
  final bool correct;
  final Color themeColor;

  static const _cellWidth = 44.0;

  @override
  Widget build(BuildContext context) {
    final top = '${question.left}';
    final bottom = '${question.right}';
    // 연산 기호 1칸 + 가장 긴 수의 자리수
    final columns = 1 +
        [top.length, bottom.length, slots.length]
            .reduce((a, b) => a > b ? a : b);

    Widget digitCell(String text) => SizedBox(
          width: _cellWidth,
          height: 52,
          child: Center(
            child: Text(
              text,
              style: const TextStyle(fontSize: 34, fontWeight: FontWeight.bold),
            ),
          ),
        );

    // 오른쪽 정렬: 앞을 빈 칸으로 채운다.
    Widget numberRow(String number, {String op = ''}) {
      final pad = columns - number.length - 1;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          digitCell(op),
          for (var i = 0; i < pad; i++) digitCell(''),
          for (final ch in number.split('')) digitCell(ch),
        ],
      );
    }

    // 답 칸: 일의 자리가 맨 오른쪽. 지금 채울 칸을 강조한다.
    final activePlace = slots.indexOf(null);
    Widget answerBox(int place) {
      final digit = slots[place];
      final isActive = !answered && place == activePlace;
      final borderColor = answered
          ? (correct ? const Color(0xFF58CC02) : const Color(0xFFEA2B2B))
          : isActive
              ? themeColor
              : Colors.grey.shade300;
      return Container(
        width: _cellWidth - 4,
        height: 54,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: answered
              ? (correct ? const Color(0xFFD7FFB8) : const Color(0xFFFFDFE0))
              : isActive
                  ? themeColor.withValues(alpha: 0.08)
                  : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: borderColor, width: isActive ? 3 : 2),
        ),
        child: Center(
          child: Text(
            digit == null ? '' : '$digit',
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final answerPad = columns - slots.length - 1;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        numberRow(top),
        numberRow(bottom, op: question.op == QuestionOp.add ? '+' : '−'),
        Container(
          width: columns * _cellWidth,
          height: 3,
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(width: _cellWidth),
            for (var i = 0; i < answerPad; i++)
              const SizedBox(width: _cellWidth),
            // 높은 자리부터 왼쪽 → 오른쪽으로 그린다.
            for (var place = slots.length - 1; place >= 0; place--)
              answerBox(place),
          ],
        ),
      ],
    );
  }
}

enum _ChoiceState { idle, correct, wrong, disabled }

/// 큼직한 3D 보기 버튼
class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
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
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
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

    // 세로셈은 자리수 학습, 듣고 풀기는 암산이 목적이라 그림 힌트를 겹치지 않는다.
    if (question.vertical || question.listenOnly) {
      return const SizedBox.shrink();
    }

    // 빈칸 덧셈: 전체를 보여주되 가려진 쪽을 흐리게 — 세면 답이 보인다.
    if (question.blankSide != 0) {
      if (question.op != QuestionOp.add ||
          question.left + question.right > _maxHintItems) {
        return const SizedBox.shrink();
      }
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: 2,
        runSpacing: 4,
        children: [
          for (var i = 0; i < question.left + question.right; i++)
            Opacity(
              opacity: (question.blankSide == 1
                      ? i < question.left
                      : i >= question.left)
                  ? 0.25
                  : 1.0,
              child: Text(question.emoji, style: style),
            ),
        ],
      );
    }

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

      // 비교·규칙 찾기는 숫자 감각이 목적이라 그림 힌트가 없다.
      case QuestionOp.compare:
      case QuestionOp.pattern:
        return const SizedBox.shrink();

      // 모양 세기: 섞여 있는 모양들이 곧 문제다.
      case QuestionOp.shape:
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 4,
          runSpacing: 6,
          children: [
            for (final item in question.shapeItems)
              Text(item, style: const TextStyle(fontSize: 30)),
          ],
        );

      // 시계 보기: 아날로그 시계 그림이 곧 문제다.
      case QuestionOp.clock:
        return SizedBox(
          width: 170,
          height: 170,
          child: CustomPaint(painter: _ClockPainter(hour: question.left)),
        );

      // 분수 이름 붙이기: 피자처럼 나눈 원에서 색칠한 조각을 보여준다.
      case QuestionOp.fraction:
        if (question.variant != 0) return const SizedBox.shrink();
        return SizedBox(
          width: 120,
          height: 120,
          child: CustomPaint(
            painter: _PiePainter(
              filled: question.left ~/ 100,
              slices: question.left % 100,
            ),
          ),
        );

      // 소수·시간 계산은 문장이 곧 문제라 그림 힌트가 없다.
      case QuestionOp.decimal:
      case QuestionOp.timeCalc:
        return const SizedBox.shrink();
    }
  }
}

/// 분수 힌트: 원을 [slices]조각으로 나누고 [filled]조각을 색칠한 피자 그림
class _PiePainter extends CustomPainter {
  const _PiePainter({required this.filled, required this.slices});

  final int filled;
  final int slices;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2 - 4;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final sweep = 2 * math.pi / slices;

    final fillPaint = Paint()..color = const Color(0xFFFFA726);
    final emptyPaint = Paint()..color = const Color(0xFFFFF3E0);
    final linePaint = Paint()
      ..color = const Color(0xFFE65100)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // 12시 방향부터 시계 방향으로 조각을 그린다.
    for (var i = 0; i < slices; i++) {
      canvas.drawArc(
        rect,
        -math.pi / 2 + i * sweep,
        sweep,
        true,
        i < filled ? fillPaint : emptyPaint,
      );
    }
    // 테두리와 조각 나누는 선
    canvas.drawCircle(center, radius, linePaint);
    if (slices > 1) {
      for (var i = 0; i < slices; i++) {
        final angle = -math.pi / 2 + i * sweep;
        canvas.drawLine(
          center,
          center + Offset(math.cos(angle), math.sin(angle)) * radius,
          linePaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PiePainter oldDelegate) =>
      oldDelegate.filled != filled || oldDelegate.slices != slices;
}

/// 정각을 가리키는 아날로그 시계 (시침은 시각, 분침은 12)
class _ClockPainter extends CustomPainter {
  const _ClockPainter({required this.hour});

  final int hour;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 시계판
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = const Color(0xFFFFF6D8),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = const Color(0xFF8B6F1F)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5,
    );

    // 숫자 1~12
    for (var n = 1; n <= 12; n++) {
      final angle = (n * 30 - 90) * math.pi / 180;
      final pos = center +
          Offset(math.cos(angle), math.sin(angle)) * (radius - 16);
      final painter = TextPainter(
        text: TextSpan(
          text: '$n',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      painter.paint(canvas, pos - Offset(painter.width / 2, painter.height / 2));
    }

    // 분침 (12를 가리킴)
    canvas.drawLine(
      center,
      center + Offset(0, -(radius - 26)),
      Paint()
        ..color = const Color(0xFF1CB0F6)
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    // 시침
    final hourAngle = ((hour % 12) * 30 - 90) * math.pi / 180;
    canvas.drawLine(
      center,
      center +
          Offset(math.cos(hourAngle), math.sin(hourAngle)) * (radius - 46),
      Paint()
        ..color = const Color(0xFFEA2B2B)
        ..strokeWidth = 7
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(center, 6, Paint()..color = Colors.black87);
  }

  @override
  bool shouldRepaint(_ClockPainter oldDelegate) => oldDelegate.hour != hour;
}
