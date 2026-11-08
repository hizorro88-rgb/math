import 'english_data.dart';
import 'english_phonics.dart';
import 'english_question.dart';
import 'english_vocab.dart';
import 'hanja_pack.dart';
import 'korean_data.dart';
import 'korean_extra.dart';
import 'korean_question.dart';
import 'language_pack.dart';

/// 배우기 카드 한 장: 크게 보여 줄 것(그림·글자) + 이름 + 작은 뜻 + 읽어 줄 말.
/// [keys]는 이 카드가 어떤 문제와 같은 것인지 맞춰 볼 때 쓰는 말들
/// (낱말·글자·그림). 비우면 [speech] 하나.
class LearnCard {
  const LearnCard(this.big, this.label,
      {this.sub = '',
      required this.speech,
      this.lang = 'ko-KR',
      this.keys = const []});

  final String big;
  final String label;
  final String sub;
  final String speech;
  final String lang;
  final List<String> keys;

  Iterable<String> get matchKeys => keys.isEmpty ? [speech] : keys;
}

/// 한 번에 보여 줄 카드 수 — 많으면 아이가 끝까지 안 본다
const learnCardLimit = 8;

/// 배우기 카드를 자동으로 띄울 단계: 묶음 첫 단계와 새 글자가 늘어나는 6단계,
/// 아직 별이 없을 때만.
bool autoShowLearnCards(int indexInUnit, int stars) =>
    stars == 0 && (indexInUnit == 0 || indexInUnit == 5);

String _norm(String s) => s.trim().toLowerCase();

/// 카드 후보 중에서 이번 판 문제에 나오는 것만, 문제 순서대로 고른다.
/// 문제 하나에 카드 하나 — 문제의 말(답·그림·읽어 줄 말)과 가장 많이 겹치는 카드.
List<LearnCard> cardsForRound(
    List<LearnCard> pool, Iterable<List<String>> questionKeys) {
  if (pool.isEmpty) return const [];
  final out = <LearnCard>[];
  final used = <LearnCard>{};
  for (final raw in questionKeys) {
    final keys = {
      for (final k in raw)
        if (k.trim().isNotEmpty) _norm(k)
    };
    LearnCard? best;
    var bestScore = 0;
    for (final c in pool) {
      if (used.contains(c)) continue;
      final score = c.matchKeys.where((k) => keys.contains(_norm(k))).length;
      if (score > bestScore) {
        best = c;
        bestScore = score;
      }
    }
    if (best != null && used.add(best)) out.add(best);
    if (out.length >= learnCardLimit) break;
  }
  return out;
}

// ── 영어 ──

LearnCard _vocabCard(EnVocab v) => LearnCard(v.emoji, v.shown,
    sub: v.ko,
    speech: v.word,
    lang: 'en-US',
    keys: [v.word, v.shown, v.ko, v.emoji]);

LearnCard _wordCard(EnWord w) => LearnCard(w.emoji, w.word.toUpperCase(),
    speech: w.word, lang: 'en-US', keys: [w.word, w.emoji]);

/// 영어 유형별 카드 후보. 미리 볼 것이 없는 유형(순서·짝 맞추기)은 빈 목록.
List<LearnCard> englishCardPool(EnQuizType type) => switch (type) {
      EnQuizType.listenLetter || EnQuizType.caseMatch => [
          for (final c in enAlphabet)
            LearnCard('$c ${c.toLowerCase()}', c,
                speech: c, lang: 'en-US', keys: [c, c.toLowerCase()]),
        ],
      EnQuizType.letterSound => [
          for (final e in phonicsLetterWords.entries)
            for (final w in e.value)
              LearnCard(w.emoji, '${e.key} — ${w.shown}',
                  speech: '${e.key}. ${w.word}',
                  lang: 'en-US',
                  keys: [
                    w.word,
                    w.shown,
                    w.emoji,
                    e.key,
                    '${e.key}. ${w.word}'
                  ]),
        ],
      EnQuizType.shortVowel || EnQuizType.decode => [
          for (final w in phonicsCvc)
            LearnCard(w.emoji, w.shown,
                speech: w.word,
                lang: 'en-US',
                keys: [w.word, w.shown, w.emoji]),
        ],
      EnQuizType.rhyme => [
          for (final f in phonicsRhymes.entries)
            for (final w in f.value)
              LearnCard(w.emoji, w.shown,
                  sub: f.key,
                  speech: w.word,
                  lang: 'en-US',
                  keys: [w.word, w.shown, w.emoji]),
        ],
      EnQuizType.cluster => [
          for (final c in [...phonicsDigraphs, ...phonicsBlends])
            LearnCard(c.emoji, c.word.toUpperCase(),
                sub: c.sound.toUpperCase(),
                speech: c.word,
                lang: 'en-US',
                keys: [c.word, c.word.toUpperCase(), c.emoji]),
        ],
      EnQuizType.themeWord ||
      EnQuizType.meaningPick ||
      EnQuizType.englishPick ||
      EnQuizType.missingLetter =>
        [for (final v in enVocab) _vocabCard(v)],
      EnQuizType.sightWord => [
          for (final w in enSightWords)
            LearnCard(w, '', speech: w, lang: 'en-US', keys: [w]),
        ],
      EnQuizType.wordToPicture ||
      EnQuizType.pictureToWord ||
      EnQuizType.firstLetter ||
      EnQuizType.wordBuild =>
        [for (final w in enAllWords) _wordCard(w)],
      EnQuizType.longWord => [for (final w in enWordsLong) _wordCard(w)],
      EnQuizType.alphabetOrder || EnQuizType.matchPairs => const [],
    };

