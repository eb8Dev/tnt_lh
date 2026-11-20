import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tnt_lh/widgets/lanyard.dart';

void main() {
  testWidgets('the badge drops in and comes to rest hanging straight', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Lanyard(
          front: SizedBox(key: Key('front')),
          back: SizedBox(),
          cardSize: Size(200, 300),
          strapLength: 120,
        ),
      ),
    ));
    final start = tester.getCenter(find.byKey(const Key('front')));
    for (var i = 0; i < 6 * 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final rest = tester.getCenter(find.byKey(const Key('front')));
    final mid = tester.getSize(find.byType(Scaffold)).width / 2;
    // ignore: avoid_print
    print('start $start rest $rest mid $mid');
    expect(start.dx - mid, greaterThan(100)); // started swung out
    expect((rest.dx - mid).abs(), lessThan(20)); // settled under the anchor
    expect(rest.dy, closeTo(120 + 150, 25));
  });
}
