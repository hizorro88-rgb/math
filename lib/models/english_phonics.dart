/// 파닉스(글자와 소리의 짝) 데이터.
///
/// 소리 합성(TTS)은 /b/ 같은 낱소리를 따로 내지 못해서, 낱소리 대신
/// "그림 낱말"로 소리를 익힌다: B → 🐻 bear, 가운데 소리 C_T → A,
/// 끝소리가 같은 짝 CAT·HAT, 두 글자 소리 SH → 🐑 sheep.
/// 그림이 하나뿐인 뜻으로 읽히는 낱말만 담는다.
library;

import 'english_data.dart';

/// 짧은 모음이 하나 든 세 글자(자음-모음-자음) 낱말 — 가운데 소리·읽기용
const List<EnWord> phonicsCvc = [
  // a
  EnWord('cat', '🐱'), EnWord('bat', '🦇'), EnWord('hat', '🎩', 'hat'),
  EnWord('rat', '🐀'), EnWord('can', '🥫'), EnWord('pan', '🍳'),
  EnWord('van', '🚐', 'vehicle'), EnWord('man', '👨'), EnWord('map', '🗺️'),
  EnWord('bag', '🎒'), EnWord('cap', '🧢', 'hat'), EnWord('ham', '🍖'),
  // e
  EnWord('hen', '🐔', 'bird'), EnWord('pen', '🖊️'), EnWord('ten', '🔟'),
  EnWord('net', '🥅'), EnWord('jet', '✈️'), EnWord('bed', '🛏️'),
  EnWord('red', '🔴'), EnWord('web', '🕸️'), EnWord('leg', '🦵'),
  // i
  EnWord('pig', '🐷'), EnWord('six', '6️⃣'), EnWord('lip', '👄'),
  EnWord('zip', '🤐'), EnWord('pin', '📌'), EnWord('bin', '🗑️'),
  EnWord('kid', '🧒'),
  // o
  EnWord('dog', '🐶'), EnWord('fox', '🦊'), EnWord('box', '📦'),
  EnWord('log', '🪵'), EnWord('pot', '🍲'),
  // u
  EnWord('bug', '🐛'), EnWord('mug', '☕', 'cup'), EnWord('sun', '☀️'),
  EnWord('bus', '🚌', 'vehicle'), EnWord('nut', '🥜'),
  EnWord('cup', '🥤', 'cup'),
  EnWord('hug', '🤗'), EnWord('tub', '🛁'), EnWord('run', '🏃'),
];

/// 짧은 모음 다섯
const List<String> phonicsVowels = ['A', 'E', 'I', 'O', 'U'];

/// 끝소리가 같은 낱말 모둠 (라임). 앞쪽은 세 글자, 뒤쪽은 조금 긴 낱말.
const Map<String, List<EnWord>> phonicsRhymes = {
  '-at': [
    EnWord('cat', '🐱'),
    EnWord('bat', '🦇'),
    EnWord('hat', '🎩'),
    EnWord('rat', '🐀'),
  ],
  '-an': [
    EnWord('can', '🥫'),
    EnWord('pan', '🍳'),
    EnWord('van', '🚐'),
    EnWord('man', '👨'),
  ],
  '-ap': [EnWord('map', '🗺️'), EnWord('cap', '🧢')],
  '-en': [EnWord('hen', '🐔'), EnWord('pen', '🖊️'), EnWord('ten', '🔟')],
  '-et': [EnWord('net', '🥅'), EnWord('jet', '✈️')],
  '-ed': [EnWord('bed', '🛏️'), EnWord('red', '🔴'), EnWord('sled', '🛷')],
  '-in': [EnWord('pin', '📌'), EnWord('bin', '🗑️')],
  '-og': [EnWord('dog', '🐶'), EnWord('log', '🪵'), EnWord('frog', '🐸')],
  '-ox': [EnWord('fox', '🦊'), EnWord('box', '📦'), EnWord('ox', '🐂')],
  '-ug': [EnWord('bug', '🐛'), EnWord('mug', '☕'), EnWord('hug', '🤗')],
  '-un': [EnWord('sun', '☀️'), EnWord('run', '🏃')],
  // 여기부터 뒤 단계 (조금 긴 낱말)
  '-ip': [
    EnWord('lip', '👄'),
    EnWord('zip', '🤐'),
    EnWord('ship', '🚢'),
    EnWord('chip', '🍟'),
  ],
  '-ock': [
    EnWord('sock', '🧦'),
    EnWord('rock', '🪨'),
    EnWord('clock', '⏰'),
    EnWord('lock', '🔒'),
  ],
  '-ake': [EnWord('cake', '🎂'), EnWord('snake', '🐍')],
  '-ing': [EnWord('ring', '💍'), EnWord('king', '🤴')],
  '-ail': [EnWord('snail', '🐌'), EnWord('mail', '📬'), EnWord('nail', '💅')],
  '-ee': [EnWord('bee', '🐝'), EnWord('tree', '🌳')],
  '-ar': [EnWord('car', '🚗'), EnWord('star', '⭐')],
};

