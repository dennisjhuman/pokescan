import 'card_key.dart';
import 'set_catalog.dart';
import 'set_info.dart';

/// Pure-Dart lookup from what is printed on a card to TCGdex set ids, for one
/// language. Shared by the finder and the OCR parser.
class SetResolver {
  /// English sets from the shared catalogue, including any the runtime check
  /// has found since the bundle was generated. Pass [sets] to pin a list.
  SetResolver([Iterable<SetInfo>? sets])
      : _sets = (sets ?? SetCatalog.instance.setsFor('en')).where(_isPhysical).toList()
          ..sort((a, b) => (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''));

  /// The catalogue for [lang] (`en`, `ja`).
  factory SetResolver.forLang(String lang, [SetCatalog? catalog]) =>
      SetResolver((catalog ?? SetCatalog.instance).setsFor(lang));

  /// Newest first.
  final List<SetInfo> _sets;

  List<SetInfo> get all => List.unmodifiable(_sets);

  static bool _isPhysical(SetInfo s) => s.serie != 'Pokémon TCG Pocket';

  /// Exact TCGdex id (`swsh3`) or printed abbreviation (`DAA`, `PAR`),
  /// case-insensitive.
  SetInfo? byCode(String code) {
    final c = code.trim().toLowerCase();
    if (c.isEmpty) return null;
    for (final s in _sets) {
      if (s.id.toLowerCase() == c) return s;
    }
    for (final s in _sets) {
      if (s.abbreviation?.toLowerCase() == c) return s;
    }
    return null;
  }

  /// Every set the code could mean. Codes are not unique: the 30th
  /// Celebration and its Classic Collection both print `30C`, so a lookup by
  /// code alone has to be allowed to come back with more than one answer.
  List<SetInfo> byCodeAll(String code) {
    final c = code.trim().toLowerCase();
    if (c.isEmpty) return const [];
    final byId = _sets.where((s) => s.id.toLowerCase() == c);
    final byAbbr = _sets.where((s) => s.abbreviation?.toLowerCase() == c && s.id.toLowerCase() != c);
    return [...byId, ...byAbbr];
  }

  /// Exact TCGdex set id only — never an abbreviation. `PAR-185` must not be
  /// read as a card id just because PAR is Paradox Rift's printed code.
  SetInfo? byId(String id) {
    final c = id.trim().toLowerCase();
    for (final s in _sets) {
      if (s.id.toLowerCase() == c) return s;
    }
    return null;
  }

  /// Sets whose printed total ("/189") matches. Secret rares are numbered
  /// above the printed total (201/189), so we match `official`, not `total`.
  List<SetInfo> byTotal(int total) => _sets.where((s) => s.official == total).toList();

  /// Candidates for a card given whatever was read off it. Empty list means
  /// "no idea"; one item means confident.
  ///
  /// [number] is the local id (may have leading zeros or letters).
  /// [total] is the number after the slash, if printed.
  /// [code] is a set id or printed abbreviation, if known.
  List<SetInfo> resolve({required String number, int? total, String? code}) {
    if (code != null && code.trim().isNotEmpty) {
      final s = byCode(code);
      return s == null ? const [] : [s];
    }
    // Promos print no total ("SWSH153", "SVP 194"): the prefix is all we get.
    if (total == null) return setsForNumberPrefix(number);
    final printed = number.trim().toUpperCase();
    final prefix = RegExp(r'^([A-Z]+)').firstMatch(printed)?.group(1);
    final n = int.tryParse(RegExp(r'\d+').firstMatch(printed)?.group(0) ?? '');
    return byTotal(total).where((s) {
      // "TG12/TG30" belongs to a *tg subset, "GG07/GG70" to *gg.
      if (prefix != null && (prefix == 'TG' || prefix == 'GG')) {
        return s.id.endsWith(prefix.toLowerCase());
      }
      return n == null || n <= s.total;
    }).toList();
  }

  /// Sets implied by a letter prefix on the number itself, newest first.
  ///
  /// `SWSH153` → the SWSH Black Star Promos; `TG12` → the trainer-gallery
  /// subsets; `194` (no prefix) → nothing, because a bare number says nothing
  /// about its set on its own.
  List<SetInfo> setsForNumberPrefix(String number) {
    final prefix = RegExp(r'^([A-Z]+)').firstMatch(number.trim().toUpperCase())?.group(1);
    if (prefix == null || prefix.isEmpty) return const [];
    if (prefix == 'TG' || prefix == 'GG') {
      return _sets.where((s) => s.id.endsWith(prefix.toLowerCase())).toList();
    }
    final promo = _promoSetIds[prefix];
    if (promo == null) return const [];
    final s = byCode(promo);
    return s == null ? const [] : [s];
  }

  static const _promoSetIds = {
    'SWSH': 'swshp',
    'SWSHP': 'swshp',
    'SVP': 'svp',
    'SM': 'smp',
    'XY': 'xyp',
    'BW': 'bwp',
    'DP': 'dpp',
    'HGSS': 'hgssp',
  };

  /// The set a card id or key belongs to (`sv04-185` → Paradox Rift). Used
  /// to label search results, which come back with only an id. Set ids can
  /// contain a hyphen themselves (`30th-c-001`), hence [CardKey.setId].
  SetInfo? setForCardId(String cardId) => byId(CardKey.parse(cardId).setId);

  /// Free-text set search for the "browse by set" picker: matches the name,
  /// the printed abbreviation, the TCGdex id and the serie. Newest first.
  List<SetInfo> searchSets(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return _sets
        .where((s) =>
            s.name.toLowerCase().contains(q) ||
            s.id.toLowerCase().contains(q) ||
            (s.abbreviation?.toLowerCase().contains(q) ?? false) ||
            (s.serie?.toLowerCase().contains(q) ?? false))
        .toList();
  }

  /// Set codes that look close to [code], for "did you mean?" after a typo or
  /// after someone types a Japanese set code we have no English set for.
  List<SetInfo> didYouMean(String code, {int limit = 4}) {
    final c = code.trim().toLowerCase();
    if (c.isEmpty) return const [];
    final scored = <(int, SetInfo)>[];
    for (final s in _sets) {
      final abbr = s.abbreviation?.toLowerCase();
      var score = 0;
      if (abbr != null && abbr.startsWith(c.substring(0, 1))) score += 1;
      if (abbr != null && _editDistance(abbr, c) <= 1) score += 4;
      if (s.id.toLowerCase().startsWith(c)) score += 3;
      if (s.name.toLowerCase().contains(c)) score += 2;
      if (score > 0) scored.add((score, s));
    }
    scored.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final e in scored.take(limit)) e.$2];
  }

  static int _editDistance(String a, String b) {
    var prev = List<int>.generate(b.length + 1, (i) => i);
    for (var i = 1; i <= a.length; i++) {
      final cur = <int>[i];
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        cur.add([prev[j] + 1, cur[j - 1] + 1, prev[j - 1] + cost].reduce((x, y) => x < y ? x : y));
      }
      prev = cur;
    }
    return prev[b.length];
  }

  /// Trim + uppercase only. Zero padding is intentionally kept: whether
  /// TCGdex wants `042` or `42` is per set — see [SetInfo.cardIdFor].
  static String normaliseNumber(String raw) => raw.trim().toUpperCase();
}
