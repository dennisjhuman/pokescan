import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../data/tcgdex/set_resolver.dart';
import '../../shared/widgets/error_banner.dart';
import 'set_picker_sheet.dart';

/// Type what is printed on the card: number and total (bottom-left,
/// e.g. `020/189`), optionally the set code (`PAR` on newer cards, or a
/// TCGdex id like `swsh3`). Resolves to `/card/{setId}-{number}`.
///
/// Usable standalone (Phase 1 Scan tab) or inside a bottom sheet (Phase 3).
class ManualEntryForm extends StatefulWidget {
  const ManualEntryForm({super.key, this.resolver});

  final SetResolver? resolver;

  static Future<void> showAsSheet(BuildContext context) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 16),
          child: const ManualEntryForm(),
        ),
      );

  @override
  State<ManualEntryForm> createState() => _ManualEntryFormState();
}

class _ManualEntryFormState extends State<ManualEntryForm> {
  late final SetResolver _resolver = widget.resolver ?? SetResolver();
  final _number = TextEditingController();
  final _total = TextEditingController();
  final _code = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _error;

  @override
  void dispose() {
    _number.dispose();
    _total.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) return;
    final number = SetResolver.normaliseNumber(_number.text);
    final total = int.tryParse(_total.text.trim());
    final code = _code.text.trim();

    if (code.isEmpty && total == null) {
      setState(() => _error = 'Need either the total (after the slash) or a set code.');
      return;
    }
    if (number.contains('/')) {
      setState(() => _error = 'Put the part after the slash in the Total box.');
      return;
    }
    final candidates = _resolver.resolve(number: number, total: total, code: code);
    if (candidates.isEmpty) {
      setState(() => _error = code.isNotEmpty
          ? 'Unknown set code "$code". Try the TCGdex id (e.g. swsh3) or leave it blank and enter the total.'
          : 'No set with $total cards. Double-check the number after the slash.');
      return;
    }
    final set = candidates.length == 1 ? candidates.first : await showSetPicker(context, candidates);
    if (set == null || !mounted) return;
    FocusScope.of(context).unfocus();
    context.push('/card/${set.cardIdFor(number)}');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Look up a card', style: text.titleLarge),
          const SizedBox(height: 4),
          Text(
            'Bottom-left of the card: number / total, e.g. 020 / 189. '
            'Newer cards also print a 3-letter set code (PAR, OBF) — enter it if you see one.',
            style: text.bodySmall,
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextFormField(
                  controller: _number,
                  decoration: const InputDecoration(labelText: 'Number', hintText: '020'),
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return 'Required';
                    if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(t)) return 'Letters/digits only';
                    return null;
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Text('/', style: TextStyle(fontSize: 28, height: 1.7)),
              ),
              Expanded(
                child: TextFormField(
                  controller: _total,
                  decoration: const InputDecoration(labelText: 'Total', hintText: '189'),
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  validator: (v) {
                    final t = (v ?? '').trim();
                    if (t.isEmpty) return null;
                    if (int.tryParse(t) == null) return 'Digits only';
                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _code,
            decoration: const InputDecoration(
              labelText: 'Set code (optional)',
              hintText: 'PAR, DAA, or swsh3',
            ),
            textInputAction: TextInputAction.done,
            autocorrect: false,
            onFieldSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.search),
            label: const Text('Find card'),
          ),
        ],
      ),
    );
  }
}
