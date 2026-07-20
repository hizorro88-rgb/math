# 🦉 수학 놀이 (Preschool Math)

미취학 아동을 위한 듀오링고 스타일 덧셈·뺄셈 퀴즈 앱입니다.
Flutter로 만들어져 **Android와 iOS 모두**에서 동작합니다.

## 주요 기능

- ➕➖ **덧셈 / 뺄셈 / 섞어서** 모드 선택
- 🐣 **난이도 2단계**: 쉬워요(5까지), 보통이에요(10까지)
- 🍎 문제마다 **이모지 그림 힌트**로 개수 세기 연습 (뺄셈은 빼는 만큼 흐리게 표시)
- 👆 **버튼 클릭 방식** 4지선다 — 글자 입력이 필요 없어요
- 📊 듀오링고처럼 **진행 바 + 정답/오답 피드백 판**이 아래에서 나타나요
- ⭐ 한 판 10문제, 끝나면 **별점과 칭찬 메시지**

## 화면 구성

1. **홈 화면** — 모드와 난이도를 큰 카드로 선택하고 시작
2. **퀴즈 화면** — 문제, 이모지 힌트, 큰 보기 버튼 4개, 정답 시 초록/오답 시 빨강 피드백
3. **결과 화면** — 별(최대 3개), 맞힌 개수, 다시 하기 / 처음으로

## 실행 방법

[Flutter SDK](https://docs.flutter.dev/get-started/install)(3.3 이상)가 설치되어 있어야 합니다.

```bash
git clone https://github.com/hizorro88-rgb/math.git
cd math
flutter pub get
flutter run          # 연결된 기기/에뮬레이터에서 실행
```

### 릴리즈 빌드

```bash
flutter build apk    # Android APK
flutter build ios    # iOS (macOS + Xcode 필요)
```

## 테스트

```bash
flutter test         # 문제 생성 규칙 + 홈 화면 위젯 테스트
flutter analyze      # 정적 분석
```

## 프로젝트 구조

```
lib/
├── main.dart                  # 앱 진입점, 테마
├── models/
│   ├── quiz_config.dart       # 모드·난이도 설정
│   └── question.dart          # 문제 생성 로직 (정답·보기 규칙)
└── screens/
    ├── home_screen.dart       # 홈(모드·난이도 선택)
    ├── quiz_screen.dart       # 퀴즈 진행 + 피드백 판
    └── result_screen.dart     # 결과(별점·다시 하기)
```

## 문제 출제 규칙

- 덧셈: 두 수의 합이 난이도 최대값(5 또는 10)을 넘지 않음
- 뺄셈: 답이 항상 0 이상 (음수 없음)
- 피연산자는 항상 1 이상 (`0 + 3` 같은 문제는 나오지 않음)
- 보기 4개는 정답 근처의 그럴듯한 수로 구성, 음수 없음
- 같은 문제가 연달아 나오지 않음
