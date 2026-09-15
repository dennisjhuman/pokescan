import 'package:flutter/material.dart';

import 'manual_entry_sheet.dart';

/// Manual lookup. The camera scanner replaces this in Phase 3; manual entry
/// stays as the "Not this card?" fallback.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('PokéScan')),
        body: const Padding(padding: EdgeInsets.all(16), child: ManualEntryForm()),
      );
}
