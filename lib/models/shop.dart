import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

import 'progress.dart';

/// 아이템을 다는 자리: 머리 위 / 얼굴 / 옆자리 친구 / 뒤 배경
enum ItemSlot {
  hat('머리'),
  face('얼굴'),
  side('친구'),
  bg('배경');

  const ItemSlot(this.label);

  final String label;
}

/// 부엉이를 꾸미는 상점 아이템
class ShopItem {
  const ShopItem({
    required this.id,
    required this.emoji,
    required this.name,
    required this.cost,
    required this.slot,
  });

  final String id;
  final String emoji;
  final String name;
  final int cost;
  final ItemSlot slot;
}

/// 상점에서 살 수 있는 아이템 목록 (코인으로 구매)
const List<ShopItem> shopItems = [
  // 머리
  ShopItem(id: 'ribbon', emoji: '🎀', name: '리본', cost: 80, slot: ItemSlot.hat),
  ShopItem(
      id: 'cap', emoji: '🧢', name: '야구 모자', cost: 150, slot: ItemSlot.hat),
  ShopItem(
      id: 'tophat', emoji: '🎩', name: '신사 모자', cost: 300, slot: ItemSlot.hat),
  ShopItem(
      id: 'gradcap', emoji: '🎓', name: '졸업 모자', cost: 450, slot: ItemSlot.hat),
  ShopItem(id: 'crown', emoji: '👑', name: '왕관', cost: 600, slot: ItemSlot.hat),
  // 얼굴
  ShopItem(
      id: 'glasses', emoji: '👓', name: '안경', cost: 100, slot: ItemSlot.face),
  ShopItem(
      id: 'goggles', emoji: '🥽', name: '물안경', cost: 200, slot: ItemSlot.face),
  ShopItem(
      id: 'sunglasses',
      emoji: '🕶️',
      name: '선글라스',
      cost: 250,
      slot: ItemSlot.face),
  // 친구
  ShopItem(
      id: 'balloon', emoji: '🎈', name: '풍선', cost: 120, slot: ItemSlot.side),
  ShopItem(
      id: 'flower', emoji: '🌷', name: '튤립', cost: 180, slot: ItemSlot.side),
  ShopItem(
      id: 'chick', emoji: '🐥', name: '병아리 친구', cost: 250, slot: ItemSlot.side),
  ShopItem(
      id: 'teddy', emoji: '🧸', name: '곰인형', cost: 400, slot: ItemSlot.side),
  ShopItem(
      id: 'puppy', emoji: '🐶', name: '강아지 친구', cost: 550, slot: ItemSlot.side),
  ShopItem(
      id: 'rainbow', emoji: '🌈', name: '무지개', cost: 800, slot: ItemSlot.side),
  // 배경
  ShopItem(id: 'grass', emoji: '🌿', name: '풀밭', cost: 300, slot: ItemSlot.bg),
  ShopItem(id: 'sea', emoji: '🌊', name: '바다', cost: 450, slot: ItemSlot.bg),
  ShopItem(id: 'space', emoji: '🌌', name: '우주', cost: 600, slot: ItemSlot.bg),
  ShopItem(id: 'castle', emoji: '🏰', name: '성', cost: 800, slot: ItemSlot.bg),
];

ShopItem? shopItemById(String id) {
  for (final item in shopItems) {
    if (item.id == id) return item;
  }
  return null;
}

/// 산 아이템과 착용 상태를 저장한다.
class ShopStore {
  ShopStore._();

  static const _ownedKey = 'owned_items_v1';
  static const _equippedKey = 'equipped_items_v1';

  static Future<Set<String>> loadOwned() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getStringList(Profiles.scoped(_ownedKey)) ?? const [])
        .toSet();
  }

  /// 착용 중인 아이템들 (자리마다 최대 1개)
  static Future<List<ShopItem>> loadEquipped() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(Profiles.scoped(_equippedKey)) ?? const [];
    return [
      for (final id in ids)
        if (shopItemById(id) != null) shopItemById(id)!,
    ];
  }

  /// 코인이 충분하면 사고 바로 착용한다. 성공 여부를 돌려준다.
  static Future<bool> buy(ShopItem item) async {
    final owned = await loadOwned();
    if (owned.contains(item.id)) return true;
    if (!await ProgressStore.spendCoins(item.cost)) return false;
    owned.add(item.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(Profiles.scoped(_ownedKey), owned.toList());
    await equip(item);
    return true;
  }

  /// 같은 자리의 다른 아이템은 벗기고 이 아이템을 착용한다.
  static Future<void> equip(ShopItem item) async {
    final equipped = await loadEquipped();
    equipped.removeWhere((e) => e.slot == item.slot);
    equipped.add(item);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      Profiles.scoped(_equippedKey),
      equipped.map((e) => e.id).toList(),
    );
  }

  /// 아이템을 벗는다.
  static Future<void> unequip(ShopItem item) async {
    final equipped = await loadEquipped();
    equipped.removeWhere((e) => e.id == item.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      Profiles.scoped(_equippedKey),
      equipped.map((e) => e.id).toList(),
    );
  }
}
