/// Models for the TCGdex v2 REST API.
///
/// Hand-written `fromJson` rather than codegen: the pricing shape has
/// hyphenated keys and variant-keyed maps that json_serializable handles
/// awkwardly, and Phase 1 has no other generated code. Shapes verified
/// against the live API on 2026-09-14 (see CLAUDE.md).
library;

/// Card variants as TCGdex names them.
enum CardVariant {
  normal,
  holo,
  reverse,
  firstEdition,
  wPromo;

  String get label => switch (this) {
        normal => 'Normal',
        holo => 'Holo',
        reverse => 'Reverse holo',
        firstEdition => '1st edition',
        wPromo => 'W promo',
      };

  static CardVariant? tryParse(String s) {
    for (final v in values) {
      if (v.name == s) return v;
    }
    return null;
  }
}

/// A single price with its currency.
class Price {
  const Price(this.amount, this.currency, {this.source});
  final double amount;
  final String currency; // "EUR" | "USD"
  final String? source; // e.g. "cardmarket.trend"

  @override
  String toString() => '$amount $currency';
}

class CardmarketPricing {
  const CardmarketPricing({
    required this.updated,
    this.avg,
    this.low,
    this.trend,
    this.avg1,
    this.avg7,
    this.avg30,
    this.avgHolo,
    this.lowHolo,
    this.trendHolo,
    this.avg1Holo,
    this.avg7Holo,
    this.avg30Holo,
  });

  final String? updated;
  final double? avg;
  final double? low;
  final double? trend;
  final double? avg1;
  final double? avg7;
  final double? avg30;
  final double? avgHolo;
  final double? lowHolo;
  final double? trendHolo;
  final double? avg1Holo;
  final double? avg7Holo;
  final double? avg30Holo;

  static const unit = 'EUR';

  factory CardmarketPricing.fromJson(Map<String, dynamic> j) => CardmarketPricing(
        updated: j['updated'] as String?,
        avg: _d(j['avg']),
        low: _d(j['low']),
        trend: _d(j['trend']),
        avg1: _d(j['avg1']),
        avg7: _d(j['avg7']),
        avg30: _d(j['avg30']),
        avgHolo: _d(j['avg-holo']),
        lowHolo: _d(j['low-holo']),
        trendHolo: _d(j['trend-holo']),
        avg1Holo: _d(j['avg1-holo']),
        avg7Holo: _d(j['avg7-holo']),
        avg30Holo: _d(j['avg30-holo']),
      );
}

class TcgplayerVariantPricing {
  const TcgplayerVariantPricing({
    this.low,
    this.mid,
    this.high,
    this.market,
    this.directLow,
  });

  final double? low;
  final double? mid;
  final double? high;
  final double? market;
  final double? directLow;

  factory TcgplayerVariantPricing.fromJson(Map<String, dynamic> j) => TcgplayerVariantPricing(
        low: _d(j['lowPrice']),
        mid: _d(j['midPrice']),
        high: _d(j['highPrice']),
        market: _d(j['marketPrice']),
        directLow: _d(j['directLowPrice']),
      );
}

class TcgplayerPricing {
  const TcgplayerPricing({required this.updated, required this.variants});

  final String? updated;

  /// Keyed by TCGplayer variant name: `normal`, `holofoil`,
  /// `reverse-holofoil`, `1st-edition`, `1st-edition-holofoil`, `unlimited`…
  final Map<String, TcgplayerVariantPricing> variants;

  static const unit = 'USD';

  factory TcgplayerPricing.fromJson(Map<String, dynamic> j) {
    final variants = <String, TcgplayerVariantPricing>{};
    for (final e in j.entries) {
      if (e.key == 'unit' || e.key == 'updated') continue;
      if (e.value is Map<String, dynamic>) {
        variants[e.key] = TcgplayerVariantPricing.fromJson(e.value as Map<String, dynamic>);
      }
    }
    return TcgplayerPricing(updated: j['updated'] as String?, variants: variants);
  }

  /// Map our variant enum to TCGplayer's key(s), most specific first.
  static List<String> keysFor(CardVariant v) => switch (v) {
        CardVariant.normal => ['normal', 'unlimited'],
        CardVariant.holo => ['holofoil', 'unlimited-holofoil'],
        CardVariant.reverse => ['reverse-holofoil'],
        CardVariant.firstEdition => ['1st-edition-holofoil', '1st-edition'],
        CardVariant.wPromo => ['normal', 'holofoil'],
      };

  TcgplayerVariantPricing? forVariant(CardVariant v) {
    for (final k in keysFor(v)) {
      final p = variants[k];
      if (p != null) return p;
    }
    return null;
  }
}

