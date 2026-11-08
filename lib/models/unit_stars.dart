import 'package:shared_preferences/shared_preferences.dart';

import 'profile.dart';

/// 예전 저장 방식(단계 번호 순서대로 늘어놓은 별 목록)의 한 버전.
/// [titles]는 그 버전이 저장될 때의 묶음 제목 순서다.
class LegacyStarLayout {
  const LegacyStarLayout(this.key, this.titles);

  /// 프로필 접두사를 뺀 저장 키 (예: 'level_stars_v5')
  final String key;
  final List<String> titles;
}

/// 묶음 제목을 기준으로 별을 저장하는 저장소 — 모든 과목 공용.
///
/// 예전에는 별을 단계 번호 순서대로 저장해서, 커리큘럼 중간에 묶음을 넣으면
/// 번호가 밀려 다른 단계에 별이 붙었다(그때마다 키를 올리고 이사 코드를 썼다).
/// 이제는 `제목=3,2,0,…` 꼴로 묶음마다 저장하므로 묶음을 어디에 넣고 빼도
/// 기록이 제자리를 지킨다. 묶음 제목만 바꾸지 않으면 된다
/// (제목을 바꿀 때는 [renamed]에 옛 제목 → 새 제목을 적는다).
class UnitStarStore {
  const UnitStarStore({
    required this.key,
    required this.titles,
    required this.perUnit,
    this.legacy = const [],
    this.renamed = const {},
  });

  /// 프로필 접두사를 뺀 저장 키 (예: 'math_unit_stars_v1')
  final String key;

  /// 지금 커리큘럼의 묶음 제목 (순서대로). 과목 안에서 겹치면 안 된다.
  final List<String> Function() titles;

  /// 묶음 하나의 단계 수
  final int perUnit;

  /// 옛 저장 방식들 — 새 키가 없을 때 앞에서부터 찾아 한 번 옮겨 담는다.
  final List<LegacyStarLayout> legacy;

  /// 옛 제목 → 새 제목 (묶음 이름을 바꿨을 때 기록을 이어 준다)
  final Map<String, String> renamed;

  /// 지금 커리큘럼 순서의 별 목록 (인덱스 0 = 1단계)
  Future<List<int>> load() async {
    final map = await _loadMap();
    final current = titles();
    return [
      for (final title in current)
        for (var i = 0; i < perUnit; i++) _at(map[title], i),
    ];
  }

  /// 더 좋은 기록일 때만 저장한다.
  Future<void> save(int levelNumber, int stars) async {
    final current = titles();
    final unit = (levelNumber - 1) ~/ perUnit;
    if (unit < 0 || unit >= current.length) return;
    final index = (levelNumber - 1) % perUnit;
    final map = await _loadMap();
    final row = List<int>.generate(perUnit, (i) => _at(map[current[unit]], i));
    if (stars <= row[index]) return;
    row[index] = stars;
    map[current[unit]] = row;
    await _write(map);
  }

  static int _at(List<int>? row, int i) =>
      row != null && i < row.length ? row[i] : 0;

  /// 옮겨 담는 중인 작업 (프로필별 키) — 처음 열 때 load와 save가 겹쳐도
  /// 옮겨 담기를 두 번 하거나 막 저장한 별을 덮어쓰지 않게 하나로 모은다.
  static final _migrating = <String, Future<Map<String, List<int>>>>{};

  Future<Map<String, List<int>>> _loadMap() async {
    final prefs = await SharedPreferences.getInstance();
    final scopedKey = Profiles.scoped(key);
    final saved = prefs.getStringList(scopedKey);
    if (saved != null) return _rename(decode(saved));
    final pending = _migrating[scopedKey];
    if (pending != null) return {...await pending};
    final job = _migrate(prefs);
    _migrating[scopedKey] = job;
    try {
      return {...await job};
    } finally {
      _migrating.remove(scopedKey);
    }
  }

  Future<Map<String, List<int>>> _migrate(SharedPreferences prefs) async {
    // 처음 열 때: 옛 순서 기록을 제목 기준으로 옮겨 담는다.
    for (final layout in legacy) {
      final old = prefs.getStringList(Profiles.scoped(layout.key));
      if (old == null) continue;
      final map = <String, List<int>>{};
      for (var u = 0; u < layout.titles.length; u++) {
        final row = [
          for (var i = 0; i < perUnit; i++)
            u * perUnit + i < old.length
                ? int.tryParse(old[u * perUnit + i]) ?? 0
                : 0,
        ];
        if (row.any((s) => s > 0)) map[layout.titles[u]] = row;
      }
      final migrated = _rename(map);
      await _write(migrated);
      return migrated;
    }
    return {};
  }

  Map<String, List<int>> _rename(Map<String, List<int>> map) {
    if (renamed.isEmpty) return map;
    return {
      for (final e in map.entries) (renamed[e.key] ?? e.key): e.value,
    };
  }

  Future<void> _write(Map<String, List<int>> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(Profiles.scoped(key), encode(map));
  }

  /// `제목=3,2,0` 줄 목록 → 지도 (백업 미리보기도 쓴다)
  static Map<String, List<int>> decode(List<String> rows) {
    final map = <String, List<int>>{};
    for (final row in rows) {
      final eq = row.lastIndexOf('=');
      if (eq <= 0) continue;
      map[row.substring(0, eq)] = [
        for (final s in row.substring(eq + 1).split(',')) int.tryParse(s) ?? 0,
      ];
    }
    return map;
  }

  static List<String> encode(Map<String, List<int>> map) => [
        for (final e in map.entries)
          if (e.value.any((s) => s > 0)) '${e.key}=${e.value.join(',')}',
      ];
}
