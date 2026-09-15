/// Mean-saturation measurement used for the soft colour prompt in Phase 4.
///
/// Web-safe: `package:image` is pure Dart, and this takes bytes rather than a
/// file path. Deliberately crude — it exists to notice a card that is wildly
/// more or less saturated than the official scan, not to grade printing.
library;

import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Mean HSV saturation (0..1) of [bytes], or null if it cannot be decoded.
///
/// Samples on a grid of at most [samples] pixels so a 4000px capture costs the
/// same as a thumbnail. Near-black and near-white pixels are skipped: their
/// hue is meaningless and card borders would otherwise dominate.
double? meanSaturation(Uint8List bytes, {int samples = 4096}) {
  final image = img.decodeImage(bytes);
  if (image == null) return null;
  return meanSaturationOfImage(image, samples: samples);
}

double? meanSaturationOfImage(img.Image image, {int samples = 4096}) {
  if (image.width == 0 || image.height == 0) return null;
  final step = _stepFor(image.width, image.height, samples);

  var total = 0.0;
  var counted = 0;
  for (var y = 0; y < image.height; y += step) {
    for (var x = 0; x < image.width; x += step) {
      final p = image.getPixel(x, y);
      final r = p.r / 255.0;
      final g = p.g / 255.0;
      final b = p.b / 255.0;
      final max = [r, g, b].reduce((a, c) => a > c ? a : c);
      final min = [r, g, b].reduce((a, c) => a < c ? a : c);
      if (max < 0.08 || min > 0.96) continue; // near-black / near-white
      total += max == 0 ? 0 : (max - min) / max;
      counted++;
    }
  }
  if (counted == 0) return null;
  return total / counted;
}

int _stepFor(int width, int height, int samples) {
  if (samples <= 0) return 1;
  final pixels = width * height;
  if (pixels <= samples) return 1;
  final step = (pixels / samples).abs();
  final s = _sqrtInt(step);
  return s < 1 ? 1 : s;
}

int _sqrtInt(double v) {
  var r = 1;
  while ((r + 1) * (r + 1) <= v) {
    r++;
  }
  return r;
}
