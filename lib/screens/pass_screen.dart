import 'package:flutter/material.dart';

import '../models/premium.dart';
import '../services/purchases.dart';
import '../widgets/bouncy_button.dart';

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
      ..showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 2)));
  }

  Future<void> _buy() async {
    final started = await Purchases.buy();
    if (!mounted) return;
    if (!started) {
      _snack('아직 스토어와 연결되지 않았어요. 출시 빌드(스토어 설치)에서 결제할 수 있어요.');
    }
  }

  Future<void> _restore() async {
    final ok = await Purchases.restore();
    if (!mounted) return;
    if (!ok) _snack('아직 스토어와 연결되지 않았어요.');
  }

  @override
  Widget build(BuildContext context) {
    final price = Purchases.product?.price;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F7F0),
      appBar: AppBar(
        backgroundColor: const Color(0xFFB8860B),
        foregroundColor: Colors.white,
        title: const Text(
          '👨‍👩‍👧 가족 이용권',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFF6D8), Color(0xFFFFE9B8)],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    border:
                        Border.all(color: const Color(0xFFFFD34D), width: 3),
                  ),
                  child: Column(
                    children: [
                      const Text('🦉👑', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 8),
                      const Text(
                        '한 번 결제로\n온 가족이 함께 배워요',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '월 구독 없음 · 광고 없음 · 1회 결제',
                        style: TextStyle(
                            fontSize: 14, color: Colors.brown.shade400),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _benefit('🗺️', '5과목 모든 단계 열기',
                    '수학 370 · 한글 120 · 영어 80 · 일본어 90 · 중국어 70단계'),
                _benefit('👨‍👩‍👧‍👦', '프로필 4명',
                    '넷플릭스처럼 아이마다 프로필을 만들어 각자 진도를 나가요'),
                _benefit('👪', '가족 기기 공유',
                    'Google Play 가족 라이브러리 / Apple 가족 공유를 켜면\n한 번 결제로 가족의 다른 폰·태블릿에서도 쓸 수 있어요'),
                _benefit('🔄', '재설치·기기 변경 시 복원',
                    '같은 스토어 계정이면 [구매 복원]으로 다시 켤 수 있어요'),
                const SizedBox(height: 20),
                if (_hasPass)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD7FFB8),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: const Color(0xFF58CC02), width: 2),
                    ),
                    child: const Text(
                      '✅ 가족 이용권 사용 중이에요!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF58A700),
                      ),
                    ),
                  )
                else ...[
                  BouncyButton(
                    color: const Color(0xFF58CC02),
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    onTap: _buy,
                    child: Text(
                      price == null ? '이용권 구매하기' : '이용권 구매하기 · $price',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  BouncyButton(
                    color: Colors.white,
                    shadowColor: Colors.grey.shade300,
                    border: Border.all(color: Colors.grey.shade300, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    onTap: _restore,
                    child: Text(
                      '구매 복원',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  if (!Purchases.available) ...[
                    const SizedBox(height: 12),
                    Text(
                      '결제는 스토어(구글 플레이/앱스토어)에서 설치한 출시 버전에서 할 수 있어요.',
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ],
                const SizedBox(height: 8),
              ],
            ),
    );
  }

  Widget _benefit(String emoji, String title, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            offset: const Offset(0, 3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style:
                      TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
