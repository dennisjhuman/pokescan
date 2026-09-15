import 'dart:ui' show Rect, Size;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'card_text_parser.dart';

/// Thin ML Kit wrapper. Runs on-device; no network, no cost.
/// Converts ML Kit lines to [OcrLine]s with boxes normalised to the image
/// (0..1) so the parser never sees pixel coordinates.
class OcrService {
  OcrService({TextRecognitionScript script = TextRecognitionScript.latin})
      : _recognizer = TextRecognizer(script: script);

  final TextRecognizer _recognizer;

  /// [imageSize] is the pixel size of the file at [path] (needed to
  /// normalise boxes; ML Kit reports pixels).
  Future<List<OcrLine>> recognizeFile(String path, Size imageSize) async {
    final result = await _recognizer.processImage(InputImage.fromFilePath(path));
    return toLines(result, imageSize);
  }

  /// Pure conversion, testable without ML Kit.
  static List<OcrLine> toLines(RecognizedText text, Size size) {
    final w = size.width == 0 ? 1.0 : size.width;
    final h = size.height == 0 ? 1.0 : size.height;
    final out = <OcrLine>[];
    for (final block in text.blocks) {
      for (final line in block.lines) {
        final Rect r = line.boundingBox;
        out.add(OcrLine(
          line.text,
          left: r.left / w,
          top: r.top / h,
          right: r.right / w,
          bottom: r.bottom / h,
        ));
      }
    }
    return out;
  }

  Future<void> close() => _recognizer.close();
}
