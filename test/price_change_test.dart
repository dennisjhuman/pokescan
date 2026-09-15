import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/price_change.dart';
import 'package:pokescan/data/tcgdex/tcgdex_models.dart';

TcgCard cardWith({double? cmTrend, double? tpMarket, String id = 'swsh3-136'}) =>
    TcgCard.fromJson({
      'id': id,
      'localId': '136',
      'name': 'Furret',
      'set': {'id': 'swsh3', 'name': 'Darkness Ablaze'},
      'variants': {'normal': true, 'reverse': true},
      'pricing': {
        if (cmTrend != null) 'cardmarket': {'unit': 'EUR', 'trend': cmTrend},
        if (tpMarket != null)
          'tcgplayer': {
            'unit': 'USD',
            'reverse-holofoil': {'marketPrice': tpMarket},
          },
      },
    });

void main() {
  group('between', () {
    test('a rise past the threshold is significant', () {
      final c = PriceChange.between(
        previousCard: cardWith(cmTrend: 1.00),
        currentCard: cardWith(cmTrend: 1.50),
        variant: CardVariant.normal,
      )!;
      expect(c.fraction, closeTo(0.5, 1e-9));
      expect(c.isRise, isTrue);
      expect(c.isSignificant, isTrue);
      expect(c.label, '+50%');
    });

    test('a fall is negative and labelled', () {
      final c = PriceChange.between(
        previousCard: cardWith(cmTrend: 2.00),
        currentCard: cardWith(cmTrend: 1.50),
        variant: CardVariant.normal,
      )!;
      expect(c.isRise, isFalse);
      expect(c.label, '-25%');
      expect(c.isSignificant, isTrue);
    });

    test('a move under 10% is not significant', () {
      final c = PriceChange.between(
        previousCard: cardWith(cmTrend: 1.00),
        currentCard: cardWith(cmTrend: 1.09),
        variant: CardVariant.normal,
      )!;
      expect(c.isSignificant, isFalse);
    });

    test('exactly 10% counts', () {
      final c = PriceChange.between(
        previousCard: cardWith(cmTrend: 1.00),
        currentCard: cardWith(cmTrend: 1.10),
        variant: CardVariant.normal,
      )!;
      expect(c.isSignificant, isTrue);
    });

    test('no previous snapshot means no change', () {
      expect(
        PriceChange.between(
          previousCard: null,
          currentCard: cardWith(cmTrend: 1.0),
          variant: CardVariant.normal,
        ),
        isNull,
      );
    });

    test('an unpriced side means no change', () {
      expect(
        PriceChange.between(
          previousCard: cardWith(),
          currentCard: cardWith(cmTrend: 1.0),
          variant: CardVariant.normal,
        ),
        isNull,
      );
    });

    test('a currency switch is not reported as a move', () {
      // Cardmarket data disappears and the value falls back to TCGplayer.
      final before = cardWith(cmTrend: 1.00, tpMarket: 9.0);
      final after = cardWith(tpMarket: 9.0);
      expect(
        PriceChange.between(
          previousCard: before,
          currentCard: after,
          variant: CardVariant.normal,
        ),
        isNull,
      );
    });

    test('a zero earlier price is not divided by', () {
      expect(
        PriceChange.between(
          previousCard: cardWith(cmTrend: 0),
          currentCard: cardWith(cmTrend: 5),
          variant: CardVariant.normal,
        ),
        isNull,
      );
    });

    test('the comparison follows the chosen variant', () {
      final before = cardWith(cmTrend: 1.00, tpMarket: 10.0);
      final after = cardWith(cmTrend: 1.00, tpMarket: 20.0);
      expect(
        PriceChange.between(
                previousCard: before, currentCard: after, variant: CardVariant.normal)!
            .isSignificant,
        isFalse,
        reason: 'normal reads Cardmarket, which did not move',
      );
      final reverse = PriceChange.between(
          previousCard: before, currentCard: after, variant: CardVariant.reverse)!;
      expect(reverse.currencyMatches, isTrue);
      expect(reverse.label, '+100%');
    });
  });
}

extension on PriceChange {
  bool get currencyMatches => previous.currency == current.currency;
}
