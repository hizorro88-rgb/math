# 작업 메모 (Claude용)

미취학~초등 3·4학년용 5과목(수학·한글·영어·일본어·중국어) 학습 게임.
서버 없는 Flutter 앱 — 모든 기록은 SharedPreferences(프로필 스코프)에 저장.

## 기능을 추가하거나 고친 뒤 반드시 할 일 (사용자와 약속)

1. `flutter analyze` + `flutter test` 전부 통과 확인
2. pubspec.yaml 버전 올리고(lib/theme.dart의 appVersionLabel도 함께) 커밋 → `claude/preschool-math-quiz-app-pvy4y4` 브랜치에 푸시
3. **웹 버전도 같은 링크로 재게시** — 사용자가 매 기능마다 웹 업데이트를 요청함
   - 공개 웹은 GitHub Pages가 푸시마다 자동 배포한다
     (.github/workflows/deploy-web.yml → https://dopamingo.dopamine.me.kr)
   - 아티팩트 URL: https://claude.ai/artifact/1xyFQtr5HJfyj7gVvMtKVH
   - 순서 (임시 패치라 빌드 후 반드시 원상복구):
     a. 한글·이모지 폰트를 assets/fonts/에 복사 (스크래치패드 fonts/ 캐시,
        NotoSansKR은 pyftsubset으로 서브셋해 2MB대로 줄인 것 사용)
     b. pubspec.yaml에 fonts 섹션 + assets/fonts/ 추가,
        lib/main.dart 테마에 fontFamily 'NotoSansKR' + NotoColorEmoji 폴백 추가
     c. `flutter build web --release --no-web-resources-cdn`
     d. build/web에서 index.html을 아티팩트용(제목+스타일+flutter_bootstrap.js만)으로
        바꾸고, AssetManifest.bin·.symbols·flutter_service_worker.js 제외하고
        위 URL로 재게시 (.wasm은 contentType application/wasm 명시)
     e. `git restore pubspec.yaml lib/main.dart && rm -rf assets/fonts`

## 주의사항

- main 브랜치는 사용자 허락 없이 푸시하지 않는다 (개발 브랜치만 푸시).
- 커밋 메시지·PR 등 저장소에 남는 어디에도 모델 ID를 적지 않는다.
- 위젯 테스트에서 플랫폼 채널(TTS·알림)을 await하면 영원히 멈춘다 —
  fire-and-forget 패턴 유지.
- 정답 자동 넘어가기(AutoNextBar)는 그려진 프레임 시간 기준 3초 —
  벽시계 기준으로 되돌리면 소리 재생 랙 때문에 즉시 넘어가는 버그가 재발한다.
- 전체 열기 코드는 lib/models/premium.dart의 unlockCode.
- 수학 커리큘럼에 유닛을 넣거나 순서를 바꾸면 단계 번호가 밀린다 —
  progress.dart의 level_stars 키를 올리고(현재 v5) 직전 버전의
  유닛 제목 목록을 추가해 제목 기반 마이그레이션으로 별 기록을 지킬 것.
  이용권 화면의 단계 수 문구와 시드 배열 길이도 함께 갱신.
- 언어 팩(lib/models/language_pack.dart)은 두 가지 방식이 있다.
  일본어·중국어·한자는 유형 기반(generateOne), 영어회화는 주제 기반
  (generateLevel — 한 판 10문제를 팩이 통째로 만든다, unitBased=true).
  주제 기반 팩은 연습 화면이 유형 대신 주제를 고르게 하고,
  퀴즈 화면은 문제마다 다른 유형(q.typeIndex)으로 그린다.
- 영어회화 표현 데이터(주제 30개 × 100개 = 3000개)는
  lib/models/conversation_data_t1~t3.dart가 원본이다. 그 파일을 직접 고치되
  규칙을 지킬 것: 영어는 아스키만·1~6낱말, 3000개 전체에서 표현이 겹치지 않고,
  한 주제 안에서는 한국어 뜻도 겹치지 않아야 한다(보기 4개가 같아지면 안 됨).
  test/conversation_pack_test.dart가 이 규칙을 전부 검사한다.
  주제를 넣거나 빼면 conversation_pack.dart의 제목 목록과
  이용권 화면의 단계 수 문구도 함께 갱신.
- 말하기 연습(lib/services/voice_input.dart)은 마이크를 쓴다.
  음성 인식(speech_to_text)과 녹음(record)이 마이크를 공유하므로
  busy 플래그로 한 번에 하나만 돌린다. 위젯 테스트 setUp에서
  `VoiceInput.enabled = false`를 넣지 않으면 플랫폼 채널에서 멈춘다.
  채점은 낱말 겹침 60% 이상이면 통과 — 엄격하게 바꾸면 잘 말해도
  계속 틀려서 아이가 포기한다(test/speaking_score_test.dart가 기준을 지킨다).
  권한: AndroidManifest RECORD_AUDIO + RecognitionService queries,
  iOS Info.plist NSMicrophoneUsageDescription·NSSpeechRecognitionUsageDescription.
- 홈 화면 맨 위는 쿼카가 아니라 친구(펫)다 — 다마고치처럼 홈에서 바로
  밥·물을 준다(lib/widgets/home_pet_card.dart). 헤더에 펫 버튼을 다시
  만들지 말 것. 쿼카는 선생님 역할로 퀴즈·결과·꾸미기 가게에만 남는다
  (꾸민 아이템은 가게의 쿼카에서 확인한다).
- 친구 고르기는 온보딩에서 이름을 넣은 바로 다음에 나온다
  (onboarding_screen의 _goToPetPick → PetIntroScreen).
- 펫 키우기(lib/models/pet.dart)의 설계 원칙 — 방치해도 벌하지 않는다.
  배가 고파도 아프거나 죽지 않고 졸려 보일 뿐이고, 단계는 절대 내려가지
  않는다. 매일 열지 않으면 손해라는 압박을 아이에게 주지 않기 위해서다.
  진화 조건은 별(학습)과 돌봄을 둘 다 봐야 한다 — 코인으로 밥만 먹여서
  진화를 사는 우회로가 생기면 공부를 건너뛴다. 하루 돌봄 횟수 제한도
  같은 이유이니 풀지 말 것(test/pet_test.dart가 이 규칙들을 지킨다).
  캐릭터 그림은 지금 임시 이모지(PetSpecies.stages)이고,
  도트 그림이 준비되면 assets/images/pets/<종id>_<단계>.png로 교체한다.
- 사용자의 빌드 PC(Windows, D:\math)는 JDK 21(Temurin) + NDK 30.0.16248370 고정.
- 클라우드 동기화(lib/services/cloud_sync.dart): lib/firebase_options.dart가
  TODO 자리표시자면 조용히 꺼진다. 사용자가 Firebase 콘솔 구성값을 주면
  그 파일만 채워서 푸시하면 켜진다. Firestore 규칙은 families/{uid}를
  본인(uid)만 읽고 쓰게 제한할 것. 데이터는 백업 코드와 같은 형식을
  JSON 문자열로 묶어 families/{uid} 문서 하나에 저장 (나중 저장이 이김).

## UI/UX 개선 사이클 기록 (2026-09, 10회 완료)

전문가 리뷰 에이전트와 10회 반복 개선. 출시 준비도 84점 → 96.1점,
최종 판정 "출시 승인(GO)". 남은 것은 코드가 아니라 프로덕션 에셋:

1. ~~오리지널 캐릭터 에셋~~ → 2026-09 마스코트를 쿼카로 교체 완료
   (assets/images/quokka.png·quokka_blink.png, 픽셀랩 생성 128px.
   픽셀랩 무료 크레딧 소진 + api.pixellab.ai가 프록시에 막혀 있어서
   inspect 픽셀 그리드를 전사해 복원했음. 추가 표정·성장 단계는
   크레딧 충전 후 같은 스타일로 생성)
2. 사운드 디자인 (효과음 세트, 오답음은 격려 톤)
3. 스토어 출시 파이프라인 (IAP 실연결·개인정보 정책 페이지·심사 요건)
4. 모션 연출 (진화·스티커 부착 등 — 에셋 이후)
5. 실사용 관찰 테스트 (5~9세 3~5명, 게이트 실패율·동선 발견율)

스크린샷 파이프라인: scratchpad/ux/shoot.sh (임시 패치 → 웹 빌드 →
14화면 캡처 → 원상복구). 시드는 프로필 1이라 접두사 없는 키를 쓸 것.
