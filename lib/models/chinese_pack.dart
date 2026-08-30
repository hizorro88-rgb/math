import 'dart:math';

import 'package:flutter/material.dart';

import 'language_pack.dart';

/// 숫자 한자 1~10
const List<String> zhNumbers = [
  '一', '二', '三', '四', '五', '六', '七', '八', '九', '十', //
];

/// 기초 한자 낱말 (그림 짝)
const List<LangWord> zhWords = [
  LangWord('猫', '🐱'),
  LangWord('狗', '🐶'),
  LangWord('鱼', '🐟'),
  LangWord('鸟', '🐦'),
  LangWord('牛', '🐮'),
  LangWord('马', '🐴'),
  LangWord('熊', '🐻'),
  LangWord('兔子', '🐰'),
  LangWord('猴子', '🐵'),
  LangWord('大象', '🐘'),
  LangWord('青蛙', '🐸'),
  LangWord('花', '🌸'),
  LangWord('山', '⛰️'),
  LangWord('水', '💧'),
  LangWord('日', '☀️'),
  LangWord('月', '🌙'),
  LangWord('星', '⭐'),
  LangWord('火', '🔥'),
  LangWord('木', '🌲'),
  LangWord('雨', '🌧️'),
  LangWord('门', '🚪'),
  LangWord('手', '✋'),
  LangWord('羊', '🐑'),
  LangWord('虎', '🐯'),
  LangWord('猪', '🐷'),
  LangWord('苹果', '🍎'),
  LangWord('香蕉', '🍌'),
  LangWord('鸡蛋', '🥚'),
  LangWord('牛奶', '🥛'),
  LangWord('蛋糕', '🎂'),
  LangWord('书', '📕'),
  LangWord('球', '⚽'),
  LangWord('家', '🏠'),
  LangWord('伞', '☔'),
  LangWord('帽子', '🎩'),
  LangWord('鞋', '👟'),
  LangWord('车', '🚗', 'vehicle'),
  LangWord('船', '🚢', 'vehicle'),
  LangWord('飞机', '✈️', 'vehicle'),
];

/// 한 글자 기초 한자의 우리말 뜻 (한자 뜻 찾기용)
const Map<String, String> zhMeanings = {
  '猫': '고양이',
  '狗': '강아지',
  '鱼': '물고기',
  '鸟': '새',
  '牛': '소',
  '马': '말',
  '熊': '곰',
  '羊': '양',
  '虎': '호랑이',
  '猪': '돼지',
  '花': '꽃',
  '山': '산',
  '水': '물',
  '火': '불',
  '木': '나무',
  '日': '해',
  '月': '달',
  '星': '별',
  '雨': '비',
  '门': '문',
  '手': '손',
  '书': '책',
  '球': '공',
  '家': '집',
  '伞': '우산',
  '车': '자동차',
  '船': '배',
  '鞋': '신발',
};

/// 중국어 팩: 소리 듣기 → 한자 낱말 → 숫자 한자 → 한자 박사
final LanguagePack chinesePack = LanguagePack(
  id: 'zh',
  name: '중국어',
  emoji: '🀄',
  ttsLang: 'zh-CN',
  types: const [
    LangUnitType('낱말 소리 찾기', '낱말 소리', '🔊', listening: true), // 0
    LangUnitType('숫자 소리 찾기', '숫자 소리', '👂', listening: true), // 1
    LangUnitType('한자 보고 그림 찾기', '한자→그림', '🔍', textDisplay: true), // 2
    LangUnitType('그림 보고 한자 찾기', '그림→한자', '🖼️'), // 3
    LangUnitType('숫자 한자 찾기', '숫자 한자', '🔢', textDisplay: true), // 4
    LangUnitType('듣고 한자 찾기', '듣고 한자', '🎧', listening: true), // 5
    LangUnitType('한자 뜻 찾기', '한자 뜻', '📜', textDisplay: true), // 6
  ],
  categories: [
    LangCategory(
      title: '중국어 소리',
      emoji: '🐼',
      desc: '소리를 듣고 그림·숫자를 찾아요',
      color: const Color(0xFFE23B3B),
      units: [
        LangUnit(title: '낱말 소리 찾기', emoji: '🔊', typeIndex: 0),
        LangUnit(title: '숫자 소리 찾기', emoji: '👂', typeIndex: 1),
      ],
    ),
    LangCategory(
      title: '한자 낱말',
      emoji: '🀄',
      desc: '한자와 그림을 짝지어요',
      color: const Color(0xFFE0A100),
      units: [
        LangUnit(title: '한자 보고 그림 찾기', emoji: '🔍', typeIndex: 2),
        LangUnit(title: '그림 보고 한자 찾기', emoji: '🖼️', typeIndex: 3),
      ],
    ),
    LangCategory(
      title: '숫자 한자',
      emoji: '🔢',
      desc: '一부터 十까지 숫자 한자를 익혀요',
      color: const Color(0xFF2FB8A6),
      units: [
        LangUnit(title: '숫자 한자 찾기', emoji: '🔢', typeIndex: 4),
      ],
    ),
    LangCategory(
      title: '한자 박사',
      emoji: '📜',
      desc: '소리로 한자를 읽고, 우리말 뜻을 이어요',
      color: const Color(0xFF8A5A2B),
      units: [
        LangUnit(title: '듣고 한자 찾기', emoji: '🎧', typeIndex: 5),
        LangUnit(title: '한자 뜻 찾기', emoji: '📜', typeIndex: 6),
      ],
    ),
  ],
  generateOne: _generate,
);

