import 'dart:math';

import 'package:flutter/material.dart';

import 'language_pack.dart';

/// 히라가나 오십음 (기본 46자, あ~ん)
const List<String> jaKana = [
  'あ', 'い', 'う', 'え', 'お', //
  'か', 'き', 'く', 'け', 'こ', //
  'さ', 'し', 'す', 'せ', 'そ', //
  'た', 'ち', 'つ', 'て', 'と', //
  'な', 'に', 'ぬ', 'ね', 'の', //
  'は', 'ひ', 'ふ', 'へ', 'ほ', //
  'ま', 'み', 'む', 'め', 'も', //
  'や', 'ゆ', 'よ', //
  'ら', 'り', 'る', 'れ', 'ろ', //
  'わ', 'を', 'ん',
];

/// 가타카나 오십음 (히라가나와 같은 순서, 짝 맞추기용)
const List<String> jaKatakana = [
  'ア', 'イ', 'ウ', 'エ', 'オ', //
  'カ', 'キ', 'ク', 'ケ', 'コ', //
  'サ', 'シ', 'ス', 'セ', 'ソ', //
  'タ', 'チ', 'ツ', 'テ', 'ト', //
  'ナ', 'ニ', 'ヌ', 'ネ', 'ノ', //
  'ハ', 'ヒ', 'フ', 'ヘ', 'ホ', //
  'マ', 'ミ', 'ム', 'メ', 'モ', //
  'ヤ', 'ユ', 'ヨ', //
  'ラ', 'リ', 'ル', 'レ', 'ロ', //
  'ワ', 'ヲ', 'ン',
];

/// 가타카나 낱말 (외래어 중심, 그림 짝)
const List<LangWord> jaKataWords = [
  LangWord('バナナ', '🍌'),
  LangWord('トマト', '🍅'),
  LangWord('メロン', '🍈'),
  LangWord('ケーキ', '🎂'),
  LangWord('ピザ', '🍕'),
  LangWord('パン', '🍞'),
  LangWord('ジュース', '🧃'),
  LangWord('アイス', '🍦'),
  LangWord('パンダ', '🐼'),
  LangWord('ライオン', '🦁'),
  LangWord('ペンギン', '🐧'),
  LangWord('コアラ', '🐨'),
  LangWord('ロボット', '🤖'),
  LangWord('テレビ', '📺'),
  LangWord('カメラ', '📷'),
  LangWord('ピアノ', '🎹'),
  LangWord('ペン', '🖊️'),
  LangWord('ボール', '⚽'),
  LangWord('バス', '🚌', 'vehicle'),
  LangWord('タクシー', '🚕', 'vehicle'),
];

/// 히라가나 낱말 (그림 짝)
const List<LangWord> jaWords = [
  LangWord('ねこ', '🐱'),
  LangWord('いぬ', '🐶'),
  LangWord('うし', '🐮'),
  LangWord('うま', '🐴'),
  LangWord('くま', '🐻'),
  LangWord('さる', '🐵'),
  LangWord('ぞう', '🐘'),
  LangWord('うさぎ', '🐰'),
  LangWord('きつね', '🦊'),
  LangWord('かえる', '🐸'),
  LangWord('かめ', '🐢'),
  LangWord('はち', '🐝'),
  LangWord('とり', '🐦'),
  LangWord('さかな', '🐟'),
  LangWord('りんご', '🍎'),
  LangWord('みかん', '🍊'),
  LangWord('ばなな', '🍌'),
  LangWord('ぶどう', '🍇'),
  LangWord('たまご', '🥚'),
  LangWord('ほし', '⭐'),
  LangWord('つき', '🌙'),
  LangWord('はな', '🌸'),
  LangWord('やま', '⛰️'),
  LangWord('うみ', '🌊'),
  LangWord('かさ', '☔'),
  LangWord('とけい', '⏰'),
  LangWord('くつ', '👟'),
  LangWord('ぼうし', '🎩'),
  LangWord('かばん', '🎒'),
  LangWord('ほん', '📕'),
  LangWord('くるま', '🚗', 'vehicle'),
  LangWord('でんしゃ', '🚃', 'vehicle'),
  LangWord('ふね', '🚢', 'vehicle'),
  LangWord('ひこうき', '✈️', 'vehicle'),
];

