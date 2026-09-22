/// One box for finding a card.
///
/// It replaces the three-field number / total / set-code form, which asked the
/// user to know which of the things printed on the card was the set code. On a
/// real card that is anyone's guess: the lone letter is a regulation mark, the
/// three letters next to it might be the set or might be the language, and
/// promos print neither. So: type whatever is printed, and let the app work
/// out what it was — see [CardQueryParser].
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/providers.dart';
import '../../data/tcgdex/card_key.dart';
import '../../data/tcgdex/card_query.dart';
import '../../data/tcgdex/set_catalog.dart';
import '../../data/tcgdex/set_info.dart';
import 'card_results.dart';
import 'set_browser.dart';

class FindCardView extends ConsumerStatefulWidget {
  const FindCardView({super.key, this.initialQuery = '', this.onPicked});

  final String initialQuery;

  /// Called with the chosen card id. Defaults to navigating to the card.
  final ValueChanged<String>? onPicked;

  /// Opens the finder as a sheet and returns the chosen card id, or null if
  /// it was dismissed. The scan flow uses this so the scan can be tied to
  /// whichever card the user settles on.
  static Future<String?> pick(BuildContext context, {String initialQuery = ''}) =>
      showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.92,
          builder: (ctx, _) => FindCardView(
            initialQuery: initialQuery,
            onPicked: (id) => Navigator.of(ctx).pop(id),
          ),
        ),
      );

  /// Same sheet, for callers that only want to navigate to the card.
  static Future<void> showAsSheet(BuildContext context, {String initialQuery = ''}) async {
    final id = await pick(context, initialQuery: initialQuery);
    if (id != null && context.mounted) context.push(cardPath(id));
  }

  @override
  ConsumerState<FindCardView> createState() => _FindCardViewState();
}

class _FindCardViewState extends ConsumerState<FindCardView> {
  var _parser = CardQueryParser();
  int? _catalogVersion;
  late final _controller = TextEditingController(text: widget.initialQuery);
  late CardQuery _query = _parser.parse(widget.initialQuery);

  /// The parser snapshots the set catalogue when built. When the background
  /// check finds a new set, rebuild it and re-read what is in the box, so a
  /// number that did not resolve a moment ago now does.
  void _syncCatalog(int version) {
    if (_catalogVersion == version) return;
    final first = _catalogVersion == null;
    _catalogVersion = version;
    if (first) return;
    _parser = CardQueryParser();
    _query = _parser.parse(_query.raw);
  }
  Timer? _debounce;
  bool _showHelp = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _submit([String? text]) {
    _debounce?.cancel();
    FocusScope.of(context).unfocus();
    setState(() => _query = _parser.parse(text ?? _controller.text));
  }

