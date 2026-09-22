/// Every set the app knows about, per language: what shipped in the bundle,
/// plus whatever the runtime check has found since.
///
/// The bundle is generated at build time (`tool/gen_set_index.dart`), which
/// means it is out of date the day after a release. The 30th Celebration set
/// came out on 2026-09-16, one day after the index was last generated, and a
/// `045/128` card from it resolved to nothing. [SetIndexRefresher] fills that
/// gap at runtime and hands its findings to this catalogue.
///
/// Pure Dart. A plain broadcast stream rather than a ChangeNotifier, so the
/// resolver and query parser that read from it stay free of Flutter.
library;

import 'dart:async';

import 'set_index.g.dart';
import 'set_index_ja.g.dart';
import 'set_info.dart';

class SetCatalog {
  SetCatalog({Map<String, List<SetInfo>>? bundled})
      : _bundled = bundled ?? const {'en': kSetIndex, 'ja': kSetIndexJa};

  /// The one the app uses. Tests build their own.
  static final instance = SetCatalog();

  /// Languages with a catalogue. Western prints (FR, DE…) share the English
  /// set codes and numbers, so they resolve against `en`.
  static const languages = ['en', 'ja'];

  final Map<String, List<SetInfo>> _bundled;
  final _extras = <String, List<SetInfo>>{};
  final _byId = <String, Map<String, SetInfo>>{};
  final _checkedAt = <String, DateTime>{};
  final _changes = StreamController<void>.broadcast();

  /// Fires whenever runtime-found sets are added, so open screens can rebuild.
  Stream<void> get changes => _changes.stream;

  /// Bundle plus extras. An extra with the same id as a bundled set replaces
  /// it — TCGdex adds a new set's cards over several days, so the runtime copy
  /// of a recent set is usually more complete than the one in the bundle.
  List<SetInfo> setsFor(String lang) {
    final extras = _extras[lang] ?? const [];
    if (extras.isEmpty) return _bundled[lang] ?? const [];
    final replaced = {for (final s in extras) s.id.toLowerCase()};
    return [
      ...?_bundled[lang]?.where((s) => !replaced.contains(s.id.toLowerCase())),
      ...extras,
    ];
  }

  /// One set by TCGdex id, case-insensitive. Indexed, because every card
  /// tile without artwork asks this to build a fallback image URL.
  SetInfo? find(String lang, String id) =>
      (_byId[lang] ??= {for (final s in setsFor(lang)) s.id.toLowerCase(): s})[id.toLowerCase()];

  List<SetInfo> bundledFor(String lang) => _bundled[lang] ?? const [];
  List<SetInfo> extrasFor(String lang) => _extras[lang] ?? const [];

  /// When TCGdex was last asked about [lang], or null if never.
  DateTime? checkedAt(String lang) => _checkedAt[lang];

  void setExtras(String lang, List<SetInfo> sets, {DateTime? checkedAt}) {
    _extras[lang] = List.unmodifiable(sets);
    _byId.remove(lang);
    if (checkedAt != null) _checkedAt[lang] = checkedAt;
    _changes.add(null);
  }

  /// Sets released (or first seen) recently, newest first — the "what's new"
  /// list on the finder.
  List<SetInfo> recent(String lang, {DateTime? now, int days = 45}) {
    final list = setsFor(lang).where((s) => s.isRecent(now: now, days: days)).toList()
      ..sort((a, b) => (b.releaseDate ?? '').compareTo(a.releaseDate ?? ''));
    return list;
  }
}
