package com.hizorro.preschool_math

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 일본어·중국어 TTS 음성이 없을 때 기기 TTS 설정으로 바로 보내는 통로.
        // (구글 TTS 앱에서 언어 음성 데이터를 내려받으면 듣기 문제를 풀 수 있다)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "quokka.school/tts")
            .setMethodCallHandler { call, result ->
                if (call.method == "openSettings") {
                    try {
                        startActivity(
                            Intent("com.android.settings.TTS_SETTINGS")
                                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        result.success(false)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
