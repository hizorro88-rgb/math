import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/services/backup.dart';
import 'package:preschool_math/services/cloud_sync.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
  });

  test('Firebase 설정이 비어 있으면 클라우드는 조용히 꺼져 있다', () async {
    await CloudSync.init();
    expect(CloudSync.available, isFalse);
    expect(CloudSync.signedIn, isFalse);

    // 꺼진 상태에서 불러도 아무 일도 안 하고, 로그인은 안내 문구를 돌려준다.
    CloudSync.scheduleUpload();
    expect(await CloudSync.uploadNow(), isFalse);
    expect(await CloudSync.pullIfNewer(), isFalse);
    expect(await CloudSync.signIn('a@b.c', '123456'), isNotNull);
    expect(await CloudSync.signUp('a@b.c', '123456'), isNotNull);
  });

  test('동기화 시각 키는 백업·클라우드 데이터에 실리지 않는다', () async {
    SharedPreferences.setMockInitialValues({
      'cloud_sync_at_v1': 12345,
      'p1_level_stars_v4': ['3'],
    });
    final data = await BackupService.exportData();
    expect(data.containsKey('cloud_sync_at_v1'), isFalse);
    expect(data.containsKey('p1_level_stars_v4'), isTrue);

    // 복원해도 이 기기의 동기화 시각은 지워지지 않게 새로 쓰지 않는다.
    expect(await BackupService.restoreData(data), isTrue);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getStringList('p1_level_stars_v4'), ['3']);
  });
}
