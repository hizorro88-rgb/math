import 'package:flutter/material.dart';

import '../models/reward_board.dart';
import '../models/sticker_canvas.dart';
import '../models/stickers.dart';
import '../services/sounds.dart';
import '../services/speech.dart';
import '../widgets/bouncy_button.dart';
import '../widgets/parent_gate.dart';

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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                          onTap: () =>
                              Navigator.of(context).pop(sticker.emoji),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border:
                                  Border.all(color: Colors.grey.shade200),
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
      _snack('🎟️ 붙일 스티커가 없어요. 퀴즈 한 판을 통과하면 1장을 받아요!');
      return;
    }
    final emoji = await _pickStickerDesign();
    if (emoji == null || !mounted) return;

    final result = await RewardBoardStore.place(slot, emoji);
    if (result == null || !mounted) return;
    Sounds.correct(1);
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

  /// 부모 확인 뒤, 판을 다 채우면 줄 선물 약속을 적는다.
  Future<void> _editPromise() async {
    final ok = await checkParentGate(context);
    if (!ok || !mounted) return;
    final controller = TextEditingController(text: _promise ?? '');
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
              style: TextStyle(fontSize: 13.5, height: 1.4),
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
    if (saved == null || !mounted) return;
    await RewardBoardStore.setPromise(saved);
    await _load();
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
      _snack('꾸미기 판이 가득 찼어요! 🧽 지우개로 조금 정리해 볼까요?');
      return;
    }
    Sounds.correct(1);
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
    Sounds.wrong();
    setState(() => _canvas.removeAt(index));
    CanvasStore.save(_canvas);
  }

  Future<void> _clearCanvas() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('꾸미기 판을 다 지울까요?'),
        content: const Text('붙인 스티커가 모두 떨어져요.\n(모은 스티커는 그대로예요!)'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('다 지우기'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      _canvas = [];
      _erasing = false;
    });
    CanvasStore.save(_canvas);
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
                // 칭찬 스티커판: 1~20 숫자 위에 스티커를 붙이고 다 모으면 선물!
                _RewardBoardCard(
                  board: _board,
                  boards: _boards,
                  promise: _promise,
                  canPlace: _tickets > 0,
                  onTapSlot: _tapBoardSlot,
                  onEditPromise: _editPromise,
                ),
                const SizedBox(height: 14),
                // 모은 스티커를 골라 원하는 곳에 붙이는 꾸미기 판
                _CanvasCard(
                  placed: _canvas,
                  palette: _palette,
                  brush: _brush,
                  erasing: _erasing,
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
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
              const Text('🖼️', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Text(
                '내 꾸미기 판',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              // 지우개 모드
              GestureDetector(
                onTap: onToggleErase,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: erasing
                        ? const Color(0xFFFFDFE0)
                        : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: erasing
                          ? const Color(0xFFEA2B2B)
                          : Colors.grey.shade300,
                      width: 1.5,
                    ),
                  ),
                  child: Text(
                    '🧽 지우개',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: erasing
                          ? const Color(0xFFEA2B2B)
                          : Colors.grey.shade600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.grey.shade300, width: 1.5),
                  ),
                  child: Text(
                    '🗑️ 정리',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
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
                              colors: [Color(0xFFBBE3FF), Color(0xFFE3F4FF)],
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: height * 0.22,
                          child: Container(color: const Color(0xFFA5D96C)),
                        ),
                        const Positioned(
                          right: 12,
                          top: 8,
                          child: Opacity(
                            opacity: 0.7,
                            child:
                                Text('☀️', style: TextStyle(fontSize: 28)),
                          ),
                        ),
                        const Positioned(
                          left: 16,
                          top: 14,
                          child: Opacity(
                            opacity: 0.6,
                            child:
                                Text('☁️', style: TextStyle(fontSize: 24)),
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
                                  ? '퀴즈를 통과해 스티커를 모으면\n여기를 마음껏 꾸밀 수 있어요!'
                                  : brush == null
                                      ? '아래에서 스티커를 고르고\n원하는 곳을 톡! 눌러 붙여요'
                                      : '원하는 곳을 톡! 눌러 붙여요',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 14,
                                height: 1.5,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey.shade400,
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
              '모은 스티커가 아직 없어요. 퀴즈 한 판 통과하면 시작!',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
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
                            ? const Color(0xFFFFF3C4)
                            : Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: selected
                              ? const Color(0xFFFFC107)
                              : Colors.grey.shade300,
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

/// 칭찬 스티커판: 1~20 숫자가 희미하게 적힌 판.
/// 빈 숫자 칸을 누르면 스티커를 골라 그 위에 붙인다.
class _RewardBoardCard extends StatelessWidget {
  const _RewardBoardCard({
    required this.board,
    required this.boards,
    required this.promise,
    required this.canPlace,
    required this.onTapSlot,
    required this.onEditPromise,
  });

  final List<String?> board;
  final int boards;
  final String? promise;
  final bool canPlace;
  final void Function(int slot) onTapSlot;
  final VoidCallback onEditPromise;

  @override
  Widget build(BuildContext context) {
    final filled = board.where((s) => s != null).length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFFFD34D), width: 2.5),
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
              const Text('🏆', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              const Text(
                '칭찬 스티커판',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Text(
                '${boards + 1}번째 판 · $filled/${RewardBoardStore.slots}',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600),
              ),
              const Spacer(),
              // 부모가 선물 약속을 적는 버튼 (부모 확인 뒤)
              GestureDetector(
                onTap: onEditPromise,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF3C4),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                        color: const Color(0xFFFFD34D), width: 1.5),
                  ),
                  child: const Text(
                    '🎁 선물 정하기',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFB05E00),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            promise != null
                ? '20칸을 다 채우면 → 🎁 $promise'
                : '20칸을 다 채우면 → 깜짝 선물 + 부엉이 꾸미기 아이템!',
            style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
                color: Colors.brown.shade400),
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
                          ? const Color(0xFFFFF9E5)
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: board[i] != null
                            ? const Color(0xFFFFD34D)
                            : canPlace
                                ? const Color(0xFFFFC107)
                                : Colors.grey.shade300,
                        width: board[i] != null || canPlace ? 2 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: board[i] != null
                          ? Text(board[i]!,
                              style: const TextStyle(fontSize: 26))
                          // 아직 안 붙인 칸: 숫자가 희미하게 보인다.
                          : Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade300,
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
