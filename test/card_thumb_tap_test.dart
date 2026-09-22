import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/shared/utils/image_loader.dart';
import 'package:pokescan/shared/widgets/card_thumb.dart';

/// Regression: a failed thumbnail used to offer "tap to retry" on the art,
/// which swallowed the tap meant for the result tile around it. Every card
/// without art in a grid — all of Japanese M6, the whole 30th Classic
/// Collection — could only be opened by tapping the small name text below.
void main() {
  Future<void> pumpTile(WidgetTester tester, {required bool speculative, required VoidCallback onTap}) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 180,
            child: CardResultTile(
              // flutter_test answers every real HTTP request with a 400, so
              // this image always fails — which is the case under test.
              imageUrl: 'https://assets.tcgdex.net/ja/M/M6/084/low.webp',
              speculative: speculative,
              name: 'Groudon',
              number: '084/76',
              onTap: onTap,
            ),
          ),
        ),
      ),
    ));
    // Let the loader give up: advance fake time past its backoff, pumping so
    // the test HTTP client's responses and the retry timers both run.
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  setUp(() {
    imageLoader.cache.clear();
    imageLoader.retryFailures();
  });

  testWidgets('tapping the art of a card with no artwork opens the card', (tester) async {
    var opened = 0;
    await pumpTile(tester, speculative: true, onTap: () => opened++);
    expect(find.text('No artwork yet'), findsOneWidget);

    await tester.tap(find.text('No artwork yet'));
    expect(opened, 1);
  });

  testWidgets('a failed listed image in a tile still opens the card', (tester) async {
    var opened = 0;
    await pumpTile(tester, speculative: false, onTap: () => opened++);
    expect(find.text('Tap to retry'), findsNothing, reason: 'the tap belongs to the tile');

    await tester.tap(find.text('Groudon').first);
    await tester.tap(find.byType(CardThumb));
    expect(opened, 2);
  });
}
