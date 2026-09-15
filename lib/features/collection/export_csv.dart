import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/repositories/collection_repository.dart';
import 'collection_csv.dart';

/// Build the CSV and hand it to the platform share sheet.
///
/// `XFile.fromData` keeps this off `dart:io`, so the same call works on web,
/// where share_plus falls back to a download.
///
/// Returns false when the user dismissed the sheet.
Future<bool> exportCollectionCsv(
  BuildContext context,
  List<CollectionEntry> entries, {
  DateTime? now,
}) async {
  final csv = collectionToCsv(entries);
  final bytes = Uint8List.fromList(utf8.encode(csv));
  final name = csvFileName(now: now);

  final box = context.findRenderObject() as RenderBox?;
  final result = await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: 'text/csv', name: name)],
    fileNameOverrides: [name],
    subject: 'PokéScan collection',
    // iPad needs an anchor rect for the popover.
    sharePositionOrigin:
        box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
  return result.status == ShareResultStatus.success;
}
