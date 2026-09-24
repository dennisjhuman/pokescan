/// Static facts about a TCGdex set, bundled at build time (see
/// `tool/gen_set_index.dart`). Enough to resolve "number/total" and printed
/// abbreviations to a set id without a network call.
class SetInfo {
  const SetInfo({
    required this.id,
    required this.name,
    required this.official,
    required this.total,
    this.lang = 'en',
    this.serie,
    this.serieId,
    this.abbreviation,
    this.releaseDate,
    this.hasLogo = false,
    this.hasSymbol = false,
    this.zeroPadded = false,
    this.firstSeenAt,
  });

  /// Builds a [SetInfo] from a `GET /v2/{lang}/sets/{id}` response. Shared by
  /// the build-time generator and the runtime new-set check, so a set found at
  /// runtime is indistinguishable from one that shipped in the bundle.
  factory SetInfo.fromSetJson(Map<String, dynamic> j, {String lang = 'en', int? firstSeenAt}) {
    final cc = (j['cardCount'] as Map<String, dynamic>?) ?? const {};
    // TCGdex keeps the printed zero padding for some sets (sv04-042, svp-012,
    // swsh9tg-TG01) but not others (swsh3-20). Detect it from the card list.
    final localIds = ((j['cards'] as List?) ?? const [])
        .whereType<Map<String, dynamic>>()
        .map((c) => c['localId'].toString());
    return SetInfo(
      id: j['id'] as String,
      name: j['name'] as String? ?? j['id'] as String,
      lang: lang,
      serie: (j['serie'] as Map<String, dynamic>?)?['name'] as String?,
      serieId: (j['serie'] as Map<String, dynamic>?)?['id'] as String?,
      abbreviation: (j['abbreviation'] as Map<String, dynamic>?)?['official'] as String?,
      official: (cc['official'] as num?)?.toInt() ?? 0,
      total: (cc['total'] as num?)?.toInt() ?? 0,
      releaseDate: j['releaseDate'] as String?,
      hasLogo: j['logo'] != null,
      hasSymbol: j['symbol'] != null,
      zeroPadded: localIds.any((x) => RegExp(r'^[A-Z]*0\d').hasMatch(x)),
      firstSeenAt: firstSeenAt,
    );
  }

