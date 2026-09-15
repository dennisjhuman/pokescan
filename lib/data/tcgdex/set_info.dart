/// Static facts about a TCGdex set, bundled at build time (see
/// `tool/gen_set_index.dart`). Enough to resolve "number/total" and printed
/// abbreviations to a set id without a network call.
class SetInfo {
  const SetInfo({
    required this.id,
    required this.name,
    required this.official,
    required this.total,
    this.serie,
    this.abbreviation,
    this.releaseDate,
    this.hasLogo = false,
    this.hasSymbol = false,
    this.zeroPadded = false,
  });

  final String id;
  final String name;
  final String? serie;

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

  /// Full TCGdex card id for a printed number.
  String cardIdFor(String printed) => '$id-${localIdFor(printed)}';

  String? get logoUrl => hasLogo ? 'https://assets.tcgdex.net/en/$_seriePath/$id/logo.webp' : null;
  String? get symbolUrl =>
      hasSymbol ? 'https://assets.tcgdex.net/univ/$_seriePath/$id/symbol.webp' : null;

  /// TCGdex asset path uses the serie id, which is the set id minus its
  /// trailing number/suffix (`swsh3` → `swsh`, `sv04` → `sv`, `base1` → `base`).
  String get _seriePath {
    final m = RegExp(r'^([a-z]+)').firstMatch(id);
    return m?.group(1) ?? id;
  }

  @override
  String toString() => 'SetInfo($id $name $official/$total ${abbreviation ?? ''})';
}
