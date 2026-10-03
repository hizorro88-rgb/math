import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/daily.dart';
import '../models/language_pack.dart';
import '../models/premium.dart';
import '../models/progress.dart';
import '../models/stats.dart';
import '../models/stickers.dart';
import '../models/wrong_notes.dart';
import '../services/cloud_sync.dart';
import '../services/sounds.dart';
import '../services/voice_input.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/listen_guard.dart';
import '../widgets/quiz_exit_dialog.dart';
import '../widgets/quiz_parts.dart';
import 'result_screen.dart';

/// 언어 팩(일본어·중국어…) 공용 퀴즈 화면: 수학 퀴즈와 같은 흐름(진행 바·콤보·재출제·피드백 판)으로
/// 낱말/글자/그림 보기를 고른다. 듣기 문제는 TTS가 문제를 읽어 준다.
class LanguageQuizScreen extends StatefulWidget {
  const LanguageQuizScreen({
    super.key,
    required this.pack,
    required this.typeIndex,
    this.stage = 0,
    this.level,
    this.unitIndex = -1,
  });

  final LanguagePack pack;

  /// pack.types 안에서의 유형 번호
  final int typeIndex;
  final int stage;

  /// 유닛 기반 팩(영어회화)에서 어느 주제로 낼지. -1이면 단계나 무작위를 따른다.
  final int unitIndex;

  /// 단계 도전이면 해당 단계, 아니면 null
  final LangLevel? level;

  @override
  State<LanguageQuizScreen> createState() => _LanguageQuizScreenState();
}

class _LangEntry {
  const _LangEntry(this.question, {this.isRetry = false});

  final LangQuestion question;
  final bool isRetry;
}

class _LanguageQuizScreenState extends State<LanguageQuizScreen> {
  late final int _baseCount;

  /// 상단바 진행 점 (틀린 문제를 다시 풀어도 점 수는 그대로)
  late final QuizDotTracker _dots;
  final List<_LangEntry> _entries = [];
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

  LangQuestion get _question => _entries[_currentIndex].question;
  bool get _isRetryQuestion => _entries[_currentIndex].isRetry;

  /// 7번째 문제는 ⚡보너스: 맞히면 코인 2배 (재출제 문제에는 없음)
  bool get _isBonusQuestion => _currentIndex == 6 && !_isRetryQuestion;

  bool get _answered => _selectedChoice != null;

  /// 마이크에 대고 직접 말해서 푸는 문제인지
  bool get _isSpeakingQuestion =>
      widget.pack.types[_question.typeIndex].speaking;

  /// 말하기 문제 상태 (문제마다 새로 시작한다)
  bool _micListening = false;
  bool _micRecording = false;
  SpeakingScore? _spoken;
  String? _myVoicePath;
  String _micNotice = '';

  /// 영어 문장처럼 긴 제시문인지 (줄바꿈해서 보여 줄지 판단)
  bool get _longDisplay =>
      widget.pack.types[_question.typeIndex].textDisplay &&
      _question.display.length > 12;
  bool get _isCorrect => _selectedChoice == _question.answer;
  Color get _themeColor =>
      widget.level?.unit.color ?? const Color(0xFF5B6CF0);

