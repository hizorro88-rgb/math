import 'dart:math';

import 'package:flutter/material.dart';

import 'language_pack.dart';

/// 천자문 한 글자: 한자·훈(뜻)·음(소리)·그림 힌트(없으면 빈 문자열).
class HanjaChar {
  const HanjaChar(this.char, this.hun, this.eum, [this.emoji = '']);

  final String char;
  final String hun;
  final String eum;
  final String emoji;

  /// "하늘 천"처럼 읽는 훈음
  String get reading => '$hun $eum';
}

/// 천자문 앞 32자 (여덟 구절). 순서가 곧 구절 완성 문제의 근거라 바꾸지 말 것.
const List<HanjaChar> hanjaChars = [
  HanjaChar('天', '하늘', '천', '⛅'),
  HanjaChar('地', '땅', '지', '🌍'),
  HanjaChar('玄', '검을', '현', '⚫'),
  HanjaChar('黃', '누를', '황', '🟡'),
  HanjaChar('宇', '집', '우', '🏠'),
  HanjaChar('宙', '집', '주', '🌌'),
  HanjaChar('洪', '넓을', '홍', '🌊'),
  HanjaChar('荒', '거칠', '황', '🏜️'),
  HanjaChar('日', '날', '일', '☀️'),
  HanjaChar('月', '달', '월', '🌙'),
  HanjaChar('盈', '찰', '영', '🌕'),
  HanjaChar('昃', '기울', '측', '🌗'),
  HanjaChar('辰', '별', '진', '⭐'),
  HanjaChar('宿', '잘', '숙', '😴'),
  HanjaChar('列', '벌일', '렬'),
  HanjaChar('張', '베풀', '장'),
  HanjaChar('寒', '찰', '한', '❄️'),
  HanjaChar('來', '올', '래'),
  HanjaChar('暑', '더울', '서', '🥵'),
  HanjaChar('往', '갈', '왕'),
  HanjaChar('秋', '가을', '추', '🍂'),
  HanjaChar('收', '거둘', '수', '🧺'),
  HanjaChar('冬', '겨울', '동', '⛄'),
  HanjaChar('藏', '감출', '장', '📦'),
  HanjaChar('閏', '윤달', '윤', '📅'),
  HanjaChar('餘', '남을', '여'),
  HanjaChar('成', '이룰', '성', '🏆'),
  HanjaChar('歲', '해', '세', '🎂'),
  HanjaChar('律', '법칙', '률', '🎼'),
  HanjaChar('呂', '음률', '려', '🎵'),
  HanjaChar('調', '고를', '조'),
  HanjaChar('陽', '볕', '양', '🌞'),
];

/// 네 글자씩 끊은 천자문 구절 (구절 완성 문제용)
List<List<HanjaChar>> get hanjaPhrases => [
      for (var i = 0; i + 4 <= hanjaChars.length; i += 4)
        hanjaChars.sublist(i, i + 4),
    ];

/// 한자 팩: 천자문을 훈음(하늘 천)으로 배우고 구절까지 완성한다.
/// 훈음은 한국어라 TTS는 항상 지원된다.
final LanguagePack hanjaPack = LanguagePack(
  id: 'hanja',
  name: '한자',
  emoji: '📜',
  ttsLang: 'ko-KR',
  types: const [
    LangUnitType('한자 소리 찾기', '소리→한자', '🔊', listening: true), // 0
    LangUnitType('한자 보고 뜻 찾기', '한자→뜻', '📖', textDisplay: true), // 1
    LangUnitType('뜻 보고 한자 찾기', '뜻→한자', '🔍', textDisplay: true), // 2
    LangUnitType('그림 보고 한자 찾기', '그림→한자', '🖼️'), // 3
    LangUnitType('구절 완성', '구절 완성', '📜', textDisplay: true), // 4
  ],
  categories: [
    LangCategory(
      title: '천자문 첫걸음',
      emoji: '⛅',
      desc: '하늘 천, 땅 지 — 훈음으로 한자를 만나요',
      color: const Color(0xFF7E57C2),
      units: [
        LangUnit(title: '한자 소리 찾기', emoji: '🔊', typeIndex: 0),
        LangUnit(title: '한자 보고 뜻 찾기', emoji: '📖', typeIndex: 1),
      ],
    ),
    LangCategory(
      title: '천자문 익히기',
      emoji: '🍂',
      desc: '뜻과 그림으로 한자를 찾아요',
      color: const Color(0xFFE0A100),
      units: [
        LangUnit(title: '뜻 보고 한자 찾기', emoji: '🔍', typeIndex: 2),
        LangUnit(title: '그림 보고 한자 찾기', emoji: '🖼️', typeIndex: 3),
      ],
    ),
    LangCategory(
      title: '천자문 박사',
      emoji: '📜',
      desc: '天地玄黃 — 네 글자 구절을 완성해요',
      color: const Color(0xFF2FB8A6),
      units: [
        LangUnit(title: '구절 완성', emoji: '📜', typeIndex: 4),
      ],
    ),
  ],
  generateOne: _generate,
);

