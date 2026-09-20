import 'package:flutter/material.dart';

import 'find_card_view.dart';

/// Web/desktop stand-in for the camera scanner.
///
/// ML Kit text recognition is mobile-only and the cropper needs `dart:io`,
/// so on web the Scan tab is the card finder. Same entry point, same route
/// out to `/card/{id}`.
class CameraScanView extends StatelessWidget {
  const CameraScanView({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(child: FindCardView()),
      );
}