class CardPricing {
  const CardPricing({this.cardmarket, this.tcgplayer});

  final CardmarketPricing? cardmarket;
  final TcgplayerPricing? tcgplayer;

  factory CardPricing.fromJson(Map<String, dynamic> j) => CardPricing(
        cardmarket: j['cardmarket'] is Map<String, dynamic>
            ? CardmarketPricing.fromJson(j['cardmarket'] as Map<String, dynamic>)
            : null,
        tcgplayer: j['tcgplayer'] is Map<String, dynamic>
            ? TcgplayerPricing.fromJson(j['tcgplayer'] as Map<String, dynamic>)
            : null,
      );

  /// The "value" of one copy in [variant], per CLAUDE.md:
  /// Cardmarket trend → Cardmarket avg → TCGplayer market. Holo variants
  /// prefer the `-holo` Cardmarket fields. Reverse has no Cardmarket field,
  /// so it goes straight to TCGplayer's reverse-holofoil, then the base price.
  Price? valueFor(CardVariant variant) {
    final cm = cardmarket;
    final tp = tcgplayer?.forVariant(variant);

    Price? eur(double? v, String src) =>
        v == null ? null : Price(v, CardmarketPricing.unit, source: 'cardmarket.$src');
    Price? usd(double? v, String src) =>
        v == null ? null : Price(v, TcgplayerPricing.unit, source: 'tcgplayer.$src');

    switch (variant) {
      case CardVariant.holo:
      case CardVariant.firstEdition:
        return eur(cm?.trendHolo, 'trend-holo') ??
            eur(cm?.avgHolo, 'avg-holo') ??
            eur(cm?.trend, 'trend') ??
            eur(cm?.avg, 'avg') ??
            usd(tp?.market, 'market');
      case CardVariant.reverse:
        return usd(tp?.market, 'reverse-holofoil.market') ??
            eur(cm?.trend, 'trend') ??
            eur(cm?.avg, 'avg');
      case CardVariant.normal:
      case CardVariant.wPromo:
        return eur(cm?.trend, 'trend') ?? eur(cm?.avg, 'avg') ?? usd(tp?.market, 'market');
    }
  }
}

/// Which variants exist for a card.
class CardVariants {
  const CardVariants({
    this.normal = false,
    this.holo = false,
    this.reverse = false,
    this.firstEdition = false,
    this.wPromo = false,
  });

  final bool normal, holo, reverse, firstEdition, wPromo;

  factory CardVariants.fromJson(Map<String, dynamic> j) => CardVariants(
        normal: j['normal'] == true,
        holo: j['holo'] == true,
        reverse: j['reverse'] == true,
        firstEdition: j['firstEdition'] == true,
        wPromo: j['wPromo'] == true,
      );

  List<CardVariant> get available => [
        if (normal) CardVariant.normal,
        if (holo) CardVariant.holo,
        if (reverse) CardVariant.reverse,
        if (firstEdition) CardVariant.firstEdition,
        if (wPromo) CardVariant.wPromo,
      ];

  /// Sensible default: the first available, else normal.
  CardVariant get defaultVariant => available.isEmpty ? CardVariant.normal : available.first;
}

class SetCardCount {
  const SetCardCount({required this.official, required this.total});
  final int official;
  final int total;

  factory SetCardCount.fromJson(Map<String, dynamic> j) => SetCardCount(
        official: (j['official'] as num?)?.toInt() ?? 0,
        total: (j['total'] as num?)?.toInt() ?? 0,
      );
}

/// Set as embedded in a card, or as an entry in `GET /sets`.
class SetBrief {
  const SetBrief({
    required this.id,
    required this.name,
    this.logo,
    this.symbol,
    this.cardCount,
  });

  final String id;
  final String name;
  final String? logo;
  final String? symbol;
  final SetCardCount? cardCount;

  factory SetBrief.fromJson(Map<String, dynamic> j) => SetBrief(
        id: j['id'] as String,
        name: j['name'] as String? ?? j['id'] as String,
        logo: j['logo'] as String?,
        symbol: j['symbol'] as String?,
        cardCount: j['cardCount'] is Map<String, dynamic>
            ? SetCardCount.fromJson(j['cardCount'] as Map<String, dynamic>)
            : null,
      );

  String? logoUrl({String ext = 'webp'}) => logo == null ? null : '$logo.$ext';
  String? symbolUrl({String ext = 'webp'}) => symbol == null ? null : '$symbol.$ext';
}

