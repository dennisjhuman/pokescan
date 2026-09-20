import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/db/database.dart';
import '../../data/tcgdex/price_change.dart';
import '../../data/tcgdex/set_resolver.dart';
import '../../data/tcgdex/tcgdex_models.dart';
import '../../shared/utils/errors.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/card_thumb.dart';
import '../../shared/widgets/price_change_badge.dart';
import '../scan/scan_outcome.dart';
import 'add_to_collection_sheet.dart';
import 'fake_signals.dart';
import 'fake_signals_panel.dart';
import 'price_panel.dart';
import 'variant_picker.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  const CardDetailScreen({super.key, required this.cardId});
  final String cardId;

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  CardVariant? _variant;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(cardProvider(widget.cardId));
    final owned = ref.watch(collectionForCardProvider(widget.cardId)).value ?? const [];
    final card = async.value;
    // Only apply a scan to the card it was actually opened as.
    final lastScan = ref.watch(lastScanProvider);
    final scan = lastScan?.resolvedCardId == widget.cardId ? lastScan : null;
    final variant = _variant ?? card?.variants.defaultVariant ?? CardVariant.normal;
    return Scaffold(
      appBar: AppBar(title: Text(card?.name ?? widget.cardId)),
      floatingActionButton: card == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => showAddToCollectionSheet(context, card: card, variant: variant),
              icon: const Icon(Icons.add),
              label: Text(owned.isEmpty ? 'Add to collection' : 'Add another'),
            ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: describeError(e),
            onRetry: () => ref.invalidate(cardProvider(widget.cardId)),
          ),
        ),
        data: (card) => RefreshIndicator(
          onRefresh: () async {
            await ref.read(cardRepositoryProvider).getCard(widget.cardId, forceRefresh: true);
            ref.invalidate(cardProvider(widget.cardId));
          },
          child: _Body(
            card: card,
            variant: variant,
            owned: owned,
            scan: scan,
            onVariant: (v) => setState(() => _variant = v),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({
    required this.card,
    required this.variant,
    required this.owned,
    required this.scan,
    required this.onVariant,
  });
  final TcgCard card;
  final CardVariant variant;
  final List<CollectionItem> owned;
  final ScanOutcome? scan;
  final ValueChanged<CardVariant> onVariant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final img = card.imageUrl();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        if (owned.isNotEmpty) ...[
          Text('In your collection', style: text.titleSmall),
          for (final it in owned)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: Text(
                '${(CardVariant.tryParse(it.variant) ?? CardVariant.normal).label}'
                ' · ${it.condition}${it.quantity > 1 ? ' · ×${it.quantity}' : ''}',
              ),
              subtitle: it.notes == null ? null : Text(it.notes!),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: () => showAddToCollectionSheet(context,
                        card: card, variant: variant, existing: it),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => ref.read(collectionRepositoryProvider).remove(it.id),
                  ),
                ],
              ),
            ),
          const Divider(),
        ],
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 360),
            child: CardThumb(
              imageUrl: img,
              name: card.name,
              number: card.numberLabel,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(card.name, style: text.headlineSmall),
        const SizedBox(height: 4),
        Row(
          children: [
            if (card.set.symbolUrl() != null)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: SizedBox(
                  height: 18,
                  width: 18,
                  child: RemoteIcon(url: card.set.symbolUrl()),
                ),
              ),
            Expanded(
              child: Text(
                '${card.set.name} · ${card.numberLabel}'
                '${card.rarity != null ? ' · ${card.rarity}' : ''}',
                style: text.bodyMedium,
              ),
            ),
          ],
        ),
        if (card.hp != null || card.types.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              [
                if (card.hp != null) 'HP ${card.hp}',
                ...card.types,
                if (card.stage != null) card.stage!,
              ].join(' · '),
              style: text.bodySmall,
            ),
          ),
        const SizedBox(height: 16),
        VariantPicker(
          available: card.variants.available,
          selected: variant,
          onChanged: onVariant,
        ),
        const SizedBox(height: 16),
        _PriceSince(cardId: card.id, card: card, variant: variant),
        PricePanel(pricing: card.pricing, variant: variant),
        const SizedBox(height: 24),
        _SignalsSection(card: card, scan: scan),
        const SizedBox(height: 24),
        if (card.attacks.isNotEmpty) ...[
          Text('Attacks', style: text.titleSmall),
          for (final a in card.attacks)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text('${a.name}${a.damage != null ? '  ${a.damage}' : ''}'),
              subtitle: a.effect == null ? null : Text(a.effect!),
              leading: Text(a.cost.map((c) => c[0]).join(), style: text.labelLarge),
            ),
        ],
        const SizedBox(height: 8),
        Text(
          'TCGdex id: ${card.id}'
          '${card.illustrator != null ? ' · Illus. ${card.illustrator}' : ''}',
          style: text.bodySmall,
        ),
      ],
    );
  }
}


/// Builds the "Things to check" panel. The colour comparison needs the
/// official image's saturation, which is fetched lazily and is often
/// unavailable (blocked by CORS on web), so the panel renders without it
/// rather than waiting.
class _SignalsSection extends ConsumerWidget {
  const _SignalsSection({required this.card, required this.scan});

  final TcgCard card;
  final ScanOutcome? scan;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final referenceUrl = card.imageUrl();
    double? delta;
    final cropSaturation = scan?.cropSaturation;
    if (cropSaturation != null && referenceUrl != null) {
      final reference = ref.watch(referenceSaturationProvider(referenceUrl)).value;
      if (reference != null) delta = cropSaturation - reference;
    }

    final signals = FakeSignals.evaluate(
      card: card,
      scan: scan?.parsed,
      set: SetResolver().byCode(card.set.id),
      saturationDelta: delta,
    );

    return FakeSignalsPanel(signals: signals, scan: scan, referenceUrl: referenceUrl);
  }
}


/// Price movement since the previous refresh, above the price tables.
/// Renders nothing until the card has been refreshed at least once.
class _PriceSince extends ConsumerWidget {
  const _PriceSince({required this.cardId, required this.card, required this.variant});

  final String cardId;
  final TcgCard card;
  final CardVariant variant;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final previous = ref.watch(previousCardProvider(cardId)).value;
    final change = PriceChange.between(
      previousCard: previous,
      currentCard: card,
      variant: variant,
    );
    if (change == null || !change.isSignificant) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          PriceChangeBadge(change: change),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'since the last refresh',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
