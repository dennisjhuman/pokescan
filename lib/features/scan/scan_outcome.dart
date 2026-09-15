/// What the last scan produced, in a form every platform can read.
///
/// Kept separate from `scan_pipeline.dart` on purpose: that file pulls in ML
/// Kit and `dart:io`, while the card detail screen needs the *result* and is
/// built on web too. Only pure-Dart types cross this boundary.
library;

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'card_text_parser.dart';

class ScanOutcome {
  const ScanOutcome({
    required this.cropPath,
    required this.cropBytes,
    required this.lines,
    required this.parsed,
    this.cropSaturation,
    this.resolvedCardId,
  });

  /// Where the cropped capture was written. Stored on a collection row so the
  /// scan can be shown again later.
  final String cropPath;

  /// The same image in memory, so it can be displayed without `dart:io`.
  final Uint8List cropBytes;

  final List<OcrLine> lines;
  final ParsedCard parsed;

  /// Mean saturation of the crop, for the soft colour comparison.
  final double? cropSaturation;

  /// The card this scan was ultimately opened as. Set once the user (or the
  /// parser) settles on an id, so the detail screen only applies a scan to the
  /// card it actually belongs to.
  final String? resolvedCardId;

  ScanOutcome resolvedAs(String cardId) => ScanOutcome(
        cropPath: cropPath,
        cropBytes: cropBytes,
        lines: lines,
        parsed: parsed,
        cropSaturation: cropSaturation,
        resolvedCardId: cardId,
      );

  /// Everything OCR read, newline-joined. Shown in the "what we read" details.
  String get rawText => lines.map((l) => l.text).join('\n');
}

class LastScan extends Notifier<ScanOutcome?> {
  @override
  ScanOutcome? build() => null;

  void set(ScanOutcome? outcome) => state = outcome;
  void clear() => state = null;
}

final lastScanProvider = NotifierProvider<LastScan, ScanOutcome?>(LastScan.new);
