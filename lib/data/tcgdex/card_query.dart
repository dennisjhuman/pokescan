/// Turns one free-text box into a lookup.
///
/// The bottom-left of a card prints wildly different things depending on era
/// and language, and the short code next to the number is usually *not* the
/// set. Real examples, all from cards in hand:
///
/// | Printed                | Means                                        |
/// |------------------------|----------------------------------------------|
/// | `E  123/203`           | `E` is the regulation mark, not a set. Total 203 → Evolving Skies. |
/// | `PAR EN  185/182`      | `PAR` *is* the set code, `EN` the language. 185 > 182 = secret rare. |
/// | `SVP EN  194 ★`        | Promo. No total at all — the set code carries it. |
/// | `SWSH153`              | Promo where the set code is glued to the number. |
/// | `M6  058/076 RR`       | Japanese. `RR` is a rarity, not a set.       |
/// | `swsh3-20`             | A TCGdex id, for when you already know it.   |
///
/// Pure Dart, no Flutter: unit-tested in `test/card_query_test.dart`.
library;

import 'card_key.dart';
import 'set_info.dart';
import 'set_resolver.dart';

/// What the typed text turned out to be.
enum CardQueryKind {
  /// A complete TCGdex id — go straight to the card.
  cardId,

  /// A printed number, with or without a total and set code.
  number,

  /// Looks like a card name.
  name,

  /// Nothing usable (empty or punctuation only).
  empty,
}

/// Structured reading of what the user typed.
class CardQuery {
  const CardQuery({
    required this.raw,
    required this.kind,
    this.number,
    this.total,
    this.setCode,
    this.name,
    this.cardId,
    this.regulationMark,
    this.japanese = false,
    this.japaneseCode = false,
    this.untracked,
    this.leftovers = const [],
  });

  final String raw;
  final CardQueryKind kind;

  /// Printed number, OCR/typo fixups applied: `185`, `058`, `SWSH153`, `TG12`.
  final String? number;

  /// The number after the slash. Null on promos and pre-2011 cards.
  final int? total;

  /// Set abbreviation (`PAR`) or TCGdex id (`swsh3`) if one was typed.
  final String? setCode;

  /// Name to search for, when the text isn't a number.
  final String? name;

  /// Full TCGdex id when the text already was one.
  final String? cardId;

  /// The single-letter regulation mark (`D`–`I`), if one was typed. Useful as
  /// a tie-breaker: it narrows which years a card can come from.
  final String? regulationMark;

  /// Text contained kana or kanji: this is definitely a Japanese card.
  final bool japanese;

  /// The set code is one only the Japanese catalogue knows (`M6`, `SV2a`).
  final bool japaneseCode;

  /// A printed code for a real product TCGdex does not list (`CLC`), if one
  /// was read. See [CardQueryParser.untrackedProducts].
  final String? untracked;

  /// Tokens we recognised as neither number, code, language nor rarity —
  /// shown back to the user so an unknown set code isn't silently dropped.
  final List<String> leftovers;

  bool get hasNumber => number != null;

  /// Kana/kanji, or an unrecognised code shaped like a Japanese set id
  /// (`M6`, `SV1a`, `S12a`) — the giveaway when someone types the number off
  /// a Japanese card without typing any Japanese. Only ever used to explain
  /// a dead end, never to look anything up.
  bool get likelyJapanese =>
      japanese || japaneseCode || leftovers.any(CardQueryParser.looksLikeJapaneseSetCode);

  /// Which catalogue to try first.
  String get preferredLang => likelyJapanese ? 'ja' : 'en';

  @override
  String toString() => 'CardQuery($kind number=$number total=$total code=$setCode '
      'reg=$regulationMark name=$name id=$cardId ja=$japanese)';
}

/// Parses the search box, and turns a [CardQuery] into candidate card ids.
class CardQueryParser {
  /// [resolver] is the English catalogue, [japanese] the Japanese one. Both
  /// default to the shared catalogue, which includes sets found at runtime.
  CardQueryParser([SetResolver? resolver, SetResolver? japanese])
      : _resolver = resolver ?? SetResolver(),
        _ja = japanese ?? SetResolver.forLang('ja');

