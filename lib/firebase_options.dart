import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase 프로젝트 설정.
///
/// 아직 자리표시자(TODO) 상태이며, 이대로면 클라우드 동기화는 조용히 꺼진
/// 채 동작한다 (앱의 다른 기능에는 영향 없음).
///
/// 채우는 방법 (한 번만):
///  1) https://console.firebase.google.com 에서 프로젝트 만들기
///  2) 프로젝트 설정 → 내 앱 → 웹 앱(</>)과 Android 앱을 각각 등록
///  3) 표시되는 구성 값(apiKey 등)을 아래 web/android에 옮겨 적기
/// 또는 Windows에서 `flutterfire configure`를 실행하면 이 파일이
/// 자동 생성본으로 통째로 바뀌는데, 그래도 정상 동작한다.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return android;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    authDomain: 'TODO',
    storageBucket: 'TODO',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'TODO',
    appId: 'TODO',
    messagingSenderId: 'TODO',
    projectId: 'TODO',
    storageBucket: 'TODO',
  );
}
