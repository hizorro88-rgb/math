import 'package:flutter/material.dart';

import '../models/stats.dart';
import '../models/wrong_notes.dart';
import '../services/sounds.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/quiz_parts.dart';
import '../widgets/quokka_avatar.dart';

/// 오답 노트: 틀렸던 낱말·글자 문제를 다시 풀고, 맞히면 노트에서 지운다.
class WrongNotesScreen extends StatefulWidget {
  const WrongNotesScreen({super.key});

  /// 한 번에 다시 푸는 최대 문제 수
  static const roundSize = 10;

  @override
  State<WrongNotesScreen> createState() => _WrongNotesScreenState();
}

class _WrongNotesScreenState extends State<WrongNotesScreen> {
  List<WrongNote> _round = [];
  int _remainingAfter = 0;
  int _index = 0;
  int _passed = 0;
  String? _selected;
  bool _finished = false;
  bool _loaded = false;
  bool _neverPlayed = false; // 아직 퀴즈를 하나도 안 풀었는지
  QuizDotTracker _dots = QuizDotTracker(0);

  WrongNote get _note => _round[_index];
  bool get _answered => _selected != null;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  Future<void> _startRound() async {
    final notes = await WrongNoteStore.load();
    final stats = await StatsStore.load();
    if (!mounted) return;
    _neverPlayed = stats.totalAnswered == 0;
    // 최근에 틀린 것부터 다시 푼다.
    final ordered = notes.reversed.toList();
    setState(() {
      _round = ordered.take(WrongNotesScreen.roundSize).toList();
      _dots = QuizDotTracker(_round.length);
      _remainingAfter = ordered.length - _round.length;
      _index = 0;
      _passed = 0;
      _selected = null;
      _finished = false;
      _loaded = true;
    });
    if (_round.isNotEmpty) _speakQuestion();
  }

  void _speakQuestion({bool force = false}) {
    final note = _note;
    if (note.speech.isEmpty) return;
    QuizVoice.question(
      task: note.instruction,
      speech: note.speech,
      lang: note.speechLang,
      force: force,
    );
  }

  void _select(String choice) {
    if (_answered) return;
    final correct = choice == _note.answer;
    setState(() {
      _selected = choice;
      _dots.record(_index, correct: correct, retry: false);
    });
    if (correct) {
      _passed++;
      Sounds.correct(1);
      QuizVoice.correct(0);
      WrongNoteStore.remove(_note.id);
    } else {
      Sounds.wrong();
      WrongNoteStore.markMissed(_note.id);
      QuizVoice.wrong(_note.answerText, lang: _note.speechLang);
    }
  }

  void _next() {
    if (!mounted) return;
    setState(() {
      if (_index + 1 >= _round.length) {
        _finished = true;
      } else {
        _index++;
        _selected = null;
      }
    });
    if (!_finished) _speakQuestion();
  }

  @override
  Widget build(BuildContext context) {
    // 푸는 동안은 다른 퀴즈와 같은 몰입 화면(✕ · 점 · 문제 · 보기 · 판)
    if (_loaded && _round.isNotEmpty && !_finished) return _quiz();
    return Scaffold(
      appBar: AppBar(title: const Text('📒 오답 노트')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _round.isEmpty
              ? _empty()
              : _result(),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const QuokkaFace(size: 76),
          const SizedBox(height: 12),
          Text(
            _neverPlayed ? '여기는 오답 노트!' : '오답 노트가 비었어요! 🎉',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            _neverPlayed
                ? '퀴즈를 풀다가 틀린 문제가 여기 모여요.\n쿼카랑 같이 첫 퀴즈부터 시작해 볼까?'
                : '틀린 게 하나도 없다니, 쿼카가 깜짝 놀랐어!\n틀린 문제가 생기면 여기 모아 뒀다가 같이 복습해요.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.green,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
            ),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text(
              '퀴즈 풀러 가기',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _result() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              _passed == _round.length ? '🏆' : '💪',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 60),
            ),
            const SizedBox(height: 12),
            Text(
              '${_round.length}개 중 $_passed개 통과!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              _passed == _round.length && _remainingAfter == 0
                  ? '맞힌 낱말은 노트에서 사라졌어요. 깨끗해졌네요! ✨'
                  : '맞힌 낱말은 노트에서 사라졌어요. 남은 낱말은 다음에 또 만나요!',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
            ),
            const SizedBox(height: 24),
            BouncyButton(
              color: AppColors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              onTap: _startRound,
              child: const Text(
                '한 번 더 풀기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            BouncyButton(
              color: Colors.white,
              shadowColor: AppColors.outline,
              border: Border.all(color: AppColors.outline, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: () => Navigator.of(context).pop(),
              child: const Text(
                '끝내기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.inkSoft,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _quiz() {
    final note = _note;
    final listen = note.display == '🔊';
    const color = Color(0xFFFF9600);
    return QuizScaffold(
      topBar: QuizTopBar(
        onClose: () => Navigator.of(context).pop(),
        dots: _dots.dots,
        current: _dots.dotFor(_index),
        coins: null,
        color: color,
        leading: '📒',
        label: '오답 노트',
      ),
      card: QuizCard(
        color: color,
        instruction: note.instruction,
        onSpeak: note.speech.isEmpty || listen
            ? null
            : () => _speakQuestion(force: true),
        child: Column(
          children: [
            if (listen)
              QuizSpeakButton(
                onTap: () => _speakQuestion(force: true),
                size: 96,
              )
            else
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  note.display,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 46, fontWeight: FontWeight.bold),
                ),
              ),
            if (note.subDisplay.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                note.subDisplay,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 24),
              ),
            ],
          ],
        ),
      ),
      answers: QuizChoiceGrid(
        children: [
          for (var i = 0; i < note.choices.length; i++)
            QuizChoiceButton(
              label: note.choices[i],
              state: !_answered
                  ? QuizChoiceState.idle
                  : note.choices[i] == note.answer
                      ? QuizChoiceState.correct
                      : note.choices[i] == _selected
                          ? QuizChoiceState.wrong
                          : QuizChoiceState.disabled,
              fillIndex: i,
              fontSize: note.emojiChoices ? 44 : 28,
              long: note.choices.any((c) => c.length > 14),
              onTap: () => _select(note.choices[i]),
            ),
        ],
      ),
      feedback: _answered
          ? QuizFeedbackPanel(
              correct: _selected == note.answer,
              answerText: note.answer,
              isLast: _index + 1 >= _round.length,
              onNext: _next,
              autoNextKey: ValueKey('wn-auto-$_index'),
            )
          : null,
    );
  }
}
