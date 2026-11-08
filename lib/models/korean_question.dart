import 'dart:math';

import 'korean_data.dart';
import 'korean_extra.dart';

/// 한글 퀴즈의 문제 유형
enum KrQuizType {
  /// 그림을 보고 알맞은 낱말을 고른다 (통문자 읽기)
  pictureToWord('그림 보고 낱말 찾기', '그림→낱말', '🖼️'),

  /// 낱말을 보고(듣고) 알맞은 그림을 고른다 — 글자를 몰라도 소리로 풀 수 있다
  wordToPicture('낱말 보고 그림 찾기', '낱말→그림', '🔍'),

  /// 모음 소리를 듣고 글자를 찾는다 (아 → ㅏ)
  listenVowel('모음 소리 찾기', '모음 소리', '🎵'),

  /// 음절 소리를 듣고 글자를 찾는다 (가 → 가)
  listenSyllable('글자 소리 찾기', '글자 소리', '👂'),

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
  combine('글자 만들기', '글자 조합', '🧱'),

  /// 글자 타일을 순서대로 눌러 낱말을 조립한다 (쓰기 전 단계)
  wordBuild('낱말 만들기', '낱말 조립', '🏗️'),

  /// 받침이 있는 낱말 읽기 도전
  batchim('받침 낱말', '받침', '💪'),

  /// 예사소리·된소리·거센소리를 듣고 구별한다 (가·까·카)
  doubleConsonant('센소리 구별하기', '가까카', '💥'),

  /// 이중모음 소리를 듣고 글자를 찾는다 (와 → ㅘ)
  complexVowel('어려운 모음 찾기', '어려운 모음', '🌀'),

  /// 받침까지 합쳐 글자를 만든다 (ㄱ + ㅏ + ㅁ = 감)
  batchimCombine('받침 글자 만들기', '받침 조합', '🧲'),

  /// 반대말을 찾는다 (크다 ↔ 작다)
  opposite('반대말 찾기', '반대말', '🔄'),

  /// 그림에 어울리는 흉내말을 찾는다 (🐶 → 멍멍)
  mimetic('흉내말 찾기', '흉내말', '🗯️'),

  /// 어울리는 말을 이어 문장을 완성한다 (사과를 → 먹어요)
  verbMatch('어울리는 말 잇기', '문장 잇기', '🔗'),

  /// 같은 무리가 아닌 것을 찾는다 (사과·포도·바나나·자동차)
  oddOneOut('다른 것 찾기', '분류', '🤔'),

  /// 어른께 쓰는 높임말을 찾는다 (밥 → 진지)
  honorific('높임말 찾기', '높임말', '🙇'),

  /// 수를 세는 말을 찾는다 (강아지 한 □ → 마리)
  counterWord('세는 말 찾기', '세는 말', '🔢'),

  /// 그림과 낱말(낱말과 반대말)을 짝지어 4쌍을 맞춘다
  matchPairs('짝 맞추기', '짝 맞추기', '🃏');

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
    this.tiles = const [],
    this.pairs = const [],
    required this.dedupKey,
  });

  final KrQuizType type;

  /// 짝 맞추기의 (왼쪽, 오른쪽) 짝들. 비어 있지 않으면 짝 맞추기 판으로 푼다.
  final List<(String, String)> pairs;

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

  /// 낱말 만들기용 글자 타일 (낱말 글자 + 함정 글자, 섞여 있음).
  /// 비어 있지 않으면 4지선다 대신 타일 조립 UI로 푼다.
  final List<String> tiles;

  /// 같은 문제가 연달아 나오는지 판정하는 키
  final String dedupKey;
}

/// 유형과 단계(0~9)에 맞는 한글 문제 목록을 만들어 준다.
class KoreanQuestionGenerator {
  KoreanQuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 문항마다 지시문을 조금씩 바꾸기 위한 순번 (generate가 문항 번호로 설정)
  int _seq = 0;

  /// [0]은 기존 문구(테스트 고정점), 나머지는 회전.
  String _rot(List<String> pool) => pool[_seq % pool.length];

