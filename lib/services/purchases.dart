import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import '../models/premium.dart';

/// 스토어 인앱 결제(가족 이용권) 담당.
/// 스토어에 연결이 안 되는 환경(테스트·미출시 빌드)에서도 앱은 조용히 동작한다.
///
/// 출시 전 준비:
/// - 플레이 콘솔 / 앱스토어 커넥트에 비소모성 상품 [productId] 등록
/// - Play: 가족 라이브러리 지원 켜기 / iOS: 인앱 상품의 '가족 공유' 켜기
class Purchases {
  Purchases._();

  static const productId = 'family_pass';

  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  /// 스토어 연결 여부와 상품 정보 (연결 전엔 null)
  static bool available = false;
  static ProductDetails? product;

  /// 이용권이 켜질 때마다 1씩 올라간다 (화면 갱신용)
  static final ValueNotifier<int> passVersion = ValueNotifier(0);

  /// 스토어가 아예 없는 환경(웹 미리보기·위젯 테스트)인지
  static bool get _noStore =>
      kIsWeb || Platform.environment.containsKey('FLUTTER_TEST');

  static Future<void> init() async {
    if (_noStore) return;
    try {
      // 스토어 응답이 늦어도 멈추지 않게 시간 제한을 둔다.
      available =
          await _iap.isAvailable().timeout(const Duration(seconds: 8));
      if (!available) return;
      _subscription ??= _iap.purchaseStream.listen(_onPurchases);
      final response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isNotEmpty) {
        product = response.productDetails.first;
      }
    } catch (_) {
      available = false;
    }
  }

  static Future<void> _onPurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.productID == productId &&
          (purchase.status == PurchaseStatus.purchased ||
              purchase.status == PurchaseStatus.restored)) {
        await PremiumStore.setPass(true);
        passVersion.value++;
      }
      try {
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } catch (_) {}
    }
  }

  /// 구매 요청. 스토어가 안 되면 false. (결과는 purchaseStream으로 온다)
  static Future<bool> buy() async {
    final details = product;
    if (!available || details == null) return false;
    try {
      return await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
    } catch (_) {
      return false;
    }
  }

  /// 다른 기기·재설치에서 이전 구매 복원
  static Future<bool> restore() async {
    if (!available) return false;
    try {
      await _iap.restorePurchases();
      return true;
    } catch (_) {
      return false;
    }
  }
}
