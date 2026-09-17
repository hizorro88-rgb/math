# 작업 메모 (Claude용)

미취학~초등 3·4학년용 5과목(수학·한글·영어·일본어·중국어) 학습 게임.
서버 없는 Flutter 앱 — 모든 기록은 SharedPreferences(프로필 스코프)에 저장.

## 기능을 추가하거나 고친 뒤 반드시 할 일 (사용자와 약속)

1. `flutter analyze` + `flutter test` 전부 통과 확인
2. pubspec.yaml 버전 올리고 커밋 → `claude/preschool-math-quiz-app-pvy4y4` 브랜치에 푸시
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
- 사용자의 빌드 PC(Windows, D:\math)는 JDK 21(Temurin) + NDK 30.0.16248370 고정.
