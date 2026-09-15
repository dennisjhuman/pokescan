import 'package:flutter/material.dart';

import '../../data/tcgdex/price_change.dart';

/// "+25%" pill, shown only when the move clears the 10% threshold.
///
/// Green for a rise, red for a fall, which reads as value rather than as
/// alarm: this is a collection, not a portfolio.
class PriceChangeBadge extends StatelessWidget {
  const PriceChangeBadge({super.key, required this.change, this.dense = false});

  final PriceChange? change;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final c = change;
    if (c == null || !c.isSignificant) return const SizedBox.shrink();

    final dark = Theme.of(context).brightness == Brightness.dark;
    final rise = c.isRise;
    final fg = rise
        ? (dark ? const Color(0xFF7BE0A5) : const Color(0xFF1B6B3A))
        : (dark ? const Color(0xFFFF9D9D) : const Color(0xFFB3261E));
    final bg = fg.withValues(alpha: dark ? 0.18 : 0.12);

    return Tooltip(
      message: 'Since the last price refresh',
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: dense ? 5 : 7, vertical: dense ? 1 : 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(rise ? Icons.arrow_upward : Icons.arrow_downward,
                size: dense ? 10 : 12, color: fg),
            const SizedBox(width: 2),
            Text(
              c.label,
              style: TextStyle(
                color: fg,
                fontSize: dense ? 10 : 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
