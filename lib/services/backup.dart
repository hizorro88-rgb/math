import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/unit_stars.dart';

/// 백업 코드 정보 (복원 전 미리보기용)
class BackupInfo {
  const BackupInfo({
    required this.savedAt,
    required this.keyCount,
    required this.clearedLevels,
    required this.coins,
    this.profiles = 1,
  });

  final DateTime savedAt;
  final int keyCount;
  final int clearedLevels;
  final int coins;

  /// 담긴 프로필(아이) 수
  final int profiles;
}

/// 서버 없이 진도를 지키는 로컬 백업.
/// 저장된 모든 기록(진도·별·코인·프로필·통계)을 하나의 텍스트 코드로 만들어
/// 복사해 두거나 메신저로 보내면, 새 폰에서 붙여넣어 그대로 복원할 수 있다.
class BackupService {
  static const _prefix = 'OWL1.';

  /// 백업에 넣지 않는 키: 결제 권한은 코드로 옮기거나 지울 수 없어야 한다.
  /// (이용권은 스토어 [구매 복원]으로만 옮긴다)
  static const _excludedKeys = {
    'family_pass_v1',
    'all_unlock_v1',
    'cloud_sync_at_v1',
    undoKey,
  };

  /// 복원 직전에 자동으로 떠 둔 기록 (백업 코드). [undoRestore]로 되돌린다.
  /// 백업·클라우드에는 넣지 않는다 (코드 안에 코드가 겹겹이 쌓이지 않게).
  static const undoKey = 'backup_undo_v1';

  /// 묶음 제목 기준 별 저장 키(…_unit_stars_v1)와, 그 키가 생기기 전의
  /// 옛 순서 저장 키. 미리보기의 '통과한 단계'는 새 키가 있으면 새 키만 센다
  /// (처음 열 때 옮겨 담고도 옛 키를 남겨 두므로 이중으로 세지 않게).
  /// 새 키 → 옛 키들 (최근 것부터). 옛 키끼리도 가장 최근 것 하나만 센다.
  static const _legacyKeys = {
    'math_unit_stars_v1': [
      'level_stars_v5',
      'level_stars_v4',
      'level_stars_v3',
      'level_stars_v2',
    ],
    'kr_unit_stars_v1': [
      'kr_level_stars_v3',
      'kr_level_stars_v2',
      'kr_level_stars_v1',
    ],
    'en_unit_stars_v1': ['en_level_stars_v1'],
  };

  static final _profilePrefix = RegExp(r'^p\d+_');

  /// 미리보기에서 이 키의 별을 셀지. 새 키는 언제나, 옛 키는 같은 프로필에
  /// 새 키도 더 최근 옛 키도 없을 때만 센다.
  static bool _countsStars(String key, Map<String, dynamic> data) {
    final prefix = _profilePrefix.firstMatch(key)?.group(0) ?? '';
    final core = key.substring(prefix.length);
    if (core.endsWith('_unit_stars_v1')) return true;
    for (final e in _legacyKeys.entries) {
      final i = e.value.indexOf(core);
      if (i < 0) continue;
      if (data.containsKey('$prefix${e.key}')) return false;
      return !e.value.take(i).any((k) => data.containsKey('$prefix$k'));
    }
    if (core.startsWith('lang_') && core.endsWith('_stars_v1')) {
      final unitKey = core.replaceFirst('_stars_v1', '_unit_stars_v1');
      return !data.containsKey('$prefix$unitKey');
    }
    return false;
  }

