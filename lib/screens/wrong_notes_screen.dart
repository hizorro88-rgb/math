import 'dart:async';

import 'package:flutter/material.dart';

import '../models/wrong_notes.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/bouncy_button.dart';

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
  Timer? _nextTimer;

  WrongNote get _note => _round[_index];
  bool get _answered => _selected != null;

  @override
  void initState() {
    super.initState();
    _startRound();
  }

  @override
  void dispose() {
    _nextTimer?.cancel();
    super.dispose();
  }

  Future<void> _startRound() async {
    final notes = await WrongNoteStore.load();
    if (!mounted) return;
    // 최근에 틀린 것부터 다시 푼다.
    final ordered = notes.reversed.toList();
    setState(() {
      _round = ordered.take(WrongNotesScreen.roundSize).toList();
      _remainingAfter = ordered.length - _round.length;
      _index = 0;
      _passed = 0;
      _selected = null;
      _finished = false;
      _loaded = true;
    });
    if (_round.isNotEmpty) _speakQuestion();
  }

  void _speakQuestion() {
    final note = _note;
    if (note.display == '🔊' && note.speech.isNotEmpty) {
      Speech.speak(note.speech, lang: note.speechLang);
    }
  }

  void _select(String choice) {
    if (_answered) return;
    final correct = choice == _note.answer;
    setState(() => _selected = choice);
    if (correct) {
      _passed++;
      Sounds.correct(1);
      WrongNoteStore.remove(_note.id);
    } else {
      Sounds.wrong();
      WrongNoteStore.markMissed(_note.id);
      Speech.speak(_note.answerText, lang: _note.speechLang);
    }
    _nextTimer = Timer(const Duration(milliseconds: 1200), _next);
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
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '오답 노트',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : _round.isEmpty
              ? _empty()
              : _finished
                  ? _result()
                  : _quiz(),
    );
  }

  Widget _empty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🦉📒', style: TextStyle(fontSize: 52)),
          const SizedBox(height: 12),
          const Text(
            '오답 노트가 비었어요! 🎉',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 6),
          Text(
            '틀린 게 하나도 없다니, 부기가 깜짝 놀랐어!\n틀린 문제가 생기면 여기 모아 뒀다가 같이 복습해요.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3DA35D),
              padding:
                  const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
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
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            BouncyButton(
              color: const Color(0xFFB05CCC),
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
              shadowColor: Colors.grey.shade300,
              border: Border.all(color: Colors.grey.shade300, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: () => Navigator.of(context).pop(),
              child: Text(
                '끝내기',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade600,
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  '${note.subjectEmoji} ${note.subjectName}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  '${_index + 1} / ${_round.length}',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: (_index + (_answered ? 1 : 0)) / _round.length,
                minHeight: 10,
                backgroundColor: Colors.grey.shade200,
                color: const Color(0xFFB05CCC),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: const Color(0xFFE6C8F2),
                  width: 3,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.instruction,
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (note.speech.isNotEmpty)
                        IconButton(
                          onPressed: () =>
                              Speech.speak(note.speech, lang: note.speechLang),
                          icon: const Icon(Icons.volume_up_rounded,
                              color: Color(0xFFB05CCC), size: 30),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    note.display,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 46, fontWeight: FontWeight.bold),
                  ),
                  if (note.subDisplay.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      note.subDisplay,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.5,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final choice in note.choices) _choiceButton(choice),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _choiceButton(String choice) {
    final isAnswer = choice == _note.answer;
    final isSelected = choice == _selected;
    Color color = Colors.white;
    Color border = Colors.grey.shade300;
    if (_answered) {
      if (isAnswer) {
        color = const Color(0xFFD7FFB8);
        border = const Color(0xFF3DA35D);
      } else if (isSelected) {
        color = const Color(0xFFFFD6D6);
        border = const Color(0xFFE05C5C);
      }
    }
    return BouncyButton(
      color: color,
      shadowColor: border,
      border: Border.all(color: border, width: 2),
      onTap: _answered ? null : () => _select(choice),
      child: Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            choice,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: _note.emojiChoices ? 44 : 26,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
