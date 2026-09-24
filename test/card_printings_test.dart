import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';

/// A card is not one product. Measured against the live API 2026-09-24:
///
/// | Card                    | plain  | stamped                  |
/// |-------------------------|--------|--------------------------|
/// | swsh12-131 Dragonite    | €1.05  | €52.90 GameStop, €56 EB  |
/// | me01-001 Bulbasaur rev. | €0.08  | €5.49 30th PokéDay       |
/// | svp-057 Chi-Yu          | €3.23  | €41.60 staff             |
///
/// The card-level `pricing` block is only ever one of those — normally the
/// plain one — so a stamped card read 10–70× under.
void main() {
  // ignore_for_file: use_null_aware_elements
  Map<String, dynamic> printing({
    String type = 'holo',
    String? subtype,
    List<String>? stamp,
    String? variantId,
    int? cardmarket,
    double? trend,
  }) =>
      {
        'type': type,
        'size': 'standard',
        if (subtype != null) 'subtype': subtype,
        if (stamp != null) 'stamp': stamp,
        if (variantId != null) 'variantId': variantId,
        if (cardmarket != null) 'thirdParty': {'cardmarket': cardmarket},
        if (trend != null)
          'pricing': {
            'cardmarket': {'unit': 'EUR', 'trend': trend, 'avg': trend},
          },
      };

  TcgCard card(List<Map<String, dynamic>> printings, {Map<String, dynamic>? pricing}) =>
      TcgCard.fromJson({
        'id': 'swsh12-131',
        'localId': '131',
        'name': 'Dragonite',
        'set': {'id': 'swsh12', 'name': 'Silver Tempest'},
        'variants': {'holo': true, 'reverse': true},
        'variants_detailed': printings,
        if (pricing != null) 'pricing': pricing,
      });

  group('parsing', () {
    test('a card with no variants_detailed has no printings', () {
      expect(card(const []).printings.all, isEmpty);
    });

    test('type, subtype, stamp and product id are read', () {
      final c = card([
        printing(subtype: 'shadowless', stamp: ['1st-edition'], cardmarket: 660224, trend: 3330.71),
      ]);
      final p = c.printings.all.single;
      expect(p.type, CardVariant.holo);
      expect(p.subtype, 'shadowless');
      expect(p.stamp, ['1st-edition']);
      expect(p.cardmarketProductId, 660224);
      expect(p.value?.amount, 3330.71);
    });

    test('the hyphenated types map onto our enum', () {
      expect(card([printing(type: '1st-edition')]).printings.all.single.type,
          CardVariant.firstEdition);
      expect(card([printing(type: 'w-promo')]).printings.all.single.type, CardVariant.wPromo);
    });
  });

  group('identity', () {
    test('TCGdex\'s own id is the key when it has one', () {
      expect(card([printing(variantId: 'jr7oetx1mqug9')]).printings.all.single.key,
          'jr7oetx1mqug9');
    });

    test('"generated" is not an identity, so the printing describes itself', () {
      // TCGdex sends the literal "generated" for printings it inferred, and
      // it is the same string on every such card.
      final c = card([
        printing(variantId: 'generated', stamp: ['gamestop']),
        printing(variantId: 'generated', stamp: ['eb-games']),
      ]);
      final keys = c.printings.all.map((p) => p.key).toList();
      expect(keys, ['holo+gamestop', 'holo+eb-games']);
      expect(keys.toSet().length, 2, reason: 'two printings must not collide');
    });
  });

  group('pricedSeparately — when to even ask the question', () {
    test('one printing is no choice', () {
      final c = card([printing(cardmarket: 1, trend: 1.05)]);
      expect(c.printings.pricedSeparately(CardVariant.holo), isEmpty);
    });

    test('normal and reverse sharing one Cardmarket product is no choice', () {
      // Measured on sv10-001, sv04-042, swsh9-020: the ordinary pair is a
      // single Cardmarket product at a single price. Offering a pick there
      // would be noise pretending to be information.
      final c = card([
        printing(type: 'normal', cardmarket: 825875, trend: 0.03),
        printing(type: 'reverse', cardmarket: 825875, trend: 0.03),
      ]);
      expect(c.printings.pricedSeparately(CardVariant.normal), isEmpty);
      expect(c.printings.pricedSeparately(CardVariant.reverse), isEmpty);
    });

    test('distinct products for one variant is a real choice', () {
      final c = card([
        printing(cardmarket: 682178, trend: 1.05),
        printing(stamp: ['gamestop'], cardmarket: 742041, trend: 52.9),
        printing(stamp: ['eb-games'], cardmarket: 884419, trend: 56),
      ]);
      expect(c.printings.pricedSeparately(CardVariant.holo), hasLength(3));
      // …and only for the variant they belong to.
      expect(c.printings.pricedSeparately(CardVariant.reverse), isEmpty);
    });
  });

  group('valueFor', () {
    final c = card(
      [
        printing(variantId: 'plain', cardmarket: 682178, trend: 1.05),
        printing(variantId: 'gs', stamp: ['gamestop'], cardmarket: 742041, trend: 52.9),
      ],
      pricing: {
        'cardmarket': {'unit': 'EUR', 'trend': 1.05, 'avg': 1.05},
      },
    );

    test('no printing chosen prices the card exactly as it always did', () {
      expect(c.valueFor(CardVariant.holo)?.amount, 1.05);
    });

    test('a chosen printing prices itself', () {
      expect(c.valueFor(CardVariant.holo, printingKey: 'gs')?.amount, 52.9);
    });

    test('an unknown key falls back rather than showing nothing', () {
      // A row written before a set was re-cut, say. Better the old number
      // than a dash.
      expect(c.valueFor(CardVariant.holo, printingKey: 'no-such')?.amount, 1.05);
    });

    test('a printing TCGdex prices at nothing falls back too', () {
      final d = card(
        [printing(variantId: 'bare', cardmarket: 1)],
        pricing: {
          'cardmarket': {'unit': 'EUR', 'trend': 9.99},
        },
      );
      expect(d.valueFor(CardVariant.holo, printingKey: 'bare')?.amount, 9.99);
    });
  });

  group('labels', () {
    test('a plain printing says so rather than being blank', () {
      expect(card([printing()]).printings.all.single.printingLabel, 'Plain');
    });

    test('stamps and subtypes are named the way they are written on the card', () {
      final c = card([
        printing(stamp: ['gamestop']),
        printing(stamp: ['eb-games']),
        printing(subtype: 'shadowless', stamp: ['1st-edition']),
        printing(stamp: ['set-logo', 'staff']),
        printing(stamp: ['30th-pokeday']),
      ]);
      final labels = c.printings.all.map((p) => p.printingLabel).toList();
      expect(labels, [
        'GameStop stamp',
        'EB Games stamp',
        'Shadowless, 1st Edition stamp',
        'Set logo, Staff stamp',
        '30th PokéDay stamp',
      ]);
    });

    test('an unknown stamp is still readable', () {
      expect(card([printing(stamp: ['some-new-promo'])]).printings.all.single.printingLabel,
          'Some New Promo stamp');
    });

    test('the full label carries the variant too', () {
      expect(card([printing(stamp: ['gamestop'])]).printings.all.single.label,
          'Holo · GameStop stamp');
    });
  });

  test('survives a card cached before variants_detailed existed', () {
    final old = jsonDecode(jsonEncode({
      'id': 'swsh3-20',
      'localId': '20',
      'name': 'Furret',
      'set': {'id': 'swsh3', 'name': 'Darkness Ablaze'},
      'variants': {'holo': true},
    })) as Map<String, dynamic>;
    final c = TcgCard.fromJson(old);
    expect(c.printings.all, isEmpty);
    expect(c.valueFor(CardVariant.holo, printingKey: 'anything'), isNull);
  });
}
