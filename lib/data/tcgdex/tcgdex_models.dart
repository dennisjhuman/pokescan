/// Models for the TCGdex v2 REST API.
///
/// Hand-written `fromJson` rather than codegen: the pricing shape has
/// hyphenated keys and variant-keyed maps that json_serializable handles
/// awkwardly, and Phase 1 has no other generated code. Shapes verified
/// against the live API on 2026-09-14 (see CLAUDE.md).
library;

import 'card_key.dart';
import 'set_catalog.dart';

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
  const Price(this.amount, this.currency, {this.source, this.estimate = false});
  final double amount;
  final String currency; // "USD" | "EUR"
  final String? source; // e.g. "tcgplayer.market"

  /// True when this isn't a real market price for this exact variant, just
  /// the closest thing available — a Cardmarket average that lumps variants
  /// together, or a TCGplayer mid/low when no market price is published.
  /// Shown to the user as "estimate" rather than a value.
  final bool estimate;

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

  TcgplayerVariantPricing? forVariant(CardVariant v) => entryFor(v)?.$2;

  /// The matched key alongside its prices, so a displayed value can say which
  /// TCGplayer listing it came from (`reverse-holofoil` rather than just
  /// "TCGplayer").
  (String, TcgplayerVariantPricing)? entryFor(CardVariant v) {
    for (final k in keysFor(v)) {
      final p = variants[k];
      if (p != null) return (k, p);
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

  /// The "value" of one copy in [variant].
  ///
  /// TCGplayer's USD market price first, because it is quoted *per variant* —
  /// a reverse holo and a plain copy of the same card get their own numbers.
  /// Cardmarket's EUR figures are a single blob for the whole card (only the
  /// hyphenated `-holo` twins split it at all), so a reverse holo reads as the
  /// price of the common non-holo and vice versa. That is what made the euro
  /// figure look off. Cardmarket is kept as the fallback for cards TCGplayer
  /// does not list (most promos), flagged [Price.estimate].
  Price? valueFor(CardVariant variant) {
    final cm = cardmarket;
    final entry = tcgplayer?.entryFor(variant);
    final tp = entry?.$2;
    final key = entry?.$1;
    final holo = variant == CardVariant.holo || variant == CardVariant.firstEdition;

    Price? usd(double? v, String src, {bool estimate = false}) => v == null
        ? null
        : Price(v, TcgplayerPricing.unit, source: 'tcgplayer.$key.$src', estimate: estimate);
    Price? eur(double? v, String src) =>
        v == null ? null : Price(v, CardmarketPricing.unit, source: 'cardmarket.$src', estimate: true);

    return usd(tp?.market, 'market') ??
        // No market price published yet (fresh sets): mid, then low.
        usd(tp?.mid, 'mid', estimate: true) ??
        usd(tp?.low, 'low', estimate: true) ??
        (holo ? eur(cm?.trendHolo, 'trend-holo') ?? eur(cm?.avgHolo, 'avg-holo') : null) ??
        eur(cm?.trend, 'trend') ??
        eur(cm?.avg, 'avg') ??
        eur(cm?.low, 'low');
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
  const CardBrief({
    required this.id,
    required this.localId,
    required this.name,
    this.image,
    this.lang = CardKey.defaultLang,
  });

  final String id;
  final String localId;
  final String name;
  final String? image;

  /// Which TCGdex catalogue this came from. The JSON does not say, so the
  /// client stamps it from the request.
  final String lang;

  /// App-wide card key — see [CardKey].
  String get key => CardKey(lang, id).key;

  factory CardBrief.fromJson(Map<String, dynamic> j, {String lang = CardKey.defaultLang}) => CardBrief(
        id: j['id'] as String,
        localId: j['localId']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        image: j['image'] as String?,
        lang: lang,
      );

  /// True when the data lists artwork; false means [imageUrl] is a guess.
  bool get hasListedImage => image != null;

  String? imageUrl({String quality = 'low', String ext = 'webp'}) {
    final base = image ?? fallbackImageBase(lang, CardKey(lang, id).setId, localId);
    return base == null ? null : '$base/$quality.$ext';
  }
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
    this.lang = CardKey.defaultLang,
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

  /// Which TCGdex catalogue this came from. Not in the JSON; stamped by the
  /// repository from the key it was fetched under.
  final String lang;

  /// App-wide card key — see [CardKey]. Use this, not [id], for routes,
  /// the cache and collection rows.
  String get key => CardKey(lang, id).key;
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

  factory TcgCard.fromJson(Map<String, dynamic> j, {String lang = CardKey.defaultLang}) => TcgCard(
        id: j['id'] as String,
        lang: lang,
        localId: j['localId']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        set: SetBrief.fromJson(j['set'] as Map<String, dynamic>),
        variants: j['variants'] is Map<String, dynamic>
            ? CardVariants.fromJson(j['variants'] as Map<String, dynamic>)
            : const CardVariants(normal: true),
        image: j['image'] as String?,
        category: j['category'] as String?,
        // TCGdex sends the literal string "None" for cards with no rarity
        // (the 30th Classic Collection reprints, for one).
        rarity: switch (j['rarity']) { final String r when r != 'None' => r, _ => null },
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

  /// `high.webp` for detail, `low.webp` for lists. Falls back to where the
  /// art would conventionally live when TCGdex's data has no `image` — see
  /// [fallbackImageBase].
  String? imageUrl({String quality = 'high', String ext = 'webp'}) {
    final base = image ?? fallbackImageBase(lang, set.id, localId);
    return base == null ? null : '$base/$quality.$ext';
  }

  /// True when the data itself lists artwork. When false, [imageUrl] is a
  /// guess that may 404 — the UI says "no artwork yet" rather than "retry".
  bool get hasListedImage => image != null;

  /// "136/189" style label using the set's official count. Sets that print
  /// no set size (the 30th Classic Collection, official 0) show the number
  /// alone rather than "001/0".
  String get numberLabel {
    final total = set.cardCount?.official;
    return total == null || total == 0 ? localId : '$localId/$total';
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

  factory TcgSet.fromJson(Map<String, dynamic> j, {String lang = CardKey.defaultLang}) => TcgSet(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        cards: (j['cards'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .map((c) => CardBrief.fromJson(c, lang: lang))
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

/// Prices only. TCGdex publishes `0` for a field it has no data for —
/// `trend-holo: 0` on a promo that has never had a holo sale, for instance —
/// and a zero sliding into the fallback chain reads as "this card is
/// worthless" rather than "we don't know". No price field can meaningfully be
/// zero, so zero means absent.
double? _d(Object? v) {
  if (v is! num) return null;
  final d = v.toDouble();
  return d > 0 ? d : null;
}


/// Where a card's art should be when TCGdex's card data does not say.
///
/// Measured 2026-09-21: for the Japanese M1S and M4 sets the API lists every
/// card with no image, yet the asset host serves art for every card sampled.
/// The art is uploaded before the data catches up. Trying the conventional
/// path costs one request that 404s when the art really is missing (M6, M5,
/// the 30th Classic Collection), which the image loader treats as an answer
/// and never retries. Null when the set is unknown to the catalogue.
String? fallbackImageBase(String lang, String setId, String localId) {
  if (localId.isEmpty) return null;
  return SetCatalog.instance.find(lang, setId)?.conventionalImageBase(localId);
}