LangQuestion _generate(int typeIndex, int stage, Random random) {
  switch (typeIndex) {
    // 낱말 소리 찾기: 소리를 듣고 그림을 고른다
    case 0:
      final pool = stage >= 5
          ? zhWords
          : [for (final w in zhWords) if (w.word.length == 1) w];
      final picked = pickLangWords(pool, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 0,
        instruction: '잘 듣고 알맞은 그림을 찾아요',
        display: '🔊',
        choices: [for (final w in picked) w.emoji]..shuffle(random),
        answer: target.emoji,
        answerText: target.word,
        speech: target.word,
        emojiChoices: true,
        dedupKey: 'lw:${target.word}',
      );

    // 숫자 소리 찾기: 소리를 듣고 아라비아 숫자를 고른다
    case 1:
      final upper = stage >= 5 ? 10 : 5;
      final numbers = <int>{};
      while (numbers.length < 4) {
        numbers.add(1 + random.nextInt(upper));
      }
      final list = numbers.toList()..shuffle(random);
      final answer = list[random.nextInt(list.length)];
      return LangQuestion(
        typeIndex: 1,
        instruction: '잘 듣고 알맞은 숫자를 찾아요',
        display: '🔊',
        choices: [for (final n in list) '$n'],
        answer: '$answer',
        answerText: '${zhNumbers[answer - 1]} ($answer)',
        speech: zhNumbers[answer - 1],
        dedupKey: 'ln:$answer',
      );

    // 한자 보고 그림 찾기 (소리도 함께 들려준다)
    case 2:
      final pool = stage >= 5
          ? zhWords
          : [for (final w in zhWords) if (w.word.length == 1) w];
      final picked = pickLangWords(pool, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 2,
        instruction: '한자에 맞는 그림은?',
        display: target.word,
        choices: [for (final w in picked) w.emoji]..shuffle(random),
        answer: target.emoji,
        answerText: target.word,
        speech: target.word,
        emojiChoices: true,
        dedupKey: 'wtp:${target.word}',
      );

    // 그림 보고 한자 찾기
    case 3:
      final pool = stage >= 5
          ? zhWords
          : [for (final w in zhWords) if (w.word.length == 1) w];
      final picked = pickLangWords(pool, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 3,
        instruction: '그림에 맞는 한자는?',
        display: target.emoji,
        choices: [for (final w in picked) w.word]..shuffle(random),
        answer: target.word,
        answerText: target.word,
        speech: target.word,
        dedupKey: 'ptw:${target.word}',
      );

    // 듣고 한자 찾기: 소리를 듣고 한자를 고른다 (읽기 연습)
    case 5:
      final pool = stage >= 5
          ? zhWords
          : [for (final w in zhWords) if (w.word.length == 1) w];
      final picked = pickLangWords(pool, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 5,
        instruction: '잘 듣고 알맞은 한자를 찾아요',
        display: '🔊',
        choices: [for (final w in picked) w.word]..shuffle(random),
        answer: target.word,
        answerText: '${target.word} ${target.emoji}',
        speech: target.word,
        dedupKey: 'lh:${target.word}',
      );

    // 한자 뜻 찾기: 山 → '산' (우리말 뜻 잇기)
    case 6:
      final pool = [
        for (final w in zhWords)
          if (zhMeanings.containsKey(w.word)) w,
      ];
      final word = pool[random.nextInt(pool.length)];
      final answer = zhMeanings[word.word]!;
      final wrong = pickLangItems(
        [
          for (final m in zhMeanings.values)
            if (m != answer) m,
        ],
        3,
        random,
      );
      return LangQuestion(
        typeIndex: 6,
        instruction: '이 한자의 뜻은 무엇일까요?',
        display: word.word,
        // 앞 단계에서는 그림 힌트를 보여주고, 뒤 단계에서는 한자만 보고 푼다.
        subDisplay: stage >= 5 ? '' : word.emoji,
        choices: [answer, ...wrong]..shuffle(random),
        answer: answer,
        answerText: '${word.word} = $answer',
        speech: word.word,
        dedupKey: 'hm:${word.word}',
      );

    // 숫자 한자 찾기: 3 → 三
    default:
      final upper = stage >= 5 ? 10 : 5;
      final answer = 1 + random.nextInt(upper);
      final wrong = <int>{};
      while (wrong.length < 3) {
        final n = 1 + random.nextInt(10);
        if (n != answer) wrong.add(n);
      }
      return LangQuestion(
        typeIndex: 4,
        instruction: '숫자에 맞는 한자는?',
        display: '$answer',
        choices: [
          zhNumbers[answer - 1],
          for (final n in wrong) zhNumbers[n - 1],
        ]..shuffle(random),
        answer: zhNumbers[answer - 1],
        answerText: '${zhNumbers[answer - 1]} ($answer)',
        speech: zhNumbers[answer - 1],
        dedupKey: 'nh:$answer',
      );
  }
}
