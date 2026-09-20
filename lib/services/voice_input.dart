import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// 말하기 연습에 쓰는 마이크 기능 두 가지.
///
/// - [listen] : 말한 내용을 글로 받아 채점한다 (음성 인식)
/// - [startRecording] / [stopRecording] : 내 목소리를 녹음해 다시 들어 본다
///
/// 둘 다 마이크를 쓰기 때문에 동시에 켜면 기기에서 충돌한다.
/// 그래서 한 번에 하나만 동작하도록 [busy]로 막는다.
///
/// 위젯 테스트에서는 [enabled]를 false로 두면 플랫폼 채널을 건드리지 않는다.
class VoiceInput {
  VoiceInput._();

  static final SpeechToText _stt = SpeechToText();
  static final AudioRecorder _recorder = AudioRecorder();

  /// 테스트·미지원 환경에서 끄는 스위치. false면 모든 기능이 조용히 실패한다.
  static bool enabled = true;

  /// 음성 인식을 쓸 수 있는지 (권한 거부·미지원 기기면 false)
  static bool available = false;

  /// 녹음을 쓸 수 있는지
  static bool canRecord = false;

  /// 지금 마이크를 쓰고 있는지 (인식이든 녹음이든)
  static bool busy = false;

  static bool _initTried = false;

  /// 마이크 권한을 물어보고 쓸 수 있는지 확인한다.
  /// 화면에서 마이크 버튼을 처음 누를 때 호출한다 (앱 시작 시가 아니라).
  static Future<bool> ensureReady() async {
    if (!enabled) return false;
    if (_initTried) return available;
    _initTried = true;
    try {
      available = await _stt.initialize(
        onError: (_) {},
        onStatus: (_) {},
        debugLogging: false,
      );
    } catch (_) {
      available = false;
    }
    try {
      canRecord = await _recorder.hasPermission();
    } catch (_) {
      canRecord = false;
    }
    return available;
  }

  /// 말한 내용을 글로 받는다. 말이 끝나거나 [timeout]이 지나면 돌려준다.
  /// 인식된 글이 없으면 빈 문자열.
  static Future<String> listen({
    String locale = 'en_US',
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (!enabled || busy) return '';
    if (!await ensureReady()) return '';
    busy = true;
    final done = Completer<String>();
    var best = '';
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          localeId: locale,
          partialResults: true,
          // 받아쓰기가 아니라 한 문장 말하기라서 문장 단위로 끊는다.
          listenMode: ListenMode.confirmation,
          cancelOnError: true,
          listenFor: timeout,
          pauseFor: const Duration(seconds: 2),
        ),
        onResult: (result) {
          if (result.recognizedWords.isNotEmpty) best = result.recognizedWords;
          if (result.finalResult && !done.isCompleted) done.complete(best);
        },
      );
      // 말이 끊기지 않아도 제한 시간이 지나면 지금까지 들은 걸로 끝낸다.
      final text = await done.future.timeout(
        timeout + const Duration(seconds: 1),
        onTimeout: () => best,
      );
      return text;
    } catch (_) {
      return best;
    } finally {
      try {
        await _stt.stop();
      } catch (_) {}
      busy = false;
    }
  }

  /// 듣기를 중간에 멈춘다 (사용자가 버튼을 다시 누를 때).
  static Future<void> stopListening() async {
    if (!enabled) return;
    try {
      await _stt.stop();
    } catch (_) {}
    busy = false;
  }

  static String? _recordPath;

  /// 내 목소리 녹음을 시작한다. 성공하면 true.
  static Future<bool> startRecording() async {
    if (!enabled || busy) return false;
    try {
      if (!await _recorder.hasPermission()) return false;
      // 웹은 파일 경로 없이 녹음하고, 멈출 때 blob 주소를 돌려받는다.
      final path = kIsWeb
          ? ''
          : '${(await getTemporaryDirectory()).path}/quokka_speak.m4a';
      await _recorder.start(const RecordConfig(), path: path);
      canRecord = true;
      busy = true;
      return true;
    } catch (_) {
      busy = false;
      return false;
    }
  }

  /// 녹음을 멈추고 다시 들을 수 있는 주소를 돌려준다. 실패하면 null.
  static Future<String?> stopRecording() async {
    if (!enabled) return null;
    try {
      _recordPath = await _recorder.stop();
      return _recordPath;
    } catch (_) {
      return null;
    } finally {
      busy = false;
    }
  }

  /// 방금 녹음한 파일 주소 (없으면 null)
  static String? get lastRecording => _recordPath;

  /// 화면을 떠날 때 마이크를 확실히 놓아 준다.
  static Future<void> release() async {
    if (!enabled) return;
    try {
      await _stt.stop();
    } catch (_) {}
    try {
      if (await _recorder.isRecording()) await _recorder.stop();
    } catch (_) {}
    busy = false;
  }
}

/// 말한 문장이 목표 문장과 얼마나 맞는지 채점한다.
///
/// 음성 인식은 조금만 발음이 달라도 다른 낱말로 적히기 때문에
/// 글자 하나까지 맞추라고 하면 아무리 잘 말해도 계속 틀린다.
/// 그래서 낱말이 얼마나 겹치는지로 느슨하게 본다.
class SpeakingScore {
  const SpeakingScore({
    required this.heard,
    required this.matched,
    required this.total,
  });

  /// 인식된 말 (사용자에게 그대로 보여 준다)
  final String heard;

  /// 목표 문장의 낱말 중 맞게 말한 개수
  final int matched;

  /// 목표 문장의 낱말 수
  final int total;

  /// 0.0 ~ 1.0
  double get ratio => total == 0 ? 0 : matched / total;

  /// 통과 기준: 낱말의 60% 이상. 짧은 문장은 하나만 틀려도 크게 깎이므로
  /// 두 낱말 이하는 하나만 맞아도 통과로 본다.
  bool get passed =>
      total <= 2 ? matched >= 1 : ratio >= 0.6;

  /// 아주 잘 말한 경우 (별도 칭찬)
  bool get perfect => total > 0 && matched == total;
}

/// 채점용으로 문장을 낱말 목록으로 바꾼다 (소문자, 기호 제거).
List<String> speakingWords(String sentence) {
  final cleaned = sentence
      .toLowerCase()
      .replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ')
      .replaceAll(RegExp(r"\s+"), ' ')
      .trim();
  if (cleaned.isEmpty) return const [];
  return cleaned.split(' ');
}

/// 목표 문장 [target]과 인식된 말 [heard]를 비교한다.
SpeakingScore scoreSpeaking(String target, String heard) {
  final want = speakingWords(target);
  final got = speakingWords(heard);
  // 같은 낱말이 두 번 나오면 두 번 말해야 두 번 인정한다.
  final pool = [...got];
  var matched = 0;
  for (final w in want) {
    final i = pool.indexOf(w);
    if (i >= 0) {
      pool.removeAt(i);
      matched++;
    }
  }
  return SpeakingScore(heard: heard, matched: matched, total: want.length);
}
