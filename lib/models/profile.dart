import 'package:shared_preferences/shared_preferences.dart';

/// 아이 한 명의 프로필
class Profile {
  const Profile({required this.id, required this.emoji, required this.name});

  final int id;
  final String emoji;
  final String name;
}

/// 프로필을 만들 때 고르는 동물 아바타
const List<String> profileAvatars = [
  '🐣',
  '🐰',
  '🦊',
  '🐻',
  '🐯',
  '🦄',
  '🐬',
  '🦖',
];

/// 여러 자녀 프로필 관리. 진행도·코인·미션·통계가 프로필마다 분리된다.
class Profiles {
  Profiles._();

  static const _listKey = 'profiles_v1'; // 'id|emoji|이름'
  static const _activeKey = 'active_profile_v1';
  static const maxProfiles = 4;

  /// 지금 사용 중인 프로필 id (앱 시작 시 init에서 불러온다)
  static int activeId = 1;

  /// 현재 프로필의 저장 키.
  /// 1번(기본) 프로필은 예전 키를 그대로 써서,
  /// 프로필 기능이 없던 버전의 데이터가 자동으로 첫 프로필이 된다.
  static String scoped(String base) =>
      activeId == 1 ? base : 'p${activeId}_$base';

  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      activeId = prefs.getInt(_activeKey) ?? 1;
    } catch (_) {
      activeId = 1;
    }
  }

  /// 프로필 목록. 하나도 없으면 기본 프로필을 만들어 준다.
  static Future<List<Profile>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_listKey) ?? const [];
    final profiles = <Profile>[];
    for (final entry in raw) {
      final parts = entry.split('|');
      if (parts.length < 3) continue;
      final id = int.tryParse(parts[0]);
      if (id == null) continue;
      profiles.add(
        Profile(id: id, emoji: parts[1], name: parts.sublist(2).join('|')),
      );
    }
    if (profiles.isEmpty) {
      const first = Profile(id: 1, emoji: '🐣', name: '우리 아이');
      await _save([first]);
      return [first];
    }
    return profiles;
  }

  static Future<void> _save(List<Profile> profiles) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _listKey,
      [for (final p in profiles) '${p.id}|${p.emoji}|${p.name}'],
    );
  }

  /// 새 프로필을 만들고 돌려준다. 가득 찼으면 null.
  static Future<Profile?> add({
    required String emoji,
    required String name,
  }) async {
    final profiles = await load();
    if (profiles.length >= maxProfiles) return null;
    final id = profiles.map((p) => p.id).fold(0, (a, b) => a > b ? a : b) + 1;
    final profile = Profile(id: id, emoji: emoji, name: name);
    await _save([...profiles, profile]);
    return profile;
  }

  /// 프로필의 아바타나 이름을 바꾼다.
  static Future<void> update(int id, {String? emoji, String? name}) async {
    final profiles = await load();
    await _save([
      for (final p in profiles)
        p.id == id
            ? Profile(id: p.id, emoji: emoji ?? p.emoji, name: name ?? p.name)
            : p,
    ]);
  }

  /// 프로필을 지우고, 그 프로필의 학습 기록도 함께 지운다.
  /// 1번(기본) 프로필은 옛 키를 그대로 쓰고 있어서 지울 수 없다.
  static Future<void> remove(int id) async {
    if (id == 1) return;
    final profiles = await load();
    await _save([
      for (final p in profiles)
        if (p.id != id) p,
    ]);
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs
        .getKeys()
        .where((k) => k.startsWith('p${id}_'))
        .toList()) {
      await prefs.remove(key);
    }
    if (activeId == id) await setActive(1);
  }

  /// 사용할 프로필을 바꾼다.
  static Future<void> setActive(int id) async {
    activeId = id;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_activeKey, id);
  }

  /// 지금 사용 중인 프로필
  static Future<Profile> active() async {
    final profiles = await load();
    return profiles.firstWhere(
      (p) => p.id == activeId,
      orElse: () => profiles.first,
    );
  }
}
