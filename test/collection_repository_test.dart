import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/db/database.dart';
import 'package:pokescan/data/repositories/collection_repository.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';

String fixture(String name) => File('test/fixtures/$name.json').readAsStringSync();

void main() {
  late AppDatabase db;
  late CollectionRepository repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = CollectionRepository(db);
    await db.cardCacheDao.put('swsh3-136', fixture('swsh3-136'));
    await db.cardCacheDao.put('swsh3-20', fixture('swsh3-20'));
  });

  tearDown(() => db.close());

  group('card keys with capitals in them', () {
    // collection_items.card_id is a foreign key to cards_cache.id, and the
    // cache stores keys lower-cased. Adding by the TCGdex id as written used
    // to violate the constraint for any id with a capital letter.
    test('a SWSH promo can be added and is joined back to its card', () async {
      await db.cardCacheDao.put('swshp-swsh153', fixture('swsh3-136'));
      await repo.add(cardId: 'swshp-SWSH153', variant: CardVariant.holo);

      final entries = await repo.watchAll().firstWhere((l) => l.isNotEmpty);
      expect(entries.single.card, isNotNull);
      expect(await repo.watchForCard('swshp-SWSH153').first, hasLength(1));
    });

    test('a Japanese card is stored under its prefixed key, as Japanese', () async {
      await db.cardCacheDao.put('ja:m6-084', fixture('swsh3-136'));
      await repo.add(cardId: 'ja:M6-084', variant: CardVariant.holo);

      final entries = await repo.watchAll().firstWhere((l) => l.isNotEmpty);
      final e = entries.single;
      expect(e.item.cardId, 'ja:m6-084');
      expect(e.item.language, 'ja', reason: 'taken from the key, not a caller default');
      expect(e.card?.lang, 'ja');
    });
  });

  test('add → watchAll emits entries joined with cards, value derived', () async {
    await repo.add(cardId: 'swsh3-20', variant: CardVariant.holo, quantity: 2);
    await repo.add(cardId: 'swsh3-136', variant: CardVariant.normal, condition: 'LP');

    final entries = await repo.watchAll().firstWhere((l) => l.length == 2);
    final zard = entries.firstWhere((e) => e.item.cardId == 'swsh3-20');
    expect(zard.card?.name, 'Charizard VMAX');
    // swsh3-20's fixture has tcgplayer null, so it falls back to euros.
    expect(zard.unitValue?.currency, 'EUR');
    expect(zard.totalValue?.amount, closeTo(zard.unitValue!.amount * 2, 1e-9));

    final summary = CollectionSummary.of(entries);
    expect(summary.cardCount, 3);
    expect(summary.uniqueCards, 2);
    final furret = entries.firstWhere((e) => e.item.cardId == 'swsh3-136');
    expect(furret.unitValue?.currency, 'USD');
    expect(summary.usdTotal, closeTo(furret.totalValue!.amount, 1e-9));
    expect(summary.eurOnlyTotal, closeTo(zard.totalValue!.amount, 1e-9));
    expect(summary.unpriced, 0);
  });

  test('setQuantity 0 deletes; remove works', () async {
    final id = await repo.add(cardId: 'swsh3-136', variant: CardVariant.reverse);
    await repo.setQuantity(id, 3);
    var rows = await repo.watchForCard('swsh3-136').first;
    expect(rows.single.quantity, 3);
    await repo.setQuantity(id, 0);
    rows = await repo.watchForCard('swsh3-136').first;
    expect(rows, isEmpty);
  });

  test('FK: cannot add a card that is not cached', () async {
    expect(() => repo.add(cardId: 'nope-1', variant: CardVariant.normal), throwsA(anything));
  });

  test('a card with no USD listing lands in eurOnlyTotal, not the headline', () {
    const cm = CardmarketPricing(updated: null, trend: 4.0);
    // Cardmarket prices the card but TCGplayer has no reverse listing.
    const tp = TcgplayerPricing(updated: null, variants: {});
    final card = TcgCard(
      id: 'x-1',
      localId: '1',
      name: 'X',
      set: const SetBrief(id: 'x', name: 'X'),
      variants: const CardVariants(reverse: true),
      pricing: const CardPricing(cardmarket: cm, tcgplayer: tp),
    );
    final entry = CollectionEntry(
      item: CollectionItem(
        id: 1,
        cardId: 'x-1',
        variant: 'reverse',
        quantity: 2,
        condition: 'NM',
        language: 'en',
        addedAt: 0,
      ),
      card: card,
    );
    final s = CollectionSummary.of([entry]);
    expect(s.usdTotal, 0);
    expect(s.eurOnlyTotal, 8.0);
  });
}
