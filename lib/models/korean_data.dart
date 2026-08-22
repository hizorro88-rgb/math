/// 한글 퀴즈에서 쓰는 낱말·자모 데이터.
/// 낱말은 아이가 아는 그림(이모지)과 짝지을 수 있는 것만 담는다.
library;

/// 낱말 하나: 글자와 그림.
/// [group]이 같은 낱말끼리는 그림이 헷갈릴 수 있어서(예: 자동차/경찰차)
/// 같은 판의 보기에 함께 나오지 않는다.
class KrWord {
  const KrWord(this.word, this.emoji, [this.group]);

  final String word;
  final String emoji;
  final String? group;
}

/// 두 글자 낱말 (한글 첫걸음용)
const List<KrWord> krWords2 = [
  KrWord('사과', '🍎', 'redfruit'),
  KrWord('포도', '🍇'),
  KrWord('수박', '🍉'),
  KrWord('딸기', '🍓', 'redfruit'),
  KrWord('체리', '🍒', 'redfruit'),
  KrWord('레몬', '🍋'),
  KrWord('당근', '🥕'),
  KrWord('오이', '🥒'),
  KrWord('감자', '🥔'),
  KrWord('버섯', '🍄'),
  KrWord('우유', '🥛'),
  KrWord('치즈', '🧀'),
  KrWord('피자', '🍕'),
  KrWord('사탕', '🍬', 'snack'),
  KrWord('과자', '🍪', 'snack'),
  KrWord('도넛', '🍩', 'snack'),
  KrWord('나무', '🌳'),
  KrWord('장미', '🌹'),
  KrWord('나비', '🦋'),
  KrWord('꿀벌', '🐝'),
  KrWord('토끼', '🐰'),
  KrWord('사자', '🦁'),
  KrWord('여우', '🦊'),
  KrWord('판다', '🐼'),
  KrWord('오리', '🦆', 'bird'),
  KrWord('펭귄', '🐧', 'bird'),
  KrWord('상어', '🦈'),
  KrWord('문어', '🐙'),
  KrWord('고래', '🐳'),
  KrWord('구름', '☁️'),
  KrWord('우산', '☔'),
  KrWord('달님', '🌙'),
  KrWord('눈꽃', '❄️'),
  KrWord('모자', '🎩'),
  KrWord('가방', '🎒'),
  KrWord('신발', '👟'),
  KrWord('양말', '🧦'),
  KrWord('안경', '👓'),
  KrWord('시계', '⏰'),
  KrWord('열쇠', '🔑'),
  KrWord('연필', '✏️'),
  KrWord('가위', '✂️'),
  KrWord('왕관', '👑'),
  KrWord('반지', '💍'),
  KrWord('전화', '☎️'),
  KrWord('풍선', '🎈'),
  KrWord('선물', '🎁'),
  KrWord('로봇', '🤖'),
  KrWord('학교', '🏫'),
  KrWord('기차', '🚂', 'vehicle'),
  KrWord('버스', '🚌', 'vehicle'),
  KrWord('로켓', '🚀', 'vehicle'),
  KrWord('축구', '⚽', 'ball'),
  KrWord('야구', '⚾', 'ball'),
  KrWord('드럼', '🥁', 'music'),
  KrWord('기타', '🎸', 'music'),
];

/// 세 글자 낱말 (긴 낱말 도전용)
const List<KrWord> krWords3 = [
  KrWord('바나나', '🍌'),
  KrWord('토마토', '🍅', 'redfruit'),
  KrWord('복숭아', '🍑'),
  KrWord('옥수수', '🌽'),
  KrWord('케이크', '🎂', 'snack'),
  KrWord('햄버거', '🍔'),
  KrWord('코끼리', '🐘'),
  KrWord('원숭이', '🐵'),
  KrWord('호랑이', '🐯'),
  KrWord('강아지', '🐶'),
  KrWord('고양이', '🐱'),
  KrWord('병아리', '🐤', 'bird'),
  KrWord('개구리', '🐸'),
  KrWord('거북이', '🐢'),
  KrWord('다람쥐', '🐿️'),
  KrWord('코알라', '🐨'),
  KrWord('무지개', '🌈'),
  KrWord('눈사람', '⛄'),
  KrWord('자전거', '🚲', 'vehicle'),
  KrWord('소방차', '🚒', 'vehicle'),
  KrWord('경찰차', '🚓', 'vehicle'),
  KrWord('비행기', '✈️', 'vehicle'),
  KrWord('자동차', '🚗', 'vehicle'),
  KrWord('피아노', '🎹', 'music'),
  KrWord('사진기', '📷'),
  KrWord('크레용', '🖍️'),
];

