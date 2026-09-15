import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pokescan/shared/utils/colour_stats.dart';

Uint8List pngOf(img.Image image) => Uint8List.fromList(img.encodePng(image));

img.Image solid(int r, int g, int b, {int size = 64}) {
  final image = img.Image(width: size, height: size);
  img.fill(image, color: img.ColorRgb8(r, g, b));
  return image;
}

void main() {
  group('meanSaturation', () {
    test('a fully saturated colour scores 1.0', () {
      expect(meanSaturation(pngOf(solid(255, 0, 0)))!, closeTo(1.0, 0.01));
    });

    test('a mid grey scores 0.0', () {
      expect(meanSaturation(pngOf(solid(128, 128, 128)))!, closeTo(0.0, 0.01));
    });

    test('a washed-out colour scores between the two', () {
      final washed = meanSaturation(pngOf(solid(200, 150, 150)))!;
      expect(washed, greaterThan(0.1));
      expect(washed, lessThan(0.5));
    });

    test('a faded card reads lower than a vivid one', () {
      final vivid = meanSaturation(pngOf(solid(220, 30, 30)))!;
      final faded = meanSaturation(pngOf(solid(200, 140, 140)))!;
      expect(vivid - faded, greaterThan(0.3));
    });

    test('near-black and near-white pixels are skipped', () {
      expect(meanSaturation(pngOf(solid(2, 2, 2))), isNull);
      expect(meanSaturation(pngOf(solid(255, 255, 255))), isNull);
    });

    test('a white border does not drag a vivid centre down', () {
      final image = solid(255, 255, 255, size: 100);
      img.fillRect(image, x1: 20, y1: 20, x2: 79, y2: 79, color: img.ColorRgb8(255, 0, 0));
      expect(meanSaturation(pngOf(image))!, closeTo(1.0, 0.01));
    });

    test('undecodable bytes give null rather than throwing', () {
      expect(meanSaturation(Uint8List.fromList('not an image'.codeUnits)), isNull);
    });

    test('sampling a large image agrees with the full scan', () {
      final image = solid(200, 60, 60, size: 400);
      final sampled = meanSaturationOfImage(image, samples: 256)!;
      final full = meanSaturationOfImage(image, samples: 400 * 400)!;
      expect(sampled, closeTo(full, 0.01));
    });
  });
}
