/// Pure-Dart parsing of OCR output from a card photo into lookup candidates.
///
/// No Flutter, no ML Kit types here — `ocr_service.dart` converts ML Kit's
/// blocks into [OcrLine]s with boxes normalised to the card crop (0..1), so
/// this file is unit-testable with hand-written fixtures.
///
/// Strategy (CLAUDE.md Phase 3), stop at the first confident step:
///  1. The bottom band, joined into one string and handed to
///     [CardQueryParser] — the same code the search box uses, so a number
///     typed by hand and a number read by OCR resolve identically.
///  2. Card name from the largest text line in the top band.
///  3. Otherwise fall back to a name search (caller's job).
library;

import '../../data/tcgdex/card_query.dart';
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
    this.regulationMark,
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

  /// The lone regulation-mark letter (`D`–`I`) if one was read. Not a set
  /// code — it just narrows the years the card can be from.
  final String? regulationMark;

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
  CardTextParser([SetResolver? resolver]) : _query = CardQueryParser(resolver ?? SetResolver());

  final CardQueryParser _query;

  /// The number line sits in the bottom ~28% of a modern card.
  static const _bottomBand = 0.72;

  /// Name + HP sit in the top ~18%.
  static const _topBand = 0.18;

  static final _hpRe = RegExp(r'(?:HP\s*([0-9OIl]{2,3}))|(?:([0-9OIl]{2,3})\s*HP)', caseSensitive: false);
  static final _stagePrefixRe = RegExp(r'^(basic|stage\s*[12]|v(max|star)?|ex|gx|mega|level\s*up|item|supporter|stadium|tool|energy)\s+', caseSensitive: false);

  ParsedCard parse(List<OcrLine> lines) {
    final sorted = [...lines]..sort((a, b) => a.centerY.compareTo(b.centerY));
    final bottom = sorted.where((l) => l.centerY >= _bottomBand).toList();
    final top = sorted.where((l) => l.centerY <= _topBand).toList();

    // 1. Number / total / set code. The bottom band first, because that is
    //    where they are printed; the whole card as a fallback, because a
    //    slightly-off crop can push the line up out of the band.
    var q = _query.parse(_joined(bottom));
    if (!q.hasNumber) q = _query.parse(_joined(sorted));

    // 2. Name + HP from the top band. Name = tallest line, after stripping
    //    stage words and HP fragments.
    String? name;
    int? hp;
    for (final l in sorted) {
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
    for (final l in sorted.where((l) => l.centerY > _topBand + 0.35 && l.centerY < _bottomBand)) {
      final m = RegExp(r'^([A-Z][A-Za-z\x27\-\s]{2,30}?)\s+(\d{2,3}\+?×?)$').firstMatch(l.text.trim());
      if (m != null) attacks.add(m.group(1)!.trim());
    }

    return ParsedCard(
      number: q.number,
      total: q.total,
      setCode: q.setCode,
      regulationMark: q.regulationMark,
      name: name,
      hp: hp,
      attackNames: attacks,
      candidateSets: q.hasNumber ? _query.candidateSets(q) : const [],
    );
  }

  /// OCR lines as one string, in reading order. The set code and the number
  /// often land in separate blocks (`PAR EN` | `185/182`), so they have to be
  /// looked at together.
  static String _joined(List<OcrLine> lines) => lines.map((l) => l.text).join(' ');

  static String _digits(String s) => s
      .replaceAll('O', '0')
      .replaceAll('o', '0')
      .replaceAll('I', '1')
      .replaceAll('l', '1')
      .replaceAll(RegExp(r'[^0-9]'), '');

  static String _cleanName(String raw) {
    var s = raw.replaceAll(_hpRe, ' ');
    s = s.replaceAll(RegExp(r'\b\d{2,3}\b'), ' ');
    s = s.replaceAll(_stagePrefixRe, '');
    s = s.replaceAll(RegExp(r'[^A-Za-z0-9\x27\-\.\s&]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }
}
