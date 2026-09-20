import 'package:flutter/material.dart';

import '../../shared/widgets/card_thumb.dart';

import '../../core/constants.dart';
import '../scan/scan_outcome.dart';

/// Your scan beside the official TCGdex image, both pinch-zoomable.
///
/// The prompts underneath are the things worth comparing; the app never says
/// which one is real.
class ReferenceCompareView extends StatelessWidget {
  const ReferenceCompareView({super.key, required this.scan, required this.referenceUrl});

  final ScanOutcome scan;
  final String? referenceUrl;

  static Future<void> open(BuildContext context,
          {required ScanOutcome scan, required String? referenceUrl}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Compare with reference')),
          body: ReferenceCompareView(scan: scan, referenceUrl: referenceUrl),
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 420,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _Pane(
                  label: 'Your scan',
                  child: Image.memory(scan.cropBytes, fit: BoxFit.contain),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _Pane(
                  label: 'Official',
                  child: RemoteIcon(
                    url: referenceUrl,
                    fallback: const Center(child: Icon(Icons.image_not_supported)),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Pinch either side to zoom. Line up the same detail on both.',
            style: text.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: 16),
        Text('Worth comparing', style: text.titleSmall),
        const SizedBox(height: 4),
        for (final prompt in const [
          'Font weight and letter shapes in the name and HP',
          'Border thickness, and whether the yellow border is even',
          'Colour saturation across the artwork',
          'Holo pattern, and where it sits',
          'Set symbol shape and sharpness',
          'Energy symbol colours and icons',
        ])
          ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.remove_red_eye_outlined, size: 18),
            title: Text(prompt, style: text.bodyMedium),
          ),
      ],
    );
  }
}

class _Pane extends StatelessWidget {
  const _Pane({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label,
              textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 4),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: Colors.black12,
                child: InteractiveViewer(
                  maxScale: 6,
                  child: AspectRatio(
                    aspectRatio: AppConstants.cardAspectRatio,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
}
