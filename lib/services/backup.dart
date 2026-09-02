import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// 백업 코드 정보 (복원 전 미리보기용)
class BackupInfo {
  const BackupInfo({
    required this.savedAt,
    required this.keyCount,
    required this.clearedLevels,
    required this.coins,
  });

  final DateTime savedAt;
  final int keyCount;
  final int clearedLevels;
  final int coins;
}

/// 서버 없이 진도를 지키는 로컬 백업.
/// 저장된 모든 기록(진도·별·코인·프로필·통계)을 하나의 텍스트 코드로 만들어
/// 복사해 두거나 메신저로 보내면, 새 폰에서 붙여넣어 그대로 복원할 수 있다.
class BackupService {
  static const _prefix = 'OWL1.';

  /// 현재 저장소 전체를 백업 코드로 만든다.
  static Future<String> export({DateTime? now}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = <String, dynamic>{};
    for (final key in prefs.getKeys()) {
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
        data[key] = {'t': 'l', 'v': [for (final e in value) '$e']};
      }
    }
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

    var cleared = 0;
    var coins = 0;
    for (final entry in data.entries) {
      final value = entry.value as Map<String, dynamic>;
      // 별 목록 키(level_stars, kr/en/lang stars)에서 통과 단계를 센다.
      if (entry.key.contains('stars') && value['t'] == 'l') {
        for (final s in (value['v'] as List)) {
          if ((int.tryParse('$s') ?? 0) >= 1) cleared++;
        }
      }
      if (entry.key.endsWith('coins_v1') && value['t'] == 'i') {
        coins += value['v'] as int;
      }
    }
    return BackupInfo(
      savedAt: saved,
      keyCount: data.length,
      clearedLevels: cleared,
      coins: coins,
    );
  }

  /// 백업 코드로 저장소를 통째로 되돌린다. 성공하면 true.
  /// 지금 기록은 모두 백업 내용으로 바뀐다.
  static Future<bool> restore(String code) async {
    final map = _decode(code);
    if (map == null) return false;
    final data = map['data'] as Map<String, dynamic>? ?? {};
    if (data.isEmpty) return false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    for (final entry in data.entries) {
      final value = entry.value as Map<String, dynamic>;
      switch (value['t']) {
        case 'b':
          await prefs.setBool(entry.key, value['v'] as bool);
        case 'i':
          await prefs.setInt(entry.key, value['v'] as int);
        case 'd':
          await prefs.setDouble(entry.key, (value['v'] as num).toDouble());
        case 's':
          await prefs.setString(entry.key, value['v'] as String);
        case 'l':
          await prefs.setStringList(
              entry.key, [for (final e in value['v'] as List) '$e']);
      }
    }
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
