import 'dart:math';

import 'korean_data.dart';

/// 한글 퀴즈의 문제 유형
enum KrQuizType {
  /// 그림을 보고 알맞은 낱말을 고른다 (통문자 읽기)
  pictureToWord('그림 보고 낱말 찾기', '그림→낱말', '🖼️'),

  /// 낱말을 보고(듣고) 알맞은 그림을 고른다 — 글자를 몰라도 소리로 풀 수 있다
  wordToPicture('낱말 보고 그림 찾기', '낱말→그림', '🔍'),

  /// 모음 소리를 듣고 글자를 찾는다 (아 → ㅏ)
  listenVowel('모음 소리 찾기', '모음 소리', '🎵'),

  /// 음절 소리를 듣고 글자를 찾는다 (가 → 가)
  listenSyllable('글자 소리 찾기', '글자 소리', '🔊'),

  /// 가나다 순서에서 다음 글자를 찾는다 (가 나 다 ?)
  syllableOrder('가나다 순서', '가나다', '🐾'),

  /// 낱말의 첫소리(초성)를 찾는다 (사과 → ㅅ)
  firstConsonant('첫소리 찾기', '첫소리', '🎯'),

  /// 낱말의 가려진 글자를 채운다 (사□ → 과)
  fillBlank('빈칸 채우기', '빈칸', '🧩'),

  /// 세 글자 낱말 읽기 도전
  longWord('긴 낱말 도전', '긴 낱말', '🚀'),

  // 아래 유형은 통계 저장이 enum 순서 기반이라 끝에 추가한다.

  /// 자음 이름 소리를 듣고 글자를 찾는다 (기역 → ㄱ)
  listenConsonant('자음 소리 찾기', '자음 소리', '🎼'),

  /// 자음과 모음을 합쳐 글자를 만든다 (ㄱ + ㅏ = 가)
  combine('글자 만들기', '글자 조합', '🧱');

  const KrQuizType(this.label, this.shortLabel, this.emoji);

  final String label;

  /// 리포트처럼 좁은 곳에 쓰는 짧은 이름
  final String shortLabel;
  final String emoji;
}

/// 한글 한 문제. 보기는 낱말/글자/이모지 문자열이다.
class KoreanQuestion {
  const KoreanQuestion({
    required this.type,
    required this.instruction,
    required this.display,
    required this.choices,
    required this.answer,
    required this.answerText,
    required this.speech,
    this.subDisplay = '',
    this.emojiChoices = false,
    required this.dedupKey,
  });

  final KrQuizType type;

  /// 문제 카드 위의 안내 문구 (예: "그림에 맞는 낱말은?")
  final String instruction;

  /// 카드 가운데 큰 표시 (이모지, 낱말, 🔊 등)
  final String display;

  /// 큰 표시 아래 보조 표시 (첫소리 찾기의 낱말, 빈칸의 사□ 등)
  final String subDisplay;

  /// 보기 4개 (정답 포함)
  final List<String> choices;

  /// 정답 보기 (choices 중 하나)
  final String answer;

  /// 피드백 판에 보여줄 정답 이름 (그림 찾기면 낱말로)
  final String answerText;

  /// 문제를 읽어 줄 말 (듣기 문제는 이 소리가 곧 문제)
  final String speech;

  /// 보기가 이모지(그림)인지 — 그림이면 더 크게 그린다.
  final bool emojiChoices;

  /// 같은 문제가 연달아 나오는지 판정하는 키
  final String dedupKey;
}

/// 유형과 단계(0~9)에 맞는 한글 문제 목록을 만들어 준다.
class KoreanQuestionGenerator {
  KoreanQuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  List<KoreanQuestion> generate(KrQuizType type,
      {int stage = 0, int count = 10}) {
    final questions = <KoreanQuestion>[];
    String? previousKey;
    for (var i = 0; i < count; i++) {
      KoreanQuestion question;
      do {
        question = _generateOne(type, stage);
      } while (question.dedupKey == previousKey);
      previousKey = question.dedupKey;
      questions.add(question);
    }
    return questions;
  }

