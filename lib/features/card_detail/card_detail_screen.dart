import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../data/providers.dart';
import '../../data/tcgdex/tcgdex_models.dart';
import '../../data/db/database.dart';
import '../../shared/utils/errors.dart';
import '../../shared/widgets/error_banner.dart';
import 'add_to_collection_sheet.dart';
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
    required this.onVariant,
  });
  final TcgCard card;
  final CardVariant variant;
  final List<CollectionItem> owned;
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
            child: AspectRatio(
              aspectRatio: AppConstants.cardAspectRatio,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: img == null
                    ? const ColoredBox(color: Colors.black12, child: Icon(Icons.image_not_supported))
                    : CachedNetworkImage(
                        imageUrl: img,
                        fit: BoxFit.contain,
                        placeholder: (_, _) => const Center(child: CircularProgressIndicator()),
                        errorWidget: (_, _, _) => const Icon(Icons.broken_image),
                      ),
              ),
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
                child: CachedNetworkImage(
                  imageUrl: card.set.symbolUrl()!,
                  height: 18,
                  errorWidget: (_, _, _) => const SizedBox.shrink(),
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
        PricePanel(pricing: card.pricing, variant: variant),
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
