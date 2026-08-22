/// 영어 퀴즈에서 쓰는 낱말·알파벳 데이터.
/// 낱말은 아이가 아는 그림(이모지)과 짝지을 수 있는 것만 담는다.
library;

/// 영어 낱말 하나: 소문자 낱말과 그림.
/// 화면에는 대문자(APPLE)로 보여주고, 발음은 소문자 그대로 읽는다.
/// [group]이 같은 낱말끼리는 그림이 헷갈려서 같은 판 보기에 함께 안 나온다.
class EnWord {
  const EnWord(this.word, this.emoji, [this.group]);

  final String word;
  final String emoji;
  final String? group;

  String get shown => word.toUpperCase();
}

/// 세 글자 낱말 (낱말 만들기·첫걸음용)
const List<EnWord> enWordsShort = [
  EnWord('cat', '🐱'),
  EnWord('dog', '🐶'),
  EnWord('sun', '☀️'),
  EnWord('bee', '🐝'),
  EnWord('pig', '🐷'),
  EnWord('cow', '🐮'),
  EnWord('fox', '🦊'),
  EnWord('owl', '🦉'),
  EnWord('ant', '🐜'),
  EnWord('egg', '🥚'),
  EnWord('hat', '🎩'),
  EnWord('key', '🔑'),
  EnWord('pen', '🖊️'),
  EnWord('bed', '🛏️'),
  EnWord('box', '📦'),
  EnWord('cup', '🥤'),
  EnWord('bus', '🚌', 'vehicle'),
  EnWord('car', '🚗', 'vehicle'),
];

/// 긴 낱말 (4글자 이상)
const List<EnWord> enWordsLong = [
  EnWord('apple', '🍎'),
  EnWord('banana', '🍌'),
  EnWord('grape', '🍇'),
  EnWord('lemon', '🍋'),
  EnWord('pizza', '🍕'),
  EnWord('milk', '🥛'),
  EnWord('cake', '🎂', 'snack'),
  EnWord('candy', '🍬', 'snack'),
  EnWord('lion', '🦁'),
  EnWord('tiger', '🐯'),
  EnWord('bear', '🐻'),
  EnWord('fish', '🐟'),
  EnWord('frog', '🐸'),
  EnWord('duck', '🦆'),
  EnWord('star', '⭐'),
  EnWord('moon', '🌙'),
  EnWord('book', '📕'),
  EnWord('ball', '⚽'),
  EnWord('tree', '🌳'),
  EnWord('train', '🚂', 'vehicle'),
  EnWord('plane', '✈️', 'vehicle'),
  EnWord('robot', '🤖'),
  EnWord('house', '🏠'),
  EnWord('shoe', '👟'),
  EnWord('sock', '🧦'),
  EnWord('clock', '⏰'),
  EnWord('crown', '👑'),
];

/// 모든 영어 낱말
final List<EnWord> enAllWords = [...enWordsShort, ...enWordsLong];

/// 알파벳 대문자 26자
final List<String> enAlphabet = [
  for (var c = 'A'.codeUnitAt(0); c <= 'Z'.codeUnitAt(0); c++)
    String.fromCharCode(c),
];
