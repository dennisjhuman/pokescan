import 'package:flutter/material.dart';

import '../../data/tcgdex/tcgdex_models.dart';

String fmtMoney(double? v, String unit) {
  if (v == null) return '—';
  final s = v.toStringAsFixed(2);
  return unit == 'EUR' ? '€$s' : '\$$s';
}

/// TCGplayer (USD) + Cardmarket (EUR) tables, plus the headline "value"
/// for the selected variant.
///
/// TCGplayer leads because its prices are per variant; Cardmarket's are one
/// blob per card, so they read as a rough European estimate. See
/// [CardPricing.valueFor].
class PricePanel extends StatelessWidget {
  const PricePanel({super.key, required this.pricing, required this.variant});

  final CardPricing? pricing;
  final CardVariant variant;

  @override
  Widget build(BuildContext context) {
    final p = pricing;
    final text = Theme.of(context).textTheme;
    if (p == null || (p.cardmarket == null && p.tcgplayer == null)) {
      return Text('No pricing data for this card.', style: text.bodyMedium);
    }
    final value = p.valueFor(variant);
    final cm = p.cardmarket;
    final tp = p.tcgplayer;
    final tpv = tp?.forVariant(variant);
    final holo = variant == CardVariant.holo || variant == CardVariant.firstEdition;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              value == null ? '—' : fmtMoney(value.amount, value.currency),
              style: text.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 8),
            if (value != null)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${variant.label} · ${value.source}'
                    '${value.estimate ? ' · estimate' : ''}',
                    style: text.bodySmall,
                  ),
                ),
              ),
          ],
        ),
        if (value != null && value.estimate) ...[
          const SizedBox(height: 4),
          Text(
            value.currency == 'EUR'
                ? 'No TCGplayer listing for this variant, so this is the Cardmarket '
                    'figure for the card as a whole — it does not separate holo, '
                    'reverse and plain copies. Treat it as a ballpark.'
                : 'No market price published yet, so this is the mid/low asking price.',
            style: text.bodySmall?.copyWith(fontStyle: FontStyle.italic),
          ),
        ],
        const SizedBox(height: 12),
        if (tp != null) ...[
          _Header('TCGplayer (USD)', tp.updated),
          if (tpv == null)
            Text('No ${variant.label.toLowerCase()} listing.', style: text.bodySmall)
          else
            _Table(rows: [
              ('Market', fmtMoney(tpv.market, 'USD')),
              ('Low', fmtMoney(tpv.low, 'USD')),
              ('Mid', fmtMoney(tpv.mid, 'USD')),
              ('High', fmtMoney(tpv.high, 'USD')),
            ]),
          const SizedBox(height: 12),
        ],
        if (cm != null) ...[
          _Header('Cardmarket (EUR, whole card)', cm.updated),
          _Table(rows: [
            ('Trend', fmtMoney(holo ? (cm.trendHolo ?? cm.trend) : cm.trend, 'EUR')),
            ('Avg', fmtMoney(holo ? (cm.avgHolo ?? cm.avg) : cm.avg, 'EUR')),
            ('Low', fmtMoney(holo ? (cm.lowHolo ?? cm.low) : cm.low, 'EUR')),
            ('Avg 7d', fmtMoney(holo ? (cm.avg7Holo ?? cm.avg7) : cm.avg7, 'EUR')),
            ('Avg 30d', fmtMoney(holo ? (cm.avg30Holo ?? cm.avg30) : cm.avg30, 'EUR')),
          ]),
        ],
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.updated);
  final String title;
  final String? updated;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final date = updated?.split('T').first;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Text(title, style: text.titleSmall),
          const Spacer(),
          if (date != null) Text('updated $date', style: text.bodySmall),
        ],
      ),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows});
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => Table(
        columnWidths: const {0: FlexColumnWidth(2), 1: FlexColumnWidth(1)},
        children: [
          for (final (label, value) in rows)
            TableRow(children: [
              Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: Text(label)),
              Text(value, textAlign: TextAlign.right,
                  style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
            ]),
        ],
      );
}
