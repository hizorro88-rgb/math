import 'package:flutter/material.dart';
import '../widgets/quokka_avatar.dart';

import '../models/premium.dart';
import '../services/purchases.dart';
import '../widgets/bouncy_button.dart';
import '../theme.dart';

/// 가족 이용권 화면 (부모 게이트 뒤에서 열림).
/// 한 번 결제하면 이 기기의 모든 단계·프로필 4명이 열리고,
/// 스토어 가족 공유를 켜 두면 가족 기기에서도 같은 결제로 쓸 수 있다.
class PassScreen extends StatefulWidget {
  const PassScreen({super.key});

  @override
  State<PassScreen> createState() => _PassScreenState();
}

class _PassScreenState extends State<PassScreen> {
  bool _hasPass = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    Purchases.passVersion.addListener(_onPassChanged);
    _load();
  }

  @override
  void dispose() {
    Purchases.passVersion.removeListener(_onPassChanged);
    super.dispose();
  }

  Future<void> _load() async {
    final hasPass = await PremiumStore.hasPass();
    if (!mounted) return;
    setState(() {
      _hasPass = hasPass;
      _loaded = true;
    });
    // 상품 정보(가격)는 화면을 막지 않고 뒤에서 다시 시도한다.
    Purchases.init().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _onPassChanged() {
    if (!mounted) return;
    setState(() => _hasPass = true);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(
        content: Text('🎉 가족 이용권이 켜졌어요! 모든 단계가 열립니다'),
        duration: Duration(seconds: 2),
      ));
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _buy() async {
    final started = await Purchases.buy();
    if (!mounted) return;
    if (!started) _snack('스토어에 연결하지 못했어요. 잠시 뒤에 다시 해 주세요.');
  }

  Future<void> _restore() async {
    final ok = await Purchases.restore();
    if (!mounted) return;
    if (!ok) _snack('스토어에 연결하지 못했어요. 잠시 뒤에 다시 해 주세요.');
  }

  @override
  Widget build(BuildContext context) {
    final price = Purchases.product?.price;
    final store = Purchases.available;

    return Scaffold(
      appBar: AppBar(
        title: const Text('가족 이용권'),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 정보 카드(테두리): 무엇을·얼마에 — 가격이 맨 위에 보인다
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.outline, width: 2),
                  ),
                  child: Column(
                    children: [
                      const QuokkaFace(size: 64),
                      const SizedBox(height: 8),
                      const Text(
                        '한 번 결제로\n온 가족이 함께 배워요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: AppFont.heading,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        price ?? (store ? '가격 불러오는 중…' : '가격은 스토어 버전에서 보여요'),
                        key: const ValueKey('pass-price'),
                        textAlign: TextAlign.center,
                        style: price != null
                            ? displayStyle(fontSize: 30)
                            : const TextStyle(
                                fontSize: AppFont.small,
                                fontWeight: FontWeight.bold,
                                color: AppColors.inkSoft),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        '월 구독 없음 · 광고 없음 · 1회 결제',
                        style: TextStyle(
                            fontSize: AppFont.small, color: AppColors.inkSoft),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _compareTable(),
                const SizedBox(height: 20),
                if (_hasPass)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.selectedFill,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.correct, width: 2),
                    ),
                    child: const Text(
                      '✅ 가족 이용권 사용 중이에요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppFont.title,
                        fontWeight: FontWeight.bold,
                        color: AppColors.greenPressed,
                      ),
                    ),
                  )
                else ...[
                  // 스토어와 연결되지 않으면(웹·개발 빌드) 누를 수 없는 버튼으로 둔다 —
                  // 눌렀는데 안 된다는 말이 뜨는 것보다 처음부터 꺼져 보이는 게 정직하다.
                  BouncyButton(
                    key: const ValueKey('pass-buy'),
                    color: store ? AppColors.green : AppColors.lockedNode,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    onTap: store ? _buy : null,
                    child: Text(
                      !store
                          ? '스토어 버전에서 구매할 수 있어요'
                          : price == null
                              ? '이용권 구매하기'
                              : '이용권 구매하기 · $price',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: store ? AppFont.heading : AppFont.body,
                        fontWeight: FontWeight.bold,
                        color: store ? Colors.white : AppColors.inkSoft,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  BouncyButton(
                    key: const ValueKey('pass-restore'),
                    color: Colors.white,
                    shadowColor: AppColors.outline,
                    border: Border.all(color: AppColors.outline, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onTap: store ? _restore : null,
                    child: Text(
                      '구매 복원',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: AppFont.body,
                        fontWeight: FontWeight.bold,
                        color: store ? AppColors.inkSoft : AppColors.inkMuted,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  '🏠 Google Play 가족 라이브러리 / Apple 가족 공유를 켜면 '
                  '가족의 다른 폰·태블릿에서도 같은 결제로 쓸 수 있어요.\n'
                  '📦 앱을 다시 깔거나 기기를 바꿔도 같은 스토어 계정이면 '
                  '[구매 복원]으로 다시 켤 수 있어요.',
                  style: TextStyle(
                      fontSize: AppFont.caption,
                      color: AppColors.inkSoft,
                      height: 1.5),
                ),
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  /// 무료 vs 이용권 두 줄 비교 — 무엇이 달라지는지 한눈에
  Widget _compareTable() {
    const rows = [
      ('🗺️ 단계', '과목마다\n첫 묶음', '전체\n1140단계'),
      ('🧒 프로필', '1명', '4명'),
      ('🏠 가족 기기', '—', '함께 쓰기'),
      ('📺 광고', '없음', '없음'),
    ];
    Widget cell(String text, {bool head = false, bool pass = false}) =>
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          alignment: Alignment.center,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: head ? AppFont.body : AppFont.small,
              height: 1.25,
              fontWeight: head || pass ? FontWeight.bold : FontWeight.normal,
              color: pass ? AppColors.greenPressed : AppColors.ink,
            ),
          ),
        );

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.outline, width: 2),
      ),
      clipBehavior: Clip.antiAlias,
      child: Table(
        key: const ValueKey('pass-compare'),
        columnWidths: const {
          0: FlexColumnWidth(1.25),
          1: FlexColumnWidth(1),
          2: FlexColumnWidth(1.1),
        },
        border: const TableBorder(
          horizontalInside: BorderSide(color: AppColors.line, width: 1.5),
        ),
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        children: [
          TableRow(
            children: [
              cell(''),
              cell('무료', head: true),
              Container(
                color: AppColors.selectedFill,
                child: cell('이용권', head: true, pass: true),
              ),
            ],
          ),
          for (final r in rows)
            TableRow(
              children: [
                cell(r.$1, head: true),
                cell(r.$2),
                Container(
                  color: AppColors.selectedFill,
                  child: cell(r.$3, pass: true),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
