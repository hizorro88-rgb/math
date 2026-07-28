import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/models/shop.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  tearDown(() {
    Profiles.activeId = 1;
  });

  group('Profiles', () {
    test('처음이면 기본 프로필이 자동으로 생긴다', () async {
      final profiles = await Profiles.load();
      expect(profiles, hasLength(1));
      expect(profiles.first.id, 1);
      expect(profiles.first.name, '우리 아이');
      expect((await Profiles.active()).id, 1);
    });

    test('프로필을 추가하고 바꿀 수 있다 (최대 4명)', () async {
      await Profiles.load();
      final second = await Profiles.add(emoji: '🐰', name: '둘째');
      expect(second!.id, 2);

      await Profiles.setActive(2);
      expect(Profiles.activeId, 2);
      expect((await Profiles.active()).name, '둘째');

      await Profiles.add(emoji: '🦊', name: '셋째');
      await Profiles.add(emoji: '🐻', name: '넷째');
      expect(await Profiles.add(emoji: '🐯', name: '다섯째'), isNull);
      expect(await Profiles.load(), hasLength(4));
    });

    test('1번 프로필은 예전 키를 그대로 써서 기존 데이터가 유지된다', () async {
      SharedPreferences.setMockInitialValues({
        'total_points_v1': 500,
        'coins_v1': 200,
      });
      expect(await ProgressStore.loadPoints(), 500);
      expect(await ProgressStore.loadCoins(), 200);
    });

    test('프로필마다 점수·코인·아이템이 따로 저장된다', () async {
      // 1번 프로필이 점수를 모으고 아이템을 산다.
      await ProgressStore.addPoints(300);
      await ShopStore.buy(shopItemById('ribbon')!);
      expect(await ProgressStore.loadCoins(), 220);

      // 2번 프로필로 바꾸면 모두 처음부터.
      await Profiles.setActive(2);
      expect(await ProgressStore.loadPoints(), 0);
      expect(await ProgressStore.loadCoins(), 0);
      expect(await ShopStore.loadOwned(), isEmpty);

      // 2번이 점수를 모아도 1번에는 영향이 없다.
      await ProgressStore.addPoints(50);
      await Profiles.setActive(1);
      expect(await ProgressStore.loadPoints(), 300);
      expect(await ProgressStore.loadCoins(), 220);
      expect(await ShopStore.loadOwned(), contains('ribbon'));
    });
  });
}
