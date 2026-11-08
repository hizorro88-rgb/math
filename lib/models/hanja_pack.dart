import 'dart:math';

import 'language_pack.dart';
import '../theme.dart';

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

/// 한자능력검정 8급 50자 (대표 훈음). 앞쪽은 숫자·자연, 뒤로 갈수록 사람·학교·나라.
/// 앞 단계(stage 0~4)는 앞 25자, 뒤 단계는 50자 전부.
/// 그림은 하나로만 읽히는 것만 — 東🌅·西🌇(둘 다 해), 先🥇(금메달 → 金)처럼
/// 다른 글자로도 읽히는 그림은 뺐다. 父·母는 아이와 함께 있는 그림으로 사람(人)과 가른다.
const List<HanjaChar> hanjaGrade8 = [
  HanjaChar('一', '한', '일', '1️⃣'),
  HanjaChar('二', '두', '이', '2️⃣'),
  HanjaChar('三', '석', '삼', '3️⃣'),
  HanjaChar('四', '넉', '사', '4️⃣'),
  HanjaChar('五', '다섯', '오', '5️⃣'),
  HanjaChar('六', '여섯', '륙', '6️⃣'),
  HanjaChar('七', '일곱', '칠', '7️⃣'),
  HanjaChar('八', '여덟', '팔', '8️⃣'),
  HanjaChar('九', '아홉', '구', '9️⃣'),
  HanjaChar('十', '열', '십', '🔟'),
  HanjaChar('日', '날', '일', '☀️'),
  HanjaChar('月', '달', '월', '🌙'),
  HanjaChar('火', '불', '화', '🔥'),
  HanjaChar('水', '물', '수', '💧'),
  HanjaChar('木', '나무', '목', '🌳'),
  HanjaChar('金', '쇠', '금', '⛏️'),
  HanjaChar('土', '흙', '토'),
  HanjaChar('山', '메', '산', '⛰️'),
  HanjaChar('人', '사람', '인', '🧍'),
  HanjaChar('大', '큰', '대'),
  HanjaChar('小', '작을', '소'),
  HanjaChar('中', '가운데', '중', '🎯'),
  HanjaChar('父', '아비', '부', '👨‍👧'),
  HanjaChar('母', '어미', '모', '👩‍👧'),
  HanjaChar('女', '계집', '녀'),
  // 여기부터 뒤 단계
  HanjaChar('兄', '형', '형'),
  HanjaChar('弟', '아우', '제'),
  HanjaChar('王', '임금', '왕', '🤴'),
  HanjaChar('門', '문', '문', '🚪'),
  HanjaChar('學', '배울', '학', '📚'),
  HanjaChar('校', '학교', '교', '🏫'),
  HanjaChar('敎', '가르칠', '교'),
  HanjaChar('先', '먼저', '선'),
  HanjaChar('生', '날', '생', '🌱'),
  HanjaChar('東', '동녘', '동'),
  HanjaChar('西', '서녘', '서'),
  HanjaChar('南', '남녘', '남'),
  HanjaChar('北', '북녘', '북'),
  HanjaChar('國', '나라', '국'),
  HanjaChar('韓', '한국', '한', '🇰🇷'),
  HanjaChar('軍', '군사', '군', '🪖'),
  HanjaChar('民', '백성', '민'),
  HanjaChar('萬', '일만', '만'),
  HanjaChar('年', '해', '년'),
  HanjaChar('長', '긴', '장', '📏'),
  HanjaChar('寸', '마디', '촌'),
  HanjaChar('外', '바깥', '외'),
  HanjaChar('室', '집', '실', '🛋️'),
  HanjaChar('白', '흰', '백', '⚪'),
  HanjaChar('靑', '푸를', '청'),
];

/// 앞 단계에서 쓰는 8급 글자 수
const hanjaGrade8EasyCount = 25;

