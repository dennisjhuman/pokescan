import 'package:flutter/material.dart';

import 'manual_entry_sheet.dart';

/// Web/desktop stand-in for the camera scanner.
///
/// ML Kit text recognition is mobile-only and the cropper needs `dart:io`,
/// so on web the Scan tab is the manual lookup form. Same entry point, same
/// route out to `/card/{id}`.
class CameraScanView extends StatelessWidget {
  const CameraScanView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('PokéScan')),
        body: const Padding(padding: EdgeInsets.all(16), child: ManualEntryForm()),
      );
}