  /// 저장소 전체를 {키: {t, v}} 꼴로 만든다 (백업 코드·클라우드 동기화 공용).
  static Future<Map<String, dynamic>> exportData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
      if (_excludedKeys.contains(key)) continue;
      final value = prefs.get(key);
      // 타입을 함께 적어 두어야 복원할 때 같은 타입으로 넣을 수 있다.
      if (value is bool) {
        data[key] = {'t': 'b', 'v': value};
      } else if (value is int) {
        data[key] = {'t': 'i', 'v': value};
      } else if (value is double) {
        data[key] = {'t': 'd', 'v': value};
      } else if (value is String) {
        data[key] = {'t': 's', 'v': value};
      } else if (value is List) {
        data[key] = {
          't': 'l',
          'v': [for (final e in value) '$e']
        };
      }
    }
    return data;
  }

  /// 현재 저장소 전체를 백업 코드로 만든다.
  static Future<String> export({DateTime? now}) async {
    final data = await exportData();
    final body = jsonEncode({
      'v': 1,
      'saved': (now ?? DateTime.now()).toIso8601String(),
      'data': data,
    });
    final payload = base64Url.encode(utf8.encode(body));
    return '$_prefix$payload.${_checksum(payload)}';
  }

  /// 코드를 해석해 요약 정보를 돌려준다. 형식이 틀리면 null.
  static BackupInfo? peek(String code) {
    final map = _decode(code);
    if (map == null) return null;
    final saved = DateTime.tryParse(map['saved'] as String? ?? '');
    if (saved == null) return null;
    final data = map['data'] as Map<String, dynamic>? ?? {};
    return _summarize(data, saved);
  }

  /// 지금 이 기기 기록의 요약 (복원 확인 창에서 백업과 나란히 보여 준다)
  static Future<BackupInfo> currentInfo({DateTime? now}) async =>
      _summarize(await exportData(), now ?? DateTime.now());

  static BackupInfo _summarize(Map<String, dynamic> data, DateTime saved) {
    var cleared = 0;
    var coins = 0;
    var profiles = 1;
    for (final entry in data.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      if (value['t'] == 'l' && _countsStars(entry.key, data)) {
        final rows = [for (final s in (value['v'] as List)) '$s'];
        if (entry.key.endsWith('_unit_stars_v1')) {
          for (final row in UnitStarStore.decode(rows).values) {
            cleared += row.where((s) => s >= 1).length;
          }
        } else {
          cleared += rows.where((s) => (int.tryParse(s) ?? 0) >= 1).length;
        }
      }
      if (entry.key.endsWith('coins_v1') && value['t'] == 'i') {
        coins += value['v'] as int;
      }
      if (entry.key == 'profiles_v1' && value['t'] == 'l') {
        final count = (value['v'] as List).length;
        if (count > 0) profiles = count;
      }
    }
    return BackupInfo(
      savedAt: saved,
      keyCount: data.length,
      clearedLevels: cleared,
      coins: coins,
      profiles: profiles,
    );
  }

  /// 백업 코드로 저장소를 통째로 되돌린다. 성공하면 true.
  /// 지금 기록은 모두 백업 내용으로 바뀐다 (이용권 상태는 이 기기 것을 유지).
  ///
  /// [keepUndo]면 바꾸기 직전 기록을 [undoKey]에 떠 두어 [undoRestore]로
  /// 한 번 되돌릴 수 있다 (잘못된 코드를 붙여 넣어도 지금 기록을 잃지 않게).
  static Future<bool> restore(String code, {bool keepUndo = true}) async {
    final map = _decode(code);
    if (map == null) return false;
    final data = map['data'] as Map<String, dynamic>? ?? {};
    final snapshot = keepUndo ? await export() : null;
    final done = await restoreData(data);
    if (done && snapshot != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(undoKey, snapshot);
    }
    return done;
  }

  /// 되돌릴 수 있는 복원 직전 기록이 있으면 그 요약
  static Future<BackupInfo?> undoInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(undoKey);
    return code == null ? null : peek(code);
  }

  /// 마지막 복원을 취소하고 복원 직전 기록으로 돌아간다. 성공하면 true.
  static Future<bool> undoRestore() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(undoKey);
    if (code == null) return false;
    // 되돌린 뒤에는 되돌리기가 남지 않는다 (restoreData가 저장소를 비운다).
    return restore(code, keepUndo: false);
  }

  /// {키: {t, v}} 데이터로 저장소를 되돌린다 (백업 코드·클라우드 공용).
  static Future<bool> restoreData(Map<String, dynamic> data) async {
    if (data.isEmpty) return false;

    // 지우기 전에 쓸 값을 전부 만들어 검증한다.
    // 중간에 형식 오류가 나면 기존 기록을 건드리지 않고 실패한다.
    final writes = <(String, Object)>[];
    for (final entry in data.entries) {
      if (_excludedKeys.contains(entry.key)) continue; // 옛 코드에 섞여 있어도 무시
      final value = entry.value;
      if (value is! Map<String, dynamic>) return false;
      final typed = switch (value['t']) {
        'b' => value['v'] is bool ? value['v'] as bool : null,
        'i' => value['v'] is int ? value['v'] as int : null,
        'd' => value['v'] is num ? (value['v'] as num).toDouble() : null,
        's' => value['v'] is String ? value['v'] as String : null,
        'l' => value['v'] is List
            ? [for (final e in value['v'] as List) '$e']
            : null,
        _ => null,
      };
      if (typed == null) return false;
      writes.add((entry.key, typed));
    }

    final prefs = await SharedPreferences.getInstance();
    final hadPass = prefs.getBool('family_pass_v1') ?? false;
    final hadUnlock = prefs.getBool('all_unlock_v1') ?? false;
    await prefs.clear();
    for (final (key, value) in writes) {
      switch (value) {
        case bool v:
          await prefs.setBool(key, v);
        case int v:
          await prefs.setInt(key, v);
        case double v:
          await prefs.setDouble(key, v);
        case String v:
          await prefs.setString(key, v);
        case List<String> v:
          await prefs.setStringList(key, v);
      }
    }
    // 이 기기에서 산 이용권은 백업과 무관하게 유지한다.
    if (hadPass) await prefs.setBool('family_pass_v1', true);
    if (hadUnlock) await prefs.setBool('all_unlock_v1', true);
    return true;
  }

  static Map<String, dynamic>? _decode(String code) {
    final trimmed = code.trim();
    if (!trimmed.startsWith(_prefix)) return null;
    final rest = trimmed.substring(_prefix.length);
    final dot = rest.lastIndexOf('.');
    if (dot < 0) return null;
    final payload = rest.substring(0, dot);
    if (rest.substring(dot + 1) != _checksum(payload)) return null;
    try {
      final map = jsonDecode(utf8.decode(base64Url.decode(payload)));
      return map is Map<String, dynamic> ? map : null;
    } catch (_) {
      return null;
    }
  }

  /// 코드가 중간에 잘리거나 바뀌었는지 확인하는 짧은 검증 값.
  static String _checksum(String payload) {
    var sum = 0;
    for (final unit in payload.codeUnits) {
      sum = (sum * 31 + unit) % 46656; // 36^3
    }
    return sum.toRadixString(36).padLeft(3, '0');
  }
}
