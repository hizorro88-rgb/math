/// 영어 단어 퀴즈 데이터 — 낱말·그림·한국어 뜻·주제.
///
/// 규칙 (test/english_vocab_test.dart가 지킨다):
/// - 영어 낱말은 전체에서 한 번만 (orange처럼 뜻이 둘이면 하나만 넣는다)
/// - 한 주제 안에서 한국어 뜻·그림이 겹치지 않는다 (보기 4개가 같아지면 안 된다)
/// - 뜻이 같은 말이 다른 주제에 있으면(눈 eye / 눈 snow) 뜻 문제에서 함께 나오지 않는다
library;

/// 단어 하나
class EnVocab {
  const EnVocab(this.word, this.emoji, this.ko, this.theme);

  /// 소문자 영어 낱말 (발음도 이것으로)
  final String word;
  final String emoji;

  /// 한국어 뜻 (아이가 아는 가장 쉬운 말)
  final String ko;

  /// 주제 id ([enThemes]의 키)
  final String theme;

  String get shown => word.toUpperCase();
}

/// 주제 id → (이름, 그림)
const Map<String, (String, String)> enThemes = {
  'color': ('색깔', '🎨'),
  'number': ('숫자', '🔢'),
  'body': ('몸', '👂'),
  'family': ('가족', '👪'),
  'action': ('동작', '🏃'),
  'feeling': ('기분', '😊'),
  'animal': ('동물', '🐶'),
  'food': ('음식', '🍎'),
  'thing': ('물건', '🎒'),
  'nature': ('자연', '🌳'),
  'vehicle': ('탈것', '🚗'),
};

