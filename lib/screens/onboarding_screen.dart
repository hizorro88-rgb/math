import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/quokka_avatar.dart';

import '../models/curriculum.dart';
import '../models/profile.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/selectable_tile.dart';
import 'level_map_screen.dart';
import 'pet_intro_screen.dart';

/// 첫 실행 온보딩 — 폰은 한 번만 건넨다.
/// ① 어른 화면 한 장: 이름(선택)·얼굴·나이·소리 확인 → "아이에게 건네주기"
/// ② 건네주기: 아무 데나 누르면 아이 구간 시작
/// ③ 아이 구간: 알 고르기 → 톡톡 부화 → 첫 선물·첫 밥 → 첫 판 바로 시작 → 홈
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
  /// 0: 어른 화면, 1: 건네주기
  int _step = 0;
  String _emoji = profileAvatars.first;
  final _nameController = TextEditingController();
  int? _ageIndex;
  bool _effectsOn = true;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 어른이 정한 것을 모두 저장하고 건네주기 화면으로.
  Future<void> _handOff() async {
    // 읽어주기는 글을 모르는 아이가 혼자 풀 수 있게 하는 기능이라 여기서 끄지 않는다.
    // '효과음'은 딩동 소리만 (읽어주기는 설정 > 부모님 확인 뒤에 끌 수 있다).
    await Sounds.setEnabled(_effectsOn);
    await Speech.setEnabled(true);
    final name = _nameController.text.trim();
    await Profiles.update(
      Profiles.activeId,
      emoji: _emoji,
      name: name.isEmpty ? '우리 아이' : name,
    );
    final prefs = await SharedPreferences.getInstance();
    if (_ageIndex != null) {
      await prefs.setInt(
          Profiles.scoped(OnboardingScreen.ageCategoryKey), _ageIndex!);
    }
    // 아이 구간 도중에 앱을 꺼도 다음엔 홈에서 이어진다 (친구 만나기 카드가 기다린다).
    await prefs.setBool(OnboardingScreen.doneKey, true);
    if (!mounted) return;
    setState(() => _step = 1);
    Speech.speak('화면을 눌러 봐!');
  }

  /// 아이 구간: 알 고르기 → 부화 → 첫 선물 → 첫 판 → 홈
  Future<void> _startKid() async {
    final picked = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const PetIntroScreen(firstRun: true)),
    );
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LevelMapScreen(firstRun: picked == true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _step == 0 ? _buildGrownUp() : _buildHandOff(),
      ),
    );
  }

  // ② 건네주기: 큰 쿼카 하나. 어디를 눌러도 시작.
  Widget _buildHandOff() {
    return GestureDetector(
      key: const ValueKey('handoff'),
      behavior: HitTestBehavior.opaque,
      onTap: _startKid,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('👐', style: TextStyle(fontSize: 56)),
            const QuokkaFace(size: 150),
            const SizedBox(height: 18),
            Text('화면을 눌러 봐!', style: displayStyle(fontSize: AppFont.display)),
            const SizedBox(height: 10),
            const Text(
              '이제 아이에게 건네주세요',
              style:
                  TextStyle(fontSize: AppFont.small, color: AppColors.inkSoft),
            ),
          ],
        ),
      ),
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Text(text, style: displayStyle(fontSize: AppFont.title)),
      );

  // ① 어른 화면 한 장
  Widget _buildGrownUp() {
    // 건네주기 버튼은 아래에 고정 — 첫 화면에서 바로 보인다
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: QuokkaFace(size: 72)),
                const SizedBox(height: 6),
                Text(
                  '보호자님, 30초면 돼요',
                  textAlign: TextAlign.center,
                  style: displayStyle(fontSize: AppFont.display),
                ),
                const SizedBox(height: 4),
                const Text(
                  '정한 뒤에 아이에게 폰을 건네주세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: AppFont.small, color: AppColors.inkSoft),
                ),
                _label('아이 이름 (안 써도 돼요)'),
                TextField(
                  controller: _nameController,
                  maxLength: 8,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: AppFont.heading, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(
                    hintText: '예: 하늘',
                    hintStyle: const TextStyle(
                      color: AppColors.inkMuted,
                      fontWeight: FontWeight.normal,
                    ),
                    counterText: '',
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.outline),
                    ),
                  ),
                ),
                _label('얼굴'),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final avatar in profileAvatars)
                      SelectableChip(
                        circle: true,
                        selected: _emoji == avatar,
                        onTap: () => setState(() => _emoji = avatar),
                        child:
                            Text(avatar, style: const TextStyle(fontSize: 30)),
                      ),
                  ],
                ),
                _label('나이 (맞는 단계를 추천해요)'),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (var i = 0; i < Curriculum.categories.length; i++)
                      SelectableChip(
                        selected: _ageIndex == i,
                        onTap: () => setState(() => _ageIndex = i),
                        child: Text(
                          '${Curriculum.categories[i].emoji} '
                          '${Curriculum.categories[i].title}',
                          style: const TextStyle(
                              fontSize: AppFont.title,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                _label('소리'),
                Row(
                  children: [
                    Expanded(
                      child: BouncyButton(
                        key: const ValueKey('sound-test'),
                        color: AppColors.listen,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        onTap: () => Speech.speak('안녕? 나는 쿼카야. 우리 같이 놀면서 공부하자!',
                            force: true),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.volume_up_rounded, color: Colors.white),
                            SizedBox(width: 6),
                            Text(
                              '소리 확인',
                              style: TextStyle(
                                fontSize: AppFont.title,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text('효과음',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    Switch(
                      key: const ValueKey('effects-switch'),
                      value: _effectsOn,
                      activeTrackColor: AppColors.green,
                      onChanged: (v) => setState(() => _effectsOn = v),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
          child: SizedBox(
            width: double.infinity,
            child: BouncyButton(
              key: const ValueKey('handoff-go'),
              color: AppColors.green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              onTap: _handOff,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '아이에게 건네주기',
                    style: TextStyle(
                      fontSize: AppFont.heading,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 6),
                  Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
