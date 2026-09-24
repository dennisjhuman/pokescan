import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/database.dart';
import '../../data/providers.dart';
import '../../data/tcgdex/tcgdex_models.dart';
import 'variant_picker.dart';

const kConditions = ['NM', 'LP', 'MP', 'HP', 'DMG'];

/// Add a new row, or edit an existing one when [existing] is given.
Future<void> showAddToCollectionSheet(
  BuildContext context, {
  required TcgCard card,
  required CardVariant variant,
  String? printingKey,
  CollectionItem? existing,
}) =>
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
        child: _AddForm(
            card: card, variant: variant, printingKey: printingKey, existing: existing),
      ),
    );

class _AddForm extends ConsumerStatefulWidget {
  const _AddForm(
      {required this.card, required this.variant, this.printingKey, this.existing});
  final TcgCard card;
  final CardVariant variant;
  final String? printingKey;
  final CollectionItem? existing;

  @override
  ConsumerState<_AddForm> createState() => _AddFormState();
}

class _AddFormState extends ConsumerState<_AddForm> {
  late CardVariant _variant = widget.existing == null
      ? widget.variant
      : (CardVariant.tryParse(widget.existing!.variant) ?? widget.variant);
  late String? _printingKey = widget.existing?.printingKey ?? widget.printingKey;
  late int _qty = widget.existing?.quantity ?? 1;

  /// Printings of the chosen variant that are priced apart, or none.
  List<CardPrinting> get _printings => widget.card.printings.pricedSeparately(_variant);

  late String _condition = widget.existing?.condition ?? 'NM';
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late final _paid = TextEditingController(
      text: widget.existing?.pricePaid == null ? '' : widget.existing!.pricePaid.toString());

  @override
  void dispose() {
    _notes.dispose();
    _paid.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final repo = ref.read(collectionRepositoryProvider);
    final paid = double.tryParse(_paid.text.replaceAll(',', '.').trim());
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final ex = widget.existing;
    if (ex == null) {
      await repo.add(
        cardId: widget.card.key,
        variant: _variant,
        printingKey: _printingKey,
        quantity: _qty,
        condition: _condition,
        notes: notes,
        pricePaid: paid,
      );
    } else {
      await repo.update(ex.copyWith(
        variant: _variant.name,
        printingKey: Value(_printingKey),
        quantity: _qty,
        condition: _condition,
        notes: Value(notes),
        pricePaid: Value(paid),
      ));
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final available = widget.card.variants.available;
    final variants = available.contains(_variant) ? available : [...available, _variant];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.existing == null ? 'Add to collection' : 'Edit', style: text.titleLarge),
        Text(widget.card.name, style: text.bodyMedium),
        const SizedBox(height: 12),
        if (variants.length > 1)
          Wrap(
            spacing: 8,
            children: [
              for (final v in variants)
                ChoiceChip(
                  label: Text(v.label),
                  selected: v == _variant,
                  // The printing belongs to the old variant; keeping it would
                  // price the row as something it is not.
                  onSelected: (_) => setState(() {
                    _variant = v;
                    _printingKey = null;
                  }),
                ),
            ],
          ),
        if (_printings.length > 1) ...[
          const SizedBox(height: 12),
          PrintingPicker(
            printings: _printings,
            selectedKey: _printingKey,
            onChanged: (k) => setState(() => _printingKey = k),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Text('Quantity', style: text.bodyLarge),
            const Spacer(),
            IconButton(
              onPressed: _qty > 1 ? () => setState(() => _qty--) : null,
              icon: const Icon(Icons.remove_circle_outline),
            ),
            Text('$_qty', style: text.titleMedium),
            IconButton(
              onPressed: () => setState(() => _qty++),
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        Row(
          children: [
            Text('Condition', style: text.bodyLarge),
            const Spacer(),
            SegmentedButton<String>(
              segments: [for (final c in kConditions) ButtonSegment(value: c, label: Text(c))],
              selected: {_condition},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _condition = s.first),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _paid,
          decoration: const InputDecoration(labelText: 'Price paid (optional)', prefixText: '€ '),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          decoration: const InputDecoration(labelText: 'Notes (optional)'),
          maxLines: 2,
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _save, child: Text(widget.existing == null ? 'Add' : 'Save')),
      ],
    );
  }
}
