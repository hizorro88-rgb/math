import 'dart:math';

import 'english_data.dart';
import 'english_phonics.dart';
import 'english_vocab.dart';

/// 영어 퀴즈의 문제 유형
enum EnQuizType {
  /// 낱말을 보고(듣고) 알맞은 그림을 고른다 — 소리(en-US)가 먼저
  wordToPicture('낱말 듣고 그림 찾기', '듣고 그림', '🔍'),

  /// 그림을 보고 알맞은 영어 낱말을 고른다
  pictureToWord('그림 보고 낱말 찾기', '그림→낱말', '🖼️'),

  /// 알파벳 소리를 듣고 글자를 찾는다 (에이 → A)
  listenLetter('알파벳 소리 찾기', '알파벳 소리', '👂'),

  /// 대문자·소문자 짝을 맞춘다 (A ↔ a)
  caseMatch('대문자 소문자 짝', '대소문자', '🅰️'),

  /// 알파벳 순서에서 다음 글자를 찾는다 (A B C ?)
  alphabetOrder('ABC 순서', 'ABC', '🐾'),

  /// 낱말의 첫 글자를 찾는다 (apple → A)
  firstLetter('첫 글자 찾기', '첫 글자', '🎯'),

  /// 글자 타일을 순서대로 눌러 낱말을 조립한다 (C-A-T)
  wordBuild('낱말 만들기', '낱말 조립', '🏗️'),

  /// 긴 낱말 읽기 도전
  longWord('긴 낱말 도전', '긴 낱말', '🚀'),

  // ── 파닉스 (여기부터 뒤에 붙인다 — 통계가 enum 순서로 저장된다) ──

  /// 글자를 보고 그 소리로 시작하는 그림을 찾는다 (B → 🐻)
  letterSound('글자 소리로 시작해요', '첫소리', '🔠'),

  /// 그림 낱말의 가운데 짧은 모음을 찾는다 (🐱 C _ T → A)
  shortVowel('가운데 소리 찾기', '가운데 모음', '🎈'),

  /// 소리 없이 낱말을 읽고 그림을 찾는다 (PIG → 🐷) — 스스로 읽기
  decode('읽고 그림 찾기', '혼자 읽기', '📖'),

  /// 끝소리가 같은 낱말을 찾는다 (CAT → HAT)
  rhyme('끝소리 짝 찾기', '라임', '🎵'),

  /// 두 글자가 내는 첫소리를 찾는다 (🐑 _ _ EEP → SH)
  cluster('두 글자 소리', 'sh·ch·tr', '👯'),

  // ── 단어 퀴즈 ──

  /// 주제 낱말(색깔·숫자·몸…) — 듣고 그림 / 그림 보고 낱말 / 낱말 뜻을 섞어 낸다
  themeWord('주제 낱말', '주제', '🎨'),

  /// 영어 낱말을 보고(듣고) 한국어 뜻을 고른다 (APPLE → 사과)
  meaningPick('뜻 고르기', '뜻', '🤔'),

  /// 한국어 뜻을 듣고 영어 낱말을 고른다 (사과 → APPLE)
  englishPick('영어로 고르기', '영어로', '🔤'),

  /// 빠진 글자를 채운다 (🍎 AP_LE → P)
  missingLetter('빠진 글자 찾기', '빠진 글자', '🔍'),

  /// 자주 쓰는 낱말(사이트 워드)을 듣고 찾는다 (the·is·see)
  sightWord('자주 쓰는 낱말', '사이트 워드', '👀'),

  /// 그림(낱말)과 낱말(뜻)을 짝지어 4쌍을 맞춘다
  matchPairs('짝 맞추기', '짝 맞추기', '🃏');

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
    this.revealSpeech = '',
    this.revealLang = 'en-US',
    this.pairs = const [],
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

  /// 답을 고른 뒤 읽어 줄 말 (영어). 파닉스에서 글자와 낱말을 이어 들려준다.
  final String revealSpeech;

