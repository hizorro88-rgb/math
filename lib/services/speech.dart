import 'package:flutter_tts/flutter_tts.dart';

import 'sounds.dart';

/// 문제와 정답을 한국어 음성으로 읽어 준다.
/// 글을 모르는 아이도 혼자 풀 수 있게 하는 게 목적.
/// 소리 켬/끔 설정(Sounds.enabled)을 함께 따른다.
class Speech {
  Speech._();

  static final FlutterTts _tts = FlutterTts();

  /// 이 기기에서 한국어 음성을 쓸 수 있는지.
  /// 듣기 유형(듣고 풀기, 소리 찾기)은 이 값이 false면 풀 수 없다.
  static bool available = true;

  /// 앱 시작 시 한 번: 한국어, 아이가 듣기 좋게 천천히·살짝 높게.
  static Future<void> init() async {
    try {
      final ok = await _tts.isLanguageAvailable('ko-KR');
      if (ok is bool && !ok) available = false;
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.05);
    } catch (_) {
      // TTS를 못 써도 앱은 계속 동작한다 (듣기 유형만 입구에서 막는다).
      available = false;
    }
  }

  /// 읽던 것을 멈추고 새로 읽는다. 실패해도(테스트 등) 조용히 넘어간다.
  /// 호출하는 쪽에서 기다릴 필요 없음(fire-and-forget).
  static Future<void> speak(String text) async {
    if (!Sounds.enabled) return;
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {}
  }
}
