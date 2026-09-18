import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';
import 'backup.dart';

/// 가족 계정 클라우드 동기화 (Firebase 이메일 로그인 + Firestore).
///
/// - firebase_options.dart가 아직 자리표시자(TODO)면 조용히 꺼진 채 동작한다.
/// - 데이터는 백업 코드와 같은 형식({키: {t, v}})을 JSON 문자열 하나로 묶어
///   families/{uid} 문서에 저장한다. 나중에 저장한 쪽이 이긴다.
/// - 판을 끝낼 때마다 몇 초 뒤 자동 업로드, 앱을 켤 때 클라우드가 더
///   최신이면 자동 복원한다.
class CloudSync {
  CloudSync._();

  /// 마지막으로 클라우드와 맞춘 시각 (이 기기에만 저장, 백업에서 제외)
  static const _syncAtKey = 'cloud_sync_at_v1';

  /// Firebase 설정이 채워져 있고 초기화에 성공했는지
  static bool available = false;

  static Timer? _uploadTimer;

  static Future<void> init() async {
    if (DefaultFirebaseOptions.currentPlatform.apiKey == 'TODO') return;
    try {
      // 웹에서 Firebase JS 로딩이 차단된 환경(회사망 등)이면 영영 끝나지
      // 않을 수 있어, 시간을 정해 두고 안 되면 클라우드 없이 계속 간다.
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      ).timeout(const Duration(seconds: 8));
      available = true;
    } catch (_) {
      available = false;
    }
  }

  static User? get _user =>
      available ? FirebaseAuth.instance.currentUser : null;
  static bool get signedIn => _user != null;
  static String? get email => _user?.email;

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('families').doc(_user!.uid);

  /// 로그인. 성공하면 null, 실패하면 보여줄 안내 문구를 돌려준다.
  static Future<String?> signIn(String email, String password) async {
    if (!available) return '클라우드 설정이 아직 되어 있지 않아요.';
    try {
      await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return '로그인에 실패했어요. 잠시 후 다시 해보세요.';
    }
    await _afterSignIn();
    return null;
  }

  /// 새 계정 만들기(가입). 성공하면 null, 실패하면 안내 문구.
  static Future<String?> signUp(String email, String password) async {
    if (!available) return '클라우드 설정이 아직 되어 있지 않아요.';
    try {
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email.trim(), password: password);
    } on FirebaseAuthException catch (e) {
      return _authMessage(e);
    } catch (_) {
      return '가입에 실패했어요. 잠시 후 다시 해보세요.';
    }
    await _afterSignIn();
    return null;
  }

  /// 로그인 직후: 클라우드에 기록이 있으면 내려받고, 없으면 지금 기록을 올린다.
  /// 복원이 일어났으면 true (호출한 쪽에서 화면·캐시를 새로 읽어야 한다).
  static Future<bool> _afterSignIn() async {
    final pulled = await pullIfNewer();
    if (!pulled) await uploadNow();
    return pulled;
  }

  static Future<void> signOut() async {
    if (!available) return;
    _uploadTimer?.cancel();
    try {
      await FirebaseAuth.instance.signOut();
    } catch (_) {}
  }

  /// 클라우드가 이 기기보다 최신이면 내려받아 복원한다. 복원했으면 true.
  static Future<bool> pullIfNewer() async {
    if (!signedIn) return false;
    try {
      final snap = await _doc.get().timeout(const Duration(seconds: 6));
      final saved = snap.data()?['saved'];
      final json = snap.data()?['json'];
      if (saved is! int || json is! String) return false;

      final prefs = await SharedPreferences.getInstance();
      final localAt = prefs.getInt(_syncAtKey) ?? 0;
      if (saved <= localAt) return false;

      final data = jsonDecode(json);
      if (data is! Map<String, dynamic>) return false;
      final ok = await BackupService.restoreData(data);
      if (ok) await prefs.setInt(_syncAtKey, saved);
      return ok;
    } catch (_) {
      return false;
    }
  }

  /// 지금 기록을 클라우드에 올린다. 성공하면 true.
  static Future<bool> uploadNow() async {
    if (!signedIn) return false;
    try {
      final data = await BackupService.exportData();
      if (data.isEmpty) return false;
      final saved = DateTime.now().toUtc().millisecondsSinceEpoch;
      await _doc
          .set({'saved': saved, 'json': jsonEncode(data)})
          .timeout(const Duration(seconds: 10));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_syncAtKey, saved);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 판이 끝났을 때 부르는 자동 업로드 (몇 초 모았다가 한 번만 올린다).
  /// 실패해도 조용히 넘어간다 — 다음 판이나 수동 동기화가 다시 시도한다.
  static void scheduleUpload() {
    if (!signedIn) return;
    _uploadTimer?.cancel();
    _uploadTimer = Timer(const Duration(seconds: 4), () {
      uploadNow().ignore();
    });
  }

  /// 마지막 동기화 시각 (없으면 null)
  static Future<DateTime?> lastSyncedAt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final at = prefs.getInt(_syncAtKey);
      if (at == null || at == 0) return null;
      return DateTime.fromMillisecondsSinceEpoch(at, isUtc: true).toLocal();
    } catch (_) {
      return null;
    }
  }

  static String _authMessage(FirebaseAuthException e) => switch (e.code) {
        'invalid-email' => '이메일 주소 모양이 올바르지 않아요.',
        'user-not-found' => '이 이메일로 만든 계정이 없어요. [새 계정]을 눌러 보세요.',
        'wrong-password' ||
        'invalid-credential' =>
          '이메일 또는 비밀번호가 맞지 않아요.',
        'email-already-in-use' => '이미 가입된 이메일이에요. [로그인]을 눌러 보세요.',
        'weak-password' => '비밀번호를 6자 이상으로 해주세요.',
        'network-request-failed' => '인터넷 연결을 확인해 주세요.',
        _ => '실패했어요 (${e.code}). 잠시 후 다시 해보세요.',
      };
}
