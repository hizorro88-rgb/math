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

  /// 녹음한 내 목소리 재생 (효과음 스위치와 무관하게 들려준다 —
  /// 발음을 비교하려고 사용자가 직접 누른 것이라서).
  /// 웹은 blob 주소, 모바일은 파일 경로를 받는다.
  static Future<void> playFile(String path) async {
    try {
      await _player.stop();
      await _player.play(
        path.startsWith('blob:') || path.startsWith('http')
            ? UrlSource(path)
            : DeviceFileSource(path),
      );
    } catch (_) {}
  }

  // 소리의 뜻 (바꾸지 말 것 — 아이는 소리로 무슨 일이 일어났는지 안다)
  // correct: 정답만 / combo: 연속 정답 / wrong: 오답만 (부드러운 톤)
  // pop: 눌렀다·골랐다·입었다·붙였다·쓰다듬었다 / buy: 코인을 썼다
  // complete: 축하(판 통과·부화·진화·완성)
  static Future<void> pop() => play('pop');

  static Future<void> correct(int combo) =>
      play(combo >= 3 ? 'combo' : 'correct');
  static Future<void> wrong() => play('wrong');
  static Future<void> complete() => play('complete');
  static Future<void> buy() => play('buy');
}
