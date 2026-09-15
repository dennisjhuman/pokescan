import 'package:flutter/material.dart';

import '../scan/scan_outcome.dart';
import 'fake_signals.dart';
import 'reference_compare_view.dart';

/// "Things to check" — never a verdict.
///
/// Warnings sit at the top with what differed; the routine visual checklist
/// is collapsed underneath so a clean card stays quiet.
class FakeSignalsPanel extends StatelessWidget {
  const FakeSignalsPanel({
    super.key,
    required this.signals,
    this.scan,
    this.referenceUrl,
  });

  final List<FakeSignal> signals;
  final ScanOutcome? scan;
  final String? referenceUrl;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final warnings = signals.where((s) => s.isWarning).toList();
    final checks = signals.where((s) => !s.isWarning).toList();

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(warnings.isEmpty ? Icons.checklist_rtl : Icons.help_outline,
                    color: warnings.isEmpty ? scheme.onSurfaceVariant : scheme.error),
                const SizedBox(width: 8),
                Expanded(child: Text('Things to check', style: text.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              warnings.isEmpty
                  ? 'Nothing stood out against TCGdex. These are still worth an eye.'
                  : '${warnings.length} thing${warnings.length == 1 ? '' : 's'} did not line up with '
                      'TCGdex. That is a reason to look closer, not a verdict.',
              style: text.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final s in warnings)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WarningTile(signal: s),
              ),
            if (scan != null)
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () => ReferenceCompareView.open(
                    context,
                    scan: scan!,
                    referenceUrl: referenceUrl,
                  ),
                  icon: const Icon(Icons.compare_outlined),
                  label: const Text('Compare with reference'),
                ),
              ),
            if (checks.isNotEmpty)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text('Look at the card itself (${checks.length})',
                      style: text.bodyMedium),
                  children: [
                    for (final c in checks)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.remove_red_eye_outlined, size: 18),
                        title: Text(c.prompt, style: text.bodyMedium),
                      ),
                  ],
                ),
              ),
            if (scan != null)
              Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  tilePadding: EdgeInsets.zero,
                  title: Text('What the scan read', style: text.bodyMedium),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SelectableText(
                        scan!.rawText.isEmpty ? 'No text recognised.' : scan!.rawText,
                        style: text.bodySmall?.copyWith(fontFamily: 'monospace'),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WarningTile extends StatelessWidget {
  const _WarningTile({required this.signal});
  final FakeSignal signal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(signal.prompt,
              style: text.bodyLarge?.copyWith(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              )),
          if (signal.detail != null) ...[
            const SizedBox(height: 4),
            Text(signal.detail!,
                style: text.bodySmall?.copyWith(color: scheme.onErrorContainer)),
          ],
        ],
      ),
    );
  }
}
