import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/daily.dart';
import '../models/english_curriculum.dart';
import '../models/english_question.dart';
import '../models/premium.dart';
import '../models/progress.dart';
import '../models/stats.dart';
import '../models/stickers.dart';
import '../models/wrong_notes.dart';
import '../services/cloud_sync.dart';
import '../services/sounds.dart';
import '../widgets/listen_guard.dart';
import '../widgets/quiz_exit_dialog.dart';
import '../widgets/quiz_parts.dart';
import 'result_screen.dart';

/// 영어 퀴즈 화면: 수학 퀴즈와 같은 흐름(진행 바·콤보·재출제·피드백 판)으로
/// 낱말/글자/그림 보기를 고른다. 듣기 문제는 TTS가 문제를 읽어 준다.
class EnglishQuizScreen extends StatefulWidget {
  const EnglishQuizScreen({
    super.key,
    required this.type,
    this.stage = 0,
    this.level,
  });

  final EnQuizType type;
  final int stage;

  /// 단계 도전이면 해당 단계, 아니면 null
  final EnLevel? level;

  @override
  State<EnglishQuizScreen> createState() => _EnglishQuizScreenState();
}

class _EnEntry {
  const _EnEntry(this.question, {this.isRetry = false});

  final EnglishQuestion question;
  final bool isRetry;
}

class _EnglishQuizScreenState extends State<EnglishQuizScreen> {
  late final int _baseCount;

  /// 상단바 진행 점 (틀린 문제를 다시 풀어도 점 수는 그대로)
  late final QuizDotTracker _dots;
  final List<_EnEntry> _entries = [];
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

  EnglishQuestion get _question => _entries[_currentIndex].question;
  bool get _isRetryQuestion => _entries[_currentIndex].isRetry;

  /// 7번째 문제는 ⚡보너스: 맞히면 코인 2배 (재출제 문제에는 없음)
  bool get _isBonusQuestion => _currentIndex == 6 && !_isRetryQuestion;

  bool get _answered => _selectedChoice != null;
  bool get _isCorrect => _selectedChoice == _question.answer;
  Color get _themeColor =>
      widget.level?.unit.color ?? const Color(0xFF5B6CF0);

  @override
  void initState() {
    super.initState();
    final questions = EnglishQuestionGenerator()
        .generate(widget.type, stage: widget.stage);
    _baseCount = questions.length;
    _dots = QuizDotTracker(_baseCount);
    _entries.addAll(questions.map(_EnEntry.new));
    WidgetsBinding.instance.addPostFrameCallback((_) => _start());
  }

  /// 소리 찾기 유형은 소리가 있어야 풀 수 있으니 먼저 확인한다.
  Future<void> _start() async {
    final needsListening = widget.type == EnQuizType.listenLetter;
    if (needsListening) {
      final ready =
          await ensureListenReady(context, lang: 'en-US', langName: '영어');
      if (!ready) {
        if (mounted) Navigator.of(context).pop();
        return;
      }
    }
    _speakQuestion();
  }

  void _speakQuestion({bool force = false}) => QuizVoice.question(
      task: _question.instruction,
      speech: _question.speech,
      lang: _question.speechLang,
      retry: _isRetryQuestion,
      bonus: _isBonusQuestion,
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
    // 누른 조각을 소리 내어 읽어 준다 — 글자를 몰라도 소리로 맞춰 본다.
    // (마지막 조각이면 채점할 때 완성된 낱말을 통째로 읽는다)
    if (_picked.length < _question.answer.length) {
      QuizVoice.tile(_question.tiles[index], lang: _question.speechLang);
    }
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
      StatsStore.recordEnglishAnswer(widget.type,
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
          _entries.add(_EnEntry(_question, isRetry: true));
          // 보기 고르기 문제는 오답 노트에 담아 나중에 다시 푼다.
          if (_question.tiles.isEmpty) {
            WrongNoteStore.add(WrongNote.fromEnglish(_question));
          }
        }
      }
    });
    if (_isCorrect) {
      Sounds.correct(_combo);
      HapticFeedback.lightImpact().ignore();
      QuizVoice.correct(_isRetryQuestion ? 0 : _combo,
          say: _question.tiles.isNotEmpty ? choice : null, lang: _question.speechLang);
    } else {
      Sounds.wrong();
      HapticFeedback.heavyImpact().ignore();
      QuizVoice.wrong(_question.answerText, lang: _question.speechLang);
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
        await EnglishProgressStore.saveStars(level.number, stars);
      }
      await ProgressStore.addPoints(earned + chestCoins);
      final rewards = await DailyStore.recordRound(
        correctCount: _correctCount,
        stars: stars,
        english: true,
      );
      await StatsStore.recordRoundDay();
      CloudSync.scheduleUpload(); // 로그인돼 있으면 잠시 뒤 클라우드에 저장
      // 통과하면 스티커북에 붙일 스티커 1장을 준다.
      if (stars >= 1) await StickerStore.addTickets(1);
      var nextLevel = (level != null &&
              stars >= 1 &&
              level.number < EnglishCurriculum.totalLevels)
          ? EnglishCurriculum.levelAt(level.number + 1)
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
                ? () => EnglishQuizScreen(
                      type: next.unit.type,
                      stage: next.stage,
                      level: next,
                    )
                : null,
            retryBuilder: () => EnglishQuizScreen(
              type: widget.type,
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
    });
    _speakQuestion();
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
        cheer: QuizCheer(
          line: _answered
              ? null
              : quizCheerLine(
                  index: _currentIndex,
                  retry: _isRetryQuestion,
                  bonus: _isBonusQuestion),
          reaction: _answered ? _isCorrect : null,
        ),
        answers:
            _question.tiles.isNotEmpty ? _buildTiles() : _buildChoices(),
        feedback: _answered ? _buildFeedbackPanel() : null,
        sparkle: _answered && _isCorrect && _combo >= 5,
        sparkleKey: ValueKey('sparkle$_currentIndex'),
      ),
    );
  }

  Widget _buildQuestionCard() {
    // 그림·🔊는 큼직하게, 낱말·글자 배열은 그보다 작게
    final displayIsText = switch (_question.type) {
      EnQuizType.wordToPicture ||
      EnQuizType.alphabetOrder ||
      EnQuizType.caseMatch =>
        true,
      _ => false,
    };
    // 듣기 문제는 문제 자체가 커다란 듣기 버튼
    final listenDisplay = _question.display == '🔊';
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
              child: Text(
                _question.display,
                style: TextStyle(
                  fontSize: displayIsText ? 40 : 64,
                  fontWeight: FontWeight.bold,
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
              return Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var i = 0; i < _question.answer.length; i++)
                    QuizSlot(
                      text: i < _picked.length
                          ? _question.tiles[_picked[i]]
                          : '',
                      active: i == _picked.length,
                      answered: _answered,
                      correct: _isCorrect,
                      color: _themeColor,
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
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < _question.tiles.length; i++)
          QuizTile(
            text: _question.tiles[i],
            used: _picked.contains(i),
            onTap: _answered ? null : () => _tapTile(i),
          ),
        QuizTile.backspace(onTap: _answered ? null : _tapTileBackspace),
      ],
    );
  }

  Widget _buildChoices() {
    return QuizChoiceGrid(
      children: [
        for (var i = 0; i < _question.choices.length; i++)
          QuizChoiceButton(
            label: _question.choices[i],
            state: _choiceState(_question.choices[i]),
            fillIndex: i,
            fontSize: _question.emojiChoices ? 44 : 30,
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
