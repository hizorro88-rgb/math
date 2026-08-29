import 'chinese_pack.dart';
import 'japanese_pack.dart';
import 'language_pack.dart';

export 'chinese_pack.dart';
export 'japanese_pack.dart';
export 'language_pack.dart';

/// 앱에 실려 있는 언어 팩들 (홈 탭·리포트·통계가 이 순서를 따른다)
final List<LanguagePack> languagePacks = [japanesePack, chinesePack];

LanguagePack languagePackById(String id) =>
    languagePacks.firstWhere((p) => p.id == id);
