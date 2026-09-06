import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';
import 'progress.dart';

/// 스티커 한 장: 그림과 이름
class Sticker {
  const Sticker(this.emoji, this.name);

  final String emoji;
  final String name;
}

/// 스티커북 한 페이지: 같은 테마의 스티커 12장
class StickerPage {
  const StickerPage({
    required this.title,
    required this.emoji,
    required this.color,
    required this.stickers,
  });

  final String title;
  final String emoji;
  final Color color;
  final List<Sticker> stickers;
}

/// 스티커북 전체 (페이지 순서대로 채워 나간다)
const List<StickerPage> stickerPages = [
  StickerPage(
    title: '동물 친구들',
    emoji: '🦁',
    color: Color(0xFFFFB74D),
    stickers: [
      Sticker('🦁', '사자'),
      Sticker('🐯', '호랑이'),
      Sticker('🐼', '판다'),
      Sticker('🐨', '코알라'),
      Sticker('🦊', '여우'),
      Sticker('🐰', '토끼'),
      Sticker('🐸', '개구리'),
      Sticker('🦒', '기린'),
      Sticker('🐘', '코끼리'),
      Sticker('🦓', '얼룩말'),
      Sticker('🐧', '펭귄'),
      Sticker('🦉', '부엉이'),
    ],
  ),
  StickerPage(
    title: '맛있는 간식',
    emoji: '🍩',
    color: Color(0xFFF48FB1),
    stickers: [
      Sticker('🍩', '도넛'),
      Sticker('🍪', '쿠키'),
      Sticker('🧁', '컵케이크'),
      Sticker('🍦', '아이스크림'),
      Sticker('🍭', '막대사탕'),
      Sticker('🍫', '초콜릿'),
      Sticker('🍓', '딸기'),
      Sticker('🍉', '수박'),
      Sticker('🍌', '바나나'),
      Sticker('🥨', '프레첼'),
      Sticker('🍰', '케이크'),
      Sticker('🍿', '팝콘'),
    ],
  ),
  StickerPage(
    title: '탈것 총출동',
    emoji: '🚒',
    color: Color(0xFF64B5F6),
    stickers: [
      Sticker('🚒', '소방차'),
      Sticker('🚓', '경찰차'),
      Sticker('🚑', '구급차'),
      Sticker('🚜', '트랙터'),
      Sticker('🚂', '기차'),
      Sticker('🚁', '헬리콥터'),
      Sticker('✈️', '비행기'),
      Sticker('🚢', '큰 배'),
      Sticker('🏎️', '경주차'),
      Sticker('🚌', '버스'),
      Sticker('🛵', '스쿠터'),
      Sticker('🚲', '자전거'),
    ],
  ),
  StickerPage(
    title: '신나는 바다',
    emoji: '🐬',
    color: Color(0xFF4DD0E1),
    stickers: [
      Sticker('🐬', '돌고래'),
      Sticker('🐳', '고래'),
      Sticker('🦈', '상어'),
      Sticker('🐙', '문어'),
      Sticker('🦀', '게'),
      Sticker('🦞', '바닷가재'),
      Sticker('🐠', '열대어'),
      Sticker('🐡', '복어'),
      Sticker('🦑', '오징어'),
      Sticker('🐚', '조개'),
      Sticker('⭐', '불가사리'),
      Sticker('🧜', '인어'),
    ],
  ),
  StickerPage(
    title: '우주 대탐험',
    emoji: '🚀',
    color: Color(0xFF9575CD),
    stickers: [
      Sticker('🚀', '로켓'),
      Sticker('🛸', '우주선'),
      Sticker('👩‍🚀', '우주인'),
      Sticker('🌍', '지구'),
      Sticker('🌙', '달'),
      Sticker('☀️', '태양'),
      Sticker('🪐', '토성'),
      Sticker('⭐️', '별'),
      Sticker('🌠', '별똥별'),
      Sticker('☄️', '혜성'),
      Sticker('👽', '외계인'),
      Sticker('🔭', '망원경'),
    ],
  ),
];

/// 스티커를 붙인 결과 (페이지·앨범 완성 축하용)
class StickerPlaceResult {
  const StickerPlaceResult({
    required this.sticker,
    required this.pageCompleted,
    required this.albumCompleted,
    required this.bonusCoins,
  });

  final Sticker sticker;

  /// 이번 스티커로 페이지를 다 채웠는지
  final bool pageCompleted;

  /// 이번 스티커로 앨범(전체 페이지)을 다 채웠는지 (새 앨범이 시작된다)
  final bool albumCompleted;

  /// 페이지/앨범 완성 보너스 코인 (없으면 0)
  final int bonusCoins;
}

/// 퀴즈를 통과할 때마다 스티커를 한 장씩 받고,
/// 스티커북에서 아이가 원하는 자리에 직접 골라 붙인다.
/// 페이지를 다 채우면 보너스 코인, 앨범을 다 채우면 새 앨범이 시작된다.
class StickerStore {
  StickerStore._();

  static const _key = 'stickers_v1'; // ['page:sticker', ...]
  static const _ticketsKey = 'sticker_tickets_v1'; // 아직 안 붙인 스티커 수
  static const _albumKey = 'sticker_album_v1'; // 완성한 앨범 수
  static const _seenKey = 'sticker_seen_v1'; // 한 번이라도 모아 본 스티커 (앨범 리셋과 무관)

