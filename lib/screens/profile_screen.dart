import 'package:flutter/material.dart';

import '../models/premium.dart';
import '../models/profile.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/parent_gate.dart';
import 'level_map_screen.dart';
import 'pass_screen.dart';

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
    if (created == true) await _load();
  }

  Future<void> _editProfile(Profile profile) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (context) => _ProfileDialog(editing: profile),
    );
    if (changed == true) await _load();
  }

  Future<void> _deleteProfile(Profile profile) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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
        title: const Text(
          '누가 배울까요?',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : Align(
              alignment: const Alignment(0, -0.5),
              child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                if (widget.asLauncher) ...[
                  const Center(
                      child: Text('🦉', style: TextStyle(fontSize: 52))),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '내 얼굴을 고르면 내 진도로 이어져요!',
                      style: TextStyle(
                          fontSize: 14, color: Colors.grey.shade600),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                for (final profile in _profiles) ...[
                  BouncyButton(
                    color: Colors.white,
                    shadowColor: Colors.grey.shade300,
                    borderRadius: 22,
                    padding: const EdgeInsets.all(14),
                    border: !widget.asLauncher &&
                            profile.id == Profiles.activeId
                        ? Border.all(color: const Color(0xFF3DA35D), width: 3)
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
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3DA35D),
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
                        IconButton(
                          onPressed: () => _editProfile(profile),
                          icon: Icon(Icons.edit_rounded,
                              size: 22, color: Colors.grey.shade500),
                        ),
                        if (profile.id != 1)
                          IconButton(
                            onPressed: () => _deleteProfile(profile),
                            icon: Icon(Icons.delete_outline_rounded,
                                size: 22, color: Colors.grey.shade500),
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
                          color: Color(0xFF2E7D46),
                          size: 26,
                        ),
                        SizedBox(width: 8),
                        Text(
                          '새 프로필 만들기',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2E7D46),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Text(
                  '프로필은 4명까지 만들 수 있어요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade500),
                ),
              ],
              ),
            ),
            ),
    );
  }
}

/// 프로필 만들기/고치기: 동물 아바타를 고르고 이름을 적는다.
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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final editing = widget.editing;
    if (editing != null) {
      await Profiles.update(editing.id, emoji: _emoji, name: name);
    } else {
      final profile = await Profiles.add(emoji: _emoji, name: name);
      if (profile != null) await Profiles.setActive(profile.id);
    }
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
            Text(
              widget.editing != null ? '프로필 고치기' : '새 프로필 만들기',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
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