  @override
  void initState() {
    super.initState();
    final questions = widget.pack.generate(
      widget.typeIndex,
      stage: widget.stage,
      unitIndex: widget.unitIndex >= 0
          ? widget.unitIndex
          : widget.level?.unit.index ?? -1,
    );
    _baseCount = questions.length;
    _dots = QuizDotTracker(_baseCount);
    _entries.addAll(questions.map(_LangEntry.new));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  @override
  void dispose() {
    // 화면을 떠날 때 마이크를 확실히 놓아 준다 (기다리지 않는다 — 테스트가 멈춘다).
    VoiceInput.release();
    super.dispose();
  }

  /// 소리 찾기 유형은 소리가 있어야 풀 수 있으니 먼저 확인한다.
  /// 한 판에 유형이 섞이는 팩도 있어서 문제들을 보고 판단한다.
  Future<void> _start() async {
    final needsListening = _entries
        .any((e) => widget.pack.types[e.question.typeIndex].listening);
    if (needsListening) {
      final ready = await ensureListenReady(
        context,
        lang: widget.pack.ttsLang,
        langName: widget.pack.name,
      );
      if (!ready) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }
    _speakQuestion();
  }

  void _speakQuestion({bool force = false}) => QuizVoice.question(
      task: widget.pack.forAdults ? '' : _question.instruction,
      speech: _question.speech,
      lang: widget.pack.ttsLang,
      retry: _isRetryQuestion,
      force: force);

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
    if (_picked.length >= _question.slotCount) {
      _selectChoice(
        [for (final i in _picked) _question.tiles[i]].join(_question.tileJoin),
      );
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
      StatsStore.recordLangAnswer(widget.pack, _question.typeIndex,
          correct: choice == _question.answer);
    }
    setState(() {
      _selectedChoice = choice;
      _dots.record(_currentIndex,
          correct: choice == _question.answer, retry: _isRetryQuestion);
      if (choice == _question.answer) {
        if (_isRetryQuestion) {
          _lastGained = retryPoints;
          _roundPoints += retryPoints;
        } else {
          _correctCount++;
          _combo++;
          _lastGained = pointsForAnswer(_combo) * (_isBonusQuestion ? 2 : 1);
          _roundPoints += _lastGained;
        }
      } else {
        _combo = 0;
        _lastGained = 0;
        if (!_isRetryQuestion) {
          _entries.add(_LangEntry(_question, isRetry: true));
          // 보기 고르기 문제는 오답 노트에 담아 나중에 다시 푼다.
          // (말하기·타일 조립은 보기가 없어서 오답 노트로 못 낸다)
          if (_question.tiles.isEmpty && !_isSpeakingQuestion) {
            WrongNoteStore.add(WrongNote.fromLang(widget.pack, _question));
          }
        }
      }
    });
    if (_isCorrect) {
      Sounds.correct(_combo);
      HapticFeedback.lightImpact().ignore();
      QuizVoice.correct(_isRetryQuestion ? 0 : _combo);
    } else {
      Sounds.wrong();
      HapticFeedback.heavyImpact().ignore();
      QuizVoice.wrongReplay(_question.speech, lang: widget.pack.ttsLang);
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
        await LangProgressStore.saveStars(widget.pack, level.number, stars);
      }
      await ProgressStore.addPoints(earned + chestCoins);
      final rewards = await DailyStore.recordRound(
        correctCount: _correctCount,
        stars: stars,
        otherLang: true,
      );
      await StatsStore.recordRoundDay();
      CloudSync.scheduleUpload(); // 로그인돼 있으면 잠시 뒤 클라우드에 저장
      // 통과하면 스티커북에 붙일 스티커 1장을 준다.
      if (stars >= 1) await StickerStore.addTickets(1);
      var nextLevel = (level != null &&
              stars >= 1 &&
              level.number < widget.pack.totalLevels)
          ? widget.pack.levelAt(level.number + 1)
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
                ? '${level.unit.emoji} ${level.unit.title} · '
                    '${level.number - level.unit.firstLevelNumber + 1}단계'
                : null,
            showUnlockHint: level != null && stars < 1,
            nextLabel:
                next != null ? '다음 단계' : null,
            nextBuilder: next != null
                ? () => LanguageQuizScreen(
                      pack: widget.pack,
                      typeIndex: next.unit.typeIndex,
                      stage: next.stage,
                      level: next,
                    )
                : null,
            retryBuilder: () => LanguageQuizScreen(
              pack: widget.pack,
              typeIndex: widget.typeIndex,
              stage: widget.stage,
              level: level,
            ),
            // 어디서 왔든 홈으로 가는 버튼이라 표현을 하나로 통일한다.
            homeLabel: '처음으로',
          ),
        ),
      );
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedChoice = null;
      _resetSpeaking();
    });
    _speakQuestion();
  }

  /// 말하기 문제 상태를 비운다 (다음 문제로 넘어갈 때)
  void _resetSpeaking() {
    _micListening = false;
    _micRecording = false;
    _spoken = null;
    _myVoicePath = null;
    _micNotice = '';
  }

  @override
  Widget build(BuildContext context) {
    final level = widget.level;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: QuizScaffold(
        topBar: QuizTopBar(
          onClose: _confirmExit,
          dots: _dots.dots,
          current: _dots.dotFor(_currentIndex),
          coins: _roundPoints,
          combo: _combo,
          color: _themeColor,
          label: level != null
              ? '${level.unit.title} · '
                  '${level.number - level.unit.firstLevelNumber + 1}단계'
              : null,
        ),
        card: _buildQuestionCard(),
        // 어른 과정(영어회화)에는 쿼카 응원을 빼고 문제에 집중한다.
        cheer: widget.pack.forAdults
            ? null
            : QuizCheer(
                line: _answered
              ? null
              : quizCheerLine(
                  index: _currentIndex, retry: _isRetryQuestion),
          reaction: _answered ? _isCorrect : null,
              ),
        answers: _isSpeakingQuestion
            ? _buildSpeakingPanel()
            : _question.tiles.isNotEmpty
                ? _buildTiles()
                : _buildChoices(),
        feedback: _answered ? _buildFeedbackPanel() : null,
        sparkle: _answered && _isCorrect && _combo >= 5,
        sparkleKey: ValueKey('sparkle$_currentIndex'),
      ),
    );
  }

  Widget _buildQuestionCard() {
    // 그림·🔊는 큼직하게, 낱말·글자 배열은 그보다 작게
    final displayIsText = widget.pack.types[_question.typeIndex].textDisplay;
    // 듣기 문제는 문제 자체가 커다란 듣기 버튼
    final listenDisplay = _question.display == '🔊';
    // 영어 문장은 단어 단위라 칸이 넓고 여러 줄로 접힌다.
    final wordMode = _question.tileJoin.isNotEmpty;

    return QuizCard(
      color: _themeColor,
      instruction: _question.instruction,
      onSpeak: listenDisplay ? null : () => _speakQuestion(force: true),
      badge: _isRetryQuestion
          ? const QuizBadge.retry()
          : _isBonusQuestion
              ? const QuizBadge.bonus()
              : null,
      child: Column(
        children: [
          if (listenDisplay)
            QuizSpeakButton(
              onTap: () => _speakQuestion(force: true),
              size: 96,
            )
          else
            FittedBox(
              fit: BoxFit.scaleDown,
              child: ConstrainedBox(
                // 문장이 길면 줄을 바꿔서 보여 준다 (한 줄로 줄이면 너무 작아진다)
                constraints: BoxConstraints(
                  maxWidth: _longDisplay ? 300 : double.infinity,
                ),
                child: Text(
                  _question.display,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _longDisplay
                        ? 28
                        : displayIsText
                            ? 40
                            : 64,
                    height: _longDisplay ? 1.3 : null,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          if (_question.subDisplay.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _question.subDisplay,
              textAlign: TextAlign.center,
              // 한자 구절·낱말처럼 짧은 것(6자 이하)은 크게, 회화 뜻풀이처럼 길면 작게
              style: _question.subDisplay.length > 6
                  ? const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      color: AppColors.inkSoft,
                    )
                  : const TextStyle(
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
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _question.slotCount; i++)
                    QuizSlot(
                      text: i < _picked.length
                          ? _question.tiles[_picked[i]]
                          : '',
                      active: i == _picked.length,
                      answered: _answered,
                      correct: _isCorrect,
                      color: _themeColor,
                      wide: wordMode,
                    ),
                ],
              );
            }),
          ],
        ],
      ),
    );
  }

  /// 낱말 만들기용 글자 타일 (누른 타일은 비활성화, 지우기 포함)
  Widget _buildTiles() {
    _ensureTiles();
    // 영어 문장은 단어 타일이라 글자 수에 맞춰 칸이 늘어난다.
    final wordMode = _question.tileJoin.isNotEmpty;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _question.tiles.length; i++)
          QuizTile(
            text: _question.tiles[i],
            used: _picked.contains(i),
            wide: wordMode,
            onTap: _answered ? null : () => _tapTile(i),
          ),
        QuizTile.backspace(onTap: _answered ? null : _tapTileBackspace),
      ],
    );
  }

  /// 🎤 말하기: 인식해서 채점한다.
  Future<void> _tapMic() async {
    if (_answered || _micRecording) return;
    if (_micListening) {
      await VoiceInput.stopListening();
      if (mounted) setState(() => _micListening = false);
      return;
    }
    final ready = await VoiceInput.ensureReady();
    if (!mounted) return;
    if (!ready) {
      setState(() => _micNotice = '마이크를 쓸 수 없어요. 권한을 허용해 주세요.');
      return;
    }
    setState(() {
      _micListening = true;
      _micNotice = '';
    });
    final heard = await VoiceInput.listen();
    if (!mounted) return;
    setState(() => _micListening = false);
    if (heard.trim().isEmpty) {
      setState(() => _micNotice = '잘 안 들렸어요. 한 번 더 말해 볼까요?');
      return;
    }
    final score = scoreSpeaking(_question.answer, heard);
    setState(() => _spoken = score);
    // 통과하면 정답, 아니면 오답으로 채점한다 (기준은 느슨하다).
    _selectChoice(score.passed ? _question.answer : '__speak_miss__');
  }

  /// 🔴 녹음: 내 목소리를 담아 원어민 발음과 번갈아 들어 본다.
  Future<void> _tapRecord() async {
    if (_micListening) return;
    if (_micRecording) {
      final path = await VoiceInput.stopRecording();
      if (!mounted) return;
      setState(() {
        _micRecording = false;
        _myVoicePath = path;
        if (path == null) _micNotice = '녹음을 저장하지 못했어요.';
      });
      return;
    }
    final started = await VoiceInput.startRecording();
    if (!mounted) return;
    if (!started) {
      setState(() => _micNotice = '녹음을 시작할 수 없어요. 권한을 확인해 주세요.');
      return;
    }
    setState(() {
      _micRecording = true;
      _micNotice = '';
    });
  }

  /// 말하기 문제 화면: 마이크로 말해서 채점받고, 녹음해서 발음을 비교한다.
  Widget _buildSpeakingPanel() {
    final score = _spoken;
    return Column(
      children: [
        // 마이크: 누르고 말하면 채점
        BouncyButton(
          key: const ValueKey('speak-mic'),
          color: _micListening ? const Color(0xFFFFDFE0) : _themeColor,
          shadowColor:
              _micListening ? const Color(0xFFEA2B2B) : _themeColor,
          padding: const EdgeInsets.symmetric(vertical: 16),
          onTap: _answered ? null : _tapMic,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _micListening ? Icons.stop_rounded : Icons.mic_rounded,
                size: 26,
                color: _micListening ? const Color(0xFFEA2B2B) : Colors.white,
              ),
              const SizedBox(width: 8),
              Text(
                _micListening ? '듣는 중… (누르면 멈춤)' : '눌러서 말하기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color:
                      _micListening ? const Color(0xFFEA2B2B) : Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        // 녹음해서 내 발음과 원어민 발음 비교하기
        Row(
          children: [
            Expanded(
              child: BouncyButton(
                key: const ValueKey('speak-record'),
                color: _micRecording ? const Color(0xFFFFEBD6) : Colors.white,
                shadowColor: Colors.grey.shade300,
                border: Border.all(
                  color: _micRecording
                      ? const Color(0xFFEA2B2B)
                      : Colors.grey.shade300,
                  width: 2,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                onTap: _tapRecord,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _micRecording
                          ? Icons.stop_circle_rounded
                          : Icons.fiber_manual_record_rounded,
                      size: 20,
                      color: const Color(0xFFEA2B2B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _micRecording ? '녹음 멈추기' : '내 목소리 녹음',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            if (_myVoicePath != null) ...[
              const SizedBox(width: 10),
              Expanded(
                child: BouncyButton(
                  key: const ValueKey('speak-playback'),
                  color: Colors.white,
                  shadowColor: Colors.grey.shade300,
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onTap: () => Sounds.playFile(_myVoicePath!),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 20),
                      SizedBox(width: 6),
                      Text('내 목소리 듣기',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
        if (_micNotice.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            _micNotice,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
        ],
        if (score != null) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: score.passed
                  ? AppColors.selectedFill
                  : AppColors.wrongSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: score.passed ? AppColors.correct : AppColors.wrong,
                width: 2,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '이렇게 들렸어요',
                  style: TextStyle(fontSize: 13, color: AppColors.inkSoft),
                ),
                const SizedBox(height: 4),
                Text(
                  score.heard,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  score.perfect
                      ? '낱말을 모두 정확히 말했어요! 🎉'
                      : '${score.total}개 중 ${score.matched}개를 맞게 말했어요',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: score.passed
                        ? AppColors.greenPressed
                        : AppColors.wrongInk,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildChoices() {
    // 영어 문장·뜻풀이처럼 긴 보기는 두세 줄로 접히게 두고 칸도 높인다.
    final longChoices = _question.choices.any((c) => c.length > 14);
    return QuizChoiceGrid(
      height: longChoices ? 120 : 96,
      children: [
        for (var i = 0; i < _question.choices.length; i++)
          QuizChoiceButton(
            label: _question.choices[i],
            state: _choiceState(_question.choices[i]),
            fillIndex: i,
            fontSize: _question.emojiChoices ? 44 : 30,
            long: longChoices,
            onTap: () => _selectChoice(_question.choices[i]),
          ),
      ],
    );
  }

  QuizChoiceState _choiceState(String choice) {
    if (!_answered) return QuizChoiceState.idle;
    if (choice == _question.answer) return QuizChoiceState.correct;
    if (choice == _selectedChoice) return QuizChoiceState.wrong;
    return QuizChoiceState.disabled;
  }

  Widget _buildFeedbackPanel() {
    return QuizFeedbackPanel(
      correct: _isCorrect,
      answerText: _question.answerText,
      gained: _lastGained,
      fire: !_isRetryQuestion && _combo >= 3,
      isLast: _currentIndex + 1 >= _entries.length,
      onNext: _next,
      autoNextKey: ValueKey('auto-next-$_currentIndex'),
    );
  }
}
