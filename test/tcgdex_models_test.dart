import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';

Map<String, dynamic> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  group('TcgCard.fromJson', () {
    test('parses swsh3-136 (Furret, normal + reverse, both price sources)', () {
      final c = TcgCard.fromJson(fixture('swsh3-136'));
      expect(c.id, 'swsh3-136');
      expect(c.name, 'Furret');
      expect(c.localId, '136');
      expect(c.set.id, 'swsh3');
      expect(c.set.name, 'Darkness Ablaze');
      expect(c.set.cardCount?.official, 189);
      expect(c.numberLabel, '136/189');
      expect(c.hp, 110);
      expect(c.rarity, 'Uncommon');
      expect(c.variants.available, [CardVariant.normal, CardVariant.reverse]);
      expect(c.variants.defaultVariant, CardVariant.normal);
      expect(c.imageUrl(), 'https://assets.tcgdex.net/en/swsh/swsh3/136/high.webp');
      expect(c.imageUrl(quality: 'low'), 'https://assets.tcgdex.net/en/swsh/swsh3/136/low.webp');
      expect(c.attacks.map((a) => a.name), ["Feelin' Fine", 'Tail Smash']);
      expect(c.attacks[1].damage, '90');
    });

    test('parses swsh3-20 (Charizard VMAX, holo only, tcgplayer null)', () {
      final c = TcgCard.fromJson(fixture('swsh3-20'));
      expect(c.name, 'Charizard VMAX');
      expect(c.variants.available, [CardVariant.holo]);
      expect(c.variants.defaultVariant, CardVariant.holo);
      expect(c.pricing?.tcgplayer, isNull);
      expect(c.pricing?.cardmarket?.trendHolo, isNotNull);
      expect(c.pricing?.cardmarket?.avgHolo, isNull, reason: 'null in API → null, not 0');
    });

    test('tolerates a minimal card', () {
      final c = TcgCard.fromJson({
        'id': 'x-1',
        'localId': '1',
        'name': 'Thing',
        'set': {'id': 'x', 'name': 'X'},
      });
      expect(c.variants.available, [CardVariant.normal]);
      expect(c.pricing, isNull);
      expect(c.numberLabel, '1');
      expect(c.imageUrl(), isNull);
    });
  });

  group('CardPricing', () {
    test('tcgplayer variants keyed by hyphenated names', () {
      final p = TcgCard.fromJson(fixture('swsh3-136')).pricing!;
      expect(p.tcgplayer!.variants.keys, containsAll(['normal', 'reverse-holofoil']));
      expect(p.tcgplayer!.forVariant(CardVariant.reverse)?.market, isNotNull);
      expect(p.tcgplayer!.forVariant(CardVariant.holo), isNull);
    });

    test('valueFor: normal prefers the tcgplayer market price for that variant', () {
      final p = TcgCard.fromJson(fixture('swsh3-136')).pricing!;
      final v = p.valueFor(CardVariant.normal)!;
      expect(v.currency, 'USD');
      expect(v.amount, p.tcgplayer!.forVariant(CardVariant.normal)!.market);
      expect(v.source, 'tcgplayer.normal.market');
      expect(v.estimate, isFalse);
    });

    test('valueFor: the two variants of one card get different prices', () {
      // The whole point of leading with TCGplayer: Cardmarket quotes one
      // figure per card, so normal and reverse would read identically.
      final p = TcgCard.fromJson(fixture('swsh3-136')).pricing!;
      final normal = p.valueFor(CardVariant.normal)!;
      final reverse = p.valueFor(CardVariant.reverse)!;
      expect(normal.amount, isNot(reverse.amount));
    });

    test('valueFor: falls back to cardmarket, flagged as an estimate', () {
      // swsh3-20 is one of the cards TCGdex returns with tcgplayer null.
      final p = TcgCard.fromJson(fixture('swsh3-20')).pricing!;
      final v = p.valueFor(CardVariant.holo)!;
      expect(v.currency, 'EUR');
      expect(v.amount, p.cardmarket!.trendHolo);
      expect(v.source, 'cardmarket.trend-holo');
      expect(v.estimate, isTrue);
    });

    test('valueFor: reverse uses tcgplayer reverse-holofoil market', () {
      final p = TcgCard.fromJson(fixture('swsh3-136')).pricing!;
      final v = p.valueFor(CardVariant.reverse)!;
      expect(v.currency, 'USD');
      expect(v.source, 'tcgplayer.reverse-holofoil.market');
      expect(v.estimate, isFalse);
    });

    test('a published zero is absent, not free', () {
      // TCGdex answers `trend-holo: 0` on promos that have never had a holo
      // sale. Taking it literally showed a real card as worth nothing.
      final p = CardPricing.fromJson(const {
        'cardmarket': {'updated': null, 'trend-holo': 0, 'trend': 0, 'avg': 1.96},
      });
      expect(p.cardmarket!.trendHolo, isNull);
      expect(p.cardmarket!.trend, isNull);
      final v = p.valueFor(CardVariant.holo)!;
      expect(v.amount, 1.96);
      expect(v.source, 'cardmarket.avg');
    });

    test('valueFor: fallback chain market → mid → low → cardmarket', () {
      const withMarket = CardPricing(
        cardmarket: CardmarketPricing(updated: null, avg: 1.5),
        tcgplayer: TcgplayerPricing(updated: null, variants: {
          'normal': TcgplayerVariantPricing(market: 2.0),
        }),
      );
      expect(withMarket.valueFor(CardVariant.normal)!.amount, 2.0);

      // A brand-new set has asking prices but no market price yet.
      const noMarket = CardPricing(
        tcgplayer: TcgplayerPricing(updated: null, variants: {
          'normal': TcgplayerVariantPricing(mid: 3.0, low: 1.0),
        }),
      );
      final mid = noMarket.valueFor(CardVariant.normal)!;
      expect(mid.amount, 3.0);
      expect(mid.estimate, isTrue);

      // Nothing on TCGplayer at all: euros, clearly marked.
      const cmOnly = CardPricing(cardmarket: CardmarketPricing(updated: null, avg: 1.5));
      final eur = cmOnly.valueFor(CardVariant.normal)!;
      expect(eur.amount, 1.5);
      expect(eur.currency, 'EUR');
      expect(eur.estimate, isTrue);

      expect(const CardPricing().valueFor(CardVariant.normal), isNull);
    });
  });

  group('CardBrief', () {
    test('parses search results', () {
      final list = jsonDecode(File('test/fixtures/search-charizard-swsh3.json').readAsStringSync()) as List;
      final cards = list.cast<Map<String, dynamic>>().map(CardBrief.fromJson).toList();
      expect(cards.map((c) => c.id), contains('swsh3-20'));
      expect(cards.first.imageUrl(), endsWith('/low.webp'));
    });
  });
}