List<String> _enKeys(EnglishQuestion q) =>
    [q.answer, q.answerText, q.revealSpeech, q.speech, q.display, q.subDisplay];

/// 이번 판 영어 문제에 나오는 것으로 만든 배우기 카드
List<LearnCard> englishLearnCards(
        EnQuizType type, List<EnglishQuestion> round) =>
    cardsForRound(englishCardPool(type), round.map(_enKeys));

// ── 한글 ──

LearnCard _krWordCard(KrWord w) =>
    LearnCard(w.emoji, w.word, speech: w.word, keys: [w.word, w.emoji]);

/// 한글 유형별 카드 후보
List<LearnCard> koreanCardPool(KrQuizType type) => switch (type) {
      KrQuizType.listenVowel => [
          for (final v in krVowels)
            LearnCard(v.letter, v.sound,
                speech: v.sound, keys: [v.letter, v.sound]),
        ],
      KrQuizType.listenConsonant || KrQuizType.firstConsonant => [
          for (final c in krConsonantNames)
            LearnCard(c.letter, c.name,
                speech: c.name, keys: [c.letter, c.name]),
        ],
      KrQuizType.complexVowel => [
          for (final v in krComplexVowels)
            LearnCard(v.letter, v.sound,
                speech: v.sound, keys: [v.letter, v.sound]),
        ],
      // 예사소리·된소리·거센소리를 한 장에: 가 까 카
      KrQuizType.doubleConsonant => [
          for (final v in const ['ㅏ', 'ㅗ', 'ㅜ', 'ㅣ'])
            for (final t in krConsonantTriples)
              LearnCard(t.map((c) => krCompose(c, v)).join(' '), t.join(' '),
                  speech: t.map((c) => krCompose(c, v)).join(', '),
                  keys: [for (final c in t) krCompose(c, v)]),
        ],
      KrQuizType.opposite => [
          for (final o in krOpposites)
            LearnCard(o.$3, '${o.$1} ↔ ${o.$2}',
                speech: '${o.$1}, 반대말은 ${o.$2}', keys: [o.$1, o.$2, o.$3]),
        ],
      KrQuizType.mimetic => [
          for (final m in krMimetics)
            LearnCard(m.$1, m.$2, sub: m.$3, speech: m.$2, keys: [m.$1, m.$2]),
        ],
      KrQuizType.verbMatch => [
          for (final v in krVerbPairs)
            LearnCard(v.$1, '${v.$2} ${v.$3}',
                speech: '${v.$2} ${v.$3}',
                keys: [v.$1, v.$2, v.$3, '${v.$2} ${v.$3}']),
        ],
      KrQuizType.honorific => [
          for (final h in krHonorifics)
            LearnCard(h.$1, '→ ${h.$2}',
                sub: '높임말',
                speech: '${h.$1}, 높임말은 ${h.$2}',
                keys: [h.$1, h.$2]),
        ],
      KrQuizType.counterWord => [
          for (final c in krCounters)
            LearnCard(c.$1, '${c.$2} 한 ${c.$3}',
                speech: '${c.$2} 한 ${c.$3}', keys: [c.$1, c.$2, c.$3]),
        ],
      KrQuizType.listenSyllable => [
          for (final s in [...krSyllablesA, ...krSyllablesO])
            LearnCard(s, s, speech: s, keys: [s]),
        ],
      KrQuizType.syllableOrder ||
      KrQuizType.combine ||
      KrQuizType.batchimCombine ||
      KrQuizType.oddOneOut ||
      KrQuizType.matchPairs =>
        const [],
      _ => [for (final w in krAllWords) _krWordCard(w)],
    };

List<String> _krKeys(KoreanQuestion q) =>
    [q.answer, q.answerText, q.speech, q.display, q.subDisplay];

/// 이번 판 한글 문제에 나오는 것으로 만든 배우기 카드
List<LearnCard> koreanLearnCards(KrQuizType type, List<KoreanQuestion> round) =>
    cardsForRound(koreanCardPool(type), round.map(_krKeys));

// ── 외국어 팩 (지금은 한자만) ──

/// 한자 유형별 카드 후보 (훈음 카드). 구절 완성(4)·짝 맞추기(10)는 없음.
List<LearnCard> langCardPool(LanguagePack pack, int typeIndex) {
  if (pack.id != 'hanja' || typeIndex == 4 || typeIndex == 10) return const [];
  if (typeIndex == 9) {
    return [
      for (final w in hanjaWords8)
        LearnCard(w.$1, w.$2, speech: w.$2, keys: [w.$1, w.$2]),
    ];
  }
  final pool = typeIndex >= 5 ? hanjaGrade8 : hanjaChars;
  return [
    for (final c in pool)
      LearnCard(c.char, c.reading, sub: c.emoji, speech: c.reading, keys: [
        c.char,
        c.reading,
        c.hun,
        c.eum,
        if (c.emoji.isNotEmpty) c.emoji
      ]),
  ];
}

List<String> _langKeys(LangQuestion q) =>
    [q.answer, q.answerText, q.speech, q.display, q.subDisplay];

/// 이번 판 외국어 문제에 나오는 것으로 만든 배우기 카드
List<LearnCard> langLearnCards(
        LanguagePack pack, int typeIndex, List<LangQuestion> round) =>
    cardsForRound(langCardPool(pack, typeIndex), round.map(_langKeys));
