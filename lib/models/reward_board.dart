import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';
import 'progress.dart';
import 'shop.dart';
import 'stickers.dart';

/// 칭찬 스티커판에 스티커를 붙인 결과
class RewardBoardResult {
  const RewardBoardResult({
    required this.completed,
    this.promise,
    this.gift,
    this.bonusCoins = 0,
  });

  /// 이번 스티커로 20칸을 다 채웠는지
  final bool completed;

  /// 부모가 정해 둔 선물 약속 (없으면 null)
  final String? promise;

  /// 앱 선물로 받은 부엉이 꾸미기 아이템 (모두 갖고 있으면 null)
  final ShopItem? gift;

  /// 아이템 대신 받은 코인 (아이템을 다 모았을 때)
  final int bonusCoins;
}

/// 칭찬 스티커판: 1~20 숫자가 희미하게 적힌 판.
/// 퀴즈를 통과해 받은 스티커를 골라 숫자 위에 붙이고,
/// 20칸을 다 채우면 부모님의 선물 약속 + 앱 선물(꾸미기 아이템)을 받는다.
class RewardBoardStore {
  RewardBoardStore._();

  /// 판의 칸 수 (1~20)
  static const slots = 20;

  /// 꾸미기 아이템을 다 모은 아이에게 대신 주는 코인
  static const fallbackCoins = 200;

  static const _key = 'reward_board_v1'; // ['slot:emoji', ...]
  static const _doneKey = 'reward_board_done_v1'; // 완성한 판 수
  static const _promiseKey = 'reward_board_promise_v1'; // 부모의 선물 약속

  /// 칸별로 붙은 스티커 (빈 칸은 null)
  static Future<List<String?>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(Profiles.scoped(_key)) ?? const [];
    final board = List<String?>.filled(slots, null);
    for (final row in rows) {
      final sep = row.indexOf(':');
      if (sep <= 0) continue;
      final slot = int.tryParse(row.substring(0, sep));
      final emoji = row.substring(sep + 1);
      if (slot == null || slot < 0 || slot >= slots || emoji.isEmpty) continue;
      board[slot] = emoji;
    }
    return board;
  }

  /// 지금까지 완성한 판 수
  static Future<int> completedBoards() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(Profiles.scoped(_doneKey)) ?? 0;
  }

  /// 부모가 정해 둔 선물 약속 (비어 있으면 null)
  static Future<String?> promise() async {
    final prefs = await SharedPreferences.getInstance();
    final text = prefs.getString(Profiles.scoped(_promiseKey))?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  static Future<void> setPromise(String text) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(Profiles.scoped(_promiseKey), text.trim());
  }

  /// 골라 온 스티커를 [slot] 번 칸에 붙인다.
  /// 들고 있는 스티커가 없거나 이미 찬 칸이면 null.
  /// 20칸을 다 채우면 보상을 주고 판을 새로 시작한다.
  static Future<RewardBoardResult?> place(int slot, String emoji) async {
    if (slot < 0 || slot >= slots || emoji.isEmpty) return null;
    final board = await load();
    if (board[slot] != null) return null;
    if (!await StickerStore.useTicket()) return null;

    board[slot] = emoji;
    final completed = !board.contains(null);

    final prefs = await SharedPreferences.getInstance();
    if (completed) {
      // 판 완성: 비우고 완성 수를 올린 뒤 보상을 준다.
      await prefs.setStringList(Profiles.scoped(_key), const []);
      await prefs.setInt(Profiles.scoped(_doneKey),
          (prefs.getInt(Profiles.scoped(_doneKey)) ?? 0) + 1);

      // 앱 선물: 아직 없는 꾸미기 아이템 중 가장 싼 것 (없으면 코인)
      final owned = await ShopStore.loadOwned();
      final candidates = [
        for (final item in shopItems)
          if (!owned.contains(item.id)) item,
      ]..sort((a, b) => a.cost.compareTo(b.cost));
      ShopItem? gift;
      var coins = 0;
      if (candidates.isNotEmpty) {
        gift = candidates.first;
        await ShopStore.grant(gift);
      } else {
        coins = fallbackCoins;
        await ProgressStore.addPoints(coins);
      }
      return RewardBoardResult(
        completed: true,
        promise: await promise(),
        gift: gift,
        bonusCoins: coins,
      );
    }

    await prefs.setStringList(Profiles.scoped(_key), [
      for (var i = 0; i < slots; i++)
        if (board[i] != null) '$i:${board[i]}',
    ]);
    return const RewardBoardResult(completed: false);
  }
}