  /// Search as you type. A number resolves locally and only fetches the two
  /// or three ids it narrowed to, so the cost is small; a name waits for a
  /// pause and for enough letters to be worth a request.
  void _onChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      final q = _parser.parse(text);
      if (q.kind == CardQueryKind.name && (q.name ?? '').trim().length < 3) return;
      setState(() => _query = q);
    });
  }

  void _runExample(String text) {
    _controller.text = text;
    _submit(text);
  }

  void _pick(String cardId) {
    final cb = widget.onPicked;
    if (cb != null) {
      cb(cardId);
    } else {
      context.push(cardPath(cardId));
    }
  }

  Future<void> _browse({String? query, String? lang}) async {
    final id = await showSetBrowser(context,
        initialQuery: query ?? _query.setCode ?? '', lang: lang ?? _query.preferredLang);
    if (id != null && mounted) _pick(id);
  }

  @override
  Widget build(BuildContext context) {
    _syncCatalog(ref.watch(setCatalogVersionProvider).value ?? 0);
    return _body();
  }

  Widget _body() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _controller,
              autofocus: widget.initialQuery.isEmpty,
              autocorrect: false,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                labelText: 'Number, set code, or name',
                hintText: '185/182 · SWSH153 · PAR 185 · Charizard',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'What do I type?',
                  icon: Icon(_showHelp ? Icons.help : Icons.help_outline),
                  onPressed: () => setState(() => _showHelp = !_showHelp),
                ),
              ),
              onChanged: _onChanged,
              onSubmitted: _submit,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _browse(),
                    icon: const Icon(Icons.style_outlined),
                    label: const Text('Browse sets'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _submit(),
                    icon: const Icon(Icons.search),
                    label: const Text('Find'),
                  ),
                ),
              ],
            ),
          ),
          if (_showHelp) _HelpPanel(onExample: _runExample),
          Expanded(child: _results()),
        ],
      );

  Widget _results() {
    final q = _query;
    switch (q.kind) {
      case CardQueryKind.empty:
        return _Tips(
          onExample: _runExample,
          onSet: (set) => _browse(query: set.name, lang: set.lang),
        );

      case CardQueryKind.name:
        // Kana or kanji search the Japanese catalogue; TCGdex does not
        // cross-index names, so an English name never finds a Japanese print.
        // No unknown-code panel here: in a name query every word is a
        // leftover, so it would fire on "Pikachu".
        final lang = q.japanese ? 'ja' : 'en';
        return NameResultsView(
          query: q.name!,
          lang: lang,
          resolver: _parser.resolverFor(lang),
          onPick: (c) => _pick(c.key),
        );

      case CardQueryKind.cardId:
      case CardQueryKind.number:
        final ids = _parser.candidateIds(q);
        if (ids.isEmpty) return _NoCandidates(query: q, parser: _parser, onBrowse: () => _browse());
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _ReadBack(query: q, sets: _parser.candidateSets(q)),
            if (!q.likelyJapanese && q.leftovers.isNotEmpty)
              _UnknownCode(code: q.leftovers.first, parser: _parser),
            CandidateCardGrid(
              ids: ids,
              shrinkWrap: true,
              onPick: (c) => _pick(c.key),
              emptyBuilder: (_) =>
                  _NoCandidates(query: q, parser: _parser, onBrowse: () => _browse()),
            ),
          ],
        );
    }
  }
}

/// Says out loud what the app made of the text, so a misread is obvious
/// before the user starts doubting the card.
class _ReadBack extends StatelessWidget {
  const _ReadBack({required this.query, required this.sets});
  final CardQuery query;
  final List<SetInfo> sets;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final bits = <String>[
      if (query.number != null) 'number ${query.number}',
      if (query.total != null) 'of ${query.total}',
      if (query.setCode != null) 'set ${query.setCode}',
      if (query.regulationMark != null) 'regulation mark ${query.regulationMark}',
    ];
    final secret = query.total != null &&
        int.tryParse(query.number ?? '') != null &&
        int.parse(query.number!) > query.total!;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Read as ${bits.join(', ')}.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          if (secret)
            Text(
              'Numbered above the set size — that is a secret / illustration rare, '
              'not a mistake.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
          if (sets.length == 1)
            Text(
              'Only ${sets.single.name}${sets.single.lang == 'ja' ? ' (Japanese)' : ''} fits.',
              style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
            ),
        ],
      ),
    );
  }
}

class _NoCandidates extends StatelessWidget {
  const _NoCandidates({required this.query, required this.parser, required this.onBrowse});
  final CardQuery query;
  final CardQueryParser parser;
  final VoidCallback onBrowse;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final product = CardQueryParser.untrackedProducts[query.untracked];
    if (product != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('${query.untracked} is $product.', style: text.titleSmall),
          const SizedBox(height: 6),
          Text(
            'TCGdex, the free card database this app uses, does not list that '
            'product, so these cards cannot be identified or priced here. The '
            'number after the slash matches a different set, which is why it is '
            'not shown.',
            style: text.bodyMedium,
          ),
        ],
      );
    }
    final why = switch (query) {
      CardQuery(setCode: final c?) => 'No card $c ${query.number ?? ''} in that set.',
      CardQuery(total: null) =>
        'A number on its own does not say which set it is from. Add the number '
            'after the slash (185/182), or the three-letter set code if the card prints one.',
      _ => 'No set has ${query.total} cards. The number after the slash is the set '
          'size — check it against the card, or browse the sets below.',
    };
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(why, style: text.bodyMedium),
        if (query.likelyJapanese) ...[const SizedBox(height: 12), const _JapaneseNotice()],
        if (!query.likelyJapanese && query.leftovers.isNotEmpty) ...[
          const SizedBox(height: 12),
          _UnknownCode(code: query.leftovers.first, parser: parser),
        ],
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: onBrowse,
          icon: const Icon(Icons.style_outlined),
          label: const Text('Find it by set instead'),
        ),
      ],
    );
  }
}

