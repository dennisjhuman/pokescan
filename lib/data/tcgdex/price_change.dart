/// Price movement between the two most recent cached responses for a card.
///
/// Pure Dart and unit-tested. The cache keeps one step of history
/// (`cards_cache.previous_json`), which is all the badge needs.
library;

import 'tcgdex_models.dart';

class PriceChange {
  const PriceChange({required this.previous, required this.current});

  final Price previous;
  final Price current;

  /// Signed fraction, so 0.25 is a 25% rise and -0.1 a 10% fall.
  double get fraction => (current.amount - previous.amount) / previous.amount;

  double get delta => current.amount - previous.amount;
  bool get isRise => delta > 0;

  /// The threshold from CLAUDE.md Phase 5.
  static const significantFraction = 0.10;

  bool get isSignificant => fraction.abs() >= significantFraction;

  /// "+25%" / "-12%".
  String get label {
    final pct = (fraction * 100).round();
    return '${pct > 0 ? '+' : ''}$pct%';
  }

  /// Null unless both snapshots price the same variant in the same currency
  /// and the earlier price was non-zero.
  ///
  /// Cross-currency is deliberately not compared: a card whose Cardmarket
  /// entry disappears and falls back to TCGplayer would otherwise read as a
  /// huge move when nothing actually happened.
  static PriceChange? between({
    required TcgCard? previousCard,
    required TcgCard? currentCard,
    required CardVariant variant,
  }) {
    final before = previousCard?.pricing?.valueFor(variant);
    final after = currentCard?.pricing?.valueFor(variant);
    if (before == null || after == null) return null;
    if (before.currency != after.currency) return null;
    if (before.amount == 0) return null;
    return PriceChange(previous: before, current: after);
  }
}