  /// [revealSpeech]를 읽을 언어 (뜻 문제는 한국어 뜻을 읽는다)
  final String revealLang;

  /// 짝 맞추기의 (왼쪽, 오른쪽) 짝들. 비어 있지 않으면 짝 맞추기 판으로 푼다.
  final List<(String, String)> pairs;

  /// 소리 없이 스스로 읽는(떠올리는) 문제인지 — 처음엔 읽어 주지 않고
  /// 답한 뒤에 [revealSpeech]로 들려준다 (혼자 읽기, 그림 보고 영어 떠올리기)
  bool get readAlone => speech.isEmpty;

  final String dedupKey;
}

/// 유형과 단계(0~9)에 맞는 영어 문제 목록을 만들어 준다.
class EnglishQuestionGenerator {
  EnglishQuestionGenerator({Random? random}) : _random = random ?? Random();

  final Random _random;

  /// 문항마다 지시문을 조금씩 바꾸기 위한 순번 (generate가 문항 번호로 설정)
  int _seq = 0;

  /// 주제 낱말 묶음의 주제 (null이면 모든 주제)
  String? _theme;

  /// 소리를 들을 수 있는지 — 없으면 주제 낱말에서 듣기 문제를 빼고 낸다
  bool _listening = true;

  /// 이번 판에 정답으로 나온 낱말 (한 판에 같은 낱말이 거듭 나오지 않게)
  final _usedVocab = <String>{};

  /// [0]은 기존 문구(테스트 고정점), 나머지는 회전.
  String _rot(List<String> pool) => pool[_seq % pool.length];

