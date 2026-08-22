import 'dart:math';

import 'english_data.dart';

/// 영어 퀴즈의 문제 유형
enum EnQuizType {
  /// 낱말을 보고(듣고) 알맞은 그림을 고른다 — 소리(en-US)가 먼저
  wordToPicture('낱말 듣고 그림 찾기', '듣고 그림', '🔍'),

  /// 그림을 보고 알맞은 영어 낱말을 고른다
  pictureToWord('그림 보고 낱말 찾기', '그림→낱말', '🖼️'),

  /// 알파벳 소리를 듣고 글자를 찾는다 (에이 → A)
  listenLetter('알파벳 소리 찾기', '알파벳 소리', '🔊'),

  /// 대문자·소문자 짝을 맞춘다 (A ↔ a)
  caseMatch('대문자 소문자 짝', '대소문자', '🅰️'),

  /// 알파벳 순서에서 다음 글자를 찾는다 (A B C ?)
  alphabetOrder('ABC 순서', 'ABC', '🐾'),

  /// 낱말의 첫 글자를 찾는다 (apple → A)
  firstLetter('첫 글자 찾기', '첫 글자', '🎯'),

  /// 글자 타일을 순서대로 눌러 낱말을 조립한다 (C-A-T)
  wordBuild('낱말 만들기', '낱말 조립', '🏗️'),

  /// 긴 낱말 읽기 도전
  longWord('긴 낱말 도전', '긴 낱말', '🚀');

  const EnQuizType(this.label, this.shortLabel, this.emoji);

  final String label;

  /// 리포트처럼 좁은 곳에 쓰는 짧은 이름
  final String shortLabel;
  final String emoji;
}

/// 영어 한 문제. 발음은 [speech]를 [speechLang] 언어로 읽는다.
class EnglishQuestion {
  const EnglishQuestion({
    required this.type,
    required this.instruction,
    required this.display,
    required this.choices,
    required this.answer,
    required this.answerText,
    required this.speech,
    this.speechLang = 'en-US',
    this.subDisplay = '',
    this.emojiChoices = false,
    this.tiles = const [],
    required this.dedupKey,
  });

  final EnQuizType type;

  /// 문제 카드 위의 안내 문구
  final String instruction;

  /// 카드 가운데 큰 표시 (이모지, 낱말, 🔊 등)
  final String display;

  /// 큰 표시 아래 보조 표시
  final String subDisplay;

  final List<String> choices;
  final String answer;

  /// 피드백 판에 보여줄 정답 이름
  final String answerText;

  /// 문제를 읽어 줄 말 (영어 낱말·알파벳은 en-US로 읽는다)
  final String speech;
  final String speechLang;

  final bool emojiChoices;

  /// 낱말 만들기용 글자 타일. 비어 있지 않으면 타일 조립 UI로 푼다.
  final List<String> tiles;

  final String dedupKey;
}

/// 유형과 단계(0~9)에 맞는 영어 문제 목록을 만들어 준다.
class EnglishQuestionGenerator {
  EnglishQuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<EnglishQuestion> generate(EnQuizType type,
      {int stage = 0, int count = 10}) {
    final questions = <EnglishQuestion>[];
    String? previousKey;
    for (var i = 0; i < count; i++) {
      EnglishQuestion question;
      do {
        question = _generateOne(type, stage);
      } while (question.dedupKey == previousKey);
      previousKey = question.dedupKey;
      questions.add(question);
    }
    return questions;
  }

