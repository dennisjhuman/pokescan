import 'set_index.g.dart';
import 'set_info.dart';

/// Pure-Dart lookup from what is printed on a card to TCGdex set ids.
/// Shared by manual entry (Phase 1) and the OCR parser (Phase 3).
class SetResolver {
  SetResolver([Iterable<SetInfo>? sets])
      : _sets = (sets ?? kSetIndex).where(_isPhysical).toList()
          ..sort((a, b) => (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''));

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
    if (total == null) return const [];
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

  /// Trim + uppercase only. Zero padding is intentionally kept: whether
  /// TCGdex wants `042` or `42` is per set — see [SetInfo.cardIdFor].
  static String normaliseNumber(String raw) => raw.trim().toUpperCase();
}