/// 일본어 팩: 히라가나 소리 → 오십음 순서 → 낱말 → 조립
final LanguagePack japanesePack = LanguagePack(
  id: 'ja',
  name: '일본어',
  emoji: '🎌',
  ttsLang: 'ja-JP',
  types: const [
    LangUnitType('かな 소리 찾기', 'かな 소리', '🔊', listening: true), // 0
    LangUnitType('あいうえお 순서', '순서', '🐾', textDisplay: true), // 1
    LangUnitType('낱말 듣고 그림 찾기', '듣고 그림', '🔍', textDisplay: true), // 2
    LangUnitType('그림 보고 낱말 찾기', '그림→낱말', '🖼️'), // 3
    LangUnitType('첫 글자 찾기', '첫 글자', '🎯'), // 4
    LangUnitType('낱말 만들기', '낱말 조립', '🏗️'), // 5
    LangUnitType('カナ 소리 찾기', 'カナ 소리', '🎧', listening: true), // 6
    LangUnitType('히라가나·가타카나 짝', 'かな 짝', '🀄', textDisplay: true), // 7
    LangUnitType('가타카나 낱말', 'カナ 낱말', '🍦'), // 8
  ],
  categories: [
    LangCategory(
      title: 'かな 첫걸음',
      emoji: '🌸',
      desc: '소리로 히라가나와 친해져요',
      color: const Color(0xFFFF4B6E),
      units: [
        LangUnit(title: 'かな 소리 찾기', emoji: '🔊', typeIndex: 0),
        LangUnit(title: 'あいうえお 순서', emoji: '🐾', typeIndex: 1),
      ],
    ),
    LangCategory(
      title: '일본어 낱말',
      emoji: '🍙',
      desc: '듣고 보며 낱말을 익혀요',
      color: const Color(0xFF7C5CE0),
      units: [
        LangUnit(title: '낱말 듣고 그림 찾기', emoji: '🔍', typeIndex: 2),
        LangUnit(title: '그림 보고 낱말 찾기', emoji: '🖼️', typeIndex: 3),
        LangUnit(title: '첫 글자 찾기', emoji: '🎯', typeIndex: 4),
      ],
    ),
    LangCategory(
      title: '낱말 완성',
      emoji: '✏️',
      desc: '글자를 이어서 낱말을 만들어요',
      color: const Color(0xFF2FB8A6),
      units: [
        LangUnit(title: '낱말 만들기', emoji: '🏗️', typeIndex: 5),
      ],
    ),
    LangCategory(
      title: 'カタカナ 도전',
      emoji: '🗼',
      desc: '가타카나 소리·짝·낱말을 익혀요',
      color: const Color(0xFFE0637C),
      units: [
        LangUnit(title: 'カナ 소리 찾기', emoji: '🎧', typeIndex: 6),
        LangUnit(title: '히라가나·가타카나 짝', emoji: '🀄', typeIndex: 7),
        LangUnit(title: '가타카나 낱말', emoji: '🍦', typeIndex: 8),
      ],
    ),
  ],
  generateOne: _generate,
);