/// 앞 단계에서 쓰는 라임 모둠 수 (짧은 모음 + 끝소리 모둠)
const phonicsEasyRhymeCount = 11;

/// 두 글자가 한 소리를 내는 낱말 (첫머리). [sound]는 대문자 두 글자.
class PhonicsCluster {
  const PhonicsCluster(this.sound, this.word, this.emoji);

  final String sound;
  final String word;
  final String emoji;

  /// 첫머리 두 글자를 빈칸으로: _ _ EEP
  String get blanked => '_ _ ${word.substring(sound.length).toUpperCase()}';
}

/// 이중 글자 (sh·ch·th·wh) — 앞 단계
const List<PhonicsCluster> phonicsDigraphs = [
  PhonicsCluster('SH', 'ship', '🚢'),
  PhonicsCluster('SH', 'sheep', '🐑'),
  PhonicsCluster('SH', 'shell', '🐚'),
  PhonicsCluster('SH', 'shoe', '👟'),
  PhonicsCluster('SH', 'shirt', '👕'),
  PhonicsCluster('SH', 'shark', '🦈'),
  PhonicsCluster('CH', 'chick', '🐤'),
  PhonicsCluster('CH', 'cheese', '🧀'),
  PhonicsCluster('CH', 'chair', '🪑'),
  PhonicsCluster('CH', 'cherry', '🍒'),
  PhonicsCluster('CH', 'chips', '🍟'),
  PhonicsCluster('TH', 'thumb', '👍'),
  PhonicsCluster('TH', 'three', '3️⃣'),
  PhonicsCluster('WH', 'whale', '🐳'),
];

/// 자음 두 개가 붙는 소리 (fr·tr·cr…) — 뒤 단계
const List<PhonicsCluster> phonicsBlends = [
  PhonicsCluster('FR', 'frog', '🐸'),
  PhonicsCluster('TR', 'tree', '🌳'),
  PhonicsCluster('TR', 'train', '🚂'),
  PhonicsCluster('TR', 'truck', '🚚'),
  PhonicsCluster('DR', 'drum', '🥁'),
  PhonicsCluster('DR', 'dragon', '🐉'),
  PhonicsCluster('CR', 'crab', '🦀'),
  PhonicsCluster('CR', 'crown', '👑'),
  PhonicsCluster('GR', 'grapes', '🍇'),
  PhonicsCluster('BR', 'bread', '🍞'),
  PhonicsCluster('BR', 'broom', '🧹'),
  PhonicsCluster('PL', 'plane', '✈️'),
  PhonicsCluster('PL', 'plant', '🪴'),
  PhonicsCluster('SN', 'snake', '🐍'),
  PhonicsCluster('SN', 'snail', '🐌'),
  PhonicsCluster('ST', 'star', '⭐'),
  PhonicsCluster('SW', 'swan', '🦢'),
  PhonicsCluster('CL', 'clock', '⏰'),
  PhonicsCluster('CL', 'cloud', '☁️'),
  PhonicsCluster('FL', 'flower', '🌸'),
];

