import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/repositories/collection_repository.dart';
import '../../shared/utils/errors.dart';
import '../../shared/widgets/error_banner.dart';
import '../../shared/widgets/card_thumb.dart';
import '../../shared/widgets/price_change_badge.dart';
import '../card_detail/price_panel.dart';
import 'collection_summary.dart';
import 'export_csv.dart';

enum _Sort { newest, valueDesc, name, set }

class CollectionScreen extends ConsumerStatefulWidget {
  const CollectionScreen({super.key});

  @override
  ConsumerState<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends ConsumerState<CollectionScreen> {
  _Sort _sort = _Sort.set;
  String _query = '';

  Future<void> _export(List<CollectionEntry> entries) async {
    if (entries.isEmpty) {
      _tell('Nothing to export yet.');
      return;
    }
    try {
      await exportCollectionCsv(context, entries);
    } catch (e) {
      _tell(describeError(e));
    }
  }

  void _tell(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(collectionProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Collection'),
        actions: [
          PopupMenuButton<_Sort>(
            icon: const Icon(Icons.sort),
            initialValue: _sort,
            onSelected: (s) => setState(() => _sort = s),
            itemBuilder: (_) => const [
              PopupMenuItem(value: _Sort.set, child: Text('By set')),
              PopupMenuItem(value: _Sort.valueDesc, child: Text('Most valuable')),
              PopupMenuItem(value: _Sort.name, child: Text('Name')),
              PopupMenuItem(value: _Sort.newest, child: Text('Recently added')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export CSV',
            onPressed: () => _export(async.value ?? const []),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(message: describeError(e)),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(
              child: Text('Nothing here yet.\nLook up a card and tap “Add to collection”.',
                  textAlign: TextAlign.center),
            );
          }
          final filtered = _filter(entries);
          final sorted = _sorted(filtered);
          return Column(
            children: [
              CollectionSummaryBar(summary: CollectionSummary.of(entries)),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name or set',
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              Expanded(
                child: _sort == _Sort.set
                    ? _GroupedBySet(entries: sorted)
                    : ListView.builder(
                        itemCount: sorted.length,
                        itemBuilder: (_, i) => _EntryTile(entry: sorted[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<CollectionEntry> _filter(List<CollectionEntry> all) {
    if (_query.isEmpty) return all;
    return all.where((e) {
      final c = e.card;
      if (c == null) return e.item.cardId.contains(_query);
      return c.name.toLowerCase().contains(_query) ||
          c.set.name.toLowerCase().contains(_query) ||
          c.id.contains(_query);
    }).toList();
  }

  List<CollectionEntry> _sorted(List<CollectionEntry> list) {
    final out = [...list];
    switch (_sort) {
      case _Sort.newest:
        out.sort((a, b) => b.item.addedAt.compareTo(a.item.addedAt));
      case _Sort.valueDesc:
        out.sort((a, b) => (b.totalValue?.amount ?? -1).compareTo(a.totalValue?.amount ?? -1));
      case _Sort.name:
        out.sort((a, b) => (a.card?.name ?? '').compareTo(b.card?.name ?? ''));
      case _Sort.set:
        out.sort((a, b) {
          final s = (a.card?.set.name ?? '').compareTo(b.card?.set.name ?? '');
          if (s != 0) return s;
          return _numKey(a).compareTo(_numKey(b));
        });
    }
    return out;
  }

  static int _numKey(CollectionEntry e) => int.tryParse(e.card?.localId ?? '') ?? 1 << 30;
}

class _GroupedBySet extends StatelessWidget {
  const _GroupedBySet({required this.entries});
  final List<CollectionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<CollectionEntry>>{};
    for (final e in entries) {
      groups.putIfAbsent(e.card?.set.name ?? 'Unknown set', () => []).add(e);
    }
    final text = Theme.of(context).textTheme;
    return ListView(
      children: [
        for (final g in groups.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Row(
              children: [
                Expanded(child: Text(g.key, style: text.titleSmall)),
                Text(_groupTotal(g.value), style: text.bodySmall),
              ],
            ),
          ),
          for (final e in g.value) _EntryTile(entry: e),
        ],
      ],
    );
  }

  static String _groupTotal(List<CollectionEntry> es) {
    final s = CollectionSummary.of(es);
    return '${s.cardCount} · ${fmtMoney(s.usdTotal, 'USD')}';
  }
}

class _EntryTile extends ConsumerWidget {
  const _EntryTile({required this.entry});
  final CollectionEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = entry.card;
    final v = entry.totalValue;
    final img = c?.imageUrl(quality: 'low');
    return Dismissible(
      key: ValueKey(entry.item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) async {
        final repo = ref.read(collectionRepositoryProvider);
        final messenger = ScaffoldMessenger.of(context);
        final removed = await repo.removeRestorable(entry.item.id);
        if (removed == null) return;
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(SnackBar(
          content: Text('Removed ${c?.name ?? entry.item.cardId}'),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(label: 'Undo', onPressed: () => repo.restore(removed)),
        ));
      },
      child: ListTile(
        isThreeLine: true,
        // Big enough to tell two prints of the same Pokémon apart at a glance.
        leading: CardThumb(
          width: 56,
          imageUrl: img,
          name: c?.name,
          number: c?.localId,
        ),
        title: Text(c?.name ?? entry.item.cardId),
        subtitle: Text(
          '${c?.set.name ?? ''}\n'
          '${c?.numberLabel ?? ''} · ${entry.variant.label} · ${entry.item.condition}'
          '${entry.item.quantity > 1 ? ' · ×${entry.item.quantity}' : ''}',
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              v == null ? '—' : fmtMoney(v.amount, v.currency),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            PriceChangeBadge(change: entry.priceChange, dense: true),
          ],
        ),
        onTap: () => context.push('/card/${entry.item.cardId}'),
      ),
    );
  }
}
