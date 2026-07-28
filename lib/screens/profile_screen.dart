import 'package:flutter/material.dart';

import '../models/profile.dart';
import '../widgets/bouncy_button.dart';

/// 프로필 선택 화면: 누가 놀지 고르고, 새 프로필을 만든다.
/// 진행도·코인·미션은 프로필마다 따로 저장된다.
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  List<Profile> _profiles = [];
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profiles = await Profiles.load();
    if (!mounted) return;
    setState(() {
      _profiles = profiles;
      _loaded = true;
    });
  }

  Future<void> _select(Profile profile) async {
    await Profiles.setActive(profile.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _addProfile() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => const _NewProfileDialog(),
    );
    if (created == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFA560E8),
        foregroundColor: Colors.white,
        title: const Text(
          '누가 놀까요?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final profile in _profiles) ...[
                  BouncyButton(
                    color: Colors.white,
                    shadowColor: Colors.grey.shade300,
                    borderRadius: 22,
                    padding: const EdgeInsets.all(14),
                    border: profile.id == Profiles.activeId
                        ? Border.all(color: const Color(0xFFA560E8), width: 3)
                        : null,
                    onTap: () => _select(profile),
                    child: Row(
                      children: [
                        Text(profile.emoji,
                            style: const TextStyle(fontSize: 36)),
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
                        if (profile.id == Profiles.activeId)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFA560E8),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              '사용 중',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (_profiles.length < Profiles.maxProfiles)
                  BouncyButton(
                    color: const Color(0xFFF3EAFD),
                    shadowColor: const Color(0xFFD9C2F5),
                    borderRadius: 22,
                    padding: const EdgeInsets.all(16),
                    onTap: _addProfile,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_circle_rounded,
                            color: Color(0xFFA560E8), size: 26),
                        SizedBox(width: 8),
                        Text(
                          '새 프로필 만들기',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFFA560E8),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

/// 새 프로필 만들기: 동물 아바타를 고르고 이름을 적는다.
class _NewProfileDialog extends StatefulWidget {
  const _NewProfileDialog();

  @override
  State<_NewProfileDialog> createState() => _NewProfileDialogState();
}

class _NewProfileDialogState extends State<_NewProfileDialog> {
  String _emoji = profileAvatars.first;
  final _nameController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final profile = await Profiles.add(emoji: _emoji, name: name);
    if (profile != null) await Profiles.setActive(profile.id);
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '새 프로필 만들기',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 14),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final avatar in profileAvatars)
                  GestureDetector(
                    onTap: () => setState(() => _emoji = avatar),
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: avatar == _emoji
                            ? const Color(0xFFF3EAFD)
                            : Colors.grey.shade100,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: avatar == _emoji
                              ? const Color(0xFFA560E8)
                              : Colors.grey.shade300,
                          width: 2,
                        ),
                      ),
                      child: Center(
                        child:
                            Text(avatar, style: const TextStyle(fontSize: 26)),
                      ),
                    ),
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
            BouncyButton(
              color: const Color(0xFFA560E8),
              padding: const EdgeInsets.symmetric(vertical: 14),
              onTap: _create,
              child: const Text(
                '만들기',
                style: TextStyle(
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
