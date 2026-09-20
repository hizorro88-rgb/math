/// 성인용 영어회화 과정.
///
/// 주제 30개 × 표현 100개 = 3,000개를 세 단계(1000·2000·3000)로 나눠 배운다.
/// 다른 언어 팩과 달리 "유형"이 아니라 "주제"가 학습 범위라서,
/// 한 판(10문제)을 팩이 통째로 만들어 같은 표현을 알아보기 → 말하기 →
/// 빈칸 → 문장 조립 순서로 점점 깊게 다룬다.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import 'conversation_data.dart';
import 'conversation_data_t1.dart';
import 'conversation_data_t2.dart';
import 'conversation_data_t3.dart';
import 'language_pack.dart';

/// 주제 30개의 표현 묶음 (각 100개)
final List<List<ConvExpr>> convUnitExpressions = [
  ...convTier1,
  ...convTier2,
  ...convTier3,
];

/// 주제 제목과 그림 (convUnitExpressions와 순서가 같다)
const List<({String title, String emoji})> convUnitTitles = [
  // 기초 회화 1000
  (title: '첫인사·자기소개', emoji: '👋'),
  (title: '하루 일과', emoji: '☀️'),
  (title: '숫자·시간·날짜', emoji: '🕐'),
  (title: '가족·사람 소개', emoji: '👪'),
  (title: '음식 주문·식당', emoji: '🍽️'),
  (title: '쇼핑·계산', emoji: '🛒'),
  (title: '길 묻기·교통', emoji: '🚌'),
  (title: '날씨·계절', emoji: '☁️'),
  (title: '기분·상태 말하기', emoji: '🙂'),
  (title: '부탁·허락 패턴', emoji: '🙏'),
  // 실전 회화 2000
  (title: '공항·비행기', emoji: '✈️'),
  (title: '호텔·숙소', emoji: '🏨'),
  (title: '직장·업무', emoji: '💼'),
  (title: '전화·문자·이메일', emoji: '📞'),
  (title: '병원·약국', emoji: '🏥'),
  (title: '집안일·생활', emoji: '🧹'),
  (title: '취미·여가·운동', emoji: '🎬'),
  (title: '약속·초대·계획', emoji: '📅'),
  (title: '의견·동의·반대', emoji: '💭'),
  (title: '필수 구동사', emoji: '🔗'),
  // 유창한 회화 3000
  (title: '맞장구·리액션', emoji: '👏'),
  (title: '감정 표현 심화', emoji: '😤'),
  (title: '관용 표현 I', emoji: '🎭'),
  (title: '관용 표현 II', emoji: '🎪'),
  (title: '구동사 심화', emoji: '🔀'),
  (title: '비즈니스 회화', emoji: '🤝'),
  (title: '토론·설득', emoji: '⚖️'),
  (title: '스몰토크·잡담', emoji: '☕'),
  (title: '원어민처럼 말하기', emoji: '🎯'),
  (title: '종합 마스터', emoji: '🏆'),
];

/// 한 주제가 담는 표현 수
const convExpressionsPerUnit = 100;

/// 한 단계에서 다루는 표현 수
const convExpressionsPerLevel =
    convExpressionsPerUnit ~/ LanguagePack.levelsPerUnit;

/// 문제 유형 (저장 통계가 순서 기반이라 뒤에만 추가할 것)
const _convTypes = [
  LangUnitType('뜻 고르기', '뜻', '📖', textDisplay: true),
  LangUnitType('영어로 말하기', '영어', '🗣️', textDisplay: true),
  LangUnitType('듣고 고르기', '듣기', '👂', listening: true),
  LangUnitType('빈칸 채우기', '빈칸', '✏️', textDisplay: true),
  LangUnitType('문장 만들기', '배열', '🧱', textDisplay: true),
];

/// 단계가 올라갈수록 알아보기(0·1·2)에서 만들어 내기(3·4) 쪽으로 옮겨 간다.
const _planEarly = [0, 1, 0, 2, 1, 0, 2, 1, 0, 1];
const _planMid = [0, 1, 2, 3, 1, 0, 3, 2, 1, 3];
const _planLate = [1, 3, 2, 4, 1, 3, 0, 4, 2, 3];
const _planFinal = [3, 4, 2, 4, 1, 3, 4, 2, 4, 3];

List<int> _planFor(int stage) {
  if (stage <= 2) return _planEarly;
  if (stage <= 5) return _planMid;
  if (stage <= 7) return _planLate;
  return _planFinal;
}

/// 영어 낱말을 앞 기호·알맹이·뒤 기호로 나눈다 (빈칸 문제에서 쓴다)
final _wordCore = RegExp(r"^([^A-Za-z]*)([A-Za-z][A-Za-z']*)(.*)$");

/// 표현이 그 유형으로 낼 수 있는지 보고, 안 되면 쉬운 유형으로 돌린다.
int _usableType(ConvExpr expr, int type) {
  if (type == 4 && (expr.wordCount < 3 || expr.wordCount > 6)) return 1;
  if (type == 3 && expr.wordCount < 3) return 0;
  return type;
}

/// 같은 주제에서 헷갈리지 않는 오답 [n]개를 고른다.
List<ConvExpr> _distractors(
  List<ConvExpr> pool,
  ConvExpr target,
  Random random, {
  required bool korean,
  int n = 3,
}) {
  final used = {korean ? target.ko : target.en};
  final rest = [...pool]..shuffle(random);
  final picked = <ConvExpr>[];
  for (final e in rest) {
    final key = korean ? e.ko : e.en;
    if (!used.add(key)) continue;
    picked.add(e);
    if (picked.length == n) break;
  }
  return picked;
}

