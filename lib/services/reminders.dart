import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 하루 한 번 "부엉이가 기다려요" 알림. 부모가 리포트 화면에서 켜고 끈다.
/// 알림이 안 되는 환경(테스트·권한 거부)에서도 앱은 조용히 계속 동작한다.
class Reminders {
  Reminders._();

  static const _enabledKey = 'reminder_enabled_v1'; // 기기 공통 설정
  static const _notificationId = 7;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static bool _initialized = false;

  static Future<bool> isEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_enabledKey) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> _init() async {
    if (_initialized) return true;
    try {
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(),
        ),
      );
      _initialized = true;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// 알림을 켠다. 권한이 거부되면 false를 돌려준다.
  static Future<bool> enable() async {
    if (!await _init()) return false;
    try {
      // 안드로이드 13+ / iOS 권한 요청
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        final granted = await android.requestNotificationsPermission();
        if (granted == false) return false;
      }
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      if (ios != null) {
        final granted =
            await ios.requestPermissions(alert: true, badge: true, sound: true);
        if (granted == false) return false;
      }

      // 지금 시각 기준으로 매일 반복 (켠 시각쯤에 울린다)
      await _plugin.periodicallyShow(
        _notificationId,
        '부엉이가 기다려요 🦉',
        '오늘의 미션을 풀고 스트릭을 이어 가요!',
        RepeatInterval.daily,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminder',
            '매일 학습 알림',
            channelDescription: '하루 한 번 학습을 잊지 않게 알려줘요',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> disable() async {
    try {
      if (await _init()) await _plugin.cancel(_notificationId);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_enabledKey, false);
    } catch (_) {}
  }

  /// 백업 복원 뒤: 저장된 스위치 값에 실제 알림 예약을 맞춘다.
  /// 플러그인 호출은 기다리지 않는다 (실패하면 스위치를 꺼서 상태를 일치시킨다).
  static Future<void> syncWithSavedSetting() async {
    final want = await isEnabled();
    if (want) {
      enable().then((ok) async {
        if (ok) return;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setBool(_enabledKey, false);
        } catch (_) {}
      }).ignore();
    } else {
      disable().ignore();
    }
  }
}