  EnglishQuestion _generateOne(EnQuizType type, int stage) {
    switch (type) {
      case EnQuizType.wordToPicture:
        final pool = stage >= 5 ? enAllWords : enWordsShort;
        final picked = _pickWords(pool);
        final target = picked.first;
        return EnglishQuestion(
          type: type,
          instruction: '잘 듣고 알맞은 그림을 찾아요',
          display: target.shown,
          choices: _shuffled([for (final w in picked) w.emoji]),
          answer: target.emoji,
          answerText: target.shown,
          speech: target.word,
          emojiChoices: true,
          dedupKey: 'wtp:${target.word}',
        );

      case EnQuizType.pictureToWord:
        final pool = enWordsShort.take(10 + stage * 2).toList();
        return _pictureToWord(pool, type);

      case EnQuizType.longWord:
        return _pictureToWord(enWordsLong, type);

      case EnQuizType.listenLetter:
        final pool =
            stage >= 5 ? enAlphabet : enAlphabet.sublist(0, 13); // A~M부터
        final picked = _pick(pool, 4);
        final target = picked.first;
        return EnglishQuestion(
          type: type,
          instruction: '무슨 알파벳일까요? 🔊를 눌러 다시 들어요',
          display: '🔊',
          choices: _shuffled(picked),
          answer: target,
          answerText: target,
          speech: target,
          dedupKey: 'll:$target',
        );

      case EnQuizType.caseMatch:
        final pool =
            stage >= 5 ? enAlphabet : enAlphabet.sublist(0, 13);
        final picked = _pick(pool, 4);
        final target = picked.first;
        // 뒤 단계에서는 소문자를 보여주고 대문자를 찾기도 한다.
        final showLower = stage >= 5 && _random.nextBool();
        return EnglishQuestion(
          type: type,
          instruction: showLower ? '짝이 되는 대문자는?' : '짝이 되는 소문자는?',
          display: showLower ? target.toLowerCase() : target,
          choices: _shuffled([
            for (final c in picked) showLower ? c : c.toLowerCase(),
          ]),
          answer: showLower ? target : target.toLowerCase(),
          answerText: '$target (${target.toLowerCase()})',
          speech: target,
          dedupKey: 'cm:$target:$showLower',
        );

      case EnQuizType.alphabetOrder:
        // 앞 단계에서는 ABC 첫머리 위주로 나온다.
        final maxStart = stage < 3 ? 5 : enAlphabet.length - 3;
        final start = _random.nextInt(maxStart);
        final shown = enAlphabet.sublist(start, start + 3);
        final answer = enAlphabet[start + 3];
        final wrong = _pick(
          [for (final c in enAlphabet) if (c != answer) c],
          3,
        );
        return EnglishQuestion(
          type: type,
          instruction: '다음에 올 알파벳은?',
          display: '${shown.join('  ')}  ?',
          choices: _shuffled([answer, ...wrong]),
          answer: answer,
          answerText: answer,
          speech: shown.join(', '),
          dedupKey: 'ao:$start',
        );

      case EnQuizType.firstLetter:
        final pool = stage >= 5 ? enAllWords : enWordsShort;
        final word = pool[_random.nextInt(pool.length)];
        final answer = word.shown[0];
        final wrong = _pick(
          [for (final c in enAlphabet) if (c != answer) c],
          3,
        );
        return EnglishQuestion(
          type: type,
          instruction: "'${word.shown}'의 첫 글자는?",
          display: word.emoji,
          subDisplay: word.shown,
          choices: _shuffled([answer, ...wrong]),
          answer: answer,
          answerText: answer,
          speech: word.word,
          dedupKey: 'fl:${word.word}',
        );

      case EnQuizType.wordBuild:
        final pool = stage >= 5 ? enAllWords : enWordsShort;
        final word = pool[_random.nextInt(pool.length)];
        final letters = word.shown.split('');
        // 함정 글자 2개: 낱말에 없는 알파벳
        final decoys = [
          for (final c in enAlphabet) if (!letters.contains(c)) c,
        ]..shuffle(_random);
        final tiles = [...letters, ...decoys.take(2)]..shuffle(_random);
        return EnglishQuestion(
          type: type,
          instruction: '글자를 순서대로 눌러 낱말을 만들어요',
          display: word.emoji,
          choices: tiles,
          answer: word.shown,
          answerText: word.shown,
          speech: word.word,
          tiles: tiles,
          dedupKey: 'wb:${word.word}',
        );
    }
  }

  EnglishQuestion _pictureToWord(List<EnWord> pool, EnQuizType type) {
    final picked = _pickWords(pool);
    final target = picked.first;
    return EnglishQuestion(
      type: type,
      instruction: '그림에 맞는 낱말은?',
      display: target.emoji,
      choices: _shuffled([for (final w in picked) w.shown]),
      answer: target.shown,
      answerText: target.shown,
      speech: target.word,
      dedupKey: 'ptw:${target.word}',
    );
  }

  List<T> _pick<T>(List<T> pool, int n) {
    final copy = [...pool]..shuffle(_random);
    return copy.take(n).toList();
  }

  /// 낱말 4개를 고른다 (첫 번째가 정답). 같은 그룹 낱말은 오답으로 안 넣는다.
  List<EnWord> _pickWords(List<EnWord> pool) {
    final target = pool[_random.nextInt(pool.length)];
    final others = [
      for (final w in pool)
        if (w.word != target.word &&
            (w.group == null || w.group != target.group))
          w,
    ]..shuffle(_random);
    return [target, ...others.take(3)];
  }

  List<String> _shuffled(List<String> items) => [...items]..shuffle(_random);
}
