import 'dart:io';
import 'dart:ui' show Rect;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/utils/card_crop.dart';
import '../../shared/utils/colour_stats.dart';
import 'card_text_parser.dart';
import 'ocr_service.dart';
import 'scan_outcome.dart';

final ocrServiceProvider = Provider<OcrService>((ref) {
  final s = OcrService();
  ref.onDispose(s.close);
  return s;
});

final cardTextParserProvider = Provider<CardTextParser>((_) => CardTextParser());

/// capture file → crop to guide → OCR → parse.
///
/// Native only; `scan_outcome.dart` holds the result type that other
/// platforms can read.
class ScanPipeline {
  ScanPipeline(this._ocr, this._parser);

  final OcrService _ocr;
  final CardTextParser _parser;

  /// [guide] is in 0..1 coordinates of the capture. Pass null when the image
  /// is already a tight photo of the card, as with a gallery pick.
  Future<ScanOutcome> run(String capturePath, {Rect? guide}) async {
    final crop = await compute(
      _cropIsolate,
      _CropArgs(capturePath, guide ?? const Rect.fromLTWH(0, 0, 1, 1)),
    );
    final lines = await _ocr.recognizeFile(crop.path, crop.size);
    final parsed = _parser.parse(lines);
    final bytes = await File(crop.path).readAsBytes();
    final saturation = await compute(_saturationIsolate, bytes);
    return ScanOutcome(
      cropPath: crop.path,
      cropBytes: bytes,
      lines: lines,
      parsed: parsed,
      cropSaturation: saturation,
    );
  }
}

class _CropArgs {
  const _CropArgs(this.path, this.guide);
  final String path;
  final Rect guide;
}

CropResult _cropIsolate(_CropArgs a) => cropToGuide(a.path, a.guide);

double? _saturationIsolate(Uint8List bytes) => meanSaturation(bytes);

final scanPipelineProvider = Provider<ScanPipeline>(
    (ref) => ScanPipeline(ref.watch(ocrServiceProvider), ref.watch(cardTextParserProvider)));
