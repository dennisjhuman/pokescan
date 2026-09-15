/// Pure-Dart parsing of OCR output from a card photo into lookup candidates.
///
/// No Flutter, no ML Kit types here — `ocr_service.dart` converts ML Kit's
/// blocks into [OcrLine]s with boxes normalised to the card crop (0..1), so
/// this file is unit-testable with hand-written fixtures.
///
/// Strategy (CLAUDE.md Phase 3), stop at the first confident step:
///  1. Card number `NNN/TTT` in the bottom band → set total → candidate sets
///     (combined with a printed set code like `PAR` when present).
///  2. Card name from the largest text line in the top band.
///  3. Otherwise fall back to a name search (caller's job).
library;

import '../../data/tcgdex/set_info.dart';
import '../../data/tcgdex/set_resolver.dart';

/// One OCR line with its bounding box in normalised card coordinates
/// (0,0 = top-left, 1,1 = bottom-right of the card crop).
class OcrLine {
  const OcrLine(this.text, {required this.left, required this.top, required this.right, required this.bottom});

  final String text;
  final double left, top, right, bottom;

  double get height => bottom - top;
  double get centerY => (top + bottom) / 2;
  double get centerX => (left + right) / 2;

  @override
  String toString() => 'OcrLine("$text" y=${centerY.toStringAsFixed(2)} h=${height.toStringAsFixed(3)})';
}

/// Everything the parser could read. Fields are null when not found.
class ParsedCard {
  const ParsedCard({
    this.number,
    this.total,
    this.setCode,
    this.name,
    this.hp,
    this.attackNames = const [],
    this.candidateSets = const [],
  });

  /// Number as printed, after OCR fixups (`O2O` → `020`). Zero padding is
  /// kept because TCGdex keeps it for some sets; [SetInfo.cardIdFor] decides.
  final String? number;

  /// Printed set size after the slash. Null on promos / pre-2011 cards.
  final int? total;

  /// Printed set abbreviation (`PAR`, `MEW`) if seen next to the number.
  final String? setCode;

  final String? name;
  final int? hp;

  /// Attack names for Phase 4 text-mismatch checks (best effort).
  final List<String> attackNames;

  /// Sets that fit the number/total/code, newest first.
  final List<SetInfo> candidateSets;

  /// TCGdex card ids to try, in order. Empty if we couldn't read a number.
  List<String> get candidateIds =>
      number == null ? const [] : [for (final s in candidateSets) s.cardIdFor(number!)];

  /// One candidate = confident; several = ask the user; none = name search.
  bool get isConfident => candidateIds.length == 1;

  @override
  String toString() =>
      'ParsedCard(number=$number total=$total set=$setCode name=$name hp=$hp candidates=${candidateSets.map((s) => s.id).toList()})';
}

class CardTextParser {
  CardTextParser([SetResolver? resolver]) : _resolver = resolver ?? SetResolver();

  final SetResolver _resolver;

  /// The number line sits in the bottom ~22% of a modern card.
  static const _bottomBand = 0.72;

  /// Name + HP sit in the top ~16%.
  static const _topBand = 0.18;

  static final _numberRe = RegExp(r'([A-Z]{0,4}\s?[0-9OIlSB]{1,3})\s*/\s*([A-Z]{0,4}\s?[0-9OIlSB]{1,3})');
  static final _promoRe = RegExp(r'\b(SWSH|SVP|SM|XY|BW|DP|HGSS|SV|SWSHP|GG|TG)\s?([0-9OIl]{2,3})\b');
  static final _setCodeRe = RegExp(r'\b([A-Z]{2,4})\b');
  static final _hpRe = RegExp(r'(?:HP\s*([0-9OIl]{2,3}))|(?:([0-9OIl]{2,3})\s*HP)', caseSensitive: false);
  static final _stagePrefixRe = RegExp(r'^(basic|stage\s*[12]|v(max|star)?|ex|gx|mega|level\s*up|item|supporter|stadium|tool|energy)\s+', caseSensitive: false);

