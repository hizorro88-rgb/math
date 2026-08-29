import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/premium.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  group('가족 이용권', () {
    test('기본은 이용권 없음, 켜면 유지된다', () async {
      expect(await PremiumStore.hasPass(), isFalse);
      await PremiumStore.setPass(true);
      expect(await PremiumStore.hasPass(), isTrue);
    });

    test('각 과목의 첫 카테고리만 무료다', () {
      expect(PremiumStore.isCategoryFree(0), isTrue);
      expect(PremiumStore.isCategoryFree(1), isFalse);
      expect(PremiumStore.isCategoryFree(6), isFalse);
    });

    test('이용권은 프로필과 무관한 기기 공용 설정이다', () async {
      Profiles.activeId = 2;
      await PremiumStore.setPass(true);
      Profiles.activeId = 1;
      expect(await PremiumStore.hasPass(), isTrue);
    });
  });

  group('프로필 삭제', () {
    test('프로필을 지우면 그 프로필의 기록 키도 지워진다', () async {
      await Profiles.load(); // 기본 프로필 생성
      final second = await Profiles.add(emoji: '🦊', name: '둘째');
      expect(second, isNotNull);
      await Profiles.setActive(second!.id);

      // 둘째 프로필 스코프 키에 기록을 남긴다.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(Profiles.scoped('total_points_v1'), 500);
      expect(prefs.getKeys().any((k) => k.startsWith('p${second.id}_')),
          isTrue);

      await Profiles.remove(second.id);

      final profiles = await Profiles.load();
      expect(profiles.map((p) => p.id), isNot(contains(second.id)));
      expect(prefs.getKeys().any((k) => k.startsWith('p${second.id}_')),
          isFalse);
      // 지운 프로필을 쓰고 있었다면 기본 프로필로 돌아온다.
      expect(Profiles.activeId, 1);
    });

    test('기본(1번) 프로필은 지울 수 없다', () async {
      await Profiles.load();
      await Profiles.remove(1);
      expect((await Profiles.load()).map((p) => p.id), contains(1));
    });
  });
}