  KoreanQuestion _generateOne(KrQuizType type, int stage) {
    switch (type) {
      case KrQuizType.pictureToWord:
        // 단계가 오를수록 낱말 풀이 넓어진다.
        return _pictureToWord(krWords2.take(20 + stage * 4).toList());

      case KrQuizType.longWord:
        return _pictureToWord(krWords3);

      case KrQuizType.wordToPicture:
        // 뒤 단계에서는 긴 낱말도 섞인다.
        final pool = stage >= 5 ? krAllWords : krWords2;
        final picked = _pickWords(pool);
        final target = picked.first;
        return KoreanQuestion(
          type: type,
          instruction: '알맞은 그림을 찾아요',
          display: target.word,
          choices: _shuffled([for (final w in picked) w.emoji]),
          answer: target.emoji,
          answerText: target.word,
          speech: "'${target.word}'는 어디 있을까요?",
          emojiChoices: true,
          dedupKey: 'wtp:${target.word}',
        );

      case KrQuizType.listenVowel:
        final pool = stage >= 5 ? krVowels : krVowels.sublist(0, 6);
        final picked = _pick(pool, 4);
        final target = picked.first;
        return KoreanQuestion(
          type: type,
          instruction: '무슨 소리일까요? 🔊를 눌러 다시 들어요',
          display: '🔊',
          choices: _shuffled([for (final v in picked) v.letter]),
          answer: target.letter,
          answerText: '${target.letter} (${target.sound})',
          speech: target.sound,
          dedupKey: 'lv:${target.letter}',
        );

      case KrQuizType.listenSyllable:
        final pool =
            stage >= 5 ? [...krSyllablesA, ...krSyllablesO] : krSyllablesA;
        final picked = _pick(pool, 4);
        final target = picked.first;
        return KoreanQuestion(
          type: type,
          instruction: '무슨 소리일까요? 🔊를 눌러 다시 들어요',
          display: '🔊',
          choices: _shuffled(picked),
          answer: target,
          answerText: target,
          speech: target,
          dedupKey: 'ls:$target',
        );

      case KrQuizType.syllableOrder:
        // 뒤 단계에서는 ㅗ행(고노도…)도 섞여 문제 폭이 넓어진다.
        final row = stage >= 6 && _random.nextBool()
            ? krSyllablesO
            : krSyllablesA;
        // 앞 단계에서는 가나다 첫머리 위주로 나온다.
        final maxStart = stage < 3 ? 5 : row.length - 3;
        final start = _random.nextInt(maxStart);
        final shown = row.sublist(start, start + 3);
        final answer = row[start + 3];
        final wrong = _pick(
          [for (final s in row) if (s != answer) s],
          3,
        );
        return KoreanQuestion(
          type: type,
          instruction: '다음에 올 글자는?',
          display: '${shown.join('  ')}  ?',
          choices: _shuffled([answer, ...wrong]),
          answer: answer,
          answerText: answer,
          speech: '${shown.join(', ')}, 다음은?',
          dedupKey: 'so:${row.first}:$start',
        );

      case KrQuizType.listenConsonant:
        final pool = stage >= 5
            ? krConsonantNames
            : krConsonantNames.sublist(0, 7);
        final picked = _pick(pool, 4);
        final target = picked.first;
        return KoreanQuestion(
          type: type,
          instruction: '무슨 자음일까요? 🔊를 눌러 다시 들어요',
          display: '🔊',
          choices: _shuffled([for (final c in picked) c.letter]),
          answer: target.letter,
          answerText: '${target.letter} (${target.name})',
          speech: target.name,
          dedupKey: 'lc:${target.letter}',
        );

      case KrQuizType.combine:
        // 앞 단계는 아이가 익숙한 모음(ㅏㅗㅜㅣ)부터
        final vowelPool = stage >= 5
            ? krVowels
            : [krVowels[0], krVowels[4], krVowels[6], krVowels[9]];
        final consonant =
            krBasicConsonants[_random.nextInt(krBasicConsonants.length)];
        final vowel = vowelPool[_random.nextInt(vowelPool.length)];
        final answer = krCombine(consonant, vowel.letter);
        final consonantName = krConsonantNames
            .firstWhere((c) => c.letter == consonant)
            .name;
        // 오답: 같은 자음+다른 모음, 다른 자음+같은 모음으로 헷갈리게
        final candidates = <String>{
          for (final v in krVowels) krCombine(consonant, v.letter),
          for (final c in krBasicConsonants) krCombine(c, vowel.letter),
        }..remove(answer);
        final wrong = _pick(candidates.toList(), 3);
        return KoreanQuestion(
          type: type,
          instruction: '글자를 합치면 무엇이 될까요?',
          display: '$consonant + ${vowel.letter} = ?',
          choices: _shuffled([answer, ...wrong]),
          answer: answer,
          answerText: answer,
          speech: '$consonantName 하고 ${vowel.sound}를 합치면?',
          dedupKey: 'cb:$consonant${vowel.letter}',
        );

      case KrQuizType.firstConsonant:
        // 기본 자음으로 시작하는 낱말만 (ㄸ, ㄲ 등 쌍자음 제외).
        // 앞 단계는 두 글자 낱말 위주.
        final source = stage >= 5 ? krAllWords : krWords2;
        final pool = [
          for (final w in source)
            if (krBasicConsonants.contains(krFirstConsonant(w.word))) w,
        ];
        final word = pool[_random.nextInt(pool.length)];
        final answer = krFirstConsonant(word.word);
        final wrong = _pick(
          [for (final c in krBasicConsonants) if (c != answer) c],
          3,
        );
        return KoreanQuestion(
          type: type,
          instruction: "'${word.word}'의 첫소리는?",
          display: word.emoji,
          subDisplay: word.word,
          choices: _shuffled([answer, ...wrong]),
          answer: answer,
          answerText: answer,
          speech: '${word.word}의 첫소리를 찾아보세요',
          dedupKey: 'fc:${word.word}',
        );

      case KrQuizType.fillBlank:
        final pool = stage >= 5 ? krAllWords : krWords2;
        final word = pool[_random.nextInt(pool.length)];
        final hideIndex = _random.nextInt(word.word.length);
        final answer = word.word[hideIndex];
        final masked = word.word.replaceRange(hideIndex, hideIndex + 1, '□');
        // 오답 글자: 다른 낱말의 글자 중, 빈칸에 넣어도 말이 안 되는 것만
        final candidates = <String>{
          for (final w in krAllWords) ...w.word.split(''),
        }..removeWhere((c) =>
            c == answer ||
            krAllWords.any((w) =>
                w.word == word.word.replaceRange(hideIndex, hideIndex + 1, c)));
        final wrong = _pick(candidates.toList(), 3);
        return KoreanQuestion(
          type: type,
          instruction: '빈칸에 알맞은 글자는?',
          display: word.emoji,
          subDisplay: masked,
          choices: _shuffled([answer, ...wrong]),
          answer: answer,
          answerText: answer,
          speech: word.word,
          dedupKey: 'fb:${word.word}:$hideIndex',
        );
    }
  }

  KoreanQuestion _pictureToWord(List<KrWord> pool) {
    final picked = _pickWords(pool);
    final target = picked.first;
    return KoreanQuestion(
      type: pool == krWords3 ? KrQuizType.longWord : KrQuizType.pictureToWord,
      instruction: '그림에 맞는 낱말은?',
      display: target.emoji,
      choices: _shuffled([for (final w in picked) w.word]),
      answer: target.word,
      answerText: target.word,
      speech: '그림에 맞는 낱말을 골라 보세요',
      dedupKey: 'ptw:${target.word}',
    );
  }

  /// 목록에서 서로 다른 n개를 고른다. 첫 번째가 출제 대상이 된다.
  List<T> _pick<T>(List<T> pool, int n) {
    final copy = [...pool]..shuffle(_random);
    return copy.take(n).toList();
  }

  /// 낱말 4개를 고른다 (첫 번째가 정답).
  /// 그림이 헷갈리는 같은 [KrWord.group] 낱말은 오답으로 넣지 않는다.
  List<KrWord> _pickWords(List<KrWord> pool) {
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