  List<KoreanQuestion> generate(KrQuizType type,
      {int stage = 0, int count = 10}) {
    final questions = <KoreanQuestion>[];
    String? previousKey;
    for (var i = 0; i < count; i++) {
      _seq = i;
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
      case KrQuizType.doubleConsonant:
      case KrQuizType.complexVowel:
      case KrQuizType.batchimCombine:
      case KrQuizType.opposite:
      case KrQuizType.mimetic:
      case KrQuizType.verbMatch:
      case KrQuizType.oddOneOut:
      case KrQuizType.honorific:
      case KrQuizType.counterWord:
        return _extra(type, stage);
      case KrQuizType.matchPairs:
        // 앞 단계는 그림 ↔ 낱말, 뒤 단계는 낱말 ↔ 반대말
        final opposite = stage >= 5;
        final List<(String, String)> pairs;
        if (opposite) {
          final picked = _pick(krOpposites, 4);
          pairs = [for (final p in picked) (p.$1, p.$2)];
        } else {
          final picked = _pickWords(krWords2);
          pairs = [for (final w in picked) (w.emoji, w.word)];
        }
        return KoreanQuestion(
          type: type,
          instruction: opposite ? '반대말끼리 짝지어요' : '그림과 낱말을 짝지어요',
          display: '', // 판이 곧 문제 — 카드에는 과제만
          choices: const ['짝 완성'],
          answer: '짝 완성',
          answerText: [
            for (final p in pairs)
              opposite ? '${p.$1}↔${p.$2}' : '${p.$1} ${p.$2}'
          ].join('  '),
          speech: '',
          pairs: pairs,
          dedupKey: 'kmp:${pairs.map((p) => p.$2).join(',')}',
        );
      case KrQuizType.pictureToWord:
        // 단계가 오를수록 낱말 풀이 넓어진다.
        return _pictureToWord(
            krWords2.take(20 + stage * 4).toList(), KrQuizType.pictureToWord);

      case KrQuizType.longWord:
        return _pictureToWord(krWords3, KrQuizType.longWord);

      case KrQuizType.batchim:
        // 받침이 있는 낱말만 골라 읽기 연습을 한다.
        final source = stage >= 5 ? krAllWords : krWords2;
        final pool = [
          for (final w in source)
            if (w.word.codeUnits
                .any((c) => c >= 0xAC00 && (c - 0xAC00) % 28 != 0))
              w,
        ];
        return _pictureToWord(pool, KrQuizType.batchim);

      case KrQuizType.wordBuild:
        final pool = stage >= 5 ? krAllWords : krWords2;
        final word = pool[_random.nextInt(pool.length)];
        final syllables = word.word.split('');
        // 함정 글자 2개: 낱말에 없는 글자로 고른다.
        final decoys = <String>{
          for (final w in krAllWords) ...w.word.split(''),
        }..removeWhere(syllables.contains);
        final decoyList = decoys.toList()..shuffle(_random);
        final tiles = [...syllables, ...decoyList.take(2)]..shuffle(_random);
        return KoreanQuestion(
          type: type,
          instruction: '글자를 순서대로 눌러 낱말을 만들어요',
          display: word.emoji,
          choices: tiles,
          answer: word.word,
          answerText: word.word,
          speech: word.word,
          tiles: tiles,
          dedupKey: 'wb:${word.word}',
        );

      case KrQuizType.wordToPicture:
        // 뒤 단계에서는 긴 낱말도 섞인다.
        final pool = stage >= 5 ? krAllWords : krWords2;
        final picked = _pickWords(pool);
        final target = picked.first;
        return KoreanQuestion(
          type: type,
          instruction: _rot(const ['알맞은 그림을 찾아요', '어떤 그림일까요?', '그림을 골라 볼까요?']),
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
          instruction: _rot(const ['무슨 소리일까요?', '소리를 잘 들어 보세요', '귀 기울여 볼까요?']),
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
          instruction: _rot(const ['무슨 소리일까요?', '소리를 잘 들어 보세요', '귀 기울여 볼까요?']),
          display: '🔊',
          choices: _shuffled(picked),
          answer: target,
          answerText: target,
          speech: target,
          dedupKey: 'ls:$target',
        );

      case KrQuizType.syllableOrder:
        // 뒤 단계에서는 ㅗ행(고노도…)도 섞여 문제 폭이 넓어진다.
        final row =
            stage >= 6 && _random.nextBool() ? krSyllablesO : krSyllablesA;
        // 앞 단계에서는 가나다 첫머리 위주로 나온다.
        final maxStart = stage < 3 ? 5 : row.length - 3;
        final start = _random.nextInt(maxStart);
        final shown = row.sublist(start, start + 3);
        final answer = row[start + 3];
        final wrong = _pick(
          [
            for (final s in row)
              if (s != answer) s
          ],
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
        final pool =
            stage >= 5 ? krConsonantNames : krConsonantNames.sublist(0, 7);
        final picked = _pick(pool, 4);
        final target = picked.first;
        return KoreanQuestion(
          type: type,
          instruction: '무슨 자음일까요?',
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
        final consonantName =
            krConsonantNames.firstWhere((c) => c.letter == consonant).name;
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
          [
            for (final c in krBasicConsonants)
              if (c != answer) c
          ],
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

  KoreanQuestion _pictureToWord(List<KrWord> pool, KrQuizType type) {
    final picked = _pickWords(pool);
    final target = picked.first;
    return KoreanQuestion(
      type: type,
      instruction:
          _rot(const ['그림에 맞는 낱말은?', '그림의 이름은 무엇일까요?', '이 그림, 뭐라고 부를까?']),
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

  KoreanQuestion _extra(KrQuizType type, int stage) {
    switch (type) {
      case KrQuizType.doubleConsonant:
        // 앞 단계는 ㅏ 모음만, 뒤 단계는 ㅗ·ㅜ·ㅣ도
        final vowels = stage < 5 ? ['ㅏ'] : ['ㅏ', 'ㅗ', 'ㅜ', 'ㅣ'];
        final triple =
            krConsonantTriples[_random.nextInt(krConsonantTriples.length)];
        final vowel = vowels[_random.nextInt(vowels.length)];
        final answerCho = triple[_random.nextInt(triple.length)];
        final answer = krCompose(answerCho, vowel);
        // 같은 무리 셋 + 다른 무리 하나 (예사·된·거센 소리를 듣고 가르는 게 핵심)
        final others = [
          for (final t in krConsonantTriples)
            if (t != triple) t[0]
        ]..shuffle(_random);
        final choices = [
          for (final c in triple) krCompose(c, vowel),
          // 같은 무리(가·까·카 / 사·싸)가 3개가 안 되면 다른 무리 소리로 채운다
          for (final c in others.take(4 - triple.length)) krCompose(c, vowel),
        ];
        return KoreanQuestion(
          type: type,
          instruction: _rot(const ['어떤 소리일까요?', '잘 듣고 글자를 찾아요']),
          display: '🔊',
          choices: _shuffled(choices),
          answer: answer,
          answerText: answer,
          speech: answer,
          dedupKey: 'dc:$answer',
        );

      case KrQuizType.complexVowel:
        final pool = stage < 5
            ? krComplexVowels
                .where((v) => const {'ㅐ', 'ㅘ', 'ㅝ', 'ㅟ', 'ㅢ'}
                    .contains(v.letter)) // ㅚ·ㅙ·ㅞ는 뒤 단계
                .toList()
            : krComplexVowels;
        final target = pool[_random.nextInt(pool.length)];
        // 소리가 같은 모음(ㅐ·ㅔ)은 함께 내지 않는다 — 들어서는 가를 수 없다
        final usedGroups = {target.group};
        final wrong = <String>[];
        for (final v in [...krComplexVowels]..shuffle(_random)) {
          if (wrong.length == 3) break;
          if (usedGroups.add(v.group)) wrong.add(v.letter);
        }
        return KoreanQuestion(
          type: type,
          instruction: _rot(const ['무슨 모음 소리일까요?', '소리를 듣고 모음을 찾아요']),
          display: '🔊',
          choices: _shuffled([target.letter, ...wrong]),
          answer: target.letter,
          answerText: '${target.letter} (${target.sound})',
          speech: target.sound,
          dedupKey: 'cv:${target.letter}',
        );

      case KrQuizType.batchimCombine:
        final batchims =
            stage < 5 ? krEasyBatchim : [...krEasyBatchim, ...krMoreBatchim];
        final vowels =
            stage < 5 ? ['ㅏ', 'ㅗ', 'ㅜ', 'ㅣ'] : ['ㅏ', 'ㅓ', 'ㅗ', 'ㅜ', 'ㅡ', 'ㅣ'];
        final cho =
            krBasicConsonants[_random.nextInt(krBasicConsonants.length)];
        final jung = vowels[_random.nextInt(vowels.length)];
        final jong = batchims[_random.nextInt(batchims.length)];
        final answer = krCompose(cho, jung, jong);
        // 오답: 받침만 다른 글자, 받침 없는 글자 — 받침 소리에 귀 기울이게
        final candidates = <String>{
          krCompose(cho, jung),
          for (final b in [...krEasyBatchim, ...krMoreBatchim])
            if (b != jong) krCompose(cho, jung, b),
          for (final v in vowels)
            if (v != jung) krCompose(cho, v, jong),
        }..remove(answer);
        final wrong = _pick(candidates.toList(), 3);
        return KoreanQuestion(
          type: type,
          instruction: '글자를 합치면 무엇이 될까요?',
          display: '$cho + $jung + $jong = ?',
          choices: _shuffled([answer, ...wrong]),
          answer: answer,
          answerText: answer,
          // 정답 글자를 먼저 읽으면 답을 알려 주는 셈 — 자모 이름으로 읽는다
          speech:
              '${_jamoName(cho)}, ${_vowelSound(jung)}, 받침 ${_jamoName(jong)}을 합치면?',
          dedupKey: 'bc:$answer',
        );

      case KrQuizType.opposite:
        final oppPool = _grow(krOpposites, stage);
        final pair = oppPool[_random.nextInt(oppPool.length)];
        final flip = _random.nextBool();
        final shown = flip ? pair.$2 : pair.$1;
        final answer = flip ? pair.$1 : pair.$2;
        final wrong = <String>[];
        for (final p in [...krOpposites]..shuffle(_random)) {
          if (wrong.length == 3) break;
          if (p == pair) continue;
          // 품사가 비슷한 말끼리(…다 / 이름씨) 보기를 맞춘다
          final w = _random.nextBool() ? p.$1 : p.$2;
          if (w.endsWith('다') == answer.endsWith('다')) wrong.add(w);
        }
        return KoreanQuestion(
          type: type,
          instruction: _rot(const ['반대말은 무엇일까요?', '뜻이 반대인 말을 찾아요']),
          display: shown,
          subDisplay: pair.$3,
          choices: _shuffled([answer, ...wrong]),
          answer: answer,
          answerText: '$shown의 반대말은 $answer',
          speech: '$shown의 반대말은?',
          dedupKey: 'op:$shown',
        );

      case KrQuizType.mimetic:
        final mimPool = _grow(krMimetics, stage);
        final target = mimPool[_random.nextInt(mimPool.length)];
        // 소리 흉내말끼리, 움직임 흉내말끼리만 보기로 낸다
        final same = [
          for (final m in krMimetics)
            if (m.$4 == target.$4 && m.$2 != target.$2) m.$2
        ]..shuffle(_random);
        final ask = target.$4
            ? '어떤 소리를 낼까요?'
            : target.$3 == '별'
                ? '어떻게 빛날까요?'
                : target.$3 == '비'
                    ? '어떻게 내릴까요?'
                    : '어떻게 움직일까요?';
        return KoreanQuestion(
          type: type,
          instruction: target.$4 ? '어울리는 소리 흉내말은?' : '어울리는 모양 흉내말은?',
          display: target.$1,
          choices: _shuffled([target.$2, ...same.take(3)]),
          answer: target.$2,
          answerText: '${target.$3}: ${target.$2}',
          speech: '${target.$3}${_josaKr(target.$3, '은', '는')} $ask',
          dedupKey: 'mm:${target.$2}',
        );

      case KrQuizType.verbMatch:
        final verbPool = _grow(krVerbPairs, stage);
        final target = verbPool[_random.nextInt(verbPool.length)];
        // 그 대상에 함께 어울리는 동사(사과를 씻어요)는 오답에서 뺀다
        final wrongVerbs = [
          for (final v in krVerbPairs)
            if (v.$3 != target.$3 && !target.$4.contains(v.$3)) v.$3
        ]..shuffle(_random);
        return KoreanQuestion(
          type: type,
          instruction: _rot(const ['어울리는 말을 골라요', '문장을 완성해요']),
          display: target.$1,
          subDisplay: '${target.$2} □',
          choices: _shuffled([target.$3, ...wrongVerbs.take(3)]),
          answer: target.$3,
          answerText: '${target.$2} ${target.$3}',
          speech: '${target.$2} 어떻게 할까요?',
          dedupKey: 'vm:${target.$2}',
        );

      case KrQuizType.honorific:
        final honorPool = _grow(krHonorifics, stage);
        final target = honorPool[_random.nextInt(honorPool.length)];
        // 오답도 높임말 — 낱말끼리(밥·집)·'…다'끼리 모양을 맞춘다
        final wrongHonor = [
          for (final h in krHonorifics)
            if (h != target && h.$1.endsWith('다') == target.$1.endsWith('다'))
              h.$2
        ]..shuffle(_random);
        return KoreanQuestion(
          type: type,
          instruction: _rot(const ['할머니께는 뭐라고 할까요?', '어른께 쓰는 높임말은?']),
          display: target.$1,
          subDisplay: '👵',
          choices: _shuffled([target.$2, ...wrongHonor.take(3)]),
          answer: target.$2,
          answerText: '${target.$1}의 높임말은 ${target.$2}',
          speech: '${target.$1}${_josaKr(target.$1, '을', '를')} 어른께는 뭐라고 할까요?',
          dedupKey: 'hn:${target.$1}',
        );

      case KrQuizType.counterWord:
        final counterPool = _grow(krCounters, stage);
        final target = counterPool[_random.nextInt(counterPool.length)];
        final wrongCounters = [
          for (final c in krCounters)
            if (c.$3 != target.$3) c.$3
        ]..shuffle(_random);
        return KoreanQuestion(
          type: type,
          instruction: _rot(const ['알맞은 세는 말은?', '어떻게 셀까요?']),
          display: target.$1,
          subDisplay: '${target.$2} 한 □',
          choices: _shuffled([target.$3, ...wrongCounters.take(3)]),
          answer: target.$3,
          answerText: '${target.$2} 한 ${target.$3}',
          speech: '${target.$2} 하나를 어떻게 셀까요?',
          dedupKey: 'cw:${target.$2}',
        );

      case _:
        // oddOneOut: 앞 단계는 확실히 다른 무리끼리(과일·채소는 함께 안 냄)
        final names = krCategories.keys.toList()..shuffle(_random);
        final main = names.first;
        final close = {'과일': '채소', '채소': '과일'};
        final odd =
            names.skip(1).firstWhere((n) => stage >= 5 || close[main] != n);
        final three = _pick(krCategories[main]!, 3);
        final oddItem = _pick(krCategories[odd]!, 1).first;
        String label((String, String) x) => '${x.$1} ${x.$2}';
        return KoreanQuestion(
          type: type,
          instruction: _rot(const ['하나만 다른 것은?', '같은 무리가 아닌 것을 찾아요']),
          display: '🤔',
          choices: _shuffled([label(oddItem), for (final x in three) label(x)]),
          answer: label(oddItem),
          answerText: '${oddItem.$2} (나머지는 $main)',
          speech: '하나만 다른 것은 무엇일까요?',
          dedupKey: 'oo:${oddItem.$2}',
        );
    }
  }

  /// 단계가 오를수록 뒤쪽 말까지 넓힌다 (0단계는 앞 8개)
  List<T> _grow<T>(List<T> list, int stage) =>
      list.take((8 + stage * 2).clamp(4, list.length)).toList();

  /// 자음 이름 (ㄱ → 기역)
  static String _jamoName(String c) =>
      krConsonantNames.firstWhere((x) => x.letter == c).name;

  /// 모음 소리 (ㅏ → 아)
  static String _vowelSound(String v) =>
      krVowels.firstWhere((x) => x.letter == v).sound;

  /// 받침에 맞는 조사 (사과는 / 거북이는)
  static String _josaKr(String word, String withBatchim, String without) {
    final code = word.codeUnitAt(word.length - 1);
    if (code < 0xAC00 || code > 0xD7A3) return without;
    return (code - 0xAC00) % 28 != 0 ? withBatchim : without;
  }

  List<String> _shuffled(List<String> items) => [...items]..shuffle(_random);
}
