import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/curriculum.dart';
import '../models/profile.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import 'level_map_screen.dart';

/// 첫 실행 온보딩: ① 아이 이름·아바타 ② 나이 고르기 ③ 소리 확인.
/// 끝나면 다시 나오지 않는다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  /// 온보딩을 이미 마쳤는지 저장하는 키 (프로필과 무관하게 기기당 한 번)
  static const doneKey = 'onboarding_done_v1';

  /// 온보딩에서 고른 나이에 맞는 수학 카테고리 인덱스 (홈에서 추천 표시)
  static const ageCategoryKey = 'age_category_v1';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _step = 0;
  String _emoji = profileAvatars.first;
  final _nameController = TextEditingController();
  int? _ageIndex;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _finish({required bool soundOn}) async {
    await Sounds.setEnabled(soundOn);
    await Speech.setEnabled(soundOn);
    final name = _nameController.text.trim();
    await Profiles.update(
      Profiles.activeId,
      emoji: _emoji,
      name: name.isEmpty ? '우리 아이' : name,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(OnboardingScreen.doneKey, true);
    if (_ageIndex != null) {
      await prefs.setInt(
          Profiles.scoped(OnboardingScreen.ageCategoryKey), _ageIndex!);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const LevelMapScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('🦉', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 64)),
              Text(
                '부엉이 학교',
                textAlign: TextAlign.center,
                style: displayStyle(fontSize: 20, color: AppColors.brown),
              ),
              const SizedBox(height: 8),
              // 몇 단계짜리 절차인지 한눈에 (● ○ ○)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      decoration: BoxDecoration(
                        color: i == _step
                            ? AppColors.green
                            : const Color(0xFFD8CFBE),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // 단계마다 키를 줘서 버튼 상태(연타 방지 타이머)가 이월되지 않게 한다.
              KeyedSubtree(
                key: ValueKey(_step),
                child: switch (_step) {
                  0 => _buildNameStep(),
                  1 => _buildAgeStep(),
                  _ => _buildSoundStep(),
                },
              ),
            ],
          ),
          ),
        ),
      ),
    );
  }

  Widget _title(String text) => Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      );

  Widget _nextButton({required String label, required VoidCallback onTap}) {
    return BouncyButton(
      color: const Color(0xFF3DA35D),
      padding: const EdgeInsets.symmetric(vertical: 16),
      onTap: onTap,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  // ① 아바타 + 이름
  Widget _buildNameStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('만나서 반가워요!\n누가 배울 건가요?'),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final avatar in profileAvatars)
              GestureDetector(
                onTap: () => setState(() => _emoji = avatar),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: _emoji == avatar
                        ? const Color(0xFFD7FFB8)
                        : Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _emoji == avatar
                          ? const Color(0xFF3DA35D)
                          : Colors.grey.shade300,
                      width: 3,
                    ),
                  ),
                  child: Center(
                    child:
                        Text(avatar, style: const TextStyle(fontSize: 30)),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          switch (_emoji) {
            '🐣' => '병아리 친구구나! 반가워!',
            '🐰' => '깡충깡충 토끼 친구네!',
            '🦊' => '똑똑한 여우 친구!',
            '🐻' => '든든한 곰 친구야!',
            '🐯' => '용감한 호랑이 친구!',
            '🦄' => '반짝반짝 유니콘 친구!',
            '🐬' => '헤엄치는 돌고래 친구!',
            '🦖' => '으르렁 공룡 친구다!',
            _ => '마음에 드는 얼굴을 골라 봐!',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: AppColors.brown,
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _nameController,
          maxLength: 8,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            hintText: '아이 이름 (예: 하늘)',
            hintStyle: TextStyle(
              color: Colors.grey.shade400,
              fontWeight: FontWeight.normal,
            ),
            counterText: '',
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _nextButton(label: '다음', onTap: () => setState(() => _step = 1)),
      ],
    );
  }

  // ② 나이 고르기 → 홈에서 그 카테고리를 추천으로 표시
  Widget _buildAgeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('아이는 몇 살인가요?'),
        const SizedBox(height: 6),
        Text(
          '나이에 맞는 단계를 추천해 드려요\n(나중에 어디서든 시작할 수 있어요)',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 16),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 10,
          runSpacing: 10,
          children: [
            for (var i = 0; i < Curriculum.categories.length; i++)
              GestureDetector(
                onTap: () => setState(() => _ageIndex = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: _ageIndex == i
                        ? const Color(0xFFD7FFB8)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: _ageIndex == i
                          ? const Color(0xFF3DA35D)
                          : Colors.grey.shade300,
                      width: 3,
                    ),
                  ),
                  child: Text(
                    '${Curriculum.categories[i].emoji} '
                    '${Curriculum.categories[i].title}',
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        _nextButton(label: '다음', onTap: () => setState(() => _step = 2)),
      ],
    );
  }

  // ③ 소리 확인: 듣기 문제가 있어서 소리 상태를 미리 맞춰 둔다.
  Widget _buildSoundStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _title('소리를 확인해 볼까요?'),
        const SizedBox(height: 6),
        Text(
          '문제를 읽어 주는 음성과 듣기 문제가 있어요.\n버튼을 눌러 소리가 나는지 확인해 보세요!',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
        ),
        const SizedBox(height: 20),
        BouncyButton(
          color: const Color(0xFF1CB0F6),
          padding: const EdgeInsets.symmetric(vertical: 16),
          onTap: () => Speech.speak('안녕? 나는 부엉이야. 우리 같이 놀면서 공부하자!'),
          child: const Text(
            '🔊 소리 들어 보기',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 24),
        _nextButton(
          label: '잘 들려요! 시작하기',
          onTap: () => _finish(soundOn: true),
        ),
        const SizedBox(height: 10),
        BouncyButton(
          color: Colors.white,
          shadowColor: Colors.grey.shade300,
          border: Border.all(color: Colors.grey.shade300, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 14),
          onTap: () => _finish(soundOn: false),
          child: Text(
            '소리 없이 할래요',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
        ),
      ],
    );
  }
}
