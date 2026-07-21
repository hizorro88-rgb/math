import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/models/shop.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final ribbon = shopItemById('ribbon')!; // 🎀 80코인, 머리
  final crown = shopItemById('crown')!; // 👑 600코인, 머리
  final balloon = shopItemById('balloon')!; // 🎈 120코인, 친구

  group('ShopStore', () {
    test('코인이 부족하면 살 수 없다', () async {
      SharedPreferences.setMockInitialValues({'coins_v1': 50});
      expect(await ShopStore.buy(ribbon), isFalse);
      expect(await ShopStore.loadOwned(), isEmpty);
      expect(await ProgressStore.loadCoins(), 50);
    });

    test('사면 코인이 줄고, 보유 목록에 들어가고, 바로 착용된다', () async {
      SharedPreferences.setMockInitialValues({'coins_v1': 100});
      expect(await ShopStore.buy(ribbon), isTrue);
      expect(await ProgressStore.loadCoins(), 20);
      expect(await ShopStore.loadOwned(), contains('ribbon'));
      expect(
        (await ShopStore.loadEquipped()).map((e) => e.id),
        contains('ribbon'),
      );
    });

    test('이미 산 아이템은 다시 사도 코인이 줄지 않는다', () async {
      SharedPreferences.setMockInitialValues({'coins_v1': 200});
      await ShopStore.buy(ribbon);
      expect(await ShopStore.buy(ribbon), isTrue);
      expect(await ProgressStore.loadCoins(), 120);
    });

    test('같은 자리 아이템을 착용하면 이전 것은 벗겨진다', () async {
      SharedPreferences.setMockInitialValues({'coins_v1': 1000});
      await ShopStore.buy(ribbon);
      await ShopStore.buy(crown); // 같은 머리 자리
      final equipped = await ShopStore.loadEquipped();
      expect(equipped.map((e) => e.id), contains('crown'));
      expect(equipped.map((e) => e.id), isNot(contains('ribbon')));
    });

    test('다른 자리 아이템은 같이 착용할 수 있다', () async {
      SharedPreferences.setMockInitialValues({'coins_v1': 1000});
      await ShopStore.buy(ribbon);
      await ShopStore.buy(balloon);
      final ids = (await ShopStore.loadEquipped()).map((e) => e.id).toList();
      expect(ids, containsAll(['ribbon', 'balloon']));
    });

    test('벗을 수 있다', () async {
      SharedPreferences.setMockInitialValues({'coins_v1': 100});
      await ShopStore.buy(ribbon);
      await ShopStore.unequip(ribbon);
      expect(await ShopStore.loadEquipped(), isEmpty);
      expect(await ShopStore.loadOwned(), contains('ribbon')); // 보유는 유지
    });
  });

  group('코인', () {
    test('점수를 얻으면 코인도 같이 쌓인다', () async {
      await ProgressStore.addPoints(150);
      expect(await ProgressStore.loadPoints(), 150);
      expect(await ProgressStore.loadCoins(), 150);
    });

    test('코인을 써도 누적 점수(칭호)는 그대로다', () async {
      await ProgressStore.addPoints(500);
      expect(await ProgressStore.spendCoins(300), isTrue);
      expect(await ProgressStore.loadCoins(), 200);
      expect(await ProgressStore.loadPoints(), 500);
    });

    test('예전 버전 사용자는 모은 점수만큼 코인을 받는다', () async {
      SharedPreferences.setMockInitialValues({'total_points_v1': 700});
      expect(await ProgressStore.loadCoins(), 700);
    });
  });
}
