import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:pokescan/core/constants.dart';
import 'package:pokescan/shared/utils/card_crop.dart';

void main() {
  group('guideRectFor', () {
    test('window keeps the 63x88 card aspect on a portrait preview', () {
      const preview = Size(1080, 1920);
      final g = guideRectFor(preview);
      final w = g.width * preview.width;
      final h = g.height * preview.height;
      expect(w / h, closeTo(AppConstants.cardAspectRatio, 0.001));
    });

    test('window is centred and inside the preview', () {
      final g = guideRectFor(const Size(1080, 1920));
      expect(g.center.dx, closeTo(0.5, 1e-9));
      expect(g.center.dy, closeTo(0.5, 1e-9));
      expect(g.left, greaterThan(0));
      expect(g.top, greaterThan(0));
      expect(g.right, lessThan(1));
      expect(g.bottom, lessThan(1));
    });

    test('a very short preview still produces a card-shaped window', () {
      const preview = Size(1920, 1080);
      final g = guideRectFor(preview);
      final ratio = (g.width * preview.width) / (g.height * preview.height);
      expect(ratio, closeTo(AppConstants.cardAspectRatio, 0.001));
    });
  });

  group('cropToGuide', () {
    late Directory dir;

    setUp(() => dir = Directory.systemTemp.createTempSync('pokescan_crop'));
    tearDown(() => dir.deleteSync(recursive: true));

    String writeSource({int w = 400, int h = 800}) {
      final image = img.Image(width: w, height: h);
      img.fill(image, color: img.ColorRgb8(10, 20, 30));
      // Red block in the middle third so we can prove the crop landed.
      img.fillRect(image,
          x1: w ~/ 3, y1: h ~/ 3, x2: 2 * w ~/ 3, y2: 2 * h ~/ 3, color: img.ColorRgb8(255, 0, 0));
      final path = '${dir.path}/source.png';
      File(path).writeAsBytesSync(img.encodePng(image));
      return path;
    }

    test('crops to the guide rect and reports the output size', () {
      final src = writeSource();
      final res = cropToGuide(src, const Rect.fromLTWH(0.25, 0.25, 0.5, 0.5));
      expect(res.size, const Size(200, 400));
      expect(File(res.path).existsSync(), isTrue);
      expect(res.path, endsWith('_card.jpg'));

      final out = img.decodeImage(File(res.path).readAsBytesSync())!;
      expect(out.width, 200);
      expect(out.height, 400);
      final middle = out.getPixel(out.width ~/ 2, out.height ~/ 2);
      expect(middle.r, greaterThan(200), reason: 'centre of the crop is the red block');
    });

    test('a full-frame guide returns the whole image', () {
      final src = writeSource(w: 120, h: 200);
      final res = cropToGuide(src, const Rect.fromLTWH(0, 0, 1, 1));
      expect(res.size, const Size(120, 200));
    });

    test('a guide running past the edge is clamped, not an error', () {
      final src = writeSource(w: 100, h: 100);
      final res = cropToGuide(src, const Rect.fromLTWH(0.8, 0.8, 0.5, 0.5));
      expect(res.size.width, lessThanOrEqualTo(20));
      expect(res.size.height, lessThanOrEqualTo(20));
      expect(res.size.width, greaterThan(0));
    });

    test('honours an explicit output path', () {
      final src = writeSource();
      final out = '${dir.path}/explicit.jpg';
      final res = cropToGuide(src, const Rect.fromLTWH(0, 0, 1, 1), outPath: out);
      expect(res.path, out);
      expect(File(out).existsSync(), isTrue);
    });

    test('undecodable input throws FormatException', () {
      final bad = '${dir.path}/bad.png';
      File(bad).writeAsStringSync('not an image');
      expect(() => cropToGuide(bad, const Rect.fromLTWH(0, 0, 1, 1)), throwsFormatException);
    });
  });
}
