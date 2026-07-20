import 'package:flutter/material.dart';

import '../models/question.dart';
import '../models/quiz_config.dart';
import 'result_screen.dart';

/// 퀴즈 화면: 문제를 하나씩 풀고, 듀오링고처럼 아래에서 정답 여부를 알려준다.
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.config});

  final QuizConfig config;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  late final List<Question> _questions;
  int _currentIndex = 0;
  int _correctCount = 0;

  /// 아이가 고른 보기. null이면 아직 고르지 않은 상태.
  int? _selectedChoice;

  Question get _question => _questions[_currentIndex];
  bool get _answered => _selectedChoice != null;
  bool get _isCorrect => _selectedChoice == _question.answer;

  @override
  void initState() {
    super.initState();
    _questions = QuestionGenerator().generate(widget.config);
  }

  void _selectChoice(int choice) {
    if (_answered) return;
    setState(() {
      _selectedChoice = choice;
      if (choice == _question.answer) {
        _correctCount++;
      }
    });
  }

  void _next() {
    if (_currentIndex + 1 >= _questions.length) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(
            config: widget.config,
            correctCount: _correctCount,
            totalCount: _questions.length,
          ),
        ),
      );
      return;
    }
    setState(() {
      _currentIndex++;
      _selectedChoice = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
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
            onPressed: () => Navigator.of(context).pop(),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: TweenAnimationBuilder<double>(
                tween: Tween(
                  end:
                      (_currentIndex + (_answered ? 1 : 0)) / _questions.length,
                ),
                duration: const Duration(milliseconds: 300),
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 14,
                  backgroundColor: Colors.grey.shade300,
                  color: const Color(0xFF58CC02),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            '⭐ $_correctCount',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade300, width: 2),
      ),
      child: Column(
        children: [
          Text(
            _question.expression,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _EmojiHint(question: _question),
        ],
      ),
    );
  }

  Widget _buildChoices() {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.8,
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
    final message =
        _isCorrect ? '정답이에요! 🎉' : '아쉬워요! 정답은 ${_question.answer}이에요';

    final isLast = _currentIndex + 1 >= _questions.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
      color: color,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              message,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _next,
              style: ElevatedButton.styleFrom(
                backgroundColor: textColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(isLast ? '결과 보기 🏁' : '계속하기'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ChoiceState { idle, correct, wrong, disabled }

/// 큼직한 보기 버튼
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

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border, width: 3),
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
      ),
    );
  }
}

/// 개수 세기를 도와주는 이모지 그림.
/// 덧셈: 🍎🍎🍎 ➕ 🍎🍎 / 뺄셈: 빼는 만큼 흐리게 표시
class _EmojiHint extends StatelessWidget {
  const _EmojiHint({required this.question});

  final Question question;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 26);

    if (question.isAddition) {
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
    }

    // 뺄셈: 전체 중에서 빼는 개수만큼 흐리게 보여준다.
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
  }
}
