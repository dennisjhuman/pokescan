import 'package:flutter/material.dart';

// Native gets the camera + OCR scanner; web gets the manual entry form.
// The stub is the default so a platform without dart:io still compiles.
import 'camera_scan_view_stub.dart' if (dart.library.io) 'camera_scan_view.dart';

class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) => const CameraScanView();
}
