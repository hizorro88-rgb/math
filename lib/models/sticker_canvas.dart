import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

/// 꾸미기 판에 붙인 스티커 하나.
/// 위치는 캔버스 좌상단 기준 0~1000 비율 좌표로 저장한다 (기기 크기 무관).
class PlacedSticker {
  const PlacedSticker({required this.emoji, required this.x, required this.y});

  final String emoji;
  final int x;
  final int y;

  PlacedSticker moveTo(int newX, int newY) =>
      PlacedSticker(emoji: emoji, x: newX, y: newY);
}

/// 꾸미기 판: 모은 스티커를 골라 원하는 자리에 자유롭게 붙이는 캔버스.
/// (스티커북 수집과 별개 — 모은 스티커는 도장처럼 몇 번이든 쓸 수 있다)
class CanvasStore {
  CanvasStore._();

  static const _key = 'sticker_canvas_v1'; // ['emoji:x:y', ...]

  /// 판이 너무 무거워지지 않게 붙일 수 있는 최대 수
  static const maxPlaced = 40;

  static Future<List<PlacedSticker>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(Profiles.scoped(_key)) ?? const [];
    final placed = <PlacedSticker>[];
    for (final row in rows) {
      final parts = row.split(':');
      if (parts.length != 3) continue;
      final x = int.tryParse(parts[1]);
      final y = int.tryParse(parts[2]);
      if (parts[0].isEmpty || x == null || y == null) continue;
      placed.add(PlacedSticker(
        emoji: parts[0],
        x: x.clamp(0, 1000),
        y: y.clamp(0, 1000),
      ));
    }
    return placed;
  }

  static Future<void> save(List<PlacedSticker> placed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(Profiles.scoped(_key), [
      for (final p in placed.take(maxPlaced)) '${p.emoji}:${p.x}:${p.y}',
    ]);
  }
}
