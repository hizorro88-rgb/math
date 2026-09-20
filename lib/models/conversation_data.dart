/// 성인 영어회화 과정에서 쓰는 표현 데이터의 기본 단위.
/// 표현은 주제(유닛)별로 100개씩 묶여 있고, 한 단계가 그중 10개를 다룬다.
library;

/// 회화 표현 하나: 영어 표현과 한국어 뜻.
class ConvExpr {
  const ConvExpr(this.en, this.ko);

  /// 실제로 말하는 영어 표현 (한 낱말일 수도, 문장일 수도 있다)
  final String en;

  /// 한국어 뜻
  final String ko;

  /// 단어 단위로 끊은 표현 (문장 배열 문제에서 쓴다)
  List<String> get words => en.split(' ');

  int get wordCount => words.length;
}
