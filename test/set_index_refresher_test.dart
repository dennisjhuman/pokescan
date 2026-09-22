import 'package:flutter_test/flutter_test.dart';
import 'package:pokescan/data/tcgdex/set_catalog.dart';
import 'package:pokescan/data/tcgdex/set_index_refresher.dart';
import 'package:pokescan/data/tcgdex/set_info.dart';
import 'package:pokescan/data/tcgdex/set_resolver.dart';

/// The situation that prompted this: the 30th Celebration set was released
/// on 2026-09-16, the day after the bundled index was generated, so its
/// cards resolved to nothing until the next app build.
void main() {
  const bundled = [
    SetInfo(id: 'sv04', name: 'Paradox Rift', official: 182, total: 266, abbreviation: 'PAR',
        releaseDate: '2023-11-03', zeroPadded: true),
  ];

  Map<String, dynamic> brief(String id, int official, int total) => {
        'id': id,
        'name': id,
        'cardCount': {'official': official, 'total': total},
      };

  Map<String, dynamic> detail(String id, String name, int official, int total,
          {String? abbr, String? date}) =>
      {
        'id': id,
        'name': name,
        'cardCount': {'official': official, 'total': total},
        'abbreviation': abbr == null ? null : {'official': abbr},
        'releaseDate': date,
        'serie': {'name': 'Mega Evolution'},
        'cards': [
          {'localId': '001'},
        ],
      };

  late SetCatalog catalog;
  late Map<String, StoredSets> store;
  late List<String> requests;
  late DateTime now;
  late List<Map<String, dynamic>> remoteList;
  late Map<String, Map<String, dynamic>> remoteDetails;
  late Set<String> failingDetails;
  var listFails = false;

  SetIndexRefresher refresher() => SetIndexRefresher(
        catalog: catalog,
        now: () => now,
        fetchList: (lang) async {
          requests.add('list:$lang');
          if (listFails) throw Exception('offline');
          return remoteList;
        },
        fetchSet: (lang, id) async {
          requests.add('set:$lang:$id');
          if (failingDetails.contains(id)) throw Exception('503');
          return remoteDetails[id]!;
        },
        load: (lang) async => store[lang],
        save: (lang, sets, at) async => store[lang] = StoredSets(sets, at),
      );

  setUp(() {
    catalog = SetCatalog(bundled: {'en': bundled, 'ja': const []});
    store = {};
    requests = [];
    now = DateTime(2026, 9, 21, 9);
    listFails = false;
    failingDetails = {};
    remoteList = [brief('sv04', 182, 266), brief('30th', 128, 158)];
    remoteDetails = {
      '30th': detail('30th', '30th Celebration', 128, 158, abbr: '30C', date: '2026-09-16'),
    };
  });

  test('a set released after the bundle was built becomes resolvable', () async {
    expect(SetResolver(catalog.setsFor('en')).byCode('30C'), isNull);

    final r = await refresher().refresh('en');

    expect(r.status, RefreshStatus.checked);
    expect(r.added.single.id, '30th');
    final resolver = SetResolver(catalog.setsFor('en'));
    expect(resolver.byCode('30C')?.id, '30th');
    expect(resolver.resolve(number: '045', total: 128).single.cardIdFor('045'), '30th-045');
  });

  test('only unknown sets get their detail fetched', () async {
    await refresher().refresh('en');
    expect(requests, ['list:en', 'set:en:30th'], reason: 'sv04 is already known');
  });

  test('checks at most about once a day', () async {
    final r = refresher();
    await r.refresh('en');
    requests.clear();

    now = now.add(const Duration(hours: 3));
    expect((await r.refresh('en')).status, RefreshStatus.skipped);
    expect(requests, isEmpty);

    now = now.add(const Duration(hours: 20));
    expect((await r.refresh('en')).status, RefreshStatus.checked);
    expect(requests, ['list:en'], reason: 'nothing new, so one request and done');
  });

  test('force ignores the interval — the pull-to-refresh path', () async {
    final r = refresher();
    await r.refresh('en');
    requests.clear();
    await r.refresh('en', force: true);
    expect(requests, ['list:en']);
  });

  test('found sets survive a restart and resolve offline', () async {
    await refresher().refresh('en');

    // A new session: fresh catalogue, same local store, no network at all.
    catalog = SetCatalog(bundled: {'en': bundled, 'ja': const []});
    listFails = true;
    final r = refresher();
    await r.restore('en');

    expect(SetResolver(catalog.setsFor('en')).byCode('30C')?.id, '30th');
  });

  test('offline changes nothing and throws nothing', () async {
    listFails = true;
    final r = await refresher().refresh('en');
    expect(r.status, RefreshStatus.offline);
    expect(catalog.extrasFor('en'), isEmpty);
  });

  test('a set whose card count grew is refetched, and stays "new"', () async {
    await refresher().refresh('en');
    final firstSeen = catalog.extrasFor('en').single.firstSeenAt;
    expect(firstSeen, isNotNull);

    // TCGdex fills a new set in over several days.
    now = now.add(const Duration(days: 2));
    remoteList = [brief('sv04', 182, 266), brief('30th', 128, 170)];
    remoteDetails['30th'] = detail('30th', '30th Celebration', 128, 170, abbr: '30C');

    final r = await refresher().refresh('en', force: true);
    expect(r.updated.single.total, 170);
    expect(catalog.extrasFor('en').single.firstSeenAt, firstSeen,
        reason: 'the NEW badge must not reset every time a card is added');
  });

  test('a failed detail keeps what arrived and retries next launch', () async {
    remoteList = [...remoteList, brief('30th-c', 0, 30)];
    remoteDetails['30th-c'] = detail('30th-c', '30th Classic Collection', 0, 30, abbr: '30C');
    failingDetails = {'30th-c'};

    final first = refresher();
    expect((await first.refresh('en')).status, RefreshStatus.partial);
    expect(catalog.extrasFor('en').map((s) => s.id), ['30th']);
    expect(catalog.checkedAt('en'), isNull, reason: 'so the next launch does not skip');

    failingDetails = {};
    requests.clear();
    final second = refresher();
    expect((await second.refresh('en')).status, RefreshStatus.checked);
    expect(requests, ['list:en', 'set:en:30th-c'], reason: 'only what was missing');
  });

  test('never fires more than the per-run cap at the host', () async {
    remoteList = [for (var i = 0; i < 60; i++) brief('new$i', 10, 10)];
    remoteDetails = {for (var i = 0; i < 60; i++) 'new$i': detail('new$i', 'New $i', 10, 10)};

    final r = await SetIndexRefresher(
      catalog: catalog,
      now: () => now,
      fetchList: (lang) async => remoteList,
      fetchSet: (lang, id) async {
        requests.add(id);
        return remoteDetails[id]!;
      },
      load: (lang) async => store[lang],
      save: (lang, sets, at) async => store[lang] = StoredSets(sets, at),
      maxDetailsPerRun: 25,
    ).refresh('en');

    expect(requests.length, 25);
    expect(r.status, RefreshStatus.partial, reason: 'the rest come on the next launch');
  });
}