/// An unrecognised code is the single most common dead end, so it gets a
/// named explanation and near-misses rather than a shrug.
class _UnknownCode extends StatelessWidget {
  const _UnknownCode({required this.code, required this.parser});
  final String code;
  final CardQueryParser parser;

  @override
  Widget build(BuildContext context) {
    final near = parser.resolver.didYouMean(code);
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('"$code" is not a set code we know.', style: text.titleSmall),
            Text(
              'On most cards the letters next to the number are the regulation '
              'mark or the language, not the set. Only Scarlet & Violet cards '
              'print a real three-letter set code.',
              style: text.bodySmall,
            ),
            if (near.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Closest sets:', style: text.labelMedium),
              Wrap(
                spacing: 6,
                children: [
                  for (final s in near)
                    Chip(
                      label: Text('${s.abbreviation ?? s.id} · ${s.name}'),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Shown only when a Japanese-looking card could not be placed. Japanese sets
/// resolve normally now; the usual reason for this is a set released since the
/// last check, which the ⟳ in the set browser fixes.
class _JapaneseNotice extends StatelessWidget {
  const _JapaneseNotice();

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'That looks like a Japanese card, but no Japanese set matches. Japanese '
            'cards print the set code on its own (M6, SV2a) just left of the number '
            '— check it, or open Browse sets → Japanese and tap ⟳ in case the set '
            'is brand new.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
}

/// The six shapes the bottom of a card actually comes in. Every row is a card
/// that was hard to look up in testing; tapping one runs it.
class _HelpPanel extends StatelessWidget {
  const _HelpPanel({required this.onExample});
  final ValueChanged<String> onExample;

  static const _rows = <(String, String)>[
    ('185/182', 'Number and set size. Above the size = secret rare, that is fine.'),
    ('E 123/203', 'The lone letter is the regulation mark, not the set. Type it or skip it.'),
    ('PAR EN 185/182', 'Scarlet & Violet prints a real set code. EN is the language.'),
    ('SVP 194', 'Promo: no set size at all, the code carries it.'),
    ('SWSH153', 'Promo with the code glued to the number.'),
    ('M6 084/076', 'Japanese: the set code sits alone next to the number. RR/AR after it is the rarity.'),
    ('swsh3-20', 'A TCGdex id, if you already know it.'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Type what is printed along the bottom edge', style: text.titleSmall),
            const SizedBox(height: 6),
            for (final (example, meaning) in _rows)
              InkWell(
                onTap: () => onExample(example),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 110,
                        child: Text(example,
                            style: text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                fontFeatures: const [FontFeature.tabularFigures()])),
                      ),
                      Expanded(child: Text(meaning, style: text.bodySmall)),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 4),
            Text('No luck? "Browse sets" lets you find it by the set logo instead.',
                style: text.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Tips extends ConsumerWidget {
  const _Tips({required this.onExample, required this.onSet});
  final ValueChanged<String> onExample;
  final ValueChanged<SetInfo> onSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    ref.watch(setCatalogVersionProvider);
    final recent = [
      ...SetCatalog.instance.recent('en').take(4),
      ...SetCatalog.instance.recent('ja').take(2),
    ];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Find a card', style: text.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Type the number from the bottom edge of the card, the name, or both. '
          'The set code, the language and the regulation mark are all sorted out '
          'for you — you do not have to know which is which.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text('Try one:', style: text.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          children: [
            for (final e in ['185/182', 'SWSH153', 'SVP 194', 'M6 084/076', 'Charizard'])
              ActionChip(label: Text(e), onPressed: () => onExample(e)),
          ],
        ),
        if (recent.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text('New sets', style: text.labelLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in recent)
                ActionChip(
                  avatar: const Icon(Icons.fiber_new_outlined, size: 18),
                  label: Text('${s.name}${s.lang == 'ja' ? ' (JP)' : ''}'),
                  onPressed: () => onSet(s),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
