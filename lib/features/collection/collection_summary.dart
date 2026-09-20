import 'package:flutter/material.dart';

import '../../data/repositories/collection_repository.dart';
import '../card_detail/price_panel.dart';

/// Header card: total value + counts.
class CollectionSummaryBar extends StatelessWidget {
  const CollectionSummaryBar({super.key, required this.summary});
  final CollectionSummary summary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Collection value', style: text.labelMedium),
                  Text(
                    fmtMoney(summary.usdTotal, 'USD'),
                    style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (summary.eurOnlyTotal > 0)
                    Text('+ ${fmtMoney(summary.eurOnlyTotal, 'EUR')} with no USD listing',
                        style: text.bodySmall),
                  if (summary.unpriced > 0)
                    Text('${summary.unpriced} unpriced', style: text.bodySmall),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${summary.cardCount} cards', style: text.titleMedium),
                Text('${summary.uniqueCards} unique', style: text.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
