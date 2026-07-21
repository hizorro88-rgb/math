import 'package:audioplayers/audioplayers.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 짧은 효과음 재생. 설정에서 켜고 끌 수 있다.
class Sounds {
  Sounds._();

  static const _enabledKey = 'sound_enabled_v1';

  static bool enabled = true;
  static final AudioPlayer _player = AudioPlayer();

  /// 저장된 소리 켬/끔 설정을 불러온다.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_enabledKey) ?? true;
    } catch (_) {
      // 설정을 못 읽어도 앱은 계속 동작한다.
    }
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
  }

  /// assets/sounds/<name>.wav 재생. 실패해도(테스트 등) 조용히 넘어간다.
  static Future<void> play(String name) async {
    if (!enabled) return;
    try {
      await _player.stop();
      await _player.play(AssetSource('sounds/$name.wav'));
    } catch (_) {}
  }

  static Future<void> correct(int combo) =>
      play(combo >= 3 ? 'combo' : 'correct');
  static Future<void> wrong() => play('wrong');
  static Future<void> complete() => play('complete');
  static Future<void> buy() => play('buy');
}
