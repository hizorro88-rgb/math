import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/curriculum.dart';
import 'package:preschool_math/models/english_curriculum.dart';
import 'package:preschool_math/models/korean_curriculum.dart';
import 'package:preschool_math/models/language_packs.dart';
import 'package:preschool_math/models/premium.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/services/backup.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
    PremiumStore.allUnlocked = false;
  });

  tearDown(() {
    PremiumStore.allUnlocked = false;
  });

  test('전체 열기 전에는 별 없이 뒷 단계가 잠겨 있다', () {
    final stars = List.filled(Curriculum.totalLevels, 0);
    expect(ProgressStore.isUnlocked(stars, 2), isFalse);
    expect(KoreanProgressStore.isUnlocked(
        List.filled(KoreanCurriculum.totalLevels, 0), 2), isFalse);
  });

  test('전체 열기를 켜면 모든 과목의 모든 단계가 열리고 이용권도 인정된다',
      () async {
    await PremiumStore.setAllUnlocked(true);

    final mathStars = List.filled(Curriculum.totalLevels, 0);
    expect(ProgressStore.isUnlocked(mathStars, Curriculum.totalLevels), isTrue);
    expect(
      KoreanProgressStore.isUnlocked(
          List.filled(KoreanCurriculum.totalLevels, 0),
          KoreanCurriculum.totalLevels),
      isTrue,
    );
    expect(
      EnglishProgressStore.isUnlocked(
          List.filled(EnglishCurriculum.totalLevels, 0),
          EnglishCurriculum.totalLevels),
      isTrue,
    );
    final pack = languagePacks.first;
    expect(
      LangProgressStore.isUnlocked(
          pack, List.filled(pack.totalLevels, 0), pack.totalLevels),
      isTrue,
    );

    // 유료 과목 잠금(이용권 검사)도 함께 열린다.
    expect(await PremiumStore.hasPass(), isTrue);
  });

  test('켠 상태는 저장되고, 앱을 다시 켜면(init) 그대로 살아난다', () async {
    await PremiumStore.setAllUnlocked(true);
    PremiumStore.allUnlocked = false; // 앱 재시작 흉내
    await PremiumStore.init();
    expect(PremiumStore.allUnlocked, isTrue);

    await PremiumStore.setAllUnlocked(false);
    await PremiumStore.init();
    expect(PremiumStore.allUnlocked, isFalse);
    expect(await PremiumStore.hasPass(), isFalse);
  });

  test('전체 열기 상태는 백업 코드에 담기지 않고, 복원해도 유지된다', () async {
    SharedPreferences.setMockInitialValues({
      'p1_level_stars_v4': ['3', '2'], // 백업에 담길 진도 기록
    });
    await PremiumStore.setAllUnlocked(true);
    final code = await BackupService.export();
    expect(code.contains('all_unlock_v1'), isFalse);

    // 이 기기에서 복원해도 켜 둔 상태가 지워지지 않는다.
    expect(await BackupService.restore(code), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('all_unlock_v1'), isTrue);

    // 다른 기기(전체 열기 없음)에서 이 코드를 복원해도 열리지 않는다.
    SharedPreferences.setMockInitialValues({});
    expect(await BackupService.restore(code), isTrue);
    final fresh = await SharedPreferences.getInstance();
    expect(fresh.getBool('all_unlock_v1'), isNull);
  });
}
