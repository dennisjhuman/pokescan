/// Ways of showing "here are the cards it could be", all built on the same
/// big-artwork tile.
///
/// The old flow asked "which set symbol is this?" and showed a list of 40 px
/// symbols. Nobody can answer that from a card in their hand. These widgets
/// ask the answerable question instead — "which of these pictures is the card
/// you are holding?" — by fetching the candidates and showing the artwork.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tcgdex/set_info.dart';
import '../../data/tcgdex/set_resolver.dart';
import '../../data/tcgdex/tcgdex_models.dart';
import '../../shared/utils/errors.dart';
import '../../shared/widgets/card_thumb.dart';
import '../../shared/widgets/error_banner.dart';
import '../../data/tcgdex/reprints.dart';

/// Resolves each id and shows the ones that exist, artwork first.
///
/// Missing ids are normal: a number that fits four sets only really exists in
/// one or two of them, and quietly dropping the rest is most of the work of
/// narrowing the choice.
class CandidateCardGrid extends ConsumerWidget {
  const CandidateCardGrid({
    super.key,
    required this.ids,
    required this.onPick,
    this.emptyBuilder,
    this.shrinkWrap = false,
    this.padding = const EdgeInsets.all(12),
  });

  final List<String> ids;
  final ValueChanged<TcgCard> onPick;
  final WidgetBuilder? emptyBuilder;
  final bool shrinkWrap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final results = [for (final id in ids) ref.watch(maybeCardProvider(id))];
    final loading = results.any((r) => r.isLoading);
    final cards = [for (final r in results) r.value].nonNulls.toList();
    final error = results.map((r) => r.error).nonNulls.firstOrNull;

    if (cards.isEmpty && loading) {
      return const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (cards.isEmpty && error != null) {
      return Padding(
        padding: padding,
        child: ErrorBanner(
          message: describeError(error),
          onRetry: () {
            for (final id in ids) {
              ref.invalidate(maybeCardProvider(id));
            }
          },
        ),
      );
    }
    if (cards.isEmpty) {
      return emptyBuilder?.call(context) ??
          const Padding(padding: EdgeInsets.all(24), child: Text('No card with that number.'));
    }

    // Anniversary reprints print the original's number, so the number alone
    // finds the original. Offer the reprint next to it; the stamp decides.
    final reprints = [
      for (final c in cards) ...?ref.watch(reprintsOfProvider(c.key)).value,
    ];
    final reprintSets = {for (final r in reprints) reprintSetFor(r.set.id)}.nonNulls;
    final tiles = [
      for (final c in cards) _tileFor(c, onPick),
      for (final r in reprints) _reprintTile(r, onPick),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (cards.length > 1)
          Padding(
            padding: EdgeInsets.fromLTRB(padding.left, 4, padding.right, 0),
            child: Text(
              'That number fits ${cards.length} sets. Pick the artwork you are holding.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        for (final r in reprintSets)
          Padding(
            padding: EdgeInsets.fromLTRB(padding.left, 4, padding.right, 0),
            child: Text(
              'Also reprinted with the same number in the ${r.name}. '
              'If your card has ${r.stamp}, pick the reprint.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        GridView.builder(
          padding: padding,
          shrinkWrap: true,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          gridDelegate: cardGridDelegate(context),
          itemCount: tiles.length,
          itemBuilder: (_, i) => tiles[i],
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          ),
      ],
    );
  }

  static Widget _reprintTile(TcgCard c, ValueChanged<TcgCard> onPick) => CardResultTile(
        imageUrl: c.imageUrl(quality: 'low'),
        speculative: !c.hasListedImage,
        name: c.name,
        setName: c.set.name,
        number: c.numberLabel,
        trailingNote: 'Reprint',
        onTap: () => onPick(c),
      );

  static Widget _tileFor(TcgCard c, ValueChanged<TcgCard> onPick) => CardResultTile(
        imageUrl: c.imageUrl(quality: 'low'),
        speculative: !c.hasListedImage,
        name: c.name,
        setName: c.set.name,
        number: c.numberLabel,
        // A Japanese print and an English one can share a Pokémon and even a
        // number; the tag stops a mixed result list from being ambiguous.
        trailingNote: [if (c.lang != 'en') c.lang.toUpperCase(), ?c.rarity].join(' · '),
        onTap: () => onPick(c),
      );
}

/// Name-search results, grouped by set and newest set first.
///
/// A bare "Pikachu" search comes back with well over a hundred hits in one
/// undifferentiated list. The set a card came from is the thing that makes a
/// hit identifiable, and it is derivable offline from the id prefix, so the
/// results get split into labelled sections rather than left as a wall.
class NameResultsView extends ConsumerStatefulWidget {
  NameResultsView({
    super.key,
    required this.query,
    required this.onPick,
    this.lang = 'en',
    SetResolver? resolver,
  }) : resolver = resolver ?? SetResolver.forLang(lang);

  final String query;
  final ValueChanged<CardBrief> onPick;

  /// Which catalogue to search. Names are not cross-indexed between languages
  /// on TCGdex, so a Japanese name only finds Japanese cards and vice versa.
  final String lang;
  final SetResolver resolver;

  @override
  ConsumerState<NameResultsView> createState() => _NameResultsViewState();
}

class _NameResultsViewState extends ConsumerState<NameResultsView> {
  /// Set id the user narrowed to, or null for "all sets".
  String? _onlySet;

  @override
  void didUpdateWidget(NameResultsView old) {
    super.didUpdateWidget(old);
    if (old.query != widget.query || old.lang != widget.lang) _onlySet = null;
  }

  @override
  Widget build(BuildContext context) {
    final query = widget.query;
    final onPick = widget.onPick;
    final key = (lang: widget.lang, name: query);
    final async = ref.watch(cardSearchProvider(key));
    return async.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.all(16),
        child: ErrorBanner(
          message: describeError(e),
          onRetry: () => ref.invalidate(cardSearchProvider(key)),
        ),
      ),
      data: (cards) {
        if (cards.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Text('No cards with that name. Check the spelling, or try part of it.'),
          );
        }
        final all = groupBySet(cards, widget.resolver);
        final groups = _onlySet == null
            ? all
            : all.where((g) => g.setId == _onlySet).toList();
        return CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '${cards.length} cards across ${all.length} sets, newest first.'
                  '${all.length > 1 ? ' Tap a set to narrow it down.' : ''}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
            if (all.length > 1)
              SliverToBoxAdapter(
                child: _SetFilterBar(
                  groups: all,
                  selected: _onlySet,
                  onSelect: (id) => setState(() => _onlySet = id),
                ),
              ),
            for (final g in groups) ...[
              SliverToBoxAdapter(child: _SetHeading(group: g)),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                sliver: SliverGrid.builder(
                  gridDelegate: cardGridDelegate(context),
                  itemCount: g.cards.length,
                  itemBuilder: (_, i) {
                    final c = g.cards[i];
                    return CardResultTile(
                      imageUrl: c.imageUrl(),
                      speculative: !c.hasListedImage,
                      name: c.name,
                      setName: g.set?.name ?? g.setId,
                      number: g.set == null || g.set!.official == 0
                          ? c.localId
                          : '${c.localId}/${g.set!.official}',
                      onTap: () => onPick(c),
                    );
                  },
                ),
              ),
            ],
          ],
        );
      },
    );
  }

}

