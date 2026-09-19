import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 문제와 정답을 음성으로 읽어 준다.
/// 글을 모르는 아이도 혼자 풀 수 있게 하는 게 목적.
/// 효과음(Sounds)과 따로 켜고 끌 수 있다 (설정 화면).
class Speech {
  Speech._();

  static final FlutterTts _tts = FlutterTts();

  static const _enabledKey = 'speech_enabled_v1';
  static const _rateKey = 'speech_rate_v1';

  /// 아이가 듣기 좋은 두 가지 빠르기
  static const rateSlow = 0.35;
  static const rateNormal = 0.45;

  /// 이 기기에서 한국어 음성을 쓸 수 있는지.
  /// 듣기 유형(듣고 풀기, 소리 찾기)은 이 값이 false면 풀 수 없다.
  static bool available = true;

  /// 언어별 음성 지원 여부 (앱 시작 시 한 번 확인).
  /// 확인 전이거나 항목이 없으면 낙관적으로 지원한다고 본다.
  static final Map<String, bool> langAvailable = {};

  /// [lang] 음성을 쓸 수 있는지 (ko-KR는 [available]).
  static bool isLangAvailable(String lang) =>
      lang == 'ko-KR' ? available : (langAvailable[lang] ?? true);

  /// 문제 읽어주기 켬/끔 (설정 화면에서 바꾼다)
  static bool enabled = true;

  /// 말 빠르기 (rateSlow 또는 rateNormal)
  static double rate = rateNormal;

  /// 플랫폼별 빠르기 보정: 모바일 TTS는 0.5 근처가 보통 빠르기지만
  /// 웹(Web Speech API)은 1.0이 보통이라, 같은 값을 그대로 주면
  /// 절반 속도로 늘어진 이상한 목소리가 된다.
  static double get _platformRate => kIsWeb ? rate * 2 : rate;

  /// 앱 시작 시 한 번: 한국어, 아이가 듣기 좋게 천천히·살짝 높게.
  static Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 예전 버전에서는 효과음·말소리가 한 스위치였다 → 그 값을 기본으로 물려받는다.
      enabled = prefs.getBool(_enabledKey) ??
          (prefs.getBool('sound_enabled_v1') ?? true);
      rate = prefs.getDouble(_rateKey) ?? rateNormal;
    } catch (_) {}
    try {
      final ok = await _tts.isLanguageAvailable('ko-KR');
      if (ok is bool && !ok) available = false;
      await _tts.setLanguage('ko-KR');
      await _tts.setSpeechRate(_platformRate);
      await _tts.setPitch(1.05);
      // 외국어 음성 지원 여부도 확인해 둔다 (듣기 유형 입구에서 안내용).
      for (final lang in ['en-US', 'ja-JP', 'zh-CN']) {
        final langOk = await _tts.isLanguageAvailable(lang);
        langAvailable[lang] = langOk is bool ? langOk : true;
      }
    } catch (_) {
      // TTS를 못 써도 앱은 계속 동작한다 (듣기 유형만 입구에서 막는다).
      available = false;
    }
  }

  /// 백업 복원 뒤처럼 저장된 설정만 다시 읽을 때.
  /// (TTS 채널 응답은 기다리지 않는다 — 테스트 환경에서는 응답이 오지 않는다)
  static Future<void> reloadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled = prefs.getBool(_enabledKey) ??
          (prefs.getBool('sound_enabled_v1') ?? true);
      rate = prefs.getDouble(_rateKey) ?? rateNormal;
    } catch (_) {}
    _tts.setSpeechRate(_platformRate).ignore();
  }

  static Future<void> setEnabled(bool value) async {
    enabled = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, value);
    } catch (_) {}
  }

  static Future<void> setRate(double value) async {
    rate = value;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_rateKey, value);
      await _tts.setSpeechRate(_platformRate);
    } catch (_) {}
  }

  static String _currentLang = 'ko-KR';

  /// 읽던 것을 멈추고 새로 읽는다. 실패해도(테스트 등) 조용히 넘어간다.
  /// 호출하는 쪽에서 기다릴 필요 없음(fire-and-forget).
  /// [lang]으로 언어를 바꿔 읽을 수 있다 (영어 낱말은 'en-US').
  static Future<void> speak(String text, {String lang = 'ko-KR'}) async {
    if (!enabled) return;
    try {
      await _tts.stop();
      if (lang != _currentLang) {
        await _tts.setLanguage(lang);
        _currentLang = lang;
      }
      await _tts.speak(text);
    } catch (_) {}
  }
}
