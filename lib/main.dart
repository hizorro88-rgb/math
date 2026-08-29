import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/profile.dart';
import 'screens/level_map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'services/purchases.dart';
import 'services/sounds.dart';
import 'services/speech.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Profiles.init();
  await Sounds.init();
  await Speech.init();
  Purchases.init(); // 스토어 연결은 기다리지 않는다 (결과는 스트림으로)
  var onboarded = false;
  var profileCount = 1;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool(OnboardingScreen.doneKey) ?? false;
    profileCount = (await Profiles.load()).length;
  } catch (_) {}
  runApp(PreschoolMathApp(
    showOnboarding: !onboarded,
    // 가족 프로필이 여럿이면 넷플릭스처럼 "누가 놀까요?"부터 시작한다.
    showProfilePicker: onboarded && profileCount >= 2,
  ));
}

class PreschoolMathApp extends StatelessWidget {
  const PreschoolMathApp({
    super.key,
    this.showOnboarding = false,
    this.showProfilePicker = false,
  });

  /// 첫 실행이면 온보딩(이름·나이·소리 확인)부터 보여준다.
  final bool showOnboarding;

  /// 프로필이 여럿이면 시작할 때 프로필 선택부터 보여준다.
  final bool showProfilePicker;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '수학·한글 놀이',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF58CC02),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF7F7F7),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            textStyle: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
      home: showOnboarding
          ? const OnboardingScreen()
          : showProfilePicker
              ? const ProfileScreen(asLauncher: true)
              : const LevelMapScreen(),
    );
  }
}