  List<EnglishQuestion> generate(EnQuizType type,
      {int stage = 0, int count = 10, String? theme, bool listening = true}) {
    _theme = theme;
    _listening = listening;
    _usedVocab.clear();
    final questions = <EnglishQuestion>[];
    String? previousKey;
    for (var i = 0; i < count; i++) {
      _seq = i;
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
      case EnQuizType.letterSound:
      case EnQuizType.shortVowel:
      case EnQuizType.decode:
      case EnQuizType.rhyme:
      case EnQuizType.cluster:
        return _phonics(type, stage);
      case EnQuizType.themeWord:
      case EnQuizType.meaningPick:
      case EnQuizType.englishPick:
      case EnQuizType.missingLetter:
      case EnQuizType.sightWord:
        return _vocab(type, stage);
      case EnQuizType.matchPairs:
        // 앞 단계는 그림 ↔ 영어, 뒤 단계는 영어 ↔ 뜻
        final picked = _pickVocab(_vocabPool(stage));
        final meaning = stage >= 5;
        return EnglishQuestion(
          type: type,
          instruction: meaning ? '영어와 뜻을 짝지어요' : '그림과 낱말을 짝지어요',
          display: '', // 판이 곧 문제 — 카드에는 과제만
          choices: const ['짝 완성'],
          answer: '짝 완성',
          answerText: [
            for (final v in picked)
              meaning ? '${v.shown}=${v.ko}' : '${v.emoji} ${v.shown}'
          ].join('  '),
          speech: '',
          pairs: [
            for (final v in picked)
              meaning ? (v.shown, v.ko) : (v.emoji, v.shown)
          ],
          dedupKey: 'mp4:${picked.map((v) => v.word).join(',')}',
        );

      case EnQuizType.wordToPicture:
        final pool = stage >= 5 ? enAllWords : enWordsShort;
        final picked = _pickWords(pool);
        final target = picked.first;
        return EnglishQuestion(
          type: type,
          instruction: _rot(
              const ['잘 듣고 알맞은 그림을 찾아요', '소리를 듣고 그림을 골라요', '귀 기울여 듣고 찾아보세요']),
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
          instruction:
              _rot(const ['무슨 알파벳일까요?', '어떤 알파벳 소리일까요?', '소리를 듣고 찾아보세요']),
          display: '🔊',
          choices: _shuffled(picked),
          answer: target,
          answerText: target,
          speech: target,
          dedupKey: 'll:$target',
        );

      case EnQuizType.caseMatch:
        final pool = stage >= 5 ? enAlphabet : enAlphabet.sublist(0, 13);
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
          [
            for (final c in enAlphabet)
              if (c != answer) c
          ],
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
          [
            for (final c in enAlphabet)
              if (c != answer) c
          ],
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
          for (final c in enAlphabet)
            if (!letters.contains(c)) c,
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

  EnglishQuestion _phonics(EnQuizType type, int stage) {
    switch (type) {
      case EnQuizType.letterSound:
        final letters = phonicsLetterWords.keys
            .take(
                stage >= 5 ? phonicsLetterWords.length : phonicsEasyLetterCount)
            .toList();
        final letter = letters[_random.nextInt(letters.length)];
        final starts = phonicsLetterWords[letter]!;
        final target = starts[_random.nextInt(starts.length)];
        // 오답은 소리가 다른 글자의 그림에서 (C 문제에 🔑 key가 나오면 둘 다 맞다)
        final others = [
          for (final e in phonicsLetterWords.entries)
            if (phonicsSoundGroup(e.key) != phonicsSoundGroup(letter))
              ...e.value
        ]..shuffle(_random);
        final usedEmoji = {target.emoji};
        final wrong = <EnWord>[];
        for (final w in others) {
          if (wrong.length == 3) break;
          if (usedEmoji.add(w.emoji)) wrong.add(w);
        }
        final picked = [target, ...wrong];
        return EnglishQuestion(
          type: type,
          instruction: _rot([
            "'$letter' 소리로 시작하는 그림은?",
            "'$letter'로 시작하는 낱말을 찾아요",
          ]),
          display: '$letter ${letter.toLowerCase()}',
          choices: _shuffled([for (final w in picked) w.emoji]),
          answer: target.emoji,
          answerText: target.shown,
          speech: letter,
          revealSpeech: '$letter. ${target.word}',
          emojiChoices: true,
          dedupKey: 'ls:$letter',
        );

      case EnQuizType.shortVowel:
        final word = phonicsCvc[_random.nextInt(phonicsCvc.length)];
        final letters = word.shown.split('');
        final vi = letters.indexWhere(phonicsVowels.contains);
        final vowel = letters[vi];
        final blanked = [
          for (var i = 0; i < letters.length; i++) i == vi ? '_' : letters[i]
        ].join(' ');
        final wrong = [
          for (final v in phonicsVowels)
            if (v != vowel) v
        ]..shuffle(_random);
        return EnglishQuestion(
          type: type,
          instruction: _rot(const ['가운데 들어갈 소리는?', '빈칸에 알맞은 글자는?']),
          display: word.emoji,
          subDisplay: blanked,
          choices: _shuffled([vowel, ...wrong.take(3)]),
          answer: vowel,
          answerText: word.shown,
          speech: word.word,
          revealSpeech: word.word,
          dedupKey: 'sv:${word.word}',
        );

      case EnQuizType.decode:
        // 앞 단계는 세 글자 낱말, 뒤 단계는 라임 모둠의 긴 낱말까지
        final pool = stage >= 5
            ? [
                ...phonicsCvc,
                for (final f in phonicsRhymes.values) ...f,
              ]
            : phonicsCvc;
        final picked = _pickWords(_uniqueEmoji(pool));
        final target = picked.first;
        return EnglishQuestion(
          type: type,
          instruction: _rot(const ['소리 내어 읽고 그림을 찾아요', '혼자 읽어 볼까요?']),
          display: target.shown,
          choices: _shuffled([for (final w in picked) w.emoji]),
          answer: target.emoji,
          answerText: target.shown,
          speech: '',
          revealSpeech: target.word,
          emojiChoices: true,
          dedupKey: 'dc:${target.word}',
        );

      case EnQuizType.rhyme:
        final families = phonicsRhymes.entries
            .take(stage >= 5 ? phonicsRhymes.length : phonicsEasyRhymeCount)
            .toList();
        final family = families[_random.nextInt(families.length)];
        final pair = [...family.value]..shuffle(_random);
        final target = pair[0];
        final answer = pair[1];
        // 모음이 같은 모둠(-et·-ed, -in·-ing)은 거의 같게 들려서 오답으로 안 낸다
        final others = [
          for (final f in families)
            if (f.key[1] != family.key[1]) ...f.value
        ]..shuffle(_random);
        final usedEmoji = {target.emoji, answer.emoji};
        final wrong = <EnWord>[];
        for (final w in others) {
          if (wrong.length == 3) break;
          if (usedEmoji.add(w.emoji)) wrong.add(w);
        }
        String label(EnWord w) => '${w.emoji} ${w.shown}';
        return EnglishQuestion(
          type: type,
          instruction: _rot(const ['끝소리가 같은 낱말은?', '소리가 닮은 낱말을 찾아요']),
          display: target.emoji,
          subDisplay: target.shown,
          choices: _shuffled([label(answer), for (final w in wrong) label(w)]),
          answer: label(answer),
          answerText: '${target.shown} · ${answer.shown}',
          speech: target.word,
          revealSpeech: '${target.word}, ${answer.word}',
          dedupKey: 'rh:${target.word}',
        );

      case _:
        // cluster: 앞 단계는 sh·ch·th·wh, 뒤 단계는 fr·tr 같은 자음 짝까지
        final pool = stage >= 5
            ? [...phonicsDigraphs, ...phonicsBlends]
            : phonicsDigraphs;
        final target = pool[_random.nextInt(pool.length)];
        final sounds = {for (final c in pool) c.sound}.toList()
          ..remove(target.sound)
          ..shuffle(_random);
        return EnglishQuestion(
          type: type,
          instruction: _rot(const ['처음 두 글자는 무엇일까요?', '빈칸에 들어갈 두 글자는?']),
          display: target.emoji,
          subDisplay: target.blanked,
          choices: _shuffled([target.sound, ...sounds.take(3)]),
          answer: target.sound,
          answerText: target.word.toUpperCase(),
          speech: target.word,
          revealSpeech: target.word,
          dedupKey: 'cl:${target.word}',
        );
    }
  }

  EnglishQuestion _vocab(EnQuizType type, int stage) {
    switch (type) {
      case EnQuizType.themeWord:
        final themes = _theme?.split(',');
        final pool = _growPool([
          for (final v in enVocab)
            if (themes?.contains(v.theme) ?? true) v
        ], stage);
        // 문항마다 모양을 바꾼다: 듣고 그림 → 그림 보고 낱말 → 낱말 뜻
        final form = !_listening
            ? (stage < 3 ? 1 : 1 + _seq % 2)
            : stage < 3
                ? _seq % 2
                : _seq % 3;
        return switch (form) {
          0 => _vocabListen(type, pool),
          1 => _vocabPicture(type, pool),
          _ => _vocabMeaning(type, pool),
        };

      case EnQuizType.meaningPick:
        return _vocabMeaning(type, _vocabPool(stage));

      case EnQuizType.englishPick:
        final picked = _pickVocab(_vocabPool(stage));
        final target = picked.first;
        return EnglishQuestion(
          type: type,
          instruction: _rot(const ['영어로 무엇일까요?', '알맞은 영어 낱말을 골라요']),
          display: target.ko,
          subDisplay: stage < 5 ? target.emoji : '',
          choices: _shuffled([for (final v in picked) v.shown]),
          answer: target.shown,
          answerText: '${target.ko} = ${target.shown}',
          speech: target.ko,
          speechLang: 'ko-KR',
          revealSpeech: target.word,
          dedupKey: 'ep:${target.word}',
        );

      case EnQuizType.missingLetter:
        final pool = [
          for (final v in _vocabPool(stage))
            if (v.word.length >= (stage < 5 ? 3 : 5) &&
                v.word.length <= (stage < 5 ? 5 : 10) &&
                v.theme != 'number')
              v
        ];
        final target = pool[_random.nextInt(pool.length)];
        final letters = target.shown.split('');
        final at = _random.nextInt(letters.length);
        final answer = letters[at];
        final blanked = [
          for (var i = 0; i < letters.length; i++) i == at ? '_' : letters[i]
        ].join(' ');
        // 오답은 같은 종류(모음↔모음, 자음↔자음)에서, 다른 낱말이 되는 글자는 빼고
        final isVowel = 'AEIOU'.contains(answer);
        final known = {for (final v in enVocab) v.shown};
        final wrong = [
          for (final c in enAlphabet)
            if (c != answer &&
                'AEIOU'.contains(c) == isVowel &&
                !known
                    .contains(blanked.replaceAll(' ', '').replaceFirst('_', c)))
              c
        ]..shuffle(_random);
        // 모음은 다섯뿐이라 모자라면 자음으로 채운다
        for (final c in [...enAlphabet]..shuffle(_random)) {
          if (wrong.length >= 3) break;
          if (c != answer && !wrong.contains(c)) wrong.add(c);
        }
        return EnglishQuestion(
          type: type,
          instruction: _rot(const ['빠진 글자는 무엇일까요?', '빈칸에 들어갈 글자는?']),
          display: target.emoji,
          subDisplay: blanked,
          choices: _shuffled([answer, ...wrong.take(3)]),
          answer: answer,
          answerText: target.shown,
          speech: target.word,
          revealSpeech: target.word,
          dedupKey: 'ml:${target.word}',
        );

      case _:
        // sightWord: 소리를 듣고 모양이 비슷한 낱말 중에서 고른다
        final pool = stage < 5
            ? enSightWords.take(enSightEasyCount).toList()
            : enSightWords;
        final target = pool[_random.nextInt(pool.length)];
        // 첫 글자나 길이가 비슷한 낱말을 오답으로 (헷갈리는 모양끼리 구별하기)
        // 첫 글자가 같은 낱말 → 길이가 같은 낱말 → 나머지 순서로 오답을 채운다
        // (대문자 'I'는 오답으로 내면 모양만 보고 지울 수 있어 뺀다)
        final candidates = [
          for (final w in enSightWords)
            if (w != target && w != 'I') w
        ]..shuffle(_random);
        int rank(String w) => w[0].toLowerCase() == target[0].toLowerCase()
            ? 0
            : w.length == target.length
                ? 1
                : 2;
        candidates.sort((a, b) => rank(a).compareTo(rank(b)));
        final wrong = candidates.take(3).toList();
        return EnglishQuestion(
          type: type,
          instruction: _rot(const ['들리는 낱말을 찾아요', '어떤 낱말일까요?']),
          display: '🔊',
          choices: _shuffled([target, ...wrong]),
          answer: target,
          answerText: target,
          speech: target,
          dedupKey: 'sw:$target',
        );
    }
  }

  /// 단어 퀴즈 범위: 앞 단계는 그림이 쉬운 주제, 뒤 단계는 전부
  List<EnVocab> _vocabPool(int stage) => _growPool(
      stage < 5
          ? [
              for (final v in enVocab)
                if (const {
                  'animal',
                  'food',
                  'thing',
                  'vehicle',
                  'color',
                  'body'
                }.contains(v.theme))
                  v
            ]
          : enVocab,
      stage);

  /// 단계가 오를수록 주제마다 뒤쪽(조금 어려운) 낱말까지 넓힌다.
  /// 주제 안의 낱말은 쉬운 것부터 적혀 있다 — 0단계는 주제마다 앞 5개.
  List<EnVocab> _growPool(List<EnVocab> pool, int stage) {
    final perTheme = 5 + stage * 2;
    final seen = <String, int>{};
    return [
      for (final v in pool)
        if ((seen[v.theme] = (seen[v.theme] ?? 0) + 1) <= perTheme) v
    ];
  }

  /// 낱말 4개 (첫 번째가 정답). 뜻·그림이 겹치는 낱말은 같이 안 나온다.
  List<EnVocab> _pickVocab(List<EnVocab> pool) {
    final fresh = [
      for (final v in pool)
        if (!_usedVocab.contains(v.word)) v
    ];
    final from = fresh.isEmpty ? pool : fresh;
    final target = from[_random.nextInt(from.length)];
    _usedVocab.add(target.word);
    final kos = {target.ko};
    final emojis = {target.emoji};
    final groups = {if (target.group != null) target.group};
    final others = [...pool]..shuffle(_random);
    final picked = [target];
    for (final v in others) {
      if (picked.length == 4) break;
      if (v.word == target.word) continue;
      if (v.group != null && groups.contains(v.group)) continue;
      if (kos.contains(v.ko) || emojis.contains(v.emoji)) continue;
      kos.add(v.ko);
      emojis.add(v.emoji);
      if (v.group != null) groups.add(v.group);
      picked.add(v);
    }
    return picked;
  }

  EnglishQuestion _vocabListen(EnQuizType type, List<EnVocab> pool) {
    final picked = _pickVocab(pool);
    final target = picked.first;
    return EnglishQuestion(
      type: type,
      instruction: _rot(const ['잘 듣고 알맞은 그림을 찾아요', '소리를 듣고 그림을 골라요']),
      display: '🔊',
      choices: _shuffled([for (final v in picked) v.emoji]),
      answer: target.emoji,
      answerText: '${target.shown} (${target.ko})',
      speech: target.word,
      revealSpeech: target.word,
      emojiChoices: true,
      dedupKey: 'tw:${target.word}',
    );
  }

  EnglishQuestion _vocabPicture(EnQuizType type, List<EnVocab> pool) {
    final picked = _pickVocab(pool);
    final target = picked.first;
    return EnglishQuestion(
      type: type,
      instruction: _rot(const ['그림에 맞는 낱말은?', '이 그림, 영어로 뭘까?']),
      display: target.emoji,
      choices: _shuffled([for (final v in picked) v.shown]),
      answer: target.shown,
      answerText: '${target.shown} (${target.ko})',
      // 소리를 먼저 들려주면 떠올리기가 아니라 소리 맞히기가 된다
      speech: '',
      revealSpeech: target.word,
      dedupKey: 'tw:${target.word}',
    );
  }

  EnglishQuestion _vocabMeaning(EnQuizType type, List<EnVocab> pool) {
    final picked = _pickVocab(pool);
    final target = picked.first;
    return EnglishQuestion(
      type: type,
      instruction: _rot(const ['무슨 뜻일까요?', '알맞은 뜻을 골라요']),
      display: target.shown,
      choices: _shuffled([for (final v in picked) v.ko]),
      answer: target.ko,
      answerText: '${target.shown} = ${target.ko}',
      speech: target.word,
      revealSpeech: target.ko,
      revealLang: 'ko-KR',
      dedupKey: 'mp:${target.word}',
    );
  }

  /// 같은 그림이 두 번 나오지 않게 (보기 그림이 겹치면 고를 수 없다)
  List<EnWord> _uniqueEmoji(List<EnWord> pool) {
    final seen = <String>{};
    final words = <String>{};
    return [
      for (final w in pool)
        if (words.add(w.word) && seen.add(w.emoji)) w
    ];
  }

  EnglishQuestion _pictureToWord(List<EnWord> pool, EnQuizType type) {
    final picked = _pickWords(pool);
    final target = picked.first;
    return EnglishQuestion(
      type: type,
      instruction:
          _rot(const ['그림에 맞는 낱말은?', '그림의 이름은 무엇일까요?', '이 그림, 뭐라고 부를까?']),
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
