import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/card_crop.dart';
import 'card_text_parser.dart';
import 'ocr_service.dart';

/// What the last scan produced. The detail page (Phase 4) uses the crop for
/// side-by-side comparison and the OCR text for mismatch checks.
class ScanOutcome {
  const ScanOutcome({required this.cropPath, required this.lines, required this.parsed});
  final String cropPath;
  final List<OcrLine> lines;
  final ParsedCard parsed;
}

class LastScan extends Notifier<ScanOutcome?> {
  @override
  ScanOutcome? build() => null;
  void set(ScanOutcome? o) => state = o;
}

final lastScanProvider = NotifierProvider<LastScan, ScanOutcome?>(LastScan.new);

final ocrServiceProvider = Provider<OcrService>((ref) {
  final s = OcrService();
  ref.onDispose(s.close);
  return s;
});

final cardTextParserProvider = Provider<CardTextParser>((_) => CardTextParser());

/// capture file → crop to guide → OCR → parse.
class ScanPipeline {
  ScanPipeline(this._ocr, this._parser);
  final OcrService _ocr;
  final CardTextParser _parser;

  /// [guide] in 0..1 coords of the capture; pass `null` when the image is
  /// already a tight card photo (gallery pick).
  Future<ScanOutcome> run(String capturePath, {Rect? guide}) async {
    final crop = await compute(
      _cropIsolate,
      _CropArgs(capturePath, guide ?? const Rect.fromLTWH(0, 0, 1, 1)),
    );
    final lines = await _ocr.recognizeFile(crop.path, crop.size);
    final parsed = _parser.parse(lines);
    return ScanOutcome(cropPath: crop.path, lines: lines, parsed: parsed);
  }
}

class _CropArgs {
  const _CropArgs(this.path, this.guide);
  final String path;
  final Rect guide;
}

CropResult _cropIsolate(_CropArgs a) => cropToGuide(a.path, a.guide);

final scanPipelineProvider = Provider<ScanPipeline>(
    (ref) => ScanPipeline(ref.watch(ocrServiceProvider), ref.watch(cardTextParserProvider)));
