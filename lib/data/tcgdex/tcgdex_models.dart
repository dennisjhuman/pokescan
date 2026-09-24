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

/// One printing of a card, from `variants_detailed`.
///
/// A card is not one product. `swsh12-131` Dragonite exists as a plain holo
/// (€1.05), a GameStop-stamped holo (€52.90) and an EB Games one (€56); the
/// 30th PokéDay stamp on `me01-001` is €5.49 against €0.08 for the ordinary
/// reverse. Cardmarket lists each of those separately, and TCGdex now hands
/// them over with their own `thirdParty` ids and their own prices — where the
/// card-level `pricing` block is only ever *one* of them, normally the plain
/// one. Showing that for a stamped card understates it by 10–70×.
///
/// Measured over 224 cards spanning every era (2026-09-24): 135 have more than
/// one printing, but only 16 have printings that are *priced* differently. The
/// rest are the ordinary normal/reverse pair, which Cardmarket sells as a
/// single product — so the picker only appears for the 16, and the common card
/// is untouched. See [CardPrintings.pricedSeparately].
class CardPrinting {
  const CardPrinting({
    required this.type,
    this.variantId,
    this.subtype,
    this.size,
    this.stamp = const [],
    this.pricing,
    this.cardmarketProductId,
    this.tcgplayerProductId,
  });

  /// Which of our five variants this printing is.
  final CardVariant type;

  /// TCGdex's own id for the printing. Stable, and what the collection stores
  /// — except that TCGdex sends the literal `"generated"` for printings it
  /// inferred rather than recorded, which is not unique, hence [key].
  final String? variantId;

  /// Printing detail: `shadowless`, `unlimited`, `1999-2000-copyright`.
  final String? subtype;

  /// `standard` or `jumbo`.
  final String? size;

  /// What is stamped on the card: `1st-edition`, `gamestop`, `staff`,
  /// `30th-anniversary`. The main reason two printings differ in price.
  final List<String> stamp;

  /// This printing's own prices. Null for printings nobody lists.
  final CardPricing? pricing;

  final int? cardmarketProductId;
  final int? tcgplayerProductId;

  /// Stable identity for the collection. Prefers TCGdex's id and falls back to
  /// what the printing *is*, because `"generated"` is not an identity.
  String get key => (variantId == null || variantId == 'generated')
      ? [type.name, ?subtype, ...stamp].join('+')
      : variantId!;

  /// What to call it: "Holo", "Holo · GameStop stamp", "Holo · Shadowless,
  /// 1st Edition stamp".
  String get label {
    final bits = [
      if (subtype != null) _humanise(subtype!),
      if (stamp.isNotEmpty) '${stamp.map(_humanise).join(', ')} stamp',
    ];
    return bits.isEmpty ? type.label : '${type.label} · ${bits.join(', ')}';
  }

  /// Distinguishing part only, for a picker where the variant is already shown.
  String get printingLabel {
    final bits = [
      if (subtype != null) _humanise(subtype!),
      if (stamp.isNotEmpty) '${stamp.map(_humanise).join(', ')} stamp',
    ];
    return bits.isEmpty ? 'Plain' : bits.join(', ');
  }

  /// This printing's value, falling back to nothing — the caller decides
  /// whether to drop back to the card-level block.
  Price? get value => pricing?.valueFor(type);

  /// TCGdex writes these kebab-case. A few read badly title-cased, so they are
  /// named; the rest are mechanical.
  static const _names = {
    '1st-edition': '1st Edition',
    'wotc': 'WotC',
    'eb-games': 'EB Games',
    'gamestop': 'GameStop',
    'pokemon-center': 'Pokémon Center',
    'set-logo': 'Set logo',
    '25th-celebration': '25th Celebration',
    '30th-anniversary': '30th Anniversary',
    '30th-pokeday': '30th PokéDay',
    '1999-2000-copyright': '1999–2000 copyright',
    '1999-copyright': '1999 copyright',
    'no-e-reader': 'No e-Reader',
    'player-rewards-program': 'Player Rewards',
    'pre-release': 'Prerelease',
  };

  static String _humanise(String raw) =>
      _names[raw] ??
      raw
          .split('-')
          .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
          .join(' ');

  factory CardPrinting.fromJson(Map<String, dynamic> j) {
    final third = j['thirdParty'] is Map<String, dynamic>
        ? j['thirdParty'] as Map<String, dynamic>
        : const <String, dynamic>{};
    return CardPrinting(
      type: CardVariant.tryParse(_typeKey(j['type'])) ?? CardVariant.normal,
      variantId: j['variantId'] as String?,
      subtype: j['subtype'] as String?,
      size: j['size'] as String?,
      stamp: [for (final s in (j['stamp'] as List?) ?? const []) s.toString()],
      pricing: j['pricing'] is Map<String, dynamic>
          ? CardPricing.fromJson(j['pricing'] as Map<String, dynamic>)
          : null,
      cardmarketProductId: (third['cardmarket'] as num?)?.toInt(),
      tcgplayerProductId: (third['tcgplayer'] as num?)?.toInt(),
    );
  }

  /// `variants_detailed` uses the same words as `variants` except for the
  /// hyphenated ones.
  static String _typeKey(Object? raw) => switch (raw?.toString()) {
        '1st-edition' || 'firstEdition' => 'firstEdition',
        'w-promo' || 'wPromo' => 'wPromo',
        final s? => s,
        _ => 'normal',
      };
}

/// A card's printings, and the question the UI actually asks of them.
class CardPrintings {
  const CardPrintings(this.all);

  final List<CardPrinting> all;

  static const empty = CardPrintings([]);

  factory CardPrintings.fromJson(Object? raw) => CardPrintings([
        for (final e in (raw as List?) ?? const [])
          if (e is Map<String, dynamic>) CardPrinting.fromJson(e),
      ]);

  List<CardPrinting> forVariant(CardVariant v) => [for (final p in all) if (p.type == v) p];

  /// The printings of [v] that are genuinely priced apart, or empty when there
  /// is nothing to choose between.
  ///
  /// "Priced apart" means distinct Cardmarket products: an ordinary card's
  /// normal and reverse printings share one product and one price, so offering
  /// a choice there would be noise pretending to be information.
  List<CardPrinting> pricedSeparately(CardVariant v) {
    final mine = forVariant(v);
    if (mine.length < 2) return const [];
    final products = {for (final p in mine) p.cardmarketProductId}..remove(null);
    return products.length < 2 ? const [] : mine;
  }

  CardPrinting? byKey(String? key) {
    if (key == null) return null;
    for (final p in all) {
      if (p.key == key) return p;
    }
    return null;
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
    this.printings = CardPrintings.empty,
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

  /// The card's individual printings, each with its own price. See
  /// [CardPrinting] — a stamped copy can be worth many times the plain one.
  final CardPrintings printings;

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

  /// Value of one copy, for [variant] and optionally a particular
  /// [printingKey]. A printing's own prices win when it has them; otherwise
  /// this is exactly what it always was, the card-level block.
  Price? valueFor(CardVariant variant, {String? printingKey}) =>
      printings.byKey(printingKey)?.value ?? pricing?.valueFor(variant);

  factory TcgCard.fromJson(Map<String, dynamic> j, {String lang = CardKey.defaultLang}) => TcgCard(
        id: j['id'] as String,
        lang: lang,
        localId: j['localId']?.toString() ?? '',
        name: j['name'] as String? ?? '',
        set: SetBrief.fromJson(j['set'] as Map<String, dynamic>),
        printings: CardPrintings.fromJson(j['variants_detailed']),
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