/// 빈칸 문제의 오답 낱말 3개 (같은 주제의 다른 표현에서 가져온다)
List<String> _wordDistractors(
  List<ConvExpr> pool,
  String answer,
  Random random,
) {
  final used = {answer.toLowerCase()};
  final words = <String>[];
  for (final e in pool) {
    for (final w in e.words) {
      final m = _wordCore.firstMatch(w);
      if (m == null) continue;
      final core = m.group(2)!;
      if (core.length < 2) continue;
      if (!used.add(core.toLowerCase())) continue;
      words.add(core);
    }
  }
  words.shuffle(random);
  return words.take(3).toList();
}

LangQuestion _convQuestion(
  List<ConvExpr> pool,
  ConvExpr target,
  int type,
  Random random,
) {
  switch (type) {
    case 1:
      final choices = [
        target.en,
        ..._distractors(pool, target, random, korean: false).map((e) => e.en),
      ]..shuffle(random);
      return LangQuestion(
        typeIndex: 1,
        instruction: '영어로 어떻게 말할까요?',
        display: target.ko,
        choices: choices,
        answer: target.en,
        answerText: target.en,
        speech: target.en,
        dedupKey: 'c1:${target.en}',
      );
    case 2:
      final choices = [
        target.en,
        ..._distractors(pool, target, random, korean: false).map((e) => e.en),
      ]..shuffle(random);
      return LangQuestion(
        typeIndex: 2,
        instruction: '잘 듣고 알맞은 표현을 고르세요',
        display: '🔊',
        choices: choices,
        answer: target.en,
        answerText: target.en,
        speech: target.en,
        dedupKey: 'c2:${target.en}',
      );
    case 3:
      final words = target.words;
      final blank = 1 + random.nextInt(words.length - 1);
      final match = _wordCore.firstMatch(words[blank]);
      if (match == null) {
        return _convQuestion(pool, target, 0, random);
      }
      final head = match.group(1)!;
      final core = match.group(2)!;
      final tail = match.group(3)!;
      final shown = [...words]..[blank] = '${head}____$tail';
      final choices = [core, ..._wordDistractors(pool, core, random)]
        ..shuffle(random);
      return LangQuestion(
        typeIndex: 3,
        instruction: '빈칸에 알맞은 낱말은?',
        display: shown.join(' '),
        subDisplay: target.ko,
        choices: choices,
        answer: core,
        answerText: target.en,
        speech: target.en,
        dedupKey: 'c3:${target.en}',
      );
    case 4:
      final tiles = [...target.words]..shuffle(random);
      return LangQuestion(
        typeIndex: 4,
        instruction: '낱말을 눌러 문장을 만들어요',
        display: target.ko,
        choices: tiles,
        answer: target.en,
        answerText: target.en,
        speech: target.en,
        tiles: tiles,
        tileSlots: target.wordCount,
        tileJoin: ' ',
        dedupKey: 'c4:${target.en}',
      );
    default:
      final choices = [
        target.ko,
        ..._distractors(pool, target, random, korean: true).map((e) => e.ko),
      ]..shuffle(random);
      return LangQuestion(
        typeIndex: 0,
        instruction: '무슨 뜻일까요?',
        display: target.en,
        choices: choices,
        answer: target.ko,
        answerText: target.ko,
        speech: target.en,
        dedupKey: 'c0:${target.en}',
      );
  }
}

/// 한 단계(10문제)를 통째로 만든다.
/// 그 단계가 맡은 표현 10개를 하나씩 다루고, 유형만 단계에 맞춰 달라진다.
List<LangQuestion> convGenerateLevel(int unitIndex, int stage, Random random) {
  final pool = convUnitExpressions[unitIndex];
  final start = (stage * convExpressionsPerLevel) % pool.length;
  final slice = [
    for (var i = 0; i < convExpressionsPerLevel; i++)
      pool[(start + i) % pool.length],
  ]..shuffle(random);
  final plan = _planFor(stage);
  return [
    for (var i = 0; i < slice.length; i++)
      _convQuestion(pool, slice[i], _usableType(slice[i], plan[i]), random),
  ];
}

LangUnit _convUnit(int index) => LangUnit(
      title: convUnitTitles[index].title,
      emoji: convUnitTitles[index].emoji,
      typeIndex: 0,
    );

/// 영어회화 팩 (성인용): 3,000개 표현을 주제 30개로 나눠 배운다.
final conversationPack = LanguagePack(
  id: 'enconv',
  name: '영어회화',
  emoji: '💬',
  ttsLang: 'en-US',
  types: _convTypes,
  categories: [
    LangCategory(
      title: '기초 회화 1000',
      emoji: '🌱',
      desc: '여행·일상에서 바로 쓰는 필수 표현 1000개',
      color: const Color(0xFF4D96FF),
      units: [for (var i = 0; i < 10; i++) _convUnit(i)],
    ),
    LangCategory(
      title: '실전 회화 2000',
      emoji: '🚀',
      desc: '공항·직장·병원까지 상황별 표현 1000개 더',
      color: const Color(0xFF7C5CE0),
      units: [for (var i = 10; i < 20; i++) _convUnit(i)],
    ),
    LangCategory(
      title: '유창한 회화 3000',
      emoji: '🏆',
      desc: '관용표현·리액션까지, 원어민처럼 말하는 마지막 1000개',
      color: const Color(0xFF2FB8A6),
      units: [for (var i = 20; i < 30; i++) _convUnit(i)],
    ),
  ],
  generateLevel: convGenerateLevel,
  forAdults: true,
);