const List<EnVocab> enVocab = [
  // 색깔 — 그림은 색 동그라미
  EnVocab('red', '🔴', '빨간색', 'color'),
  EnVocab('blue', '🔵', '파란색', 'color'),
  EnVocab('yellow', '🟡', '노란색', 'color'),
  EnVocab('green', '🟢', '초록색', 'color'),
  EnVocab('orange', '🟠', '주황색', 'color'),
  EnVocab('purple', '🟣', '보라색', 'color'),
  EnVocab('black', '⚫', '검은색', 'color'),
  EnVocab('white', '⚪', '흰색', 'color'),
  EnVocab('brown', '🟤', '갈색', 'color'),
  // 숫자
  EnVocab('one', '1️⃣', '하나', 'number'),
  EnVocab('two', '2️⃣', '둘', 'number'),
  EnVocab('three', '3️⃣', '셋', 'number'),
  EnVocab('four', '4️⃣', '넷', 'number'),
  EnVocab('five', '5️⃣', '다섯', 'number'),
  EnVocab('six', '6️⃣', '여섯', 'number'),
  EnVocab('seven', '7️⃣', '일곱', 'number'),
  EnVocab('eight', '8️⃣', '여덟', 'number'),
  EnVocab('nine', '9️⃣', '아홉', 'number'),
  EnVocab('ten', '🔟', '열', 'number'),
  // 몸
  EnVocab('eye', '👁️', '눈', 'body'),
  EnVocab('ear', '👂', '귀', 'body'),
  EnVocab('nose', '👃', '코', 'body'),
  EnVocab('mouth', '👄', '입', 'body'),
  EnVocab('hand', '✋', '손', 'body'),
  EnVocab('foot', '🦶', '발', 'body'),
  EnVocab('leg', '🦵', '다리', 'body'),
  EnVocab('arm', '💪', '팔', 'body'),
  EnVocab('tooth', '🦷', '이', 'body'),
  // 가족
  EnVocab('mom', '👩', '엄마', 'family'),
  EnVocab('dad', '👨', '아빠', 'family'),
  EnVocab('baby', '👶', '아기', 'family'),
  EnVocab('grandma', '👵', '할머니', 'family'),
  EnVocab('grandpa', '👴', '할아버지', 'family'),
  EnVocab('boy', '👦', '남자아이', 'family'),
  EnVocab('girl', '👧', '여자아이', 'family'),
  EnVocab('family', '👪', '가족', 'family'),
  // 동작
  EnVocab('run', '🏃', '달리다', 'action'),
  EnVocab('swim', '🏊', '수영하다', 'action'),
  EnVocab('sleep', '😴', '자다', 'action'),
  EnVocab('read', '📖', '읽다', 'action'),
  EnVocab('sing', '🎤', '노래하다', 'action'),
  EnVocab('dance', '💃', '춤추다', 'action'),
  EnVocab('cry', '😭', '울다', 'action'),
  EnVocab('walk', '🚶', '걷다', 'action'),
  EnVocab('write', '✍️', '쓰다', 'action'),
  EnVocab('climb', '🧗', '오르다', 'action'),
  EnVocab('ride', '🚴', '타다', 'action'),
  EnVocab('eat', '😋', '먹다', 'action'),
  // 기분
  EnVocab('happy', '😊', '기쁜', 'feeling'),
  EnVocab('sad', '😞', '슬픈', 'feeling'),
  EnVocab('angry', '😠', '화난', 'feeling'),
  EnVocab('scared', '😨', '무서운', 'feeling'),
  EnVocab('sleepy', '😪', '졸린', 'feeling'),
  EnVocab('hot', '🥵', '더운', 'feeling'),
  EnVocab('cold', '🥶', '추운', 'feeling'),
  EnVocab('sick', '🤒', '아픈', 'feeling'),
  EnVocab('surprised', '😲', '놀란', 'feeling'),
  // 동물
  EnVocab('cat', '🐱', '고양이', 'animal'),
  EnVocab('dog', '🐶', '개', 'animal'),
  EnVocab('pig', '🐷', '돼지', 'animal'),
  EnVocab('cow', '🐮', '소', 'animal'),
  EnVocab('fox', '🦊', '여우', 'animal'),
  EnVocab('owl', '🦉', '부엉이', 'animal'),
  EnVocab('ant', '🐜', '개미', 'animal'),
  EnVocab('bee', '🐝', '벌', 'animal'),
  EnVocab('hen', '🐔', '닭', 'animal'),
  EnVocab('lion', '🦁', '사자', 'animal'),
  EnVocab('tiger', '🐯', '호랑이', 'animal'),
  EnVocab('bear', '🐻', '곰', 'animal'),
  EnVocab('fish', '🐟', '물고기', 'animal'),
  EnVocab('frog', '🐸', '개구리', 'animal'),
  EnVocab('duck', '🦆', '오리', 'animal'),
  EnVocab('horse', '🐴', '말', 'animal'),
  EnVocab('sheep', '🐑', '양', 'animal'),
  EnVocab('snake', '🐍', '뱀', 'animal'),
  EnVocab('whale', '🐳', '고래', 'animal'),
  EnVocab('rabbit', '🐰', '토끼', 'animal'),
  EnVocab('monkey', '🐵', '원숭이', 'animal'),
  EnVocab('zebra', '🦓', '얼룩말', 'animal'),
  EnVocab('turtle', '🐢', '거북', 'animal'),
  EnVocab('penguin', '🐧', '펭귄', 'animal'),
  EnVocab('mouse', '🐭', '쥐', 'animal'),
  EnVocab('elephant', '🐘', '코끼리', 'animal'),
  EnVocab('giraffe', '🦒', '기린', 'animal'),
  EnVocab('chick', '🐤', '병아리', 'animal'),
  EnVocab('octopus', '🐙', '문어', 'animal'),
  EnVocab('butterfly', '🦋', '나비', 'animal'),
  EnVocab('spider', '🕷️', '거미', 'animal'),
  EnVocab('crab', '🦀', '게', 'animal'),
  // 음식
  EnVocab('apple', '🍎', '사과', 'food'),
  EnVocab('banana', '🍌', '바나나', 'food'),
  EnVocab('grape', '🍇', '포도', 'food'),
  EnVocab('lemon', '🍋', '레몬', 'food'),
  EnVocab('strawberry', '🍓', '딸기', 'food'),
  EnVocab('watermelon', '🍉', '수박', 'food'),
  EnVocab('peach', '🍑', '복숭아', 'food'),
  EnVocab('tomato', '🍅', '토마토', 'food'),
  EnVocab('potato', '🥔', '감자', 'food'),
  EnVocab('carrot', '🥕', '당근', 'food'),
  EnVocab('corn', '🌽', '옥수수', 'food'),
  EnVocab('bread', '🍞', '빵', 'food'),
  EnVocab('milk', '🥛', '우유', 'food'),
  EnVocab('egg', '🥚', '달걀', 'food'),
  EnVocab('rice', '🍚', '밥', 'food'),
  EnVocab('cake', '🎂', '케이크', 'food'),
  EnVocab('candy', '🍬', '사탕', 'food'),
  EnVocab('cheese', '🧀', '치즈', 'food'),
  EnVocab('cookie', '🍪', '쿠키', 'food'),
  EnVocab('pizza', '🍕', '피자', 'food'),
  EnVocab('honey', '🍯', '꿀', 'food'),
  EnVocab('juice', '🧃', '주스', 'food'),
  // 물건
  EnVocab('hat', '🎩', '모자', 'thing'),
  EnVocab('key', '🔑', '열쇠', 'thing'),
  EnVocab('bed', '🛏️', '침대', 'thing'),
  EnVocab('box', '📦', '상자', 'thing'),
  EnVocab('cup', '🥤', '컵', 'thing'),
  EnVocab('bag', '🎒', '가방', 'thing'),
  EnVocab('book', '📕', '책', 'thing'),
  EnVocab('ball', '⚽', '공', 'thing'),
  EnVocab('clock', '⏰', '시계', 'thing'),
  EnVocab('shoe', '👟', '신발', 'thing'),
  EnVocab('sock', '🧦', '양말', 'thing'),
  EnVocab('chair', '🪑', '의자', 'thing'),
  EnVocab('pencil', '✏️', '연필', 'thing'),
  EnVocab('scissors', '✂️', '가위', 'thing'),
  EnVocab('umbrella', '☂️', '우산', 'thing'),
  EnVocab('glasses', '👓', '안경', 'thing'),
  EnVocab('phone', '📱', '전화기', 'thing'),
  EnVocab('door', '🚪', '문', 'thing'),
  EnVocab('house', '🏠', '집', 'thing'),
  EnVocab('balloon', '🎈', '풍선', 'thing'),
  EnVocab('gift', '🎁', '선물', 'thing'),
  EnVocab('bell', '🔔', '종', 'thing'),
  // 자연
  EnVocab('sun', '☀️', '해', 'nature'),
  EnVocab('moon', '🌙', '달', 'nature'),
  EnVocab('star', '⭐', '별', 'nature'),
  EnVocab('tree', '🌳', '나무', 'nature'),
  EnVocab('flower', '🌸', '꽃', 'nature'),
  EnVocab('cloud', '☁️', '구름', 'nature'),
  EnVocab('rain', '🌧️', '비', 'nature'),
  EnVocab('snow', '☃️', '눈', 'nature'),
  EnVocab('rainbow', '🌈', '무지개', 'nature'),
  EnVocab('fire', '🔥', '불', 'nature'),
  EnVocab('leaf', '🍃', '나뭇잎', 'nature'),
  EnVocab('sea', '🌊', '바다', 'nature'),
  EnVocab('mountain', '⛰️', '산', 'nature'),
  // 탈것
  EnVocab('car', '🚗', '자동차', 'vehicle'),
  EnVocab('bus', '🚌', '버스', 'vehicle'),
  EnVocab('train', '🚂', '기차', 'vehicle'),
  EnVocab('plane', '✈️', '비행기', 'vehicle'),
  EnVocab('ship', '🚢', '배', 'vehicle'),
  EnVocab('bike', '🚲', '자전거', 'vehicle'),
  EnVocab('truck', '🚚', '트럭', 'vehicle'),
  EnVocab('taxi', '🚕', '택시', 'vehicle'),
  EnVocab('rocket', '🚀', '로켓', 'vehicle'),
  EnVocab('helicopter', '🚁', '헬리콥터', 'vehicle'),
];

/// 자주 쓰는 낱말(사이트 워드) — 그림이 없어 소리와 모양으로 익힌다.
/// 앞쪽 24개는 첫 단계용(Dolch 유치부), 뒤쪽은 다음 단계.
const List<String> enSightWords = [
  'the', 'a', 'I', 'is', 'see', 'can', 'my', 'like', //
  'go', 'it', 'in', 'up', 'you', 'me', 'we', 'and', //
  'big', 'look', 'come', 'play', 'here', 'to', 'for', 'yes', //
  'no', 'he', 'she', 'was', 'are', 'have', 'do', 'not', //
  'on', 'at', 'this', 'that', 'what', 'all', 'said', 'they', //
  'with', 'there', 'little', 'down', 'where', 'went', 'get', 'good',
];

/// 첫 단계에서 쓰는 사이트 워드 수
const enSightEasyCount = 24;
