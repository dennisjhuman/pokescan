import 'package:flutter/material.dart';

import '../../data/tcgdex/tcgdex_models.dart';

/// Chips for the printings of one variant that are priced apart.
///
/// Only shown when there is a real choice to make — see
/// [CardPrintings.pricedSeparately]. The price sits on the chip because that
/// is the whole point of the question: a GameStop-stamped Dragonite is €52.90
/// against €1.05 for the plain one, and without this the app quietly showed
/// the plain one for both.
class PrintingPicker extends StatelessWidget {
  const PrintingPicker({
    super.key,
    required this.printings,
    required this.selectedKey,
    required this.onChanged,
  });

  final List<CardPrinting> printings;

  /// Null means no printing chosen, which values the card at the card-level
  /// price. Every row written before this existed is in that state.
  final String? selectedKey;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (printings.length < 2) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Which printing?', style: text.titleSmall),
        const SizedBox(height: 2),
        Text(
          'These sell as separate cards, at very different prices.',
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final p in printings)
              ChoiceChip(
                label: Text(_labelFor(p)),
                selected: p.key == selectedKey,
                onSelected: (_) => onChanged(p.key),
              ),
          ],
        ),
      ],
    );
  }

  static String _labelFor(CardPrinting p) {
    final v = p.value;
    if (v == null) return p.printingLabel;
    final amount = v.currency == 'EUR'
        ? '€${v.amount.toStringAsFixed(2)}'
        : '\$${v.amount.toStringAsFixed(2)}';
    return '${p.printingLabel}  $amount';
  }
}

/// Chips for the variants this card exists in. Hidden if only one.
class VariantPicker extends StatelessWidget {
  const VariantPicker({
    super.key,
    required this.available,
    required this.selected,
    required this.onChanged,
  });

  final List<CardVariant> available;
  final CardVariant selected;
  final ValueChanged<CardVariant> onChanged;

  @override
  Widget build(BuildContext context) {
    if (available.length <= 1) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      children: [
        for (final v in available)
          ChoiceChip(
            label: Text(v.label),
            selected: v == selected,
            onSelected: (_) => onChanged(v),
          ),
      ],
    );
  }
}
