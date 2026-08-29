import 'package:shared_preferences/shared_preferences.dart';

/// 가족 이용권(1회 결제, 비소모성).
/// 프로필과 무관하게 기기 전체에 적용되고,
/// 스토어의 가족 공유(Google Play 가족 라이브러리 / Apple 가족 공유)를 켜면
/// 한 번 결제로 가족 기기에서도 함께 쓸 수 있다.
class PremiumStore {
  PremiumStore._();

  // 프로필 스코프를 쓰지 않는 전역 키 (이용권은 가족 공용)
  static const _key = 'family_pass_v1';

  /// 이용권 없이 만들 수 있는 프로필 수
  static const freeProfiles = 1;

  static Future<bool> hasPass() async {
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