/// Brief card as returned by `GET /cards?name=` and inside `GET /sets/{id}`.
class CardBrief {
  const CardBrief({required this.id, required this.localId, required this.name, this.image});

  final String id;
  final String localId;
  final String name;
  final String? image;

  factory CardBrief.fromJson(Map<String, dynamic> j) => CardBrief(
        id: j['id'] as String,
        localId: j['localId']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        image: j['image'] as String?,
      );

  String? imageUrl({String quality = 'low', String ext = 'webp'}) =>
      image == null ? null : '$image/$quality.$ext';
}

class Attack {
  const Attack({required this.name, this.cost = const [], this.effect, this.damage});
  final String name;
  final List<String> cost;
  final String? effect;
  final String? damage;

  factory Attack.fromJson(Map<String, dynamic> j) => Attack(
        name: j['name'] as String? ?? '',
        cost: (j['cost'] as List?)?.cast<String>() ?? const [],
        effect: j['effect'] as String?,
        damage: j['damage']?.toString(),
      );
}

/// Full card from `GET /cards/{id}`.
class TcgCard {
  const TcgCard({
    required this.id,
    required this.localId,
    required this.name,
    required this.set,
    required this.variants,
    this.image,
    this.category,
    this.rarity,
    this.illustrator,
    this.hp,
    this.types = const [],
    this.stage,
    this.evolveFrom,
    this.attacks = const [],
    this.regulationMark,
    this.updated,
    this.pricing,
  });

  final String id;
  final String localId;
  final String name;
  final SetBrief set;
  final CardVariants variants;
  final String? image;
  final String? category;
  final String? rarity;
  final String? illustrator;
  final int? hp;
  final List<String> types;
  final String? stage;
  final String? evolveFrom;
  final List<Attack> attacks;
  final String? regulationMark;
  final String? updated;
  final CardPricing? pricing;

  factory TcgCard.fromJson(Map<String, dynamic> j) => TcgCard(
        id: j['id'] as String,
        localId: j['localId']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        set: SetBrief.fromJson(j['set'] as Map<String, dynamic>),
        variants: j['variants'] is Map<String, dynamic>
            ? CardVariants.fromJson(j['variants'] as Map<String, dynamic>)
            : const CardVariants(normal: true),
        image: j['image'] as String?,
        category: j['category'] as String?,
        rarity: j['rarity'] as String?,
        illustrator: j['illustrator'] as String?,
        hp: (j['hp'] as num?)?.toInt(),
        types: (j['types'] as List?)?.cast<String>() ?? const [],
        stage: j['stage'] as String?,
        evolveFrom: j['evolveFrom'] as String?,
        attacks: (j['attacks'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(Attack.fromJson)
                .toList() ??
            const [],
        regulationMark: j['regulationMark'] as String?,
        updated: j['updated'] as String?,
        pricing: j['pricing'] is Map<String, dynamic>
            ? CardPricing.fromJson(j['pricing'] as Map<String, dynamic>)
            : null,
      );

  /// `high.webp` for detail, `low.webp` for lists.
  String? imageUrl({String quality = 'high', String ext = 'webp'}) =>
      image == null ? null : '$image/$quality.$ext';

  /// "136/189" style label using the set's official count.
  String get numberLabel {
    final total = set.cardCount?.official;
    return total == null ? localId : '$localId/$total';
  }
}

/// Full set from `GET /sets/{id}`.
class TcgSet {
  const TcgSet({
    required this.id,
    required this.name,
    required this.cards,
    this.logo,
    this.symbol,
    this.cardCount,
    this.releaseDate,
    this.serieName,
    this.abbreviation,
  });

  final String id;
  final String name;
  final List<CardBrief> cards;
  final String? logo;
  final String? symbol;
  final SetCardCount? cardCount;
  final String? releaseDate;
  final String? serieName;
  final String? abbreviation;

  factory TcgSet.fromJson(Map<String, dynamic> j) => TcgSet(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        cards: (j['cards'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map(CardBrief.fromJson)
                .toList() ??
            const [],
        logo: j['logo'] as String?,
        symbol: j['symbol'] as String?,
        cardCount: j['cardCount'] is Map<String, dynamic>
            ? SetCardCount.fromJson(j['cardCount'] as Map<String, dynamic>)
            : null,
        releaseDate: j['releaseDate'] as String?,
        serieName: (j['serie'] as Map<String, dynamic>?)?['name'] as String?,
        abbreviation: (j['abbreviation'] as Map<String, dynamic>?)?['official'] as String?,
      );
}

double? _d(Object? v) => v == null ? null : (v as num).toDouble();
