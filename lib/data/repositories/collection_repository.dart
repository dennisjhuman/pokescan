import 'dart:async';
import 'dart:convert';

import 'package:drift/drift.dart';

import '../db/database.dart';
import '../tcgdex/price_change.dart';
import '../tcgdex/tcgdex_models.dart';

/// A collection row joined with its cached card, plus derived value.
/// Nothing computed is stored; value is derived here at read time.
class CollectionEntry {
  const CollectionEntry({required this.item, required this.card, this.previousCard});

  final CollectionItem item;

  /// Null only if the cache row vanished (shouldn't happen; FK protects it).
  final TcgCard? card;

  /// The response this card's cache row replaced, if it has been refreshed at
  /// least once. Drives the price-change badge.
  final TcgCard? previousCard;

  /// Movement since the previous refresh, or null if not comparable.
  PriceChange? get priceChange =>
      PriceChange.between(previousCard: previousCard, currentCard: card, variant: variant);

  CardVariant get variant => CardVariant.tryParse(item.variant) ?? CardVariant.normal;

  /// Price of one copy in the chosen variant.
  Price? get unitValue => card?.pricing?.valueFor(variant);

  /// Price × quantity, same currency as [unitValue].
  Price? get totalValue {
    final u = unitValue;
    return u == null ? null : Price(u.amount * item.quantity, u.currency, source: u.source);
  }
}

/// Totals for the whole collection. EUR is primary; anything only priced in
/// USD is summed separately rather than converted with a made-up rate.
class CollectionSummary {
  const CollectionSummary({
    required this.cardCount,
    required this.uniqueCards,
    required this.usdTotal,
    required this.eurOnlyTotal,
    required this.unpriced,
  });

  final int cardCount;
  final int uniqueCards;
  /// Sum of everything priced in USD (TCGplayer), the primary figure.
  final double usdTotal;

  /// Sum of the cards TCGplayer does not list, which fall back to Cardmarket
  /// euros. Kept apart rather than converted — there is no rate here, and
  /// mixing the two would invent precision.
  final double eurOnlyTotal;
  final int unpriced;

  static CollectionSummary of(List<CollectionEntry> entries) {
    var eur = 0.0, usd = 0.0, unpriced = 0, count = 0;
    final ids = <String>{};
    for (final e in entries) {
      count += e.item.quantity;
      ids.add(e.item.cardId);
      final v = e.totalValue;
      if (v == null) {
        unpriced += e.item.quantity;
      } else if (v.currency == 'EUR') {
        eur += v.amount;
      } else {
        usd += v.amount;
      }
    }
    return CollectionSummary(
      cardCount: count,
      uniqueCards: ids.length,
      usdTotal: usd,
      eurOnlyTotal: eur,
      unpriced: unpriced,
    );
  }
}

class CollectionRepository {
  CollectionRepository(this._db);

  final AppDatabase _db;

  /// Live view of the whole collection with cards attached.
  Stream<List<CollectionEntry>> watchAll() {
    final items = _db.collectionDao.watchAll();
    final cache = _db.cardCacheDao.watchAll();
    // Combine the two streams by hand (no rxdart): re-emit whenever either
    // changes. Drift streams are broadcast + replay latest, so this is cheap.
    return _combine(items, cache);
  }

  Stream<List<CollectionItem>> watchForCard(String cardId) =>
      _db.collectionDao.watchForCard(cardId);

  Future<int> add({
    required String cardId,
    required CardVariant variant,
    int quantity = 1,
    String condition = 'NM',
    String language = 'en',
    String? notes,
    double? pricePaid,
  }) =>
      _db.collectionDao.insert(CollectionItemsCompanion.insert(
        cardId: cardId,
        variant: variant.name,
        quantity: Value(quantity),
        condition: Value(condition),
        language: Value(language),
        notes: Value(notes),
        pricePaid: Value(pricePaid),
        addedAt: DateTime.now().millisecondsSinceEpoch,
      ));

  Future<void> update(CollectionItem item) => _db.collectionDao.updateItem(item);

  Future<void> remove(int id) => _db.collectionDao.deleteById(id);

  /// Delete a row but hand back everything needed to put it back, so a
  /// mistaken swipe is recoverable. The restored row keeps its original
  /// `addedAt` rather than jumping to the top of "recently added".
  Future<CollectionItem?> removeRestorable(int id) async {
    final existing = await _db.collectionDao.getById(id);
    if (existing == null) return null;
    await _db.collectionDao.deleteById(id);
    return existing;
  }

  /// Put back a row removed by [removeRestorable]. A new id is assigned;
  /// everything the user typed is preserved.
  Future<void> restore(CollectionItem item) => _db.collectionDao.insert(
        CollectionItemsCompanion.insert(
          cardId: item.cardId,
          variant: item.variant,
          quantity: Value(item.quantity),
          condition: Value(item.condition),
          language: Value(item.language),
          scanPath: Value(item.scanPath),
          notes: Value(item.notes),
          acquiredAt: Value(item.acquiredAt),
          pricePaid: Value(item.pricePaid),
          addedAt: item.addedAt,
        ),
      );

  Future<void> setQuantity(int id, int quantity) =>
      quantity <= 0 ? remove(id) : _db.collectionDao.setQuantity(id, quantity);

  static Stream<List<CollectionEntry>> _combine(
    Stream<List<CollectionItem>> items,
    Stream<List<CardsCacheData>> cache,
  ) async* {
    List<CollectionItem>? latestItems;
    Map<String, TcgCard>? latestCards;
    final parsed = <String, TcgCard>{};
    final parsedJson = <String, String>{};
    final parsedPrevious = <String, TcgCard>{};
    final parsedPreviousJson = <String, String>{};

    await for (final event in _merge(items, cache)) {
      if (event is List<CollectionItem>) {
        latestItems = event;
      } else if (event is List<CardsCacheData>) {
        for (final row in event) {
          if (parsedJson[row.id] != row.json) {
            parsedJson[row.id] = row.json;
            parsed[row.id] = TcgCard.fromJson(jsonDecode(row.json) as Map<String, dynamic>);
          }
          final prev = row.previousJson;
          if (prev == null) {
            parsedPreviousJson.remove(row.id);
            parsedPrevious.remove(row.id);
          } else if (parsedPreviousJson[row.id] != prev) {
            parsedPreviousJson[row.id] = prev;
            parsedPrevious[row.id] = TcgCard.fromJson(jsonDecode(prev) as Map<String, dynamic>);
          }
        }
        latestCards = parsed;
      }
      if (latestItems != null && latestCards != null) {
        final cards = latestCards;
        yield [
          for (final it in latestItems)
            CollectionEntry(
              item: it,
              card: cards[it.cardId],
              previousCard: parsedPrevious[it.cardId],
            ),
        ];
      }
    }
  }

  static Stream<Object> _merge(Stream<Object> a, Stream<Object> b) {
    late StreamController<Object> c;
    StreamSubscription<Object>? sa, sb;
    c = StreamController<Object>(
      onListen: () {
        sa = a.listen(c.add, onError: c.addError);
        sb = b.listen(c.add, onError: c.addError);
      },
      onCancel: () async {
        await sa?.cancel();
        await sb?.cancel();
      },
    );
    return c.stream;
  }
}
