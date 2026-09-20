/// "I can't read the number — let me find the set by eye."
///
/// The set symbol on a card is a few millimetres of monochrome line art, and
/// the three-letter code next to it only exists on Scarlet & Violet cards.
/// This is the escape hatch: search the set list by name, year or code, see
/// the set's logo at a size that is actually legible, then pick the card out
/// of the set's own grid.
library;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tcgdex/set_info.dart';
import '../../data/tcgdex/set_resolver.dart';
import '../../shared/utils/errors.dart';
import '../../shared/widgets/card_thumb.dart';
import '../../shared/widgets/error_banner.dart';

/// Pushes the browser. Returns the chosen TCGdex card id, or null.
Future<String?> showSetBrowser(BuildContext context, {String? initialQuery}) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => _SetListPage(initialQuery: initialQuery ?? '')),
    );

class _SetListPage extends StatefulWidget {
  const _SetListPage({required this.initialQuery});
  final String initialQuery;

  @override
  State<_SetListPage> createState() => _SetListPageState();
}

class _SetListPageState extends State<_SetListPage> {
  final _resolver = SetResolver();
  late final _query = TextEditingController(text: widget.initialQuery);
  late List<SetInfo> _sets = _resolver.searchSets(widget.initialQuery);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _filter(String q) => setState(() => _sets = _resolver.searchSets(q));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Browse sets')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: TextField(
                controller: _query,
                autofocus: widget.initialQuery.isEmpty,
                decoration: const InputDecoration(
                  labelText: 'Set name, year or code',
                  hintText: 'Evolving Skies, 2021, PAR…',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: _filter,
              ),
            ),
            Expanded(
              child: _sets.isEmpty
                  ? const Center(child: Text('No sets match.'))
                  : ListView.builder(
                      itemCount: _sets.length,
                      itemBuilder: (ctx, i) => _SetTile(
                        set: _sets[i],
                        onTap: () async {
                          final id = await Navigator.of(ctx).push<String>(
                            MaterialPageRoute(builder: (_) => _SetCardsPage(set: _sets[i])),
                          );
                          if (id != null && ctx.mounted) Navigator.of(ctx).pop(id);
                        },
                      ),
                    ),
            ),
          ],
        ),
      );
}

class _SetTile extends StatelessWidget {
  const _SetTile({required this.set, required this.onTap});
  final SetInfo set;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final year = set.releaseDate?.substring(0, 4);
    return ListTile(
      onTap: onTap,
      // The logo is the thing you can actually recognise; the symbol next to
      // it is what is printed on the card, so both are shown.
      leading: SizedBox(
        width: 72,
        height: 48,
        child: set.logoUrl == null
            ? Center(child: Icon(Icons.style_outlined, color: scheme.outline))
            : CachedNetworkImage(
                imageUrl: set.logoUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => Center(child: Icon(Icons.style_outlined, color: scheme.outline)),
              ),
      ),
      title: Text(set.name),
      subtitle: Text(
        [
          ?set.serie,
          ?year,
          '${set.official} cards',
          if (set.abbreviation != null) 'code ${set.abbreviation}',
        ].join(' · '),
        style: text.bodySmall,
      ),
      trailing: set.symbolUrl == null
          ? null
          : SizedBox(
              width: 28,
              height: 28,
              child: CachedNetworkImage(
                imageUrl: set.symbolUrl!,
                fit: BoxFit.contain,
                errorWidget: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
    );
  }
}

class _SetCardsPage extends ConsumerStatefulWidget {
  const _SetCardsPage({required this.set});
  final SetInfo set;

  @override
  ConsumerState<_SetCardsPage> createState() => _SetCardsPageState();
}

class _SetCardsPageState extends ConsumerState<_SetCardsPage> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(setCardsProvider(widget.set.id));
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.set.name),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                hintText: 'Filter by name or number',
                prefixIcon: Icon(Icons.filter_alt_outlined),
              ),
              onChanged: (v) => setState(() => _filter = v.trim().toLowerCase()),
            ),
          ),
        ),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorBanner(
            message: describeError(e),
            onRetry: () => ref.invalidate(setCardsProvider(widget.set.id)),
          ),
        ),
        data: (set) {
          final cards = _filter.isEmpty
              ? set.cards
              : set.cards
                  .where((c) =>
                      c.name.toLowerCase().contains(_filter) ||
                      c.localId.toLowerCase().contains(_filter))
                  .toList();
          if (cards.isEmpty) return const Center(child: Text('Nothing matches that filter.'));
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: cardGridDelegate(context),
            itemCount: cards.length,
            itemBuilder: (_, i) {
              final c = cards[i];
              return CardResultTile(
                imageUrl: c.imageUrl(),
                name: c.name,
                number: '${c.localId}/${widget.set.official}',
                onTap: () => Navigator.of(context).pop(c.id),
              );
            },
          );
        },
      ),
    );
  }
}
