import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/curriculum.dart';
import '../models/premium.dart';
import '../models/profile.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/parent_gate.dart';
import '../widgets/quokka_avatar.dart';
import '../widgets/selectable_tile.dart';
import 'level_map_screen.dart';
import 'onboarding_screen.dart';
import 'pass_screen.dart';
import 'pet_intro_screen.dart';

/// 프로필 선택 화면: 누가 놀지 고르고, 프로필을 만들고 고치고 지운다.
/// 진행도·코인·미션은 프로필마다 따로 저장된다.
/// [asLauncher]면 앱 시작 화면으로 쓰여서, 고르면 홈으로 들어간다.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.asLauncher = false});

  final bool asLauncher;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Profile> _profiles = [];
  bool _hasPass = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await Profiles.load();
    final hasPass = await PremiumStore.hasPass();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _hasPass = hasPass;
      _loaded = true;
    });
  }

  Future<void> _select(Profile profile) async {
    await Profiles.setActive(profile.id);
    if (!mounted) return;
    if (widget.asLauncher) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LevelMapScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addProfile() async {
    // 무료는 프로필 1명 — 더 만들려면 가족 이용권 (부모 확인 뒤 안내)
    if (!_hasPass && _profiles.length >= PremiumStore.freeProfiles) {
      final ok = await checkParentGate(context);
      if (!ok || !mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const PassScreen()),
      );
      await _load();
      return;
    }
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _ProfileDialog(),
    );
    if (created != true || !mounted) return;
    // 새 아이도 첫 실행과 같은 길: 알 고르기 → 톡톡 부화 → 첫 선물·첫 밥 → 홈
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const PetIntroScreen()),
    );
    if (!mounted) return;
    await _select((await Profiles.active()));
  }

  Future<void> _editProfile(Profile profile) async {
    // 이름·나이를 바꾸는 건 어른만 (나이는 설정에서도 부모 확인 뒤에 바뀐다)
    final ok = await checkParentGate(context);
    if (!ok || !mounted) return;
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ProfileDialog(editing: profile),
    );
    if (changed == true) await _load();
  }

  Future<void> _deleteProfile(Profile profile) async {
    // 형제의 기록을 아이가 지우지 않게 부모 확인부터
    final ok = await checkParentGate(context);
    if (!ok || !mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('${profile.emoji} ${profile.name} 프로필을 지울까요?'),
        content: const Text('이 프로필의 별·점수·코인 등 모든 기록이 함께 지워져요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('지우기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await Profiles.remove(profile.id);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.asLauncher,
        title: const Text('누가 배울까요?'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: const Alignment(0, -0.2),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (widget.asLauncher) ...[
                      const Center(child: QuokkaFace(size: 78)),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          '내 얼굴을 고르면 내 진도로 이어져요!',
                          style:
                              TextStyle(fontSize: 14, color: AppColors.inkSoft),
                        ),
                      ),
                      const SizedBox(height: 14),
                    ],
                    for (final profile in _profiles) ...[
                      BouncyButton(
                        color: Colors.white,
                        shadowColor: AppColors.outline,
                        borderRadius: 22,
                        padding: const EdgeInsets.all(14),
                        border: !widget.asLauncher &&
                                profile.id == Profiles.activeId
                            ? Border.all(color: AppColors.correct, width: 3)
                            : null,
                        onTap: () => _select(profile),
                        child: Row(
                          children: [
                            Container(
                              width: 64,
                              height: 64,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF0F7EC),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(profile.emoji,
                                    style: const TextStyle(fontSize: 38)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                profile.name,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            if (!widget.asLauncher &&
                                profile.id == Profiles.activeId)
                              // 고른 칸 = ✓ 하나 (SelectableTile과 같은 모양)
                              Semantics(
                                label: '사용 중',
                                child: const CircleAvatar(
                                  radius: 13,
                                  backgroundColor: AppColors.correct,
                                  child: Icon(Icons.check_rounded,
                                      size: 17, color: Colors.white),
                                ),
                              ),
                            IconButton(
                              onPressed: () => _editProfile(profile),
                              icon: const Icon(Icons.edit_rounded,
                                  size: 22, color: AppColors.inkMuted),
                            ),
                            if (profile.id != 1)
                              IconButton(
                                onPressed: () => _deleteProfile(profile),
                                icon: const Icon(Icons.delete_outline_rounded,
                                    size: 22, color: AppColors.inkMuted),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_profiles.length < Profiles.maxProfiles)
                      BouncyButton(
                        color: const Color(0xFFF0F7EC),
                        shadowColor: const Color(0xFFC9E3BF),
                        borderRadius: 22,
                        padding: const EdgeInsets.all(16),
                        onTap: _addProfile,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_rounded,
                              color: AppColors.greenPressed,
                              size: 26,
                            ),
                            SizedBox(width: 8),
                            Text(
                              '새 프로필 만들기',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: AppColors.greenPressed,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 12),
                    const Text(
                      '프로필은 4명까지 만들 수 있어요',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12.5, color: AppColors.inkMuted),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// 프로필 만들기/고치기: 동물 아바타를 고르고 이름을 적고 나이를 고른다.
/// 나이는 홈의 추천 배지와 '이전 단계 접기' 기준이 된다.
class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({this.editing});

  /// null이면 새로 만들기, 있으면 그 프로필을 고친다.
  final Profile? editing;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  late String _emoji = widget.editing?.emoji ?? profileAvatars.first;
  late final _nameController =
      TextEditingController(text: widget.editing?.name ?? '');

  /// 고른 나이(수학 카테고리 인덱스). null이면 선택 안 함.
  int? _ageIndex;

  @override
  void initState() {
    super.initState();
    final editing = widget.editing;
    if (editing != null) _loadAge(editing.id);
  }

  Future<void> _loadAge(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final idx =
        prefs.getInt(Profiles.scopedFor(id, OnboardingScreen.ageCategoryKey));
    if (!mounted) return;
    setState(() {
      _ageIndex = idx != null && idx >= 0 && idx < Curriculum.categories.length
          ? idx
          : null;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 이름은 안 써도 된다 (눌렀는데 아무 일도 없으면 고장으로 안다).
    final typed = _nameController.text.trim();
    final name = typed.isEmpty ? '우리 아이' : typed;
    final editing = widget.editing;
    int profileId;
    if (editing != null) {
      await Profiles.update(editing.id, emoji: _emoji, name: name);
      profileId = editing.id;
    } else {
      final profile = await Profiles.add(emoji: _emoji, name: name);
      if (profile == null) {
        if (mounted) Navigator.of(context).pop(false);
        return;
      }
      await Profiles.setActive(profile.id);
      profileId = profile.id;
    }
    // 나이 저장: 홈의 추천 배지·이전 단계 접기가 이 값을 따라간다.
    final prefs = await SharedPreferences.getInstance();
    final ageKey =
        Profiles.scopedFor(profileId, OnboardingScreen.ageCategoryKey);
    if (_ageIndex != null) {
      await prefs.setInt(ageKey, _ageIndex!);
    } else {
      await prefs.remove(ageKey);
    }
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Widget _ageChip(String label, int? value) {
    return SelectableChip(
      selected: _ageIndex == value,
      onTap: () => setState(() => _ageIndex = value),
      child: Text(
        label,
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.editing != null ? '프로필 고치기' : '새 프로필 만들기',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final avatar in profileAvatars)
                  SelectableChip(
                    circle: true,
                    size: 52,
                    selected: avatar == _emoji,
                    onTap: () => setState(() => _emoji = avatar),
                    child: Text(avatar, style: const TextStyle(fontSize: 26)),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              maxLength: 8,
              decoration: InputDecoration(
                hintText: '이름을 적어 주세요',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              '몇 살이에요? (딱 맞는 단계를 추천해 드려요)',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.inkSoft,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 6,
              runSpacing: 6,
              children: [
                for (var i = 0; i < Curriculum.categories.length; i++)
                  _ageChip(Curriculum.categories[i].title, i),
                _ageChip('선택 안 함', null),
              ],
            ),
            const SizedBox(height: 14),
            BouncyButton(
              color: AppColors.green,
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: _save,
              child: Text(
                widget.editing != null ? '저장하기' : '만들기',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
