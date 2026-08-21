/// 한글 퀴즈에서 쓰는 낱말·자모 데이터.
/// 낱말은 아이가 아는 그림(이모지)과 짝지을 수 있는 것만 담는다.
library;

/// 낱말 하나: 글자와 그림
class KrWord {
  const KrWord(this.word, this.emoji);

  final String word;
  final String emoji;
}

/// 두 글자 낱말 (한글 첫걸음용)
const List<KrWord> krWords2 = [
  KrWord('사과', '🍎'),
  KrWord('포도', '🍇'),
  KrWord('수박', '🍉'),
  KrWord('딸기', '🍓'),
  KrWord('레몬', '🍋'),
  KrWord('당근', '🥕'),
  KrWord('우유', '🥛'),
  KrWord('치즈', '🧀'),
  KrWord('피자', '🍕'),
  KrWord('사탕', '🍬'),
  KrWord('과자', '🍪'),
  KrWord('김밥', '🍙'),
  KrWord('나무', '🌳'),
  KrWord('장미', '🌹'),
  KrWord('나비', '🦋'),
  KrWord('꿀벌', '🐝'),
  KrWord('토끼', '🐰'),
  KrWord('사자', '🦁'),
  KrWord('여우', '🦊'),
  KrWord('판다', '🐼'),
  KrWord('오리', '🦆'),
  KrWord('펭귄', '🐧'),
  KrWord('상어', '🦈'),
  KrWord('문어', '🐙'),
  KrWord('고래', '🐳'),
  KrWord('구름', '☁️'),
  KrWord('우산', '☔'),
  KrWord('모자', '🎩'),
  KrWord('가방', '🎒'),
  KrWord('신발', '👟'),
  KrWord('양말', '🧦'),
  KrWord('안경', '👓'),
  KrWord('시계', '⏰'),
  KrWord('열쇠', '🔑'),
  KrWord('연필', '✏️'),
  KrWord('가위', '✂️'),
  KrWord('풍선', '🎈'),
  KrWord('선물', '🎁'),
  KrWord('로봇', '🤖'),
  KrWord('기차', '🚂'),
  KrWord('버스', '🚌'),
  KrWord('축구', '⚽'),
  KrWord('야구', '⚾'),
  KrWord('기타', '🎸'),
];

/// 세 글자 낱말 (긴 낱말 도전용)
const List<KrWord> krWords3 = [
  KrWord('바나나', '🍌'),
  KrWord('토마토', '🍅'),
  KrWord('코끼리', '🐘'),
  KrWord('원숭이', '🐵'),
  KrWord('호랑이', '🐯'),
  KrWord('강아지', '🐶'),
  KrWord('고양이', '🐱'),
  KrWord('병아리', '🐤'),
  KrWord('개구리', '🐸'),
  KrWord('거북이', '🐢'),
  KrWord('다람쥐', '🐿️'),
  KrWord('코알라', '🐨'),
  KrWord('무지개', '🌈'),
  KrWord('눈사람', '⛄'),
  KrWord('자전거', '🚲'),
  KrWord('소방차', '🚒'),
  KrWord('경찰차', '🚓'),
  KrWord('비행기', '✈️'),
  KrWord('자동차', '🚗'),
  KrWord('햄버거', '🍔'),
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

/// 가나다 순서 (ㅏ 모음 음절)
const List<String> krSyllablesA = [
  '가', '나', '다', '라', '마', '바', '사', '아', '자', '차', '카', '타', '파', '하', //
];

/// ㅗ 모음 음절 (듣기 심화용)
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

/// 낱말 첫 글자의 첫소리(초성)를 돌려준다. (사과 → ㅅ)
String krFirstConsonant(String word) {
  final code = word.codeUnitAt(0) - 0xAC00;
  return _choseong[code ~/ (21 * 28)];
}