  final SetResolver _resolver;
  final SetResolver _ja;

  /// The English resolver: set browser, name grouping, "did you mean".
  SetResolver get resolver => _resolver;

  SetResolver resolverFor(String lang) => lang == 'ja' ? _ja : _resolver;

  /// A full card key: optional language, set id, hyphen, local id.
  /// `swsh3-20`, `sv03.5-125`, `swshp-SWSH061`, `30th-c-001`, `ja:M6-058`.
  /// Set ids can start with a digit (`30th`) and contain a hyphen (`30th-c`,
  /// `M-P`); the greedy set part backtracks to the last hyphen.
  static final _idRe = RegExp(
      r'^(?:([a-z]{2}):)?([A-Za-z0-9][A-Za-z0-9.\-]{0,11})-([A-Za-z]{0,4}\d{1,3}[A-Za-z]?)$');

  /// `185/182`, `020 / 189`, `TG12/TG30`.
  /// No whitespace inside either side: a lone letter before the number is a
  /// regulation mark (`E 123/203`), not part of it, and swallowing it here
  /// would throw away a useful tie-breaker.
  static final _numberTotalRe =
      RegExp(r'([A-Za-z]{0,4}\d{1,3}[A-Za-z]?)\s*/\s*([A-Za-z]{0,4}\d{1,3})');

  /// Promo where the code is glued to the number: `SWSH153`, `SVP194`, `XY42`.
  static final _promoRe = RegExp(
      r'^(SWSHP|SWSH|SVP|HGSS|SM|XY|BW|DP|SV|GG|TG|RC|SH)[-\s]?(\d{1,3})$',
      caseSensitive: false);

  /// Language markers printed next to the set code.
  static const _languages = {'EN', 'FR', 'DE', 'IT', 'ES', 'PT', 'JP', 'JA', 'KO', 'ZH'};

  /// Japanese set ids have a short series letter and a number, sometimes with
  /// a suffix: `M6`, `SV1a`, `S12a`, `SM11b`. Several of them collide with
  /// English set ids (`SV10` is a set in both languages, and a different one
  /// in each), which is exactly why they are not looked up.
  static final _japaneseSetCodeRe =
      RegExp(r'^(M|S|SV|SM|XY|BW|CP|LL|SH|SI|SL)\d{1,2}[a-zA-Z]?$');

  static bool looksLikeJapaneseSetCode(String token) =>
      _japaneseSetCodeRe.hasMatch(token.trim());

  /// Real printed codes for products TCGdex does not have. Without this, the
  /// set size alone decides: `CLC 003/034` resolved to Double Crisis #3, the
  /// only 34-card set TCGdex knows — a confident wrong answer, when the code
  /// on the card says plainly that it is not Double Crisis.
  static const untrackedProducts = {
    'CLV': 'Pokémon Trading Card Game Classic (2023) — Venusaur deck',
    'CLC': 'Pokémon Trading Card Game Classic (2023) — Charizard deck',
    'CLB': 'Pokémon Trading Card Game Classic (2023) — Blastoise deck',
  };

  /// Regulation marks (the lone letter left of the number on 2020+ cards).
  /// `J` is the 2026 mark — printed on the Japanese M6 cards in hand.
  static const _regulationMarks = {'D', 'E', 'F', 'G', 'H', 'I', 'J'};

  /// Rarity codes printed after the number, mostly on Japanese cards
  /// (`058/076 RR`). They are only treated as rarities once a number *and* a
  /// total have already been read, because that is the position they appear
  /// in. Two of them — `AR` and `RR` — are also the TCGO codes of two 2009
  /// Platinum sets, but those cards print no set code at all, so reading them
  /// as rarities is right far more often than not.
  static const _rarityCodes = {
    'RR', 'RRR', 'SR', 'SAR', 'AR', 'UR', 'CHR', 'CSR', 'HR', 'ACE', 'PROMO',
  };

  /// Anything in these scripts means the card is Japanese.
  static final _cjkRe = RegExp('[\u3040-\u30ff\u3400-\u4dbf\u4e00-\u9fff\uff66-\uff9f]');

