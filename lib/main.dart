import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/profile.dart';
import 'screens/level_map_screen.dart';
import 'screens/onboarding_screen.dart';
import 'services/sounds.dart';
import 'services/speech.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Profiles.init();
  await Sounds.init();
  await Speech.init();
  var onboarded = false;
  try {
    final prefs = await SharedPreferences.getInstance();
    onboarded = prefs.getBool(OnboardingScreen.doneKey) ?? false;
  } catch (_) {}
  runApp(PreschoolMathApp(showOnboarding: !onboarded));
}

class PreschoolMathApp extends StatelessWidget {
  const PreschoolMathApp({super.key, this.showOnboarding = false});

  /// 첫 실행이면 온보딩(이름·나이·소리 확인)부터 보여준다.
  final bool showOnboarding;

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
          : const LevelMapScreen(),
    );
  }
}
