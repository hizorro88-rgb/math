import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/boss.dart';
import '../models/daily.dart';
import '../models/premium.dart';
import '../models/progress.dart';
import '../models/stats.dart';
import '../models/stickers.dart';
import '../services/cloud_sync.dart';
import '../services/sounds.dart';
import '../widgets/quiz_parts.dart';
import 'result_screen.dart';

/// 판이 어느 과목인지 (오늘의 미션 카운터가 과목별로 다르다)
enum RoundSubject { math, korean, english, otherLang }

/// 통과하면 이어서 할 다음 단계
class NextStage {
  const NextStage({required this.categoryIndex, required this.builder});

  /// 다음 단계의 나이 묶음 (이용권 잠금 확인용)
  final int categoryIndex;
  final Widget Function() builder;
}

/// 결과 화면 머리글: "🔤 낱말 읽기 · 3단계"
String stageHeader(String emoji, String title, int numberInUnit) =>
    '$emoji $title · $numberInUnit단계';

/// 한 판을 마칠 때 퀴즈 화면 네 벌(수학·한글·영어·외국어)이 똑같이 하는 일.
/// 별·코인 계산 → 기록 저장 → 미션·출석·통계·스티커 → 결과 화면으로 교체.
///
/// 과목마다 다른 것(별 저장 위치, 다음 단계, 다시 하기)만 함수로 받는다.
Future<void> finishRound(
  BuildContext context, {
  required RoundSubject subject,
  required List<QuizDot> dots,
  required int correctCount,
  required int totalCount,
  required int roundPoints,
  required math.Random random,
  required Widget Function() retryBuilder,

  /// 단계 판이면 별을 저장한다 (자유 연습이면 null)
  Future<void> Function(int stars)? saveStars,

  /// 통과했을 때 다음 단계 (마지막이거나 자유 연습이면 null을 돌려준다)
  NextStage? Function(int stars)? next,
  String? headerText,
  bool bossMode = false,
}) async {
  final stars = starsForScore(correctCount, totalCount);
  // 보스전을 통과하면 큰 보너스가 붙고, 이번 주는 잠긴다.
  // 이미 이번 주에 클리어했으면 (결과 화면의 '다시 하기' 등) 보상을 또 주지 않는다.
  final bossCleared =
      bossMode && stars >= 1 && !await BossStore.isClearedThisWeek();
  final earned = roundPoints +
      completionBonus(stars) +
      (bossCleared ? BossStore.reward : 0);
  // 통과하면 가끔 보물상자가 나온다 (3별이면 확률 업, 보너스 10~50코인)
  final chestCoins =
      random.nextDouble() < (stars >= 3 ? 0.35 : (stars >= 1 ? 0.15 : 0))
          ? (2 + random.nextInt(9)) * 5
          : 0;
  if (bossCleared) await BossStore.markCleared();
  if (stars >= 1) Sounds.complete();
  // 결과 화면으로 넘어가기 전에 기록을 저장한다.
  if (saveStars != null) await saveStars(stars);
  await ProgressStore.addPoints(earned + chestCoins);
  // 데일리 미션·출석 기록 (새로 달성한 미션은 결과 화면에서 축하)
  final rewards = await DailyStore.recordRound(
    correctCount: correctCount,
    stars: stars,
    korean: subject == RoundSubject.korean,
    english: subject == RoundSubject.english,
    otherLang: subject == RoundSubject.otherLang,
  );
  // 리포트용 주간 활동 기록
  await StatsStore.recordRoundDay();
  CloudSync.scheduleUpload(); // 로그인돼 있으면 잠시 뒤 클라우드에 저장
  // 통과하면 스티커북에 붙일 스티커 1장을 준다.
  if (stars >= 1) await StickerStore.addTickets(1);

  var nextStage = next?.call(stars);
  // 다음 단계가 이용권으로 잠긴 묶음이면 버튼을 숨긴다
  // (홈에서 부모 확인 → 이용권 안내를 거치게 한다).
  if (nextStage != null &&
      !PremiumStore.isCategoryFree(nextStage.categoryIndex) &&
      !await PremiumStore.hasPass()) {
    nextStage = null;
  }
  if (!context.mounted) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute(
      builder: (_) => ResultScreen(
        dots: dots,
        correctCount: correctCount,
        totalCount: totalCount,
        earnedPoints: earned,
        chestCoins: chestCoins,
        stickerEarned: stars >= 1,
        bossCleared: bossCleared,
        completedMissions: rewards.missions,
        milestoneDays: rewards.milestoneDays,
        milestoneCoins: rewards.milestoneCoins,
        headerText: headerText,
        showUnlockHint: saveStars != null && stars < 1,
        nextLabel: nextStage != null ? '다음 단계' : null,
        nextBuilder: nextStage?.builder,
        retryBuilder: retryBuilder,
        // 어디서 왔든 홈으로 가는 버튼이라 표현을 하나로 통일한다.
        homeLabel: '처음으로',
      ),
    ),
  );
}