  /// Prefixes that are genuinely part of a printed number rather than an
  /// OCR'd digit. A lone leading `I`/`O`/`S` is a misread `1`/`0`/`5`.
  static const _numberPrefixes = {'TG', 'GG', 'SWSH', 'SVP', 'SV', 'SM', 'XY', 'BW', 'DP',
    'HGSS', 'RC', 'SH'};

  CardQuery parse(String input) {
    final raw = input.trim();
    if (raw.isEmpty) return CardQuery(raw: raw, kind: CardQueryKind.empty);
    final japanese = _cjkRe.hasMatch(raw);

    // 1. Already a card key. Matched against set *ids* only: `PAR-185` is a
    //    code and a number, not an id, and must fall through to step 3.
    final id = _idRe.firstMatch(raw.replaceAll(' ', ''));
    if (id != null) {
      final setId = id.group(2)!;
      final explicit = id.group(1);
      final langs = explicit != null ? [explicit] : const ['en', 'ja'];
      for (final lang in langs) {
        final set = resolverFor(lang).byId(setId);
        if (set == null) continue;
        return CardQuery(
          raw: raw,
          kind: CardQueryKind.cardId,
          cardId: CardKey(lang, '${set.id}-${id.group(3)}').key,
          setCode: set.id,
          japanese: japanese,
          japaneseCode: lang == 'ja',
        );
      }
    }

    // 2. Number / total anywhere in the text.
    String? number;
    int? total;
    var rest = raw;
    final nt = _numberTotalRe.firstMatch(raw);
    if (nt != null) {
      final n = cleanNumber(nt.group(1)!);
      final t = int.tryParse(_digits(nt.group(2)!));
      if (n != null && t != null && t > 0) {
        number = n;
        total = t;
        rest = raw.replaceRange(nt.start, nt.end, ' ');
      }
    }

    // 3. Classify the remaining tokens.
    String? setCode;
    String? untracked;
    var japaneseCode = false;
    String? regulationMark;
    final leftovers = <String>[];
    // Hyphens split too, so `PAR-185` reads as a code and a number.
    final words = rest.split(RegExp(r'[\s,·|\-]+')).where((w) => w.trim().isNotEmpty);
    for (final w in words) {
      // A word containing kana or kanji is part of a Japanese card name, not
      // a code. Stripping the CJK out leaves whatever Latin was glued to it:
      // `メガレックウザex` left `ex`, which matches the English e-Card set, so
      // the app read a Japanese name as "set ex" and offered to browse it.
      if (_cjkRe.hasMatch(w)) continue;
      final token = w.replaceAll(RegExp(r'[^A-Za-z0-9.]'), '');
      if (token.isEmpty) continue;
      final upper = token.toUpperCase();

      if (_languages.contains(upper)) continue;
      if (upper.length == 1 && _regulationMarks.contains(upper)) {
        regulationMark ??= upper;
        continue;
      }
      // A bare number, when we haven't got one: "PAR 185".
      if (number == null && RegExp(r'^\d{1,3}$').hasMatch(token)) {
        number = cleanNumber(token);
        continue;
      }
      // Promo with the code glued on: "SWSH153".
      final promo = _promoRe.firstMatch(token);
      if (number == null && promo != null) {
        number = '${promo.group(1)!.toUpperCase()}${_digits(promo.group(2)!)}';
        setCode ??= _promoSetFor(promo.group(1)!.toUpperCase());
        continue;
      }
      if (number != null && total != null && _rarityCodes.contains(upper)) continue;
      if (untrackedProducts.containsKey(upper)) {
        untracked ??= upper;
        continue;
      }
      // A set code either catalogue knows.
      if (setCode == null) {
        final en = _resolver.byCode(token) != null;
        final ja = _ja.byCode(token) != null;
        if (en || ja) {
          setCode = token;
          japaneseCode = ja && !en;
          continue;
        }
      }
      leftovers.add(token);
    }

    if (number != null) {
      return CardQuery(
        raw: raw,
        kind: CardQueryKind.number,
        number: number,
        total: total,
        setCode: setCode,
        regulationMark: regulationMark,
        japanese: japanese,
        japaneseCode: japaneseCode,
        untracked: untracked,
        leftovers: leftovers,
      );
    }
    return CardQuery(
      raw: raw,
      kind: CardQueryKind.name,
      name: raw,
      setCode: setCode,
      japanese: japanese,
      japaneseCode: japaneseCode,
      leftovers: leftovers,
    );
  }