/// Horizontal chips, one per set the search hit, so a 240-result "Pikachu"
/// becomes a handful of cards in one click.
class _SetFilterBar extends StatelessWidget {
  const _SetFilterBar({required this.groups, required this.selected, required this.onSelect});

  final List<SetGroup> groups;
  final String? selected;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) => SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                label: const Text('All sets'),
                selected: selected == null,
                onSelected: (_) => onSelect(null),
              ),
            ),
            for (final g in groups)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text('${g.set?.name ?? g.setId} (${g.cards.length})'),
                  selected: selected == g.setId,
                  onSelected: (_) => onSelect(g.setId),
                ),
              ),
          ],
        ),
      );
}

/// Split briefs by the set in their id, newest set first. Top-level and pure
/// so the grouping can be unit-tested without building a widget.
List<SetGroup> groupBySet(List<CardBrief> cards, SetResolver resolver) {
  final bySet = <String, List<CardBrief>>{};
  for (final c in cards) {
    final dash = c.id.lastIndexOf('-');
    final setId = dash <= 0 ? c.id : c.id.substring(0, dash);
    bySet.putIfAbsent(setId, () => []).add(c);
  }
  final groups = [
    for (final e in bySet.entries) SetGroup(e.key, resolver.byId(e.key), e.value),
  ];
  // Undated sets sort last rather than first: an empty string would beat a
  // real date under a plain descending compare.
  groups.sort((a, b) => (b.set?.releaseDate ?? '').compareTo(a.set?.releaseDate ?? ''));
  return groups;
}

class SetGroup {
  const SetGroup(this.setId, this.set, this.cards);
  final String setId;
  final SetInfo? set;
  final List<CardBrief> cards;
}

class _SetHeading extends StatelessWidget {
  const _SetHeading({required this.group});
  final SetGroup group;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final s = group.set;
    final year = s?.releaseDate?.substring(0, 4);
    final sub = [
      ?s?.serie,
      ?year,
      ?s?.abbreviation,
      '${group.cards.length} match${group.cards.length == 1 ? '' : 'es'}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s?.name ?? group.setId, style: text.titleSmall),
          Text(sub, style: text.labelSmall?.copyWith(color: scheme.outline)),
        ],
      ),
    );
  }
}
