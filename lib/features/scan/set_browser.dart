/// "I can't read the number — let me find the set by eye."
///
/// The set symbol on a card is a few millimetres of monochrome line art, and
/// the three-letter code next to it only exists on Scarlet & Violet cards.
/// This is the escape hatch: search the set list by name, year or code, see
/// the set's logo at a size that is actually legible, then pick the card out
/// of the set's own grid.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tcgdex/set_catalog.dart';
import '../../data/tcgdex/set_index_refresher.dart';
import '../../data/tcgdex/set_info.dart';
import '../../data/tcgdex/set_resolver.dart';
import '../../shared/utils/errors.dart';
import '../../shared/widgets/card_thumb.dart';
import '../../shared/widgets/error_banner.dart';

/// Pushes the browser. Returns the chosen card key, or null.
Future<String?> showSetBrowser(BuildContext context, {String? initialQuery, String lang = 'en'}) =>
    Navigator.of(context).push<String>(
      MaterialPageRoute(
          builder: (_) => _SetListPage(initialQuery: initialQuery ?? '', initialLang: lang)),
    );

class _SetListPage extends ConsumerStatefulWidget {
  const _SetListPage({required this.initialQuery, required this.initialLang});
  final String initialQuery;
  final String initialLang;

  @override
  ConsumerState<_SetListPage> createState() => _SetListPageState();
}

class _SetListPageState extends ConsumerState<_SetListPage> {
  late final _query = TextEditingController(text: widget.initialQuery);
  late String _lang = widget.initialLang;
  bool _checking = false;
  String? _checkMessage;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  /// The pull-to-refresh / "check now" path: ignores the once-a-day limit.
  Future<void> _checkNow() async {
    setState(() {
      _checking = true;
      _checkMessage = null;
    });
    final r = await ref.read(setIndexRefresherProvider).refresh(_lang, force: true);
    if (!mounted) return;
    setState(() {
      _checking = false;
      _checkMessage = switch (r.status) {
        RefreshStatus.offline => 'Could not reach TCGdex. Showing what is already known.',
        RefreshStatus.partial => 'Some new sets could not be fetched yet; will retry next launch.',
        _ when r.added.isNotEmpty =>
          'Found ${r.added.length} new set${r.added.length == 1 ? '' : 's'}: '
              '${r.added.map((s) => s.name).join(', ')}.',
        _ => 'Up to date — no new sets.',
      };
    });
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild when the background check finds something.
    ref.watch(setCatalogVersionProvider);
    final resolver = SetResolver.forLang(_lang);
    final sets = resolver.searchSets(_query.text);
    final checked = SetCatalog.instance.checkedAt(_lang);
    final text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Browse sets'),
        actions: [
          IconButton(
            tooltip: 'Check for new sets',
            onPressed: _checking ? null : _checkNow,
            icon: _checking
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.sync),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'en', label: Text('English')),
                ButtonSegment(value: 'ja', label: Text('Japanese')),
              ],
              selected: {_lang},
              onSelectionChanged: (v) => setState(() => _lang = v.single),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _query,
              autofocus: widget.initialQuery.isEmpty,
              decoration: InputDecoration(
                labelText: _lang == 'ja' ? 'Set name or code' : 'Set name, year or code',
                hintText: _lang == 'ja' ? 'M6, SV2a, 151…' : 'Evolving Skies, 2021, PAR…',
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: Text(
              _checkMessage ??
                  (checked == null
                      ? 'New sets are checked for once a day. Tap ⟳ to check now.'
                      : 'Checked for new sets ${_ago(checked)}. Tap ⟳ to check now.'),
              style: text.bodySmall,
            ),
          ),
          Expanded(
            child: sets.isEmpty
                ? const Center(child: Text('No sets match.'))
                : RefreshIndicator(
                    onRefresh: _checkNow,
                    child: ListView.builder(
                      itemCount: sets.length,
                      itemBuilder: (ctx, i) => _SetTile(
                        set: sets[i],
                        onTap: () async {
                          final id = await Navigator.of(ctx).push<String>(
                            MaterialPageRoute(builder: (_) => _SetCardsPage(set: sets[i])),
                          );
                          if (id != null && ctx.mounted) Navigator.of(ctx).pop(id);
                        },
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  static String _ago(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 2) return 'just now';
    if (d.inHours < 1) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
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
        child: RemoteIcon(
          url: set.logoUrl,
          fallback: Center(child: Icon(Icons.style_outlined, color: scheme.outline)),
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(set.name, overflow: TextOverflow.ellipsis)),
          if (set.isRecent()) ...[
            const SizedBox(width: 8),
            _NewBadge(color: scheme.primary, onColor: scheme.onPrimary),
          ],
        ],
      ),
      subtitle: Text(
        [
          ?set.serie,
          ?year,
          if (set.official > 0) '${set.official} cards' else '${set.total} cards',
          // Japanese cards print the set id itself (M6, SV2a) — that is the code.
          if (set.abbreviation != null) 'code ${set.abbreviation}'
          else if (set.lang != 'en') 'code ${set.id}',
        ].join(' · '),
        style: text.bodySmall,
      ),
      trailing: set.symbolUrl == null
          ? null
          : SizedBox(width: 28, height: 28, child: RemoteIcon(url: set.symbolUrl)),
    );
  }
}

class _NewBadge extends StatelessWidget {
  const _NewBadge({required this.color, required this.onColor});
  final Color color;
  final Color onColor;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(4)),
        child: Text('NEW',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: onColor, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
      );
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
    final setKey = (lang: widget.set.lang, id: widget.set.id);
    final async = ref.watch(setCardsProvider(setKey));
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
            onRetry: () => ref.invalidate(setCardsProvider(setKey)),
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
                speculative: !c.hasListedImage,
                name: c.name,
                // The Classic Collection has no printed set size (official 0).
                number: widget.set.official > 0 ? '${c.localId}/${widget.set.official}' : c.localId,
                onTap: () => Navigator.of(context).pop(c.key),
              );
            },
          );
        },
      ),
    );
  }
}
