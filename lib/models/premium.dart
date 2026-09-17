import 'package:shared_preferences/shared_preferences.dart';

/// 가족 이용권(1회 결제, 비소모성).
/// 프로필과 무관하게 기기 전체에 적용되고,
/// 스토어의 가족 공유(Google Play 가족 라이브러리 / Apple 가족 공유)를 켜면
/// 한 번 결제로 가족 기기에서도 함께 쓸 수 있다.
class PremiumStore {
  PremiumStore._();

  // 프로필 스코프를 쓰지 않는 전역 키 (이용권은 가족 공용)
  static const _key = 'family_pass_v1';
  static const _unlockKey = 'all_unlock_v1';

  /// 전체 열기 코드 (설정 → 전체 열기에서 입력).
  /// 개인/가족용 배포에서 결제 없이 모든 잠금을 푸는 비밀 코드.
  static const unlockCode = 'hizorro88';

  /// 전체 열기 상태 캐시. 앱 시작(init) 때 읽어 두고,
  /// 단계 자물쇠 검사처럼 동기 코드에서도 바로 쓴다.
  static bool allUnlocked = false;

  /// 이용권 없이 만들 수 있는 프로필 수
  static const freeProfiles = 1;

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      allUnlocked = prefs.getBool(_unlockKey) ?? false;
    } catch (_) {
      allUnlocked = false;
    }
  }

  static Future<void> setAllUnlocked(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_unlockKey, value);
    allUnlocked = value;
  }

  static Future<bool> hasPass() async {
    if (allUnlocked) return true;
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_key) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPass(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, value);
  }

  /// 무료로 열려 있는 카테고리인지: 모든 과목의 첫 번째 카테고리는 무료 체험
  static bool isCategoryFree(int categoryIndex) => categoryIndex == 0;
}