  /// 페이지를 다 채우면 주는 보너스 코인
  static const pageBonus = 50;

  /// 앨범(5페이지)을 다 채우면 추가로 주는 보너스 코인
  static const albumBonus = 100;

  /// 페이지별로 모은 스티커 번호 집합
  static Future<List<Set<int>>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList(Profiles.scoped(_key)) ?? const [];
    final collected = [for (final _ in stickerPages) <int>{}];
    for (final row in rows) {
      final parts = row.split(':');
      if (parts.length != 2) continue;
      final page = int.tryParse(parts[0]);
      final sticker = int.tryParse(parts[1]);
      if (page == null || sticker == null) continue;
      if (page < 0 || page >= stickerPages.length) continue;
      if (sticker < 0 || sticker >= stickerPages[page].stickers.length) {
        continue;
      }
      collected[page].add(sticker);
    }
    return collected;
  }

  /// 지금까지 완성한 앨범 수
  static Future<int> completedAlbums() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(Profiles.scoped(_albumKey)) ?? 0;
  }

  /// 모은 스티커 총 장수 (현재 앨범 기준)
  static Future<int> count() async {
    final collected = await load();
    return collected.fold<int>(0, (sum, page) => sum + page.length);
  }

  /// 꾸미기 판에서 쓸 수 있는 스티커들:
  /// 지금 앨범에 모은 것 + 예전 앨범에서 모아 봤던 것 (페이지 순서대로)
  static Future<List<Sticker>> collectedStickers() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(Profiles.scoped(_seenKey)) ?? const [])
        .toSet();
    final collected = await load();
    for (var p = 0; p < collected.length; p++) {
      for (final s in collected[p]) {
        ids.add('$p:$s');
      }
    }
    final result = <Sticker>[];
    for (var p = 0; p < stickerPages.length; p++) {
      for (var s = 0; s < stickerPages[p].stickers.length; s++) {
        if (ids.contains('$p:$s')) result.add(stickerPages[p].stickers[s]);
      }
    }
    return result;
  }

  /// 아직 붙이지 않고 들고 있는 스티커 수
  static Future<int> tickets() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(Profiles.scoped(_ticketsKey)) ?? 0;
  }

  /// 퀴즈를 통과하면 붙일 수 있는 스티커를 준다.
  static Future<int> addTickets(int count) async {
    final prefs = await SharedPreferences.getInstance();
    final total =
        (prefs.getInt(Profiles.scoped(_ticketsKey)) ?? 0) + count;
    await prefs.setInt(Profiles.scoped(_ticketsKey), total);
    return total;
  }

  /// 아이가 고른 자리에 스티커를 붙인다.
  /// 들고 있는 스티커가 없거나 이미 붙어 있는 자리면 null.
  /// 앨범을 다 채우면 보너스를 주고 새 앨범(빈 스티커북)이 시작된다.
  static Future<StickerPlaceResult?> place(
      int pageIndex, int stickerIndex) async {
    if (pageIndex < 0 || pageIndex >= stickerPages.length) return null;
    final page = stickerPages[pageIndex];
    if (stickerIndex < 0 || stickerIndex >= page.stickers.length) return null;

    final prefs = await SharedPreferences.getInstance();
    final have = prefs.getInt(Profiles.scoped(_ticketsKey)) ?? 0;
    if (have < 1) return null;

    final collected = await load();
    if (collected[pageIndex].contains(stickerIndex)) return null;
    collected[pageIndex].add(stickerIndex);

    final pageCompleted =
        collected[pageIndex].length == page.stickers.length;
    final albumCompleted = collected.indexed.every(
        (e) => e.$2.length == stickerPages[e.$1].stickers.length);

    await prefs.setInt(Profiles.scoped(_ticketsKey), have - 1);
    // 꾸미기 판 팔레트용: 한 번 모은 스티커는 앨범이 새로 시작돼도 기억한다.
    final seen = (prefs.getStringList(Profiles.scoped(_seenKey)) ?? const [])
        .toSet()
      ..add('$pageIndex:$stickerIndex');
    await prefs.setStringList(Profiles.scoped(_seenKey), seen.toList());
    if (albumCompleted) {
      // 새 앨범 시작: 스티커북을 비운다.
      await prefs.setStringList(Profiles.scoped(_key), const []);
      await prefs.setInt(Profiles.scoped(_albumKey),
          (prefs.getInt(Profiles.scoped(_albumKey)) ?? 0) + 1);
    } else {
      await prefs.setStringList(Profiles.scoped(_key), [
        for (var p = 0; p < collected.length; p++)
          for (final s in collected[p]) '$p:$s',
      ]);
    }

    var bonus = 0;
    if (pageCompleted) bonus += pageBonus;
    if (albumCompleted) bonus += albumBonus;
    if (bonus > 0) await ProgressStore.addPoints(bonus);

    return StickerPlaceResult(
      sticker: page.stickers[stickerIndex],
      pageCompleted: pageCompleted,
      albumCompleted: albumCompleted,
      bonusCoins: bonus,
    );
  }
}
