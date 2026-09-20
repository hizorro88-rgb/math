import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/pet.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/screens/pet_intro_screen.dart';
import 'package:preschool_math/screens/pet_room_screen.dart';
import 'package:preschool_math/services/sounds.dart';
import 'package:preschool_math/services/speech.dart';
import 'package:preschool_math/theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    AppMotion.loops = false; // 어슬렁거리는 타이머를 꺼야 pumpAndSettle이 끝난다
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
    Sounds.enabled = false;
    Speech.enabled = false;
  });

  group('친구 고르기', () {
    testWidgets('박사님이 알 세 개를 보여 준다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PetIntroScreen()));
      await tester.pumpAndSettle();

      expect(find.text('쿼카 박사'), findsOneWidget);
      for (var i = 0; i < petSpeciesList.length; i++) {
        expect(find.byKey(ValueKey('egg-$i')), findsOneWidget);
      }
      // 누르기 전에는 고르기 버튼이 없다 (급하게 못 고른다)
      expect(find.byKey(const ValueKey('pick-0')), findsNothing);
    });

    testWidgets('알을 누르면 귀띔이 뜨고 그때 고를 수 있다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PetIntroScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('egg-0')));
      await tester.pumpAndSettle();

      expect(find.text(petSpeciesList[0].hint), findsOneWidget);
      expect(find.byKey(const ValueKey('pick-0')), findsOneWidget);
    });

    testWidgets('고르면 알이 부화하고 저장된다', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: PetIntroScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('egg-1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pick-1')));
      // 알이 흔들리다 깨지는 데 700ms가 걸린다.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pumpAndSettle();

      expect(find.textContaining('태어났어요'), findsWidgets);
      expect(find.byKey(const ValueKey('hatch-done')), findsOneWidget);

      final saved = await PetStore.load();
      expect(saved.chosen, isTrue);
      expect(saved.species?.id, petSpeciesList[1].id);
    });
  });

  group('친구 방', () {
    Future<void> openRoom(WidgetTester tester) async {
      await tester.pumpWidget(const MaterialApp(home: PetRoomScreen()));
      await tester.pumpAndSettle();
    }

    testWidgets('밥·물 버튼과 성장 조건이 보인다', (tester) async {
      await PetStore.choose(petSpeciesList.first);
      await ProgressStore.addPoints(500);
      await openRoom(tester);

      expect(find.byKey(const ValueKey('pet-feed')), findsOneWidget);
      expect(find.byKey(const ValueKey('pet-drink')), findsOneWidget);
      expect(find.text('배부름'), findsOneWidget);
      expect(find.text('목마름'), findsOneWidget);
      expect(find.textContaining('별 모으기'), findsOneWidget);
    });

    testWidgets('밥을 주면 코인이 줄고 남은 횟수가 바뀐다', (tester) async {
      await PetStore.choose(petSpeciesList.first);
      await ProgressStore.addPoints(500);
      final before = await ProgressStore.loadCoins();
      await openRoom(tester);

      await tester.tap(find.byKey(const ValueKey('pet-feed')));
      await tester.pumpAndSettle();

      expect(await ProgressStore.loadCoins(), before - petMealCost);
      expect((await PetStore.load()).meals, 1);
    });

    testWidgets('코인이 없으면 안내만 뜨고 횟수는 그대로다', (tester) async {
      await PetStore.choose(petSpeciesList.first);
      await openRoom(tester);

      await tester.tap(find.byKey(const ValueKey('pet-feed')));
      await tester.pumpAndSettle();

      expect(find.textContaining('코인이 모자라요'), findsOneWidget);
      expect((await PetStore.load()).meals, 0);
    });

    testWidgets('조건을 채운 상태로 방에 들어가면 진화 축하가 뜬다', (tester) async {
      SharedPreferences.setMockInitialValues({
        'pet_species_v1': 'leaf',
        'pet_stage_v1': 1,
        'pet_meals_v1': 5,
        'pet_drinks_v1': 5,
        'level_stars_v5': ['3', '3', '3', '3'], // 별 12개 (10개 필요)
      });
      Profiles.activeId = 1;
      await openRoom(tester);

      expect(find.textContaining('축하해요'), findsOneWidget);
      expect(find.byKey(const ValueKey('evolve-ok')), findsOneWidget);
      expect((await PetStore.load()).stage, 2);

      // 확인을 누르면 방으로 돌아온다.
      await tester.tap(find.byKey(const ValueKey('evolve-ok')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('evolve-ok')), findsNothing);
    });

    testWidgets('작은 화면에서도 넘치지 않는다', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await PetStore.choose(petSpeciesList.first);
      await openRoom(tester);
      expect(find.byType(PetRoomScreen), findsOneWidget);
    });
  });
}
