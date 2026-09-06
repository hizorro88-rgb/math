import 'package:flutter/material.dart';

import '../models/stickers.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/bouncy_button.dart';

/// 스티커북: 퀴즈를 통과하면 받은 스티커를
/// 아이가 원하는 자리에 직접 골라 붙인다.
/// 페이지를 다 채우면 보너스 코인, 앨범을 다 채우면 새 앨범!
class StickerBookScreen extends StatefulWidget {
  const StickerBookScreen({super.key});

  @override
  State<StickerBookScreen> createState() => _StickerBookScreenState();
}

class _StickerBookScreenState extends State<StickerBookScreen> {
  List<Set<int>>? _collected;
  int _tickets = 0;
  int _albums = 0;
  bool _placing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final collected = await StickerStore.load();
    final tickets = await StickerStore.tickets();
    final albums = await StickerStore.completedAlbums();
    if (!mounted) return;
    setState(() {
      _collected = collected;
      _tickets = tickets;
      _albums = albums;
    });
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _tapSlot(int pageIndex, int stickerIndex) async {
    final collected = _collected;
    if (collected == null || _placing) return;
    final sticker = stickerPages[pageIndex].stickers[stickerIndex];

    // 이미 붙인 스티커: 이름을 읽어 준다.
    if (collected[pageIndex].contains(stickerIndex)) {
      Speech.speak(sticker.name);
      return;
    }
    if (_tickets < 1) {
      _snack('🎟️ 붙일 스티커가 없어요. 퀴즈 한 판을 통과하면 1장을 받아요!');
      return;
    }

    _placing = true;
    final result = await StickerStore.place(pageIndex, stickerIndex);
    _placing = false;
    if (!mounted || result == null) return;

    Sounds.correct(1);
    Speech.speak('${sticker.name} 스티커!');
    await _load();
    if (!mounted) return;

    if (result.albumCompleted) {
      await _celebrate(
        emoji: '🏆',
        title: '앨범을 다 채웠어요!',
        message:
            '축하해요! 보너스 🪙 ${result.bonusCoins}을 받았어요.\n반짝반짝 새 앨범이 시작돼요!',
      );
    } else if (result.pageCompleted) {
      await _celebrate(
        emoji: '🎉',
        title: '페이지 완성!',
        message: '보너스 🪙 ${result.bonusCoins}을 받았어요!',
      );
    } else {
      _snack('${sticker.emoji} ${sticker.name} 스티커를 붙였어요!');
    }
  }

  Future<void> _celebrate({
    required String emoji,
    required String title,
    required String message,
  }) async {
    Sounds.complete();
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(emoji,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 52)),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 15, color: Colors.grey.shade600, height: 1.5),
              ),
              const SizedBox(height: 20),
              BouncyButton(
                color: const Color(0xFF58CC02),
                padding: const EdgeInsets.symmetric(vertical: 14),
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  '신난다!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final collected = _collected;
    final total = stickerPages.fold(0, (sum, p) => sum + p.stickers.length);
    final owned = collected?.fold(0, (sum, set) => sum + set.length) ?? 0;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFEC7CA5),
        foregroundColor: Colors.white,
        title: const Text(
          '📔 스티커북',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: collected == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // 들고 있는 스티커: 여기서 골라 붙인다
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _tickets > 0
                        ? const Color(0xFFFFF3C4)
                        : const Color(0xFFFDE8F4),
                    borderRadius: BorderRadius.circular(20),
                    border: _tickets > 0
                        ? Border.all(color: const Color(0xFFFFD34D), width: 2)
                        : null,
                  ),
                  child: Column(
                    children: [
                      Text(
                        _tickets > 0
                            ? '🎟️ 붙일 수 있는 스티커 $_tickets장!'
                            : '모은 스티커 $owned / $total'
                                '${_albums > 0 ? ' · 완성한 앨범 🏆 $_albums권' : ''}',
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tickets > 0
                            ? '마음에 드는 흐린 스티커를 눌러서 붙여 보세요!'
                            : '퀴즈 한 판을 통과할 때마다 스티커 1장을 받아요.\n'
                                '페이지 완성 🪙 ${StickerStore.pageBonus} · '
                                '앨범 완성 🪙 ${StickerStore.albumBonus} 보너스!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                for (var p = 0; p < stickerPages.length; p++) ...[
                  _PageCard(
                    page: stickerPages[p],
                    collected: collected[p],
                    canPlace: _tickets > 0,
                    onTap: (s) => _tapSlot(p, s),
                  ),
                  const SizedBox(height: 14),
                ],
              ],
            ),
    );
  }
}

class _PageCard extends StatelessWidget {
  const _PageCard({
    required this.page,
    required this.collected,
    required this.canPlace,
    required this.onTap,
  });

  final StickerPage page;
  final Set<int> collected;
  final bool canPlace;
  final void Function(int stickerIndex) onTap;

  @override
  Widget build(BuildContext context) {
    final done = collected.length == page.stickers.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: done ? page.color : Colors.grey.shade200,
          width: 2.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 4),
            blurRadius: 10,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(page.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Text(
                page.title,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              done
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: page.color,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        '완성! 🎉',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      '${collected.length}/${page.stickers.length}',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade600),
                    ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            children: [
              for (var i = 0; i < page.stickers.length; i++)
                _StickerSlot(
                  sticker: page.stickers[i],
                  owned: collected.contains(i),
                  highlight: canPlace && !collected.contains(i),
                  color: page.color,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StickerSlot extends StatelessWidget {
  const _StickerSlot({
    required this.sticker,
    required this.owned,
    required this.highlight,
    required this.color,
    required this.onTap,
  });

  final Sticker sticker;
  final bool owned;

  /// 붙일 스티커가 있어서 이 빈 자리를 고를 수 있는 상태
  final bool highlight;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: owned ? color.withValues(alpha: 0.15) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: owned
                ? color
                : highlight
                    ? const Color(0xFFFFC107)
                    : Colors.grey.shade300,
            width: owned || highlight ? 2 : 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 못 모은 스티커는 흐린 그림자(실루엣)로 보여줘서 골라 붙일 수 있게 한다.
            Opacity(
              opacity: owned ? 1 : 0.3,
              child: Text(sticker.emoji, style: const TextStyle(fontSize: 30)),
            ),
            const SizedBox(height: 2),
            Text(
              sticker.name,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.bold,
                color: owned ? Colors.black87 : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