/// 모든 낱말
final List<KrWord> krAllWords = [...krWords2, ...krWords3];

/// 기본 모음과 소리 (ㅏ → "아")
const List<({String letter, String sound})> krVowels = [
  (letter: 'ㅏ', sound: '아'),
  (letter: 'ㅑ', sound: '야'),
  (letter: 'ㅓ', sound: '어'),
  (letter: 'ㅕ', sound: '여'),
  (letter: 'ㅗ', sound: '오'),
  (letter: 'ㅛ', sound: '요'),
  (letter: 'ㅜ', sound: '우'),
  (letter: 'ㅠ', sound: '유'),
  (letter: 'ㅡ', sound: '으'),
  (letter: 'ㅣ', sound: '이'),
];

/// 기본 자음 14개와 이름 (ㄱ → "기역")
const List<({String letter, String name})> krConsonantNames = [
  (letter: 'ㄱ', name: '기역'),
  (letter: 'ㄴ', name: '니은'),
  (letter: 'ㄷ', name: '디귿'),
  (letter: 'ㄹ', name: '리을'),
  (letter: 'ㅁ', name: '미음'),
  (letter: 'ㅂ', name: '비읍'),
  (letter: 'ㅅ', name: '시옷'),
  (letter: 'ㅇ', name: '이응'),
  (letter: 'ㅈ', name: '지읒'),
  (letter: 'ㅊ', name: '치읓'),
  (letter: 'ㅋ', name: '키읔'),
  (letter: 'ㅌ', name: '티읕'),
  (letter: 'ㅍ', name: '피읖'),
  (letter: 'ㅎ', name: '히읗'),
];

/// 가나다 순서 (ㅏ 모음 음절)
const List<String> krSyllablesA = [
  '가', '나', '다', '라', '마', '바', '사', '아', '자', '차', '카', '타', '파', '하', //
];

/// ㅗ 모음 음절 (듣기·순서 심화용)
const List<String> krSyllablesO = [
  '고', '노', '도', '로', '모', '보', '소', '오', '조', '초', '코', '토', '포', '호', //
];

/// 기본 자음 14개 (첫소리 찾기 보기용)
const List<String> krBasicConsonants = [
  'ㄱ', 'ㄴ', 'ㄷ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅅ', 'ㅇ', 'ㅈ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ', //
];

const List<String> _choseong = [
  'ㄱ', 'ㄲ', 'ㄴ', 'ㄷ', 'ㄸ', 'ㄹ', 'ㅁ', 'ㅂ', 'ㅃ', 'ㅅ', //
  'ㅆ', 'ㅇ', 'ㅈ', 'ㅉ', 'ㅊ', 'ㅋ', 'ㅌ', 'ㅍ', 'ㅎ',
];

/// 기본 자음의 초성 인덱스 (유니코드 한글 조합용)
const Map<String, int> _choseongIndex = {
  'ㄱ': 0, 'ㄴ': 2, 'ㄷ': 3, 'ㄹ': 5, 'ㅁ': 6, 'ㅂ': 7, 'ㅅ': 9, //
  'ㅇ': 11, 'ㅈ': 12, 'ㅊ': 14, 'ㅋ': 15, 'ㅌ': 16, 'ㅍ': 17, 'ㅎ': 18,
};

/// 기본 모음의 중성 인덱스
const Map<String, int> _jungseongIndex = {
  'ㅏ': 0, 'ㅑ': 2, 'ㅓ': 4, 'ㅕ': 6, 'ㅗ': 8, 'ㅛ': 12, //
  'ㅜ': 13, 'ㅠ': 17, 'ㅡ': 18, 'ㅣ': 20,
};

/// 자음과 모음을 합쳐 글자를 만든다. (ㄱ + ㅏ → 가)
String krCombine(String consonant, String vowel) {
  final code = 0xAC00 +
      _choseongIndex[consonant]! * 21 * 28 +
      _jungseongIndex[vowel]! * 28;
  return String.fromCharCode(code);
}

/// 낱말 첫 글자의 첫소리(초성)를 돌려준다. (사과 → ㅅ)
String krFirstConsonant(String word) {
  final code = word.codeUnitAt(0) - 0xAC00;
  return _choseong[code ~/ (21 * 28)];
}