/// 첫소리를 익힐 그림 — 글자마다 손으로 고른, 이름이 하나뿐인 그림.
/// (🧢는 cap도 hat도 되고, ☕는 mug도 cup도 돼서 첫소리 문제에 못 쓴다)
/// 앞 단계 글자는 글자 이름에 그 소리가 들어 있는 것만(B=비, M=엠…).
/// C·G·H·W와 모음은 이름과 소리가 달라 뒤 단계에서 나온다.
const Map<String, List<EnWord>> phonicsLetterWords = {
  'B': [
    EnWord('bear', '🐻'),
    EnWord('bee', '🐝'),
    EnWord('banana', '🍌'),
    EnWord('bus', '🚌'),
    EnWord('bed', '🛏️'),
    EnWord('bike', '🚲'),
  ],
  'D': [EnWord('dog', '🐶'), EnWord('duck', '🦆'), EnWord('door', '🚪')],
  'F': [
    EnWord('fish', '🐟'),
    EnWord('fox', '🦊'),
    EnWord('fire', '🔥'),
    EnWord('foot', '🦶'),
  ],
  'J': [EnWord('juice', '🧃'), EnWord('jeans', '👖')],
  'K': [
    EnWord('key', '🔑'),
    EnWord('kite', '🪁'),
    EnWord('king', '🤴'),
    EnWord('koala', '🐨'),
    EnWord('kangaroo', '🦘'),
  ],
  'L': [EnWord('lion', '🦁'), EnWord('lemon', '🍋'), EnWord('leaf', '🍃')],
  'M': [
    EnWord('monkey', '🐵'),
    EnWord('moon', '🌙'),
    EnWord('mouse', '🐭'),
    EnWord('milk', '🥛'),
  ],
  'N': [EnWord('nose', '👃'), EnWord('nut', '🥜'), EnWord('nine', '9️⃣')],
  'P': [
    EnWord('pig', '🐷'),
    EnWord('pizza', '🍕'),
    EnWord('panda', '🐼'),
    EnWord('penguin', '🐧'),
    EnWord('pencil', '✏️'),
  ],
  'R': [
    EnWord('rabbit', '🐰'),
    EnWord('robot', '🤖'),
    EnWord('rainbow', '🌈'),
    EnWord('ring', '💍'),
    EnWord('rocket', '🚀'),
  ],
  'S': [
    EnWord('sun', '☀️'),
    EnWord('snake', '🐍'),
    EnWord('sock', '🧦'),
    EnWord('star', '⭐'),
    EnWord('spider', '🕷️'),
  ],
  'T': [
    EnWord('tiger', '🐯'),
    EnWord('tomato', '🍅'),
    EnWord('turtle', '🐢'),
    EnWord('tooth', '🦷'),
    EnWord('ten', '🔟'),
  ],
  'V': [EnWord('violin', '🎻'), EnWord('volcano', '🌋')],
  'Z': [EnWord('zebra', '🦓'), EnWord('zero', '0️⃣')],
  // 여기부터 뒤 단계
  'A': [EnWord('ant', '🐜'), EnWord('apple', '🍎'), EnWord('alligator', '🐊')],
  'C': [
    EnWord('cat', '🐱'),
    EnWord('cow', '🐮'),
    EnWord('cake', '🎂'),
    EnWord('carrot', '🥕'),
    EnWord('camel', '🐫'),
  ],
  'E': [EnWord('egg', '🥚'), EnWord('elephant', '🐘')],
  'G': [EnWord('goat', '🐐'), EnWord('gorilla', '🦍'), EnWord('guitar', '🎸')],
  'H': [
    EnWord('horse', '🐴'),
    EnWord('house', '🏠'),
    EnWord('hippo', '🦛'),
    EnWord('honey', '🍯'),
  ],
  'O': [EnWord('octopus', '🐙'), EnWord('ox', '🐂')],
  'U': [EnWord('umbrella', '☂️')],
  'W': [EnWord('watermelon', '🍉'), EnWord('wolf', '🐺')],
  'Q': [EnWord('queen', '👸')],
};

/// 앞 단계 글자 수 (B D F J K L M N P R S T V Z)
const phonicsEasyLetterCount = 14;

/// 같은 소리를 내는 글자 (C·K·Q는 모두 /k/) — 서로 오답으로 내지 않는다
String phonicsSoundGroup(String letter) =>
    const {'C': 'K', 'Q': 'K'}[letter] ?? letter;
