import 'dart:math' show Point;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pokescan/features/scan/ocr_service.dart';

TextLine mlLine(String text, Rect box) => TextLine(
      text: text,
      elements: const [],
      boundingBox: box,
      recognizedLanguages: const [],
      cornerPoints: const <Point<int>>[],
      confidence: null,
      angle: null,
    );

TextBlock mlBlock(List<TextLine> lines) => TextBlock(
      text: lines.map((l) => l.text).join('\n'),
      lines: lines,
      boundingBox: lines.first.boundingBox,
      recognizedLanguages: const [],
      cornerPoints: const <Point<int>>[],
    );

void main() {
  group('OcrService.toLines', () {
    test('flattens blocks and normalises pixel boxes to 0..1', () {
      final recognized = RecognizedText(text: 'x', blocks: [
        mlBlock([mlLine('Charizard VMAX', const Rect.fromLTWH(100, 80, 400, 40))]),
        mlBlock([mlLine('020/189', const Rect.fromLTWH(90, 940, 120, 20))]),
      ]);

      final lines = OcrService.toLines(recognized, const Size(1000, 1000));
      expect(lines, hasLength(2));
      expect(lines.first.text, 'Charizard VMAX');
      expect(lines.first.left, closeTo(0.10, 1e-9));
      expect(lines.first.top, closeTo(0.08, 1e-9));
      expect(lines.first.right, closeTo(0.50, 1e-9));
      expect(lines.first.bottom, closeTo(0.12, 1e-9));
      expect(lines.first.height, closeTo(0.04, 1e-9));
      expect(lines.last.centerY, closeTo(0.95, 1e-9));
    });

    test('non-square images normalise each axis separately', () {
      final recognized = RecognizedText(text: 'x', blocks: [
        mlBlock([mlLine('name', const Rect.fromLTWH(315, 88, 630, 88))]),
      ]);
      final lines = OcrService.toLines(recognized, const Size(1260, 1760));
      expect(lines.single.left, closeTo(0.25, 1e-9));
      expect(lines.single.top, closeTo(0.05, 1e-9));
      expect(lines.single.right, closeTo(0.75, 1e-9));
      expect(lines.single.bottom, closeTo(0.10, 1e-9));
    });

    test('empty recognition yields no lines', () {
      expect(OcrService.toLines(RecognizedText(text: '', blocks: []), const Size(100, 100)), isEmpty);
    });

    test('a zero image size does not divide by zero', () {
      final recognized = RecognizedText(text: 'x', blocks: [
        mlBlock([mlLine('a', const Rect.fromLTWH(0, 0, 10, 10))]),
      ]);
      final lines = OcrService.toLines(recognized, Size.zero);
      expect(lines.single.right, 10);
    });
  });
}
