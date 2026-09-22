/// How the app names a card: TCGdex id plus the language it came from.
///
/// TCGdex keeps each language as a separate catalogue, and the ids collide —
/// Japanese `SV10` (ロケット団の栄光) and English `sv10` (Destined Rivals) are
/// different sets, and the cache lowercases its keys, so `sv10-100` would
/// quietly return the wrong card. The language has to travel with the id.
///
/// English keys are the bare TCGdex id (`swsh3-20`), exactly as they were
/// before any other language existed, so every collection row and cache entry
/// written before this change still means what it meant. Every other language
/// is prefixed: `ja:M6-058`.
///
/// Western-language prints (FR, DE, IT…) share the English set codes and
/// numbers and resolve to the English card; only the Asian catalogues are
/// separate sets.
library;

class CardKey {
  const CardKey(this.lang, this.id);

  /// TCGdex language segment: `en`, `ja`.
  final String lang;

  /// TCGdex card id within that language: `swsh3-20`, `M6-058`.
  final String id;

  static const defaultLang = 'en';

  /// `ja:M6-058` → (ja, M6-058); `swsh3-20` → (en, swsh3-20).
  ///
  /// The language part is only recognised when it looks like one (two letters,
  /// optionally with a region: `zh-tw`), so an id can never be misread as a
  /// language just because it has a colon in it.
  factory CardKey.parse(String key) {
    final m = RegExp(r'^([a-z]{2}(?:-[a-z]{2})?):(.+)$').firstMatch(key.trim());
    if (m == null) return CardKey(defaultLang, key.trim());
    return CardKey(m.group(1)!, m.group(2)!);
  }

  /// The string used for routes, the card cache and collection rows.
  String get key => lang == defaultLang ? id : '$lang:$id';

  bool get isEnglish => lang == defaultLang;

  /// The TCGdex set id this card belongs to. Set ids can themselves contain a
  /// hyphen (`30th-c`, `M-P`), so it is everything before the *last* one.
  String get setId {
    final dash = id.lastIndexOf('-');
    return dash <= 0 ? id : id.substring(0, dash);
  }

  @override
  bool operator ==(Object other) =>
      other is CardKey && other.lang == lang && other.id.toLowerCase() == id.toLowerCase();

  @override
  int get hashCode => Object.hash(lang, id.toLowerCase());

  @override
  String toString() => key;
}

/// Route to a card's detail page. The key is encoded because a language
/// prefix brings a colon into the path.
String cardPath(String key) => '/card/${Uri.encodeComponent(key)}';
