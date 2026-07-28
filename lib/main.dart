import 'package:flutter/material.dart';

import 'models/profile.dart';
import 'screens/level_map_screen.dart';
import 'services/sounds.dart';
import 'services/speech.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Profiles.init();
  await Sounds.init();
  await Speech.init();
  runApp(const PreschoolMathApp());
}

class PreschoolMathApp extends StatelessWidget {
  const PreschoolMathApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '수학 놀이',
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
      home: const LevelMapScreen(),
    );
  }
}