LangQuestion _generate(int typeIndex, int stage, Random random) {
  switch (typeIndex) {
    // かな 소리 찾기: 앞 단계는 あ~そ, 뒤 단계는 오십음 전체
    case 0:
      final pool = stage >= 5 ? jaKana : jaKana.sublist(0, 15);
      final picked = pickLangItems(pool, 4, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 0,
        instruction: '무슨 글자일까요? 🔊를 눌러 다시 들어요',
        display: '🔊',
        choices: [...picked]..shuffle(random),
        answer: target,
        answerText: target,
        speech: target,
        dedupKey: 'lk:$target',
      );

    // あいうえお 순서: 오십음에서 다음 글자 찾기
    case 1:
      final maxStart = stage < 3 ? 5 : jaKana.length - 3;
      final start = random.nextInt(maxStart);
      final shown = jaKana.sublist(start, start + 3);
      final answer = jaKana[start + 3];
      final wrong = pickLangItems(
          [for (final k in jaKana) if (k != answer) k], 3, random);
      return LangQuestion(
        typeIndex: 1,
        instruction: '다음에 올 글자는?',
        display: '${shown.join('  ')}  ?',
        choices: [answer, ...wrong]..shuffle(random),
        answer: answer,
        answerText: answer,
        speech: shown.join(', '),
        dedupKey: 'ko:$start',
      );

    // 낱말 듣고 그림 찾기
    case 2:
      final pool = stage >= 5
          ? jaWords
          : [for (final w in jaWords) if (w.word.length <= 2) w];
      final picked = pickLangWords(pool, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 2,
        instruction: '잘 듣고 알맞은 그림을 찾아요',
        display: target.word,
        choices: [for (final w in picked) w.emoji]..shuffle(random),
        answer: target.emoji,
        answerText: target.word,
        speech: target.word,
        emojiChoices: true,
        dedupKey: 'wtp:${target.word}',
      );

    // 그림 보고 낱말 찾기
    case 3:
      final pool = stage >= 5
          ? jaWords
          : [for (final w in jaWords) if (w.word.length <= 2) w];
      final picked = pickLangWords(pool, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 3,
        instruction: '그림에 맞는 낱말은?',
        display: target.emoji,
        choices: [for (final w in picked) w.word]..shuffle(random),
        answer: target.word,
        answerText: target.word,
        speech: target.word,
        dedupKey: 'ptw:${target.word}',
      );

    // 첫 글자 찾기: ねこ → ね
    case 4:
      final word = jaWords[random.nextInt(jaWords.length)];
      final answer = word.word[0];
      final wrong = pickLangItems(
          [for (final k in jaKana) if (k != answer) k], 3, random);
      return LangQuestion(
        typeIndex: 4,
        instruction: "'${word.word}'의 첫 글자는?",
        display: word.emoji,
        subDisplay: word.word,
        choices: [answer, ...wrong]..shuffle(random),
        answer: answer,
        answerText: answer,
        speech: word.word,
        dedupKey: 'fk:${word.word}',
      );

    // カナ 소리 찾기: 소리를 듣고 가타카나를 고른다
    case 6:
      final pool = stage >= 5 ? jaKatakana : jaKatakana.sublist(0, 15);
      final picked = pickLangItems(pool, 4, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 6,
        instruction: '무슨 글자일까요? 🔊를 눌러 다시 들어요',
        display: '🔊',
        choices: [...picked]..shuffle(random),
        answer: target,
        answerText: target,
        speech: target,
        dedupKey: 'kk:$target',
      );

    // 히라가나·가타카나 짝 맞추기 (あ ↔ ア)
    case 7:
      final upper = stage >= 5 ? jaKana.length : 15;
      final indexes = pickLangItems(
          [for (var i = 0; i < upper; i++) i], 4, random);
      final target = indexes.first;
      // 뒤 단계에서는 가타카나를 보여주고 히라가나를 찾기도 한다.
      final showKata = stage >= 5 && random.nextBool();
      return LangQuestion(
        typeIndex: 7,
        instruction: showKata ? '짝이 되는 히라가나는?' : '짝이 되는 가타카나는?',
        display: showKata ? jaKatakana[target] : jaKana[target],
        choices: [
          for (final i in indexes) showKata ? jaKana[i] : jaKatakana[i],
        ]..shuffle(random),
        answer: showKata ? jaKana[target] : jaKatakana[target],
        answerText: '${jaKana[target]} (${jaKatakana[target]})',
        speech: jaKana[target],
        dedupKey: 'pk:$target:$showKata',
      );

    // 가타카나 낱말: 그림 보고 낱말 찾기
    case 8:
      final picked = pickLangWords(jaKataWords, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 8,
        instruction: '그림에 맞는 낱말은?',
        display: target.emoji,
        choices: [for (final w in picked) w.word]..shuffle(random),
        answer: target.word,
        answerText: target.word,
        speech: target.word,
        dedupKey: 'kw:${target.word}',
      );

    // 낱말 만들기: 글자 타일 조립
    default:
      final pool = stage >= 5
          ? jaWords
          : [for (final w in jaWords) if (w.word.length <= 2) w];
      final word = pool[random.nextInt(pool.length)];
      final letters = word.word.split('');
      final decoys = [
        for (final k in jaKana) if (!letters.contains(k)) k,
      ]..shuffle(random);
      final tiles = [...letters, ...decoys.take(2)]..shuffle(random);
      return LangQuestion(
        typeIndex: 5,
        instruction: '글자를 순서대로 눌러 낱말을 만들어요',
        display: word.emoji,
        choices: tiles,
        answer: word.word,
        answerText: word.word,
        speech: word.word,
        tiles: tiles,
        dedupKey: 'wb:${word.word}',
      );
  }
}