  /// Sets the query could belong to, best first. Empty when we can't tell.
  ///
  /// Both catalogues are consulted, the likelier language first. With a set
  /// code, every set either language has under that code is a candidate, and
  /// the printed total picks between them — which is how `SV10 100/182`
  /// stays English Destined Rivals (182 cards) rather than Japanese SV10 (98),
  /// and how `30C 045/128` picks the 30th Celebration over its Classic
  /// Collection. Without a code, the second language is only tried when the
  /// first finds nothing, so an ordinary English number never grows a list of
  /// Japanese look-alikes.
  List<SetInfo> candidateSets(CardQuery q) {
    // The card names a product TCGdex does not have. Matching on the set size
    // anyway would only find some other set that happens to share it.
    if (q.untracked != null) return const [];
    final langs = q.preferredLang == 'ja' ? const ['ja', 'en'] : const ['en', 'ja'];

    if (q.setCode != null) {
      final all = [for (final l in langs) ...resolverFor(l).byCodeAll(q.setCode!)];
      if (all.isNotEmpty) {
        if (q.total == null) return all;
        final fits = all.where((s) => s.official == q.total).toList();
        // A misread total should not throw away a set the code named exactly.
        return fits.isNotEmpty ? fits : all;
      }
    }
    if (q.number == null) return const [];
    if (q.total == null) {
      // A promo prefix ("SWSH153") pins the set even with no total printed.
      // Promo prefixes are English-only.
      return _resolver.setsForNumberPrefix(q.number!);
    }
    for (final l in langs) {
      var sets = resolverFor(l).resolve(number: q.number!, total: q.total);
      if (q.regulationMark != null) {
        final narrowed = sets.where((s) => _fitsRegulationMark(s, q.regulationMark!)).toList();
        if (narrowed.isNotEmpty) sets = narrowed;
      }
      if (sets.isNotEmpty) return sets;
    }
    return const [];
  }

  /// Candidate TCGdex ids for the query, best first.
  List<String> candidateIds(CardQuery q) {
    if (q.cardId != null) return [q.cardId!];
    if (q.number == null) return const [];
    return [for (final s in candidateSets(q)) s.cardIdFor(q.number!)];
  }

  /// Regulation marks run roughly one letter per year from D (2020).
  /// Used only to break ties, and only when it rules nothing useful out.
  static bool _fitsRegulationMark(SetInfo s, String mark) {
    final year = int.tryParse(s.releaseDate?.substring(0, 4) ?? '');
    if (year == null) return true;
    final first = {'D': 2019, 'E': 2020, 'F': 2021, 'G': 2022, 'H': 2023, 'I': 2024, 'J': 2025}[mark];
    if (first == null) return true;
    return year >= first && year <= first + 3;
  }

  /// `"O2O"` → `"020"`, `"I36"` → `"136"`, `"TG12"` → `"TG12"`.
  /// Zero padding is deliberately preserved — [SetInfo.cardIdFor] decides.
  static String? cleanNumber(String raw) {
    final s = raw.replaceAll(' ', '').toUpperCase();
    var letters = RegExp(r'^([A-Z]{1,4})').firstMatch(s)?.group(1) ?? '';
    if (!_numberPrefixes.contains(letters)) letters = '';
    final digits = _digits(s.substring(letters.length));
    if (digits.isEmpty) return null;
    return '$letters$digits';
  }

  static String _digits(String s) => s
      .toUpperCase()
      .replaceAll('O', '0')
      .replaceAll('I', '1')
      .replaceAll('L', '1')
      .replaceAll('S', '5')
      .replaceAll('B', '8')
      .replaceAll(RegExp(r'[^0-9]'), '');

  static String? _promoSetFor(String prefix) => switch (prefix) {
        'SWSH' || 'SWSHP' => 'swshp',
        'SVP' => 'svp',
        'SM' => 'smp',
        'XY' => 'xyp',
        'BW' => 'bwp',
        'DP' => 'dpp',
        'HGSS' => 'hgssp',
        _ => null,
      };
}
