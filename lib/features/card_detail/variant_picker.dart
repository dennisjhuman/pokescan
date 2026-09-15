import 'package:flutter/material.dart';

import '../../data/tcgdex/tcgdex_models.dart';

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
