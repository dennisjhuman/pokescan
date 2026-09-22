/// Anniversary reprints that keep the original card's printed number.
///
/// The 30th Classic Collection (2026) and the Celebrations Classic Collection
/// (2021) reprint famous cards from across the years, each with a small
/// anniversary stamp — but print the *original* number: the 30th Charizard
/// says `4/102`, exactly like the 1999 Base Set one. So typing or scanning
/// what is printed finds the original, and the reprint never came up.
///
/// TCGdex numbers the reprints separately (`30th-c-001`) and records no link
/// back to the original. Matching on name, HP, illustrator and attack names is
/// exact for every pair checked (Charizard ↔ base1-4, Crobat G ↔ pl1-47,
/// Magikarp ↔ sv02-203), so that is the link.
///
/// Pure Dart; the fetching lives in providers.dart.
library;

import 'tcgdex_models.dart';

class ReprintSet {
  const ReprintSet(this.setId, this.name, this.stamp);

  final String setId;
  final String name;

  /// What to look for on the physical card, in the user's words.
  final String stamp;
}

const kReprintSets = [
  ReprintSet('30th-c', '30th Classic Collection', 'a “30” Pikachu stamp'),
  ReprintSet('cel25cc', 'Celebrations Classic Collection', 'a “25” anniversary stamp'),
];

bool isReprintSet(String setId) => kReprintSets.any((r) => r.setId == setId.toLowerCase());

ReprintSet? reprintSetFor(String setId) {
  for (final r in kReprintSets) {
    if (r.setId == setId.toLowerCase()) return r;
  }
  return null;
}

/// Reprint-set cards worth fetching to compare with [original]: same name.
/// Cheap, offline, and deliberately loose — [isReprintOf] does the real check.
List<CardBrief> nameMatches(TcgCard original, Iterable<CardBrief> reprintSetCards) {
  final name = _norm(original.name);
  return [for (final c in reprintSetCards) if (_norm(c.name) == name) c];
}

/// True when [reprint] is the same card as [original], reprinted.
///
/// Name and illustrator must match; HP and attack names must match whenever
/// both cards have them (trainers such as Misty or N have neither). That rules
/// out every other Charizard: a modern Charizard ex shares the name and
/// nothing else.
bool isReprintOf(TcgCard reprint, TcgCard original) {
  if (reprint.key == original.key) return false;
  if (!isReprintSet(reprint.set.id)) return false;
  if (_norm(reprint.name) != _norm(original.name)) return false;
  final ri = reprint.illustrator, oi = original.illustrator;
  if (ri == null || oi == null || _norm(ri) != _norm(oi)) return false;
  if (reprint.hp != null && original.hp != null && reprint.hp != original.hp) return false;
  final ra = [for (final a in reprint.attacks) _norm(a.name)];
  final oa = [for (final a in original.attacks) _norm(a.name)];
  if (ra.isNotEmpty && oa.isNotEmpty && ra.join('|') != oa.join('|')) return false;
  return true;
}

String _norm(String s) => s.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
