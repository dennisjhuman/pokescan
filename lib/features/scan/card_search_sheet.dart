import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/tcgdex/tcgdex_models.dart';
import '../../shared/utils/errors.dart';
import '../../shared/widgets/error_banner.dart';

/// Name-search fallback: "we read 'Charizard' but couldn't place the set".
/// Returns the chosen card id, or null.
Future<String?> showCardSearchSheet(BuildContext context, {String initialQuery = ''}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        builder: (ctx, controller) => _SearchBody(initialQuery: initialQuery, controller: controller),
      ),
    );

class _SearchBody extends ConsumerStatefulWidget {
  const _SearchBody({required this.initialQuery, required this.controller});
  final String initialQuery;
  final ScrollController controller;

  @override
  ConsumerState<_SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends ConsumerState<_SearchBody> {
  late final _query = TextEditingController(text: widget.initialQuery);
  Future<List<CardBrief>>? _results;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery.trim().isNotEmpty) _search();
  }

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _search() {
    final q = _query.text.trim();
    if (q.length < 2) return;
    setState(() => _results = ref.read(cardRepositoryProvider).searchByName(q));
  }

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: widget.initialQuery.isEmpty,
              decoration: InputDecoration(
                labelText: 'Card name',
                suffixIcon: IconButton(icon: const Icon(Icons.search), onPressed: _search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
            ),
          ),
          Expanded(
            child: _results == null
                ? const Center(child: Text('Type a name and search.'))
                : FutureBuilder<List<CardBrief>>(
                    future: _results,
                    builder: (ctx, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snap.hasError) {
                        return Padding(
                          padding: const EdgeInsets.all(16),
                          child: ErrorBanner(message: describeError(snap.error!), onRetry: _search),
                        );
                      }
                      final cards = snap.data ?? const [];
                      if (cards.isEmpty) return const Center(child: Text('No matches.'));
                      return ListView.builder(
                        controller: widget.controller,
                        itemCount: cards.length,
                        itemBuilder: (_, i) {
                          final c = cards[i];
                          final img = c.imageUrl();
                          return ListTile(
                            leading: SizedBox(
                              width: 40,
                              child: img == null
                                  ? const Icon(Icons.image_not_supported)
                                  : CachedNetworkImage(imageUrl: img, fit: BoxFit.contain),
                            ),
                            title: Text(c.name),
                            subtitle: Text(c.id),
                            onTap: () => Navigator.of(ctx).pop(c.id),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      );
}
