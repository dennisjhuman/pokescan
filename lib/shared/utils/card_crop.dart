import 'dart:io';
import 'dart:ui' show Rect, Size;

import 'package:image/image.dart' as img;

/// Result of cropping a capture to the card guide.
class CropResult {
  const CropResult({required this.path, required this.size});
  final String path;
  final Size size;
}

/// Crop [sourcePath] to [guide] (a rect in 0..1 coordinates of the source
/// image), bake in EXIF orientation, and write a JPEG next to it.
///
/// Runs on the calling isolate; wrap in `compute` on the UI side. Pure Dart
/// (`package:image`) so it works on every platform without native plugins.
CropResult cropToGuide(String sourcePath, Rect guide, {String? outPath}) {
  final bytes = File(sourcePath).readAsBytesSync();
  var decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('Could not decode capture');
  decoded = img.bakeOrientation(decoded);

  final x = (guide.left * decoded.width).round().clamp(0, decoded.width - 1);
  final y = (guide.top * decoded.height).round().clamp(0, decoded.height - 1);
  final w = (guide.width * decoded.width).round().clamp(1, decoded.width - x);
  final h = (guide.height * decoded.height).round().clamp(1, decoded.height - y);
  final cropped = img.copyCrop(decoded, x: x, y: y, width: w, height: h);

  final stem = sourcePath.replaceAll(RegExp(r'\.\w+$'), '');
  final target = outPath ?? '${stem}_card.jpg';
  File(target).writeAsBytesSync(img.encodeJpg(cropped, quality: 92));
  return CropResult(path: target, size: Size(w.toDouble(), h.toDouble()));
}

/// Where the card guide sits inside a preview of [previewSize]: centred,
/// 63×88 aspect, [widthFraction] of the shorter side. Returned in 0..1
/// coordinates so the same rect can be applied to the full-res capture
/// (which shares the preview's aspect ratio).
Rect guideRectFor(Size previewSize, {double widthFraction = 0.82, double cardAspect = 63 / 88}) {
  final portrait = previewSize.height >= previewSize.width;
  final shortSide = portrait ? previewSize.width : previewSize.height;
  final cardW = shortSide * widthFraction;
  final cardH = cardW / cardAspect;
  final left = (previewSize.width - cardW) / 2;
  final top = (previewSize.height - cardH) / 2;
  return Rect.fromLTWH(
    left / previewSize.width,
    top / previewSize.height,
    cardW / previewSize.width,
    cardH / previewSize.height,
  );
}
