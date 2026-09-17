import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

/// Firebase 프로젝트 설정 (dopamingo).
///
/// 이 값들은 앱에 공개적으로 들어가는 클라이언트 구성값이다 —
/// 실제 접근 제어는 Firestore 보안 규칙(families/{uid} 본인만)이 담당한다.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    return android;
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyAejJGbQ6vxFDJDd5yJIV-LPIH819Iv1mI',
    appId: '1:187012476812:web:64ccc567457ec8e6a5f0a9',
    messagingSenderId: '187012476812',
    projectId: 'dopamingo',
    authDomain: 'dopamingo.firebaseapp.com',
    storageBucket: 'dopamingo.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyCQ9Hw5YAUDLeQtkcYFzrg8-vklrZ6UQXo',
    appId: '1:187012476812:android:f1ec584bbe5af026a5f0a9',
    messagingSenderId: '187012476812',
    projectId: 'dopamingo',
    storageBucket: 'dopamingo.firebasestorage.app',
  );
}
