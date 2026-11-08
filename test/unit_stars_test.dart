import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/curriculum.dart';
import 'package:preschool_math/models/english_curriculum.dart';
import 'package:preschool_math/models/korean_curriculum.dart';
import 'package:preschool_math/models/language_packs.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/models/unit_stars.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    Profiles.activeId = 1;
    SharedPreferences.setMockInitialValues({});
  });

  test('묶음 제목은 과목 안에서 겹치지 않는다 (별이 제목으로 저장된다)', () {
    void unique(String name, List<String> titles) {
      expect(titles.toSet().length, titles.length, reason: name);
      for (final t in titles) {
        expect(t.contains('='), isFalse, reason: '$name: $t');
      }
    }

    unique('수학', [for (final u in Curriculum.units) u.title]);
    unique('한글', [for (final u in KoreanCurriculum.units) u.title]);
    unique('영어', [for (final u in EnglishCurriculum.units) u.title]);
    for (final pack in languagePacks) {
      unique(pack.name, [for (final u in pack.units) u.title]);
    }
  });

  test('옛 순서 기록은 제목을 따라 새 번호로 옮겨 간다', () async {
    // 옛 v5 순서에서 '시계 읽기'는 15번째 묶음(141~150단계)이었다.
    final old = List.filled(430, '0');
    old[140] = '3';
    old[0] = '2';
    SharedPreferences.setMockInitialValues({'level_stars_v5': old});
    final stars = await ProgressStore.load();
    final clock = Curriculum.units.firstWhere((u) => u.title == '시계 읽기');
    expect(stars[clock.firstLevelNumber - 1], 3);
    expect(stars[0], 2);
  });

  test('묶음을 중간에 넣어도 기록이 제자리를 지킨다', () async {
    var titles = ['가', '나'];
    final store = UnitStarStore(
        key: 'test_unit_stars_v1', titles: () => titles, perUnit: 2);
    await store.save(3, 2); // '나'의 첫 단계
    titles = ['가', '새 묶음', '나'];
    final stars = await store.load();
    expect(stars, [0, 0, 0, 0, 2, 0]);
    await store.save(5, 1); // 더 낮은 기록은 덮지 않는다
    expect((await store.load())[4], 2);
  });

  test('프로필마다 따로 저장된다', () async {
    await ProgressStore.saveStars(1, 3);
    Profiles.activeId = 2;
    expect((await ProgressStore.load())[0], 0);
    Profiles.activeId = 1;
    expect((await ProgressStore.load())[0], 3);
  });

  test('옛 기록의 묶음 제목은 지금도 그대로 있다 (제목을 바꾸면 기록이 사라진다)', () {
    // 묶음 이름을 바꿔야 하면 UnitStarStore의 renamed에 옛 이름 → 새 이름을 적고
    // 이 목록도 함께 고친다.
    const pinned = {
      '수학': ['수 세기 첫걸음', '시계 읽기', '시계 보기', '분수 첫걸음', '시간 계산'],
      '한글': ['낱말 보고 그림 찾기', '받침 낱말', '긴 낱말 도전'],
      '영어': ['알파벳 소리 찾기', '첫 글자 찾기', '낱말 만들기', '긴 낱말 도전'],
    };
    final current = {
      '수학': [for (final u in Curriculum.units) u.title],
      '한글': [for (final u in KoreanCurriculum.units) u.title],
      '영어': [for (final u in EnglishCurriculum.units) u.title],
    };
    for (final e in pinned.entries) {
      for (final t in e.value) {
        expect(current[e.key], contains(t), reason: '${e.key}: $t');
      }
    }
    for (final pack in languagePacks) {
      final titles = [for (final u in pack.units) u.title];
      for (final t in pack.v1UnitTitles) {
        expect(titles, contains(t), reason: '${pack.name}: $t');
      }
    }
  });
}
