import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:preschool_math/models/profile.dart';
import 'package:preschool_math/models/progress.dart';
import 'package:preschool_math/models/sticker_canvas.dart';
import 'package:preschool_math/models/stickers.dart';
import 'package:preschool_math/screens/sticker_book_screen.dart';
import 'package:preschool_math/services/sounds.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Profiles.activeId = 1;
    Sounds.enabled = true;
  });

  test('스티커 데이터: 페이지마다 12장, 이름·그림이 겹치지 않는다', () {
    for (final page in stickerPages) {
      expect(page.stickers, hasLength(12), reason: page.title);
      expect(page.stickers.map((s) => s.name).toSet(), hasLength(12));
      expect(page.stickers.map((s) => s.emoji).toSet(), hasLength(12));
    }
  });

  test('통과하면 스티커를 받고, 골라 붙이면 1장씩 줄어든다', () async {
    expect(await StickerStore.tickets(), 0);
    await StickerStore.addTickets(1);
    expect(await StickerStore.tickets(), 1);

    final result = await StickerStore.place(0, 3);
    expect(result, isNotNull);
    expect(result!.sticker.name, stickerPages[0].stickers[3].name);
    expect(result.pageCompleted, isFalse);
    expect(await StickerStore.tickets(), 0);
    expect((await StickerStore.load())[0], {3});
  });

  test('스티커가 없거나 이미 붙은 자리에는 못 붙인다', () async {
    // 스티커 없이 붙이기 → 실패
    expect(await StickerStore.place(0, 0), isNull);

    await StickerStore.addTickets(2);
    await StickerStore.place(0, 0);
    // 같은 자리에 또 붙이기 → 실패, 스티커는 그대로
    expect(await StickerStore.place(0, 0), isNull);
    expect(await StickerStore.tickets(), 1);
  });

  test('페이지를 다 채우면 보너스 코인을 준다', () async {
    await StickerStore.addTickets(12);
    StickerPlaceResult? last;
    for (var i = 0; i < 12; i++) {
      last = await StickerStore.place(2, i);
    }
    expect(last!.pageCompleted, isTrue);
    expect(last.albumCompleted, isFalse);
    expect(last.bonusCoins, StickerStore.pageBonus);
    expect(await ProgressStore.loadCoins(), StickerStore.pageBonus);
  });

  test('앨범을 다 채우면 큰 보너스를 주고 새 앨범이 시작된다', () async {
    final total = stickerPages.fold<int>(0, (s, p) => s + p.stickers.length);
    await StickerStore.addTickets(total);
    StickerPlaceResult? last;
    for (var p = 0; p < stickerPages.length; p++) {
      for (var i = 0; i < stickerPages[p].stickers.length; i++) {
        last = await StickerStore.place(p, i);
      }
    }
    expect(last!.albumCompleted, isTrue);
    expect(last.bonusCoins, StickerStore.pageBonus + StickerStore.albumBonus);
    expect(await StickerStore.completedAlbums(), 1);
    // 새 앨범: 스티커북이 비었다.
    expect(await StickerStore.count(), 0);
  });

  testWidgets('스티커북에서 흐린 스티커를 눌러 직접 붙인다', (tester) async {
    SharedPreferences.setMockInitialValues({'sticker_tickets_v1': 1});
    await tester.pumpWidget(const MaterialApp(home: StickerBookScreen()));
    await tester.pumpAndSettle();

    expect(find.text('🎟️ 붙일 수 있는 스티커 1장!'), findsOneWidget);

    // 첫 페이지의 '사자' 자리까지 내려가서 골라 누른다.
    await tester.scrollUntilVisible(find.text('사자'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('사자'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사자'));
    await tester.pumpAndSettle();

    expect(find.textContaining('사자 스티커를 붙였어요'), findsOneWidget);
    expect(await StickerStore.tickets(), 0);
    expect((await StickerStore.load())[0], {0});
  });

  test('꾸미기 판: 붙이고 옮기고 지운 상태가 저장된다', () async {
    await CanvasStore.save([
      const PlacedSticker(emoji: '🦁', x: 100, y: 200),
      const PlacedSticker(emoji: '🚀', x: 900, y: 300),
    ]);
    var placed = await CanvasStore.load();
    expect(placed, hasLength(2));
    expect(placed[0].emoji, '🦁');

    // 옮기기 (범위 밖은 잘라낸다)
    placed[0] = placed[0].moveTo(1200, -5);
    await CanvasStore.save(placed);
    placed = await CanvasStore.load();
    expect((placed[0].x, placed[0].y), (1000, 0));

    // 지우기
    placed.removeAt(0);
    await CanvasStore.save(placed);
    expect(await CanvasStore.load(), hasLength(1));
  });

  test('한 번 모은 스티커는 앨범이 리셋돼도 꾸미기 팔레트에 남는다', () async {
    await StickerStore.addTickets(1);
    await StickerStore.place(0, 0); // 사자
    // 앨범 리셋 흉내: 수집 기록만 비운다.
    SharedPreferences.setMockInitialValues({
      'sticker_seen_v1': ['0:0'],
    });
    final palette = await StickerStore.collectedStickers();
    expect(palette.map((s) => s.name), ['사자']);
  });

  testWidgets('꾸미기 판에서 스티커를 골라 원하는 곳에 붙인다', (tester) async {
    SharedPreferences.setMockInitialValues({
      'stickers_v1': ['0:0'], // 사자를 모아 둔 상태
    });
    await tester.pumpWidget(const MaterialApp(home: StickerBookScreen()));
    await tester.pumpAndSettle();

    // 팔레트에서 사자를 고르고 캔버스를 톡 누른다.
    await tester.ensureVisible(find.byKey(const ValueKey('palette:🦁')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('palette:🦁')));
    await tester.pump();
    final canvas = find.byKey(const ValueKey('sticker-canvas'));
    await tester.ensureVisible(canvas);
    await tester.pumpAndSettle();
    await tester.tapAt(tester.getCenter(canvas));
    await tester.pumpAndSettle();

    final placed = await CanvasStore.load();
    expect(placed, hasLength(1));
    expect(placed.first.emoji, '🦁');
    // 가운데쯤 붙었다.
    expect(placed.first.x, inInclusiveRange(400, 600));
    expect(placed.first.y, inInclusiveRange(400, 600));
  });

  testWidgets('붙일 스티커가 없으면 안내만 나온다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: StickerBookScreen()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('사자'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.text('사자'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('사자'));
    await tester.pumpAndSettle();

    expect(find.textContaining('붙일 스티커가 없어요'), findsOneWidget);
    expect(await StickerStore.count(), 0);
  });
}