  /// Round-trips through the local set cache.
  factory SetInfo.fromMap(Map<String, dynamic> m) => SetInfo(
        id: m['id'] as String,
        name: m['name'] as String,
        lang: m['lang'] as String? ?? 'en',
        serie: m['serie'] as String?,
        serieId: m['serieId'] as String?,
        abbreviation: m['abbreviation'] as String?,
        official: (m['official'] as num).toInt(),
        total: (m['total'] as num).toInt(),
        releaseDate: m['releaseDate'] as String?,
        hasLogo: m['hasLogo'] as bool? ?? false,
        hasSymbol: m['hasSymbol'] as bool? ?? false,
        zeroPadded: m['zeroPadded'] as bool? ?? false,
        firstSeenAt: (m['firstSeenAt'] as num?)?.toInt(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'lang': lang,
        'serie': serie,
        'serieId': serieId,
        'abbreviation': abbreviation,
        'official': official,
        'total': total,
        'releaseDate': releaseDate,
        'hasLogo': hasLogo,
        'hasSymbol': hasSymbol,
        'zeroPadded': zeroPadded,
        'firstSeenAt': firstSeenAt,
      };

  final String id;

  /// TCGdex language segment. Japanese sets are a separate catalogue with
  /// their own ids, several of which collide with English ones (`SV10`).
  final String lang;

  /// Epoch ms when the runtime check first saw this set. Null for sets that
  /// shipped in the bundle. Drives the "NEW" badge alongside [releaseDate].
  final int? firstSeenAt;
  final String name;
  final String? serie;

  /// TCGdex series id (`sv`, `swsh`, `me`, `M`). It is the middle segment of
  /// every asset URL, and it cannot be derived from the set id: `30th` belongs
  /// to `me`, `cel25` to `swsh`. Null for sets stored before it was recorded.
  final String? serieId;

  /// Printed 3-letter code on Scarlet & Violet era cards (e.g. `PAR`), and
  /// the TCGO code for older sets (e.g. `DAA`). Null for some promos.
  final String? abbreviation;

  /// The number after the slash on the card ("/189").
  final int official;

  /// Including secret rares.
  final int total;
  final String? releaseDate;
  final bool hasLogo;
  final bool hasSymbol;

  /// Whether TCGdex keeps printed zero padding in this set's local ids
  /// (`sv04-042`, `svp-012`, `swsh9tg-TG01`) or strips it (`swsh3-20`).
  final bool zeroPadded;

  /// TCGdex local id for a number as printed on the card.
  /// `"020"` → `"20"` or `"020"` depending on [zeroPadded]; letter prefixes
  /// (`TG12`, `SWSH061`) are kept and their digits padded the same way.
  String localIdFor(String printed) {
    final s = printed.trim().toUpperCase();
    final m = RegExp(r'^([A-Z]*)(\d+)([A-Z]*)$').firstMatch(s);
    if (m == null) return s;
    final prefix = m.group(1)!;
    final n = int.parse(m.group(2)!);
    final suffix = m.group(3)!;
    if (!zeroPadded) return '$prefix$n$suffix';
    // Gallery subsets use two digits (TG01, GG07); everything else three.
    final base = (prefix == 'TG' || prefix == 'GG') ? 2 : 3;
    final width = m.group(2)!.length > base ? m.group(2)!.length : base;
    return '$prefix${n.toString().padLeft(width, '0')}$suffix';
  }

  /// App card key for a printed number: the plain TCGdex id for English
  /// (`swsh3-20`), language-prefixed otherwise (`ja:M6-058`). See `card_key.dart`.
  String cardIdFor(String printed) {
    final id = '${this.id}-${localIdFor(printed)}';
    return lang == 'en' ? id : '$lang:$id';
  }

  /// Released within the last [days] — or, for a set the runtime check picked
  /// up, first seen that recently. Either makes it worth a "NEW" badge.
  bool isRecent({DateTime? now, int days = 45}) {
    final t = now ?? DateTime.now();
    final released = releaseDate == null ? null : DateTime.tryParse(releaseDate!);
    // A future date (TCGdex lists sets ahead of release) counts as recent too.
    if (released != null && t.difference(released).inDays <= days) return true;
    final seen = firstSeenAt;
    return seen != null && t.difference(DateTime.fromMillisecondsSinceEpoch(seen)).inDays <= days;
  }

  /// Where the set logo might be, best first.
  ///
  /// Two separate things had to be got right here, both measured 2026-09-24:
  ///
  ///  * **The data often omits the logo that exists.** 63 of the 220 English
  ///    sets carry no `logo` key at all, the 30th Celebration and its Classic
  ///    Collection among them — yet `.../me/30th/logo.png` serves a logo. Same
  ///    story as card art: the file is uploaded before the data points at it.
  ///    So a set whose data lists no logo is still guessed at, and
  ///    [hasListedLogo] says which case we are in.
  ///  * **The format is not fixed.** The 30th Celebration logo is a PNG and
  ///    `logo.webp` 404s, while most other sets serve both. So both are tried,
  ///    webp first because it is smaller.
  ///
  /// A guess that is wrong is a 404, which [ImageLoader] treats as final.
  List<String> get logoUrls {
    final base = 'https://assets.tcgdex.net/$lang/$seriePath/$id/logo';
    return ['$base.webp', '$base.png'];
  }

  /// True when the set data named a logo; false means [logoUrls] is a guess
  /// and should be loaded speculatively (fewer attempts, no retry offer).
  bool get hasListedLogo => hasLogo;

  String? get symbolUrl =>
      hasSymbol ? 'https://assets.tcgdex.net/univ/$seriePath/$id/symbol.webp' : null;

  /// TCGdex asset path uses the serie id, which is the set id minus its
  /// trailing number/suffix (`swsh3` → `swsh`, `sv04` → `sv`, `base1` → `base`).
  /// The recorded series id when there is one; otherwise the leading letters
  /// of the set id, which is right for most sets (`swsh3` → `swsh`,
  /// `SV2a` → `SV`) and harmlessly wrong for the rest — a wrong guess is a 404.
  String get seriePath {
    if (serieId != null) return serieId!;
    final m = RegExp(r'^([A-Za-z]+)').firstMatch(id);
    return m?.group(1) ?? id;
  }

  /// Where TCGdex keeps a card's artwork by convention. Used when the card
  /// data has no `image` field — for some sets the art is uploaded before the
  /// data is updated to point at it (measured 2026-09-21: every sampled card
  /// in JP M1S and M4). Append `/low.webp` etc. as with any image base.
  String conventionalImageBase(String localId) =>
      'https://assets.tcgdex.net/$lang/$seriePath/$id/$localId';

  @override
  String toString() => 'SetInfo($lang:$id $name $official/$total ${abbreviation ?? ''})';
}