/// 8급 글자로만 된 두 글자 한자어와 읽기 (두음법칙·예외 읽기(六月=유월) 없는 것만)
const List<(String, String)> hanjaWords8 = [
  // 앞 단계 글자(숫자·자연·사람)로만 된 낱말
  ('水中', '수중'), ('山中', '산중'), ('大小', '대소'), ('母女', '모녀'),
  ('父女', '부녀'), ('三月', '삼월'), ('五月', '오월'), ('八月', '팔월'),
  ('一月', '일월'), ('火山', '화산'), ('山水', '산수'), ('人生', '인생'),
  // 뒤 단계 글자까지
  ('父母', '부모'), ('兄弟', '형제'), ('學校', '학교'), ('先生', '선생'),
  ('生日', '생일'), ('國王', '국왕'), ('大門', '대문'), ('南北', '남북'),
  ('東西', '동서'), ('校門', '교문'), ('外國', '외국'), ('韓國', '한국'),
  ('中國', '중국'), ('王國', '왕국'), ('軍人', '군인'), ('三寸', '삼촌'),
  ('四寸', '사촌'), ('校長', '교장'), ('生水', '생수'), ('大國', '대국'),
  ('學生', '학생'), ('大學', '대학'), ('敎室', '교실'), ('國民', '국민'),
  ('靑年', '청년'),
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
    LangUnitType('한자 소리 찾기', '소리→한자', '👂', listening: true), // 0
    LangUnitType('한자 보고 뜻 찾기', '한자→뜻', '📖', textDisplay: true), // 1
    LangUnitType('뜻 보고 한자 찾기', '뜻→한자', '🔍', textDisplay: true), // 2
    LangUnitType('그림 보고 한자 찾기', '그림→한자', '🖼️'), // 3
    LangUnitType('구절 완성', '구절 완성', '📜', textDisplay: true), // 4
    // 아래는 8급 (통계가 순서로 저장돼 뒤에 붙인다)
    LangUnitType('8급 소리 찾기', '8급 소리', '👂', listening: true), // 5
    LangUnitType('8급 뜻 찾기', '8급 뜻', '📖', textDisplay: true), // 6
    LangUnitType('8급 한자 찾기', '8급 한자', '🔍', textDisplay: true), // 7
    LangUnitType('8급 그림 찾기', '8급 그림', '🖼️'), // 8
    LangUnitType('한자어 읽기', '한자어', '🈶', textDisplay: true), // 9
  ],
  categories: [
    LangCategory(
      title: '8급 한자',
      emoji: '🈷️',
      desc: '一 二 三, 日 月 火 — 급수 시험 8급 50자를 익혀요',
      color: UnitColors.rose,
      units: [
        LangUnit(title: '8급 소리 찾기', emoji: '👂', typeIndex: 5),
        LangUnit(title: '8급 그림 찾기', emoji: '🖼️', typeIndex: 8),
        LangUnit(title: '8급 뜻 찾기', emoji: '📖', typeIndex: 6),
        LangUnit(title: '8급 한자 찾기', emoji: '🔍', typeIndex: 7),
        LangUnit(title: '한자어 읽기', emoji: '🈶', typeIndex: 9),
      ],
    ),
    LangCategory(
      title: '천자문 첫걸음',
      emoji: '⛅',
      desc: '하늘 천, 땅 지 — 훈음으로 한자를 만나요',
      color: UnitColors.violet,
      units: [
        LangUnit(title: '한자 소리 찾기', emoji: '👂', typeIndex: 0),
        LangUnit(title: '한자 보고 뜻 찾기', emoji: '🔍', typeIndex: 1),
      ],
    ),
    LangCategory(
      title: '천자문 익히기',
      emoji: '🍂',
      desc: '뜻과 그림으로 한자를 찾아요',
      color: UnitColors.mustard,
      units: [
        LangUnit(title: '뜻 보고 한자 찾기', emoji: '🔍', typeIndex: 2),
        LangUnit(title: '그림 보고 한자 찾기', emoji: '🖼️', typeIndex: 3),
      ],
    ),
    LangCategory(
      title: '천자문 박사',
      emoji: '📜',
      desc: '天地玄黃 — 네 글자 구절을 완성해요',
      color: UnitColors.teal,
      units: [
        LangUnit(title: '구절 완성', emoji: '📜', typeIndex: 4),
      ],
    ),
  ],
  // 별을 단계 번호 순서로 저장하던 시절의 묶음 순서 (기록 이사용 — 고치지 말 것)
  v1UnitTitles: const [
    '한자 소리 찾기',
    '한자 보고 뜻 찾기',
    '뜻 보고 한자 찾기',
    '그림 보고 한자 찾기',
    '구절 완성'
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

/// 8급: 앞 단계는 숫자·자연 25자, 뒤 단계는 50자
List<HanjaChar> _pool8(int stage) =>
    stage >= 5 ? hanjaGrade8 : hanjaGrade8.sublist(0, hanjaGrade8EasyCount);

LangQuestion _generate(int typeIndex, int stage, Random random) {
  // 8급 유형(5~8)은 천자문 유형(0~3)과 같은 모양, 글자 범위만 다르다
  if (typeIndex >= 5 && typeIndex <= 8) {
    final q = _generateFrom(typeIndex - 5, _pool8(stage), stage, random);
    return LangQuestion(
      typeIndex: typeIndex,
      instruction: q.instruction,
      display: q.display,
      subDisplay: q.subDisplay,
      choices: q.choices,
      answer: q.answer,
      answerText: q.answerText,
      speech: q.speech,
      dedupKey: 'g8:${q.dedupKey}',
    );
  }
  if (typeIndex == 9) {
    // 한자어 읽기: 父母 → 부모 (앞 단계는 앞 25자로만 된 낱말)
    final easy = {
      for (final c in hanjaGrade8.take(hanjaGrade8EasyCount)) c.char
    };
    final pool = stage >= 5
        ? hanjaWords8
        : [
            for (final w in hanjaWords8)
              if (w.$1.split('').every(easy.contains)) w
          ];
    final words = [...(pool.length >= 4 ? pool : hanjaWords8)]..shuffle(random);
    final target = words.first;
    // 읽기가 같은 낱말(日月·一月 = 일월)은 함께 내지 않는다
    final readings = <String>{target.$2};
    final wrong = <String>[];
    for (final w in words.skip(1)) {
      if (wrong.length == 3) break;
      if (readings.add(w.$2)) wrong.add(w.$2);
    }
    final meanings = [
      for (final ch in target.$1.split(''))
        hanjaGrade8.firstWhere((c) => c.char == ch).hun
    ];
    return LangQuestion(
      typeIndex: 9,
      instruction: '이 낱말은 어떻게 읽을까요?',
      display: target.$1,
      subDisplay: stage < 5 ? '(${meanings.join(' + ')})' : '',
      choices: [target.$2, ...wrong]..shuffle(random),
      answer: target.$2,
      answerText: '${target.$1} = ${target.$2}',
      speech: target.$2,
      dedupKey: 'hw:${target.$1}',
    );
  }
  return _generateFrom(typeIndex, _pool(stage), stage, random);
}

LangQuestion _generateFrom(
    int typeIndex, List<HanjaChar> charPool, int stage, Random random) {
  switch (typeIndex) {
    // 소리를 듣고 한자를 찾는다 ("하늘 천" → 天)
    case 0:
      final picked = _pick(charPool, random);
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
      final picked = _pick(charPool, random);
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
      final picked = _pick(charPool, random);
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
        for (final c in charPool)
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
      final phrase = phrases[random.nextInt(stage >= 5 ? phrases.length : 4)];
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
