import 'package:flutter/material.dart';

import '../models/reward_board.dart';
import '../models/sticker_canvas.dart';
import '../models/stickers.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../theme.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/kid_notice.dart';

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

  /// 꾸미기 판 상태
  List<PlacedSticker> _canvas = [];
  List<Sticker> _palette = [];
  String? _brush; // 팔레트에서 고른 스티커
  bool _erasing = false;

  /// 칭찬 스티커판 상태
  List<String?> _board = List.filled(RewardBoardStore.slots, null);
  String? _promise;
  int _boards = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final collected = await StickerStore.load();
    final tickets = await StickerStore.tickets();
    final albums = await StickerStore.completedAlbums();
    final canvas = await CanvasStore.load();
    final palette = await StickerStore.collectedStickers();
    final board = await RewardBoardStore.load();
    final promise = await RewardBoardStore.promise();
    final boards = await RewardBoardStore.completedBoards();
    if (!mounted) return;
    setState(() {
      _collected = collected;
      _tickets = tickets;
      _albums = albums;
      _canvas = canvas;
      _palette = palette;
      _board = board;
      _promise = promise;
      _boards = boards;
      if (_brush != null && !palette.any((s) => s.emoji == _brush)) {
        _brush = null;
      }
    });
  }

  // ── 칭찬 스티커판 ──────────────────────────────────────────

  /// 붙일 스티커 그림을 고르는 바텀 시트 (60종 전체 중에서)
  Future<String?> _pickStickerDesign() {
    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                '어떤 스티커를 붙일까요?',
                style: TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: GridView.count(
                  crossAxisCount: 6,
                  shrinkWrap: true,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: [
                    for (final page in stickerPages)
                      for (final sticker in page.stickers)
                        GestureDetector(
                          key: ValueKey('design:${sticker.emoji}'),
                          onTap: () => Navigator.of(context).pop(sticker.emoji),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.cream,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Center(
                              child: Text(sticker.emoji,
                                  style: const TextStyle(fontSize: 26)),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _tapBoardSlot(int slot) async {
    if (_board[slot] != null) return; // 이미 붙은 칸
    if (_tickets < 1) {
      _snack('🎟️', '스티커가 없어요. 한 판 통과하면 1장 생겨요!');
      return;
    }
    final emoji = await _pickStickerDesign();
    if (emoji == null || !mounted) return;

    final result = await RewardBoardStore.place(slot, emoji);
    if (result == null || !mounted) return;
    Sounds.pop();
    await _load();
    if (!mounted) return;

    if (result.completed) {
      final lines = [
        if (result.promise != null) '🎁 약속한 선물: ${result.promise}',
        if (result.gift != null)
          '앱 선물: ${result.gift!.emoji} ${result.gift!.name}을(를) 받았어요!'
        else
          '보너스 🪙 ${result.bonusCoins}을 받았어요!',
        '반짝반짝 새 스티커판이 시작돼요!',
      ];
      await _celebrate(
        emoji: '🏆',
        title: '스티커판 완성!',
        message: lines.join('\n'),
      );
    }
  }

  // ── 꾸미기 판 ──────────────────────────────────────────────

  void _pickBrush(Sticker sticker) {
    Speech.speak(sticker.name);
    setState(() {
      _brush = sticker.emoji;
      _erasing = false;
    });
  }

  void _tapCanvas(Offset fraction) {
    final brush = _brush;
    if (_erasing || brush == null) return;
    if (_canvas.length >= CanvasStore.maxPlaced) {
      _snack('✋', '판이 가득 찼어요! 몇 개 떼어 볼까요?');
      return;
    }
    Sounds.pop();
    setState(() {
      _canvas.add(PlacedSticker(
        emoji: brush,
        x: (fraction.dx * 1000).round().clamp(0, 1000),
        y: (fraction.dy * 1000).round().clamp(0, 1000),
      ));
    });
    CanvasStore.save(_canvas);
  }

  void _dragCanvasSticker(int index, Offset fractionDelta) {
    final current = _canvas[index];
    setState(() {
      _canvas[index] = current.moveTo(
        (current.x + fractionDelta.dx * 1000).round().clamp(0, 1000),
        (current.y + fractionDelta.dy * 1000).round().clamp(0, 1000),
      );
    });
  }

  void _dragEnd() => CanvasStore.save(_canvas);

  void _tapCanvasSticker(int index) {
    if (!_erasing) return;
    Sounds.pop();
    setState(() => _canvas.removeAt(index));
    CanvasStore.save(_canvas);
  }

  Future<void> _clearCanvas() async {
    final ok = await showKidConfirm(
      context,
      emoji: '🗑️',
      question: '판을 다 지울까요?',
      detail: '모은 스티커는 그대로예요',
      speech: '판을 다 지울까요? 초록 버튼을 누르면 그대로 둬요',
      keepLabel: '그대로 둘래요',
      actionLabel: '🗑️ 다 지우기',
    );
    if (!ok || !mounted) return;
    setState(() {
      _canvas = [];
      _erasing = false;
    });
    CanvasStore.save(_canvas);
  }

  void _snack(String emoji, String message) =>
      showKidNotice(context, emoji: emoji, text: message);

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
      _snack('🎟️', '스티커가 없어요. 한 판 통과하면 1장 생겨요!');
      return;
    }

    _placing = true;
    final result = await StickerStore.place(pageIndex, stickerIndex);
    _placing = false;
    if (!mounted || result == null) return;

    Sounds.pop();
    await _load();
    if (!mounted) return;

    if (result.albumCompleted) {
      await _celebrate(
        emoji: '🏆',
        title: '앨범을 다 채웠어요!',
        message: '축하해요! 보너스 🪙 ${result.bonusCoins}을 받았어요.\n반짝반짝 새 앨범이 시작돼요!',
      );
    } else if (result.pageCompleted) {
      await _celebrate(
        emoji: '🎉',
        title: '페이지 완성!',
        message: '보너스 🪙 ${result.bonusCoins}을 받았어요!',
      );
    } else {
      _snack(sticker.emoji, '${sticker.name} 붙였어요!');
    }
  }

  Future<void> _celebrate({
    required String emoji,
    required String title,
    required String message,
  }) async {
    Sounds.complete();
    Speech.speak(title);
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
                style: const TextStyle(
                    fontSize: AppFont.display, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: AppFont.body,
                    color: AppColors.inkSoft,
                    height: 1.5),
              ),
              const SizedBox(height: 20),
              BouncyButton(
                color: AppColors.green,
                padding: const EdgeInsets.symmetric(vertical: 14),
                onTap: () => Navigator.of(context).pop(),
                child: const Text(
                  '신난다!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: AppFont.heading,
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
      appBar: AppBar(
        title: const Text('스티커북'),
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
                    color:
                        _tickets > 0 ? AppColors.rewardSurface : Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: _tickets > 0 ? AppColors.amber : AppColors.outline,
                      width: 2,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        _tickets > 0
                            ? '🎟️ 붙일 수 있는 스티커 $_tickets장!'
                            : '모은 스티커 $owned / $total'
                                '${_albums > 0 ? ' · 완성한 앨범 🏆 $_albums권' : ''}',
                        style: const TextStyle(
                            fontSize: AppFont.title,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _tickets > 0 ? '? 칸을 눌러 붙여요!' : '▶ 한 판 통과하면 1장!',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: AppFont.small,
                            height: 1.5,
                            color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                // 칭찬 스티커판: 1~20 숫자 위에 스티커를 붙이고 다 모으면 선물!
                _RewardBoardCard(
                  board: _board,
                  boards: _boards,
                  promise: _promise,
                  canPlace: _tickets > 0,
                  onTapSlot: _tapBoardSlot,
                ),
                const SizedBox(height: 14),
                // 모은 스티커를 골라 원하는 곳에 붙이는 꾸미기 판
                _CanvasCard(
                  placed: _canvas,
                  palette: _palette,
                  brush: _brush,
                  erasing: _erasing,
                  hasTickets: _tickets > 0,
                  onPickBrush: _pickBrush,
                  onTapCanvas: _tapCanvas,
                  onDragSticker: _dragCanvasSticker,
                  onDragEnd: _dragEnd,
                  onTapSticker: _tapCanvasSticker,
                  onToggleErase: () => setState(() => _erasing = !_erasing),
                  onClear: _clearCanvas,
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
          color: done ? page.color : AppColors.line,
          width: 2.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(page.emoji,
                  style: const TextStyle(fontSize: AppFont.display)),
              const SizedBox(width: 8),
              Text(
                page.title,
                style: const TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.bold),
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
                          fontSize: AppFont.small,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    )
                  : Text(
                      '${collected.length}/${page.stickers.length}',
                      style: const TextStyle(
                          fontSize: AppFont.small,
                          fontWeight: FontWeight.bold,
                          color: AppColors.inkSoft),
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
          color: owned ? color.withValues(alpha: 0.15) : AppColors.cream,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: owned
                ? color
                : highlight
                    ? AppColors.amber
                    : AppColors.outline,
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
                fontSize: AppFont.small,
                fontWeight: FontWeight.bold,
                color: owned ? AppColors.ink : AppColors.inkMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 꾸미기 판: 모은 스티커를 골라 원하는 자리에 자유롭게 붙인다.
class _CanvasCard extends StatelessWidget {
  const _CanvasCard({
    required this.placed,
    required this.palette,
    required this.brush,
    required this.erasing,
    required this.onPickBrush,
    required this.onTapCanvas,
    required this.onDragSticker,
    required this.onDragEnd,
    required this.onTapSticker,
    required this.onToggleErase,
    required this.onClear,
    required this.hasTickets,
  });

  final List<PlacedSticker> placed;
  final List<Sticker> palette;
  final String? brush;
  final bool erasing;
  final void Function(Sticker) onPickBrush;
  final void Function(Offset fraction) onTapCanvas;
  final void Function(int index, Offset fractionDelta) onDragSticker;
  final VoidCallback onDragEnd;
  final void Function(int index) onTapSticker;
  final VoidCallback onToggleErase;
  final VoidCallback onClear;

  /// 아직 안 붙인 스티커가 있는지 (빈 팔레트 안내 분기용)
  final bool hasTickets;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🖼️', style: TextStyle(fontSize: AppFont.display)),
              const SizedBox(width: 8),
              const Text(
                '내 꾸미기 판',
                style: TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // 지우개 모드
              GestureDetector(
                onTap: placed.isEmpty ? null : onToggleErase,
                // 켜짐 = 앱 공용 선택 모양(라임+초록) — 빨강은 오답에만 쓴다
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: erasing ? AppColors.selectedFill : AppColors.cream,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: erasing ? AppColors.correct : AppColors.outline,
                      width: erasing ? 3 : 2,
                    ),
                  ),
                  child: Text(
                    erasing ? '✋ 떼어내는 중' : '✋ 떼어내기',
                    style: TextStyle(
                      fontSize: AppFont.small,
                      fontWeight: FontWeight.bold,
                      color: placed.isEmpty
                          ? AppColors.inkMuted
                          : erasing
                              ? AppColors.greenPressed
                              : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: placed.isEmpty ? null : onClear,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: AppColors.outline, width: 2),
                  ),
                  child: Text(
                    '🗑️ 모두 지우기',
                    style: TextStyle(
                      fontSize: AppFont.caption,
                      fontWeight: FontWeight.bold,
                      color: placed.isEmpty
                          ? AppColors.inkMuted
                          : AppColors.inkSoft,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // 캔버스: 하늘·잔디 배경 위에 스티커를 붙인다.
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = width * 0.72;
              Offset toFraction(Offset local) =>
                  Offset(local.dx / width, local.dy / height);
              return GestureDetector(
                key: const ValueKey('sticker-canvas'),
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) =>
                    onTapCanvas(toFraction(details.localPosition)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Stack(
                      children: [
                        // 배경: 하늘 + 잔디
                        Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                SceneColors.skyTop,
                                SceneColors.skyBottom
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: height * 0.22,
                          child: Container(color: SceneColors.grass),
                        ),
                        const Positioned(
                          right: 12,
                          top: 8,
                          child: Opacity(
                            opacity: 0.7,
                            child: Text('🌞', style: TextStyle(fontSize: 28)),
                          ),
                        ),
                        const Positioned(
                          left: 16,
                          top: 14,
                          child: Opacity(
                            opacity: 0.6,
                            child: Text('⛅',
                                style: TextStyle(fontSize: AppFont.display)),
                          ),
                        ),
                        // 붙인 스티커들 (끌어서 옮길 수 있다)
                        for (var i = 0; i < placed.length; i++)
                          Positioned(
                            left: placed[i].x / 1000 * width - 17,
                            top: placed[i].y / 1000 * height - 17,
                            child: GestureDetector(
                              onTap: () => onTapSticker(i),
                              onPanUpdate: (details) => onDragSticker(
                                i,
                                Offset(details.delta.dx / width,
                                    details.delta.dy / height),
                              ),
                              onPanEnd: (_) => onDragEnd(),
                              child: Text(
                                placed[i].emoji,
                                style: const TextStyle(fontSize: 34),
                              ),
                            ),
                          ),
                        // 아직 아무것도 없을 때 안내
                        if (placed.isEmpty)
                          Center(
                            child: Text(
                              palette.isEmpty
                                  ? (hasTickets
                                      ? '위 칭찬판에 스티커를 붙이면\n여기를 꾸밀 수 있어요!'
                                      : '퀴즈를 통과해 스티커를 모으면\n여기를 마음껏 꾸밀 수 있어요!')
                                  : brush == null
                                      ? '아래에서 스티커를 고르고\n원하는 곳을 톡! 눌러 붙여요'
                                      : '원하는 곳을 톡! 눌러 붙여요',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: AppFont.small,
                                height: 1.5,
                                fontWeight: FontWeight.bold,
                                color: AppColors.inkSoft,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          // 팔레트: 모은 스티커 중에서 골라 도장처럼 쓴다.
          if (palette.isEmpty)
            Text(
              hasTickets
                  ? '위 칭찬판·스티커북에 스티커를 붙이면\n여기서도 꾸밀 수 있어요!'
                  : '칭찬판이나 스티커북에 붙인 스티커가 생기면\n여기를 마음껏 꾸밀 수 있어요!',
              style: const TextStyle(
                  fontSize: AppFont.small, color: AppColors.inkSoft),
            )
          else
            SizedBox(
              height: 52,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: palette.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final sticker = palette[i];
                  final selected = !erasing && brush == sticker.emoji;
                  return GestureDetector(
                    key: ValueKey('palette:${sticker.emoji}'),
                    onTap: () => onPickBrush(sticker),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 52,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.rewardSurface
                            : AppColors.cream,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected ? AppColors.amber : AppColors.outline,
                          width: selected ? 2.5 : 1.5,
                        ),
                      ),
                      child: Center(
                        child: Text(sticker.emoji,
                            style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// 칭찬 스티커판: 스티커를 채워 가는 판 (다음 칸만 물음표가 빛난다).
/// 빈 숫자 칸을 누르면 스티커를 골라 그 위에 붙인다.
class _RewardBoardCard extends StatelessWidget {
  const _RewardBoardCard({
    required this.board,
    required this.boards,
    required this.promise,
    required this.canPlace,
    required this.onTapSlot,
  });

  final List<String?> board;
  final int boards;
  final String? promise;
  final bool canPlace;
  final void Function(int slot) onTapSlot;

  @override
  Widget build(BuildContext context) {
    final nextSlot = board.indexWhere((slot) => slot == null);
    final filled = board.where((s) => s != null).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏆', style: TextStyle(fontSize: AppFont.display)),
              const SizedBox(width: 8),
              const Text(
                '칭찬 스티커판',
                style: TextStyle(
                    fontSize: AppFont.title, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${boards + 1}번째 판 · $filled/${RewardBoardStore.slots}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: AppFont.small,
                      fontWeight: FontWeight.bold,
                      color: AppColors.inkSoft),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            promise != null ? '다 채우면 🎁 $promise!' : '다 채우면 🎁 선물!',
            style: const TextStyle(
                fontSize: AppFont.small,
                fontWeight: FontWeight.bold,
                color: AppColors.brown),
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              for (var i = 0; i < RewardBoardStore.slots; i++)
                GestureDetector(
                  key: ValueKey('board:$i'),
                  onTap: () => onTapSlot(i),
                  child: Container(
                    decoration: BoxDecoration(
                      color: board[i] != null
                          ? AppColors.rewardSurface
                          : Colors.white,
                      borderRadius: BorderRadius.circular(999),
                      // 앰버 테두리는 '다음에 붙일 칸' 하나만 (붙일 스티커가 있을 때)
                      border: Border.all(
                        color: i == nextSlot && canPlace
                            ? AppColors.amber
                            : AppColors.line,
                        width: i == nextSlot && canPlace ? 3 : 1.5,
                      ),
                    ),
                    child: Center(
                      // 붙인 스티커는 살짝 비뚤게 — 진짜 붙인 것처럼.
                      child: board[i] != null
                          ? Transform.rotate(
                              angle: (i.isEven ? 1 : -1) * 0.07,
                              child: Text(board[i]!,
                                  style: const TextStyle(fontSize: 26)),
                            )
                          // 마지막 칸은 🎁 — 끝에 선물이 있다는 걸 그림으로.
                          : i == RewardBoardStore.slots - 1
                              ? const Text('🎁',
                                  style: TextStyle(fontSize: AppFont.display))
                              // 빈 칸은 "다음엔 뭐가 올까?" — 다음 칸만 앰버.
                              : Text(
                                  '?',
                                  style: displayStyle(
                                    fontSize: AppFont.heading,
                                    color: i == nextSlot
                                        ? AppColors.amber
                                        : AppColors.line,
                                  ),
                                ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 칭찬판을 다 채우면 줄 선물 약속을 적는다 (설정의 부모 메뉴에서 연다 —
/// 아이 화면인 스티커북에는 어른용 글·버튼을 두지 않는다). 저장하면 true.
Future<bool> editRewardPromise(BuildContext context) async {
  final controller =
      TextEditingController(text: await RewardBoardStore.promise() ?? '');
  if (!context.mounted) return false;
  final saved = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Text('🎁 선물 약속 정하기'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '아이가 스티커 20개를 다 모으면 주기로 한\n약속을 적어 주세요. (비우면 약속 없음)',
            style: TextStyle(fontSize: AppFont.small, height: 1.4),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            maxLength: 30,
            decoration: InputDecoration(
              hintText: '예: 아이스크림 사 먹기 🍦',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, controller.text),
          child: const Text('저장'),
        ),
      ],
    ),
  );
  if (saved == null) return false;
  await RewardBoardStore.setPromise(saved);
  return true;
}
