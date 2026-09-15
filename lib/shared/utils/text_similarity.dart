/// Fuzzy string comparison for matching noisy OCR text against TCGdex data.
///
/// OCR gets letters wrong often enough that exact comparison would cry wolf on
/// every scan, so mismatch warnings are only raised when the strings are far
/// apart. Pure Dart, unit-tested.
library;

/// Lowercase, strip accents and punctuation, collapse whitespace.
/// `"G-Max Wildfire!"` and `"gmax wildfire"` normalise to the same string.
String normalizeForCompare(String s) {
  const from = 'áàâäãåéèêëíìîïóòôöõúùûüñçÁÀÂÄÃÅÉÈÊËÍÌÎÏÓÒÔÖÕÚÙÛÜÑÇ';
  const to = 'aaaaaaeeeeiiiiooooouuuuncAAAAAAEEEEIIIIOOOOOUUUUNC';
  final buf = StringBuffer();
  for (final rune in s.runes) {
    final ch = String.fromCharCode(rune);
    final i = from.indexOf(ch);
    buf.write(i == -1 ? ch : to[i]);
  }
  return buf
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Levenshtein edit distance between two already-normalised strings.
int editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var prev = List<int>.generate(b.length + 1, (i) => i);
  var curr = List<int>.filled(b.length + 1, 0);
  for (var i = 0; i < a.length; i++) {
    curr[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final cost = a.codeUnitAt(i) == b.codeUnitAt(j) ? 0 : 1;
      final del = prev[j + 1] + 1;
      final ins = curr[j] + 1;
      final sub = prev[j] + cost;
      curr[j + 1] = del < ins ? (del < sub ? del : sub) : (ins < sub ? ins : sub);
    }
    final tmp = prev;
    prev = curr;
    curr = tmp;
  }
  return prev[b.length];
}

/// 1.0 = identical after normalising, 0.0 = nothing in common.
double similarity(String a, String b) {
  final x = normalizeForCompare(a);
  final y = normalizeForCompare(b);
  if (x.isEmpty && y.isEmpty) return 1;
  if (x.isEmpty || y.isEmpty) return 0;
  final longest = x.length > y.length ? x.length : y.length;
  return 1 - editDistance(x, y) / longest;
}

/// Best [similarity] of [needle] against any of [haystack].
double bestSimilarity(String needle, Iterable<String> haystack) {
  var best = 0.0;
  for (final h in haystack) {
    final s = similarity(needle, h);
    if (s > best) best = s;
  }
  return best;
}
