/// Keeps the set catalogue current without shipping a new build.
///
/// Once a day at most, per language, it asks TCGdex for the set list — one
/// request — and compares it with what the app already knows. Only sets that
/// are new, or whose card counts have changed, get their detail fetched. On a
/// normal day that is one request and nothing else; on a release day it is a
/// handful. The findings are stored locally, so a set found once keeps
/// resolving offline.
///
/// Why card counts too: TCGdex adds a new set's cards over several days. The
/// 30th Celebration went up with 158 cards; an early snapshot with fewer would
/// otherwise stay wrong until the next app build.
///
/// All I/O is injected, so the policy — what to fetch, when to skip, what to
/// keep when a request fails — is unit-tested without a network or database.
library;

import 'set_catalog.dart';
import 'set_info.dart';

typedef FetchSetList = Future<List<Map<String, dynamic>>> Function(String lang);
typedef FetchSetDetail = Future<Map<String, dynamic>> Function(String lang, String id);
typedef LoadStoredSets = Future<StoredSets?> Function(String lang);
typedef SaveStoredSets = Future<void> Function(String lang, List<SetInfo> sets, DateTime checkedAt);

class StoredSets {
  const StoredSets(this.sets, this.checkedAt);
  final List<SetInfo> sets;
  final DateTime checkedAt;
}

enum RefreshStatus {
  /// Checked recently enough; nothing was requested.
  skipped,

  /// Asked TCGdex and brought the catalogue up to date.
  checked,

  /// Asked, but some set details could not be fetched. What did arrive is
  /// kept; the check time is not advanced, so the next launch tries again.
  partial,

  /// Could not reach TCGdex at all. Nothing changed.
  offline,
}

class RefreshResult {
  const RefreshResult(this.status, {this.added = const [], this.updated = const []});
  final RefreshStatus status;

  /// Sets that were not known before this check.
  final List<SetInfo> added;

  /// Known sets whose card counts changed.
  final List<SetInfo> updated;

  static const skipped = RefreshResult(RefreshStatus.skipped);
  static const offline = RefreshResult(RefreshStatus.offline);
}

class SetIndexRefresher {
  SetIndexRefresher({
    required this.fetchList,
    required this.fetchSet,
    required this.load,
    required this.save,
    SetCatalog? catalog,
    DateTime Function()? now,
    this.interval = const Duration(hours: 20),
    this.maxDetailsPerRun = 25,
  })  : catalog = catalog ?? SetCatalog.instance,
        _now = now ?? DateTime.now;

  final FetchSetList fetchList;
  final FetchSetDetail fetchSet;
  final LoadStoredSets load;
  final SaveStoredSets save;
  final SetCatalog catalog;
  final DateTime Function() _now;

  /// A little under a day, so opening the app at roughly the same time each
  /// morning still checks every morning.
  final Duration interval;

  /// A cap, not an expectation: a normal release is one to three sets. It
  /// only matters on a first run against an old bundle, and keeps that from
  /// firing off a hundred requests at a host that sheds load.
  final int maxDetailsPerRun;

  final _loaded = <String>{};

  /// Puts previously found sets into the catalogue. Cheap and offline; call
  /// it at startup before anything tries to resolve a number.
  Future<void> restore(String lang) async {
    if (_loaded.contains(lang)) return;
    final stored = await load(lang);
    _loaded.add(lang);
    if (stored != null) {
      // Epoch zero is how a partial first run records "never fully checked".
      final at = stored.checkedAt.millisecondsSinceEpoch == 0 ? null : stored.checkedAt;
      catalog.setExtras(lang, stored.sets, checkedAt: at);
    }
  }

  Future<RefreshResult> refresh(String lang, {bool force = false}) async {
    await restore(lang);
    final now = _now();
    final last = catalog.checkedAt(lang);
    if (!force && last != null && now.difference(last) < interval) return RefreshResult.skipped;

    final List<Map<String, dynamic>> remote;
    try {
      remote = await fetchList(lang);
    } catch (_) {
      return RefreshResult.offline;
    }

    final known = {for (final s in catalog.setsFor(lang)) s.id.toLowerCase(): s};
    final extras = {for (final s in catalog.extrasFor(lang)) s.id.toLowerCase(): s};

    final toFetch = <(String, bool)>[]; // (id, isNew)
    for (final brief in remote) {
      final id = brief['id'] as String?;
      if (id == null) continue;
      final k = known[id.toLowerCase()];
      if (k == null) {
        toFetch.add((id, true));
        continue;
      }
      final cc = brief['cardCount'] as Map<String, dynamic>?;
      final official = (cc?['official'] as num?)?.toInt();
      final total = (cc?['total'] as num?)?.toInt();
      if ((official != null && official != k.official) || (total != null && total != k.total)) {
        toFetch.add((id, false));
      }
    }

    final added = <SetInfo>[];
    final updated = <SetInfo>[];
    var failed = false;
    for (final (id, isNew) in toFetch.take(maxDetailsPerRun)) {
      try {
        final json = await fetchSet(lang, id);
        final previous = extras[id.toLowerCase()];
        final info = SetInfo.fromSetJson(
          json,
          lang: lang,
          // Keep the original sighting through later count updates, so the
          // "NEW" badge does not reset every time TCGdex adds a card.
          firstSeenAt: previous?.firstSeenAt ?? (isNew ? now.millisecondsSinceEpoch : null),
        );
        extras[id.toLowerCase()] = info;
        (isNew ? added : updated).add(info);
      } catch (_) {
        failed = true;
      }
    }
    if (toFetch.length > maxDetailsPerRun) failed = true;

    final sets = extras.values.toList();
    // A partial run keeps what it found but leaves the check time alone, so
    // the next launch goes back for the rest instead of waiting a day.
    await save(lang, sets, failed ? (last ?? DateTime.fromMillisecondsSinceEpoch(0)) : now);
    catalog.setExtras(lang, sets, checkedAt: failed ? last : now);
    return RefreshResult(failed ? RefreshStatus.partial : RefreshStatus.checked,
        added: added, updated: updated);
  }
}