  ParsedCard parse(List<OcrLine> lines) {
    final bottom = lines.where((l) => l.centerY >= _bottomBand).toList();
    final top = lines.where((l) => l.centerY <= _topBand).toList();

    // 1. Number / total.
    String? number;
    int? total;
    String? setCode;
    // Prefer bottom lines, but scan everything: crops are imperfect.
    for (final l in [...bottom, ...lines.where((l) => l.centerY < _bottomBand)]) {
      final m = _numberRe.firstMatch(l.text.toUpperCase());
      if (m == null) continue;
      final n = _cleanNumber(m.group(1)!);
      final t = int.tryParse(_digits(m.group(2)!));
      if (n == null || t == null || t == 0) continue;
      number = n;
      total = t;
      setCode = _findSetCode(l.text, exclude: {n});
      break;
    }
    // Promo without a slash: "SWSH001", "SVP 012".
    if (number == null) {
      for (final l in bottom) {
        final m = _promoRe.firstMatch(l.text.toUpperCase().replaceAll(' ', ''));
        if (m == null) continue;
        number = '${m.group(1)}${_digits(m.group(2)!)}';
        setCode = _promoSetFor(m.group(1)!);
        break;
      }
    }
    // Set code may be on its own line near the number (SV era: "PAR EN" line
    // is sometimes split from "042/193").
    if (number != null && setCode == null) {
      for (final l in bottom) {
        final c = _findSetCode(l.text, exclude: {number});
        if (c != null) {
          setCode = c;
          break;
        }
      }
    }

    // 2. Name + HP from the top band. Name = tallest line, after stripping
    //    stage words and HP fragments.
    String? name;
    int? hp;
    for (final l in lines) {
      final m = _hpRe.firstMatch(l.text);
      if (m != null) {
        hp = int.tryParse(_digits(m.group(1) ?? m.group(2)!));
        if (hp != null && hp >= 30 && hp <= 400) break;
        hp = null;
      }
    }
    final nameCandidates = top
        .map((l) => (line: l, text: _cleanName(l.text)))
        .where((e) => e.text.length >= 3)
        .toList()
      ..sort((a, b) => b.line.height.compareTo(a.line.height));
    if (nameCandidates.isNotEmpty) name = nameCandidates.first.text;

    // 3. Attack names: lines in the middle band that start with a capital
    //    word and end in a damage number.
    final attacks = <String>[];
    for (final l in lines.where((l) => l.centerY > _topBand + 0.35 && l.centerY < _bottomBand)) {
      final m = RegExp(r'^([A-Z][A-Za-z\x27\-\s]{2,30}?)\s+(\d{2,3}\+?×?)$').firstMatch(l.text.trim());
      if (m != null) attacks.add(m.group(1)!.trim());
    }

    final candidates = number == null
        ? const <SetInfo>[]
        : _resolver.resolve(number: number, total: total, code: setCode);

    return ParsedCard(
      number: number,
      total: total,
      setCode: setCode,
      name: name,
      hp: hp,
      attackNames: attacks,
      candidateSets: candidates,
    );
  }

  /// Digit-only OCR fixups: O→0, I/l→1, S→5, B→8.
  static String _digits(String s) => s
      .replaceAll('O', '0')
      .replaceAll('o', '0')
      .replaceAll('I', '1')
      .replaceAll('l', '1')
      .replaceAll('S', '5')
      .replaceAll('B', '8')
      .replaceAll(RegExp(r'[^0-9]'), '');

  /// "O2O" → "020"; "I36" → "136"; "TG12" → "TG12"; "SWSH O61" → "SWSH061".
  /// Only known gallery/promo prefixes count as letters — a lone leading
  /// `I`/`O`/`S`/`B` is an OCR'd digit.
  static const _knownPrefixes = {'TG', 'GG', 'SWSH', 'SVP', 'SV', 'SM', 'XY', 'BW', 'DP', 'HGSS', 'RC', 'SH'};

  static String? _cleanNumber(String raw) {
    final s = raw.replaceAll(' ', '');
    var letters = RegExp(r'^([A-Z]{1,4})').firstMatch(s)?.group(1) ?? '';
    if (!_knownPrefixes.contains(letters)) letters = '';
    final digits = _digits(s.substring(letters.length));
    if (digits.isEmpty) return null;
    return '$letters$digits';
  }

  String? _findSetCode(String text, {Set<String> exclude = const {}}) {
    for (final m in _setCodeRe.allMatches(text.toUpperCase())) {
      final c = m.group(1)!;
      if (c == 'HP' || c == 'EN' || c == 'LV' || exclude.contains(c)) continue;
      if (_resolver.byCode(c) != null) return c;
    }
    return null;
  }

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

  static String _cleanName(String raw) {
    var s = raw.replaceAll(_hpRe, ' ');
    s = s.replaceAll(RegExp(r'\b\d{2,3}\b'), ' ');
    s = s.replaceAll(_stagePrefixRe, '');
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9\x27\-\.\s&]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
