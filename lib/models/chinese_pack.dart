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
  LangWord('太阳', '☀️'),
  LangWord('月亮', '🌙'),
  LangWord('星星', '⭐'),
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

/// 중국어 팩: 소리 듣기 → 한자 낱말 → 숫자 한자
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
