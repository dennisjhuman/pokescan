/// "Things to check" signals for a card.
///
/// Deliberately never produces a verdict. No reliable counterfeit-detection
/// API exists, print runs vary, and phone cameras lie about colour, so every
/// item is phrased as a question or a "check X" and the user decides. See
/// CLAUDE.md Phase 4.
///
/// Pure Dart so it can be unit-tested without a camera or a network.
library;

import '../../data/tcgdex/set_info.dart';
import '../../data/tcgdex/tcgdex_models.dart';
import '../../shared/utils/text_similarity.dart';
import '../scan/card_text_parser.dart';

enum SignalLevel {
  /// Routine prompt. Shown on every card; nothing was found to be off.
  check,

  /// Something read off the card did not line up with TCGdex.
  warning,
}

enum SignalKind { textMismatch, numberSanity, setSanity, colour, visual }

class FakeSignal {
  const FakeSignal({
    required this.kind,
    required this.level,
    required this.prompt,
    this.detail,
  });

  final SignalKind kind;
  final SignalLevel level;

  /// Always a question or an instruction, never a conclusion.
  final String prompt;

  /// What differed, when something did.
  final String? detail;

  bool get isWarning => level == SignalLevel.warning;

  @override
  String toString() => '${level.name}: $prompt${detail == null ? '' : ' ($detail)'}';
}

/// Thresholds are deliberately loose: OCR noise must not manufacture warnings.
class FakeSignalThresholds {
  const FakeSignalThresholds({
    this.nameSimilarity = 0.6,
    this.attackSimilarity = 0.6,
    this.saturationDelta = 0.22,
  });

  final double nameSimilarity;
  final double attackSimilarity;

  /// Mean-saturation gap between scan and reference past which the soft
  /// colour prompt appears.
  final double saturationDelta;
}

/// The always-shown visual checklist from CLAUDE.md.
const _visualChecklist = [
  'Is the font weight the same as the reference, especially the name and HP?',
  'Is the border thickness even, and the yellow border the same width all round?',
  'Does the holo pattern match, and does it sit where the reference has it?',
  'Does the set symbol match in shape and sharpness?',
  'Are the energy symbols crisp, with the same colours and icons?',
  'Is the back-to-front alignment straight when you look at the edges?',
];

class FakeSignals {
  const FakeSignals._();

  /// Build the panel contents for [card].
  ///
  /// [scan] is the OCR result when this card was reached by scanning; without
  /// it only the number/set sanity checks and the visual checklist apply.
  /// [saturationDelta] is the optional soft colour comparison, already
  /// computed; null when it could not be measured.
  static List<FakeSignal> evaluate({
    required TcgCard card,
    ParsedCard? scan,
    SetInfo? set,
    double? saturationDelta,
    FakeSignalThresholds thresholds = const FakeSignalThresholds(),
  }) {
    final out = <FakeSignal>[];

    out.addAll(_numberSanity(card: card, scan: scan, set: set));
    if (scan != null) {
      out.addAll(_textMismatch(card: card, scan: scan, thresholds: thresholds));
    }
    if (saturationDelta != null && saturationDelta.abs() >= thresholds.saturationDelta) {
      out.add(FakeSignal(
        kind: SignalKind.colour,
        level: SignalLevel.warning,
        prompt: 'Colour looks off against the reference — check it under daylight.',
        detail: 'Phone lighting shifts colour a lot, so treat this as a nudge, not evidence. '
            'Mean saturation differs by ${(saturationDelta.abs() * 100).round()}%.',
      ));
    }

    for (final prompt in _visualChecklist) {
      out.add(FakeSignal(kind: SignalKind.visual, level: SignalLevel.check, prompt: prompt));
    }

    // Warnings first, then routine prompts, each keeping its own order.
    out.sort((a, b) {
      if (a.isWarning == b.isWarning) return 0;
      return a.isWarning ? -1 : 1;
    });
    return out;
  }

  static List<FakeSignal> _numberSanity({
    required TcgCard card,
    ParsedCard? scan,
    SetInfo? set,
  }) {
    final out = <FakeSignal>[];
    final official = set?.official ?? card.set.cardCount?.official;
    final printedTotal = scan?.total;

    // The total printed on the card should match the set it claims to be from.
    if (printedTotal != null && official != null && printedTotal != official) {
      out.add(FakeSignal(
        kind: SignalKind.setSanity,
        level: SignalLevel.warning,
        prompt: 'Does the number after the slash match the set?',
        detail: 'The card reads /$printedTotal but ${card.set.name} has $official cards. '
            'Genuine secret rares go above the total, not the other way round.',
      ));
    }

    // A local id above the full print run, including secret rares, is odd.
    final localNumber = int.tryParse(RegExp(r'\d+').firstMatch(card.localId)?.group(0) ?? '');
    final fullRun = set?.total ?? card.set.cardCount?.total;
    if (localNumber != null && fullRun != null && localNumber > fullRun) {
      out.add(FakeSignal(
        kind: SignalKind.numberSanity,
        level: SignalLevel.warning,
        prompt: 'Is the card number inside the set?',
        detail: 'Number $localNumber is higher than the $fullRun cards in ${card.set.name}.',
      ));
    }
    return out;
  }

  static List<FakeSignal> _textMismatch({
    required TcgCard card,
    required ParsedCard scan,
    required FakeSignalThresholds thresholds,
  }) {
    final out = <FakeSignal>[];

    final scannedHp = scan.hp;
    if (scannedHp != null && card.hp != null && scannedHp != card.hp) {
      out.add(FakeSignal(
        kind: SignalKind.textMismatch,
        level: SignalLevel.warning,
        prompt: 'Does the HP on the card really read ${card.hp}?',
        detail: 'The scan read $scannedHp; TCGdex has ${card.hp}. '
            'Wrong HP is a common counterfeit tell, but so is a bad scan.',
      ));
    }

    // The OCR model is Latin-only. On a Japanese card it reads the number
    // line and HP fine, but whatever it makes of the name and attacks is
    // noise, and comparing that noise with the real Japanese text would warn
    // about every Japanese card in the collection. HP is a number either way,
    // so that check above still runs.
    if (card.lang != 'en') return out;

    final scannedName = scan.name;
    if (scannedName != null && scannedName.trim().length >= 3) {
      final score = similarity(scannedName, card.name);
      if (score < thresholds.nameSimilarity) {
        out.add(FakeSignal(
          kind: SignalKind.textMismatch,
          level: SignalLevel.warning,
          prompt: 'Is the name spelled exactly as on the reference?',
          detail: 'The scan read "$scannedName"; this card is "${card.name}".',
        ));
      }
    }

    final known = card.attacks.map((a) => a.name).toList();
    if (known.isNotEmpty) {
      for (final scanned in scan.attackNames) {
        if (scanned.trim().length < 3) continue;
        final score = bestSimilarity(scanned, known);
        if (score < thresholds.attackSimilarity) {
          out.add(FakeSignal(
            kind: SignalKind.textMismatch,
            level: SignalLevel.warning,
            prompt: 'Do the attack names match the reference exactly?',
            detail: 'The scan read "$scanned"; this card has ${known.map((k) => '"$k"').join(' and ')}. '
                'Typos and altered attack names are worth a close look.',
          ));
        }
      }
    }
    return out;
  }
}