/// 앞 단계는 천자문 앞 16자만, 뒤 단계(stage 5+)는 32자 전부.
List<HanjaChar> _pool(int stage) =>
    stage >= 5 ? hanjaChars : hanjaChars.sublist(0, 16);

/// 정답 1 + 오답 3 (훈음이 같은 글자는 헷갈려서 오답에서 뺀다: 집 우/집 주 등)
List<HanjaChar> _pick(List<HanjaChar> pool, Random random) {
  final target = pool[random.nextInt(pool.length)];
  final others = [
    for (final c in pool)
      if (c.char != target.char && c.reading != target.reading) c,
  ]..shuffle(random);
  return [target, ...others.take(3)];
}

LangQuestion _generate(int typeIndex, int stage, Random random) {
  switch (typeIndex) {
    // 소리를 듣고 한자를 찾는다 ("하늘 천" → 天)
    case 0:
      final picked = _pick(_pool(stage), random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 0,
        instruction: '잘 듣고 알맞은 한자를 찾아요',
        display: '🔊',
        choices: [for (final c in picked) c.char]..shuffle(random),
        answer: target.char,
        answerText: '${target.char} (${target.reading})',
        speech: target.reading,
        dedupKey: 'hs:${target.char}',
      );

    // 한자를 보고 훈음을 찾는다 (天 → 하늘 천)
    case 1:
      final picked = _pick(_pool(stage), random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 1,
        instruction: '이 한자는 어떻게 읽을까요?',
        display: target.char,
        // 앞 단계에서는 그림 힌트를 보여준다.
        subDisplay: stage >= 5 ? '' : target.emoji,
        choices: [for (final c in picked) c.reading]..shuffle(random),
        answer: target.reading,
        answerText: '${target.char} = ${target.reading}',
        speech: target.reading,
        dedupKey: 'hr:${target.char}',
      );

    // 훈음을 보고 한자를 찾는다 (하늘 천 → 天)
    case 2:
      final picked = _pick(_pool(stage), random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 2,
        instruction: '이 뜻에 맞는 한자는?',
        display: target.reading,
        choices: [for (final c in picked) c.char]..shuffle(random),
        answer: target.char,
        answerText: '${target.reading} = ${target.char}',
        speech: target.reading,
        dedupKey: 'hh:${target.char}',
      );

    // 그림을 보고 한자를 찾는다 (그림 있는 글자만)
    case 3:
      final pool = [
        for (final c in _pool(stage))
          if (c.emoji.isNotEmpty) c,
      ];
      final picked = _pick(pool, random);
      final target = picked.first;
      return LangQuestion(
        typeIndex: 3,
        instruction: '그림에 맞는 한자는?',
        display: target.emoji,
        choices: [for (final c in picked) c.char]..shuffle(random),
        answer: target.char,
        answerText: '${target.char} (${target.reading})',
        speech: target.reading,
        dedupKey: 'hp:${target.char}',
      );

    // 구절 완성: 天地玄□ → 黃 (천자문 네 글자 구절)
    default:
      final phrases = hanjaPhrases;
      // 앞 단계는 앞 네 구절(16자 범위), 뒤 단계는 전부.
      final phrase =
          phrases[random.nextInt(stage >= 5 ? phrases.length : 4)];
      // 앞 단계는 마지막 글자만 가리고, 뒤 단계는 아무 자리나 가린다.
      final blank = stage >= 5 ? random.nextInt(4) : 3;
      final target = phrase[blank];
      final shown = [
        for (var i = 0; i < 4; i++) i == blank ? '□' : phrase[i].char,
      ].join(' ');
      final reading = [for (final c in phrase) c.eum].join('');
      final wrong = ([
        for (final c in hanjaChars)
          if (!phrase.contains(c)) c.char,
      ]..shuffle(random))
          .take(3);
      return LangQuestion(
        typeIndex: 4,
        instruction: '구절을 완성해요',
        display: shown,
        subDisplay: '($reading)',
        choices: [target.char, ...wrong]..shuffle(random),
        answer: target.char,
        answerText: '${[for (final c in phrase) c.char].join()} ($reading)',
        speech: reading,
        dedupKey: 'hj:${phrase.first.char}:$blank',
      );
  }
}
