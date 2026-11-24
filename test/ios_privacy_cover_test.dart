import 'dart:ui' show ImageByteFormat;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prize_bond_checking_app/ios_privacy_cover.dart';

void main() {
  const first = '8123456789abcdef';
  const second = '9fedcba987654321';

  test('Keeps the proof frame pending until native confirms the current generation', () {
    final cover = IosPrivacyCover();

    expect(cover.request(1, first), isTrue);
    expect(cover.proof, first);
    expect(cover.presentationConfirmed(2), isFalse);
    expect(cover.proof, first);
    expect(cover.presentationConfirmed(1), isTrue);
    expect(cover.proof, isNull);
    expect(cover.presentationConfirmed(1), isFalse);
  });

  test('A newer resume ignores stale requests and stale completion messages', () {
    final cover = IosPrivacyCover();

    expect(cover.request(5, first), isTrue);
    expect(cover.request(6, second), isTrue);
    expect(cover.request(5, first), isFalse);
    expect(cover.request(6, first), isFalse);
    expect(cover.presentationConfirmed(5), isFalse);
    expect(cover.proof, second);
    expect(cover.presentationConfirmed(6), isTrue);
    expect(cover.proof, isNull);
  });

  test('Malformed and blank-frame proofs cannot replace an active proof', () {
    final cover = IosPrivacyCover();

    expect(cover.request(10, first), isTrue);
    expect(cover.request(11, '0000000000000000'), isFalse);
    expect(cover.request(11, 'ffffffffffffffff'), isFalse);
    expect(cover.request(11, 'not-hex'), isFalse);
    expect(cover.proof, first);
  });

  testWidgets('The proof painter renders an opaque matte and the expected ordered bits', (tester) async {
    tester.view.physicalSize = const Size(512, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const key = ValueKey('proof-frame-boundary');
    await tester.pumpWidget(
      const RepaintBoundary(
        key: key,
        child: IosPrivacyFrame(proof: first),
      ),
    );

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
    await tester.runAsync(() async {
      final image = await boundary.toImage();
      try {
        final data = (await image.toByteData(format: ImageByteFormat.rawRgba))!;
        expect(data.getUint32(0), 0xffffffff);
        expect(data.getUint32((image.width * (image.height - 1) + image.width - 1) * 4), 0xffffffff);
        for (var i = 0; i < 64; i++) {
          final x = (image.width * (0.125 + 0.75 * (i + 0.5) / 64)).floor();
          final pixel = data.getUint32(((image.height ~/ 2) * image.width + x) * 4);
          final digit = int.parse(first[i ~/ 4], radix: 16);
          final white = digit & (1 << (3 - i % 4)) != 0;
          expect(pixel, white ? 0xffffffff : 0x000000ff, reason: 'Proof stripe bit $i');
        }
      } finally {
        image.dispose();
      }
    });
  });
}
