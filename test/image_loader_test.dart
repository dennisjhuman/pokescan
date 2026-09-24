import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pokescan/shared/utils/image_loader.dart';

/// The asset host answers 62 simultaneous requests with 44 failures, so these
/// tests are about not asking for 62 at once and about coming back from the
/// failures that still happen.
void main() {
  Uint8List bytes(int n) => Uint8List.fromList(List.filled(n, 7));

  /// No real waiting: the loader's sleep is replaced, and the delays it asks
  /// for are recorded so the backoff curve can be asserted on.
  ({ImageLoader loader, List<Duration> slept}) loaderWith(
    Future<http.Response> Function(http.Request) handler, {
    int maxConcurrent = 5,
    int maxAttempts = 4,
  }) {
    final slept = <Duration>[];
    final loader = ImageLoader(
      client: MockClient(handler),
      maxConcurrent: maxConcurrent,
      maxAttempts: maxAttempts,
      sleep: (d) async => slept.add(d),
      random: Random(1),
    );
    return (loader: loader, slept: slept);
  }

  group('concurrency gate', () {
    test('never has more than maxConcurrent requests in flight', () async {
      var inFlight = 0;
      var peak = 0;
      final gates = <Completer<void>>[];

      final l = loaderWith((req) async {
        inFlight++;
        peak = max(peak, inFlight);
        final gate = Completer<void>();
        gates.add(gate);
        await gate.future;
        inFlight--;
        return http.Response.bytes(bytes(10), 200);
      }, maxConcurrent: 5);

      final all = [for (var i = 0; i < 62; i++) l.loader.load('https://x/$i')];
      await Future<void>.delayed(Duration.zero);
      expect(peak, lessThanOrEqualTo(5), reason: 'this is the whole fix');

      // Let them drain, opening gates as they appear.
      while (gates.isNotEmpty) {
        gates.removeAt(0).complete();
        await Future<void>.delayed(Duration.zero);
      }
      await Future.wait(all);
      expect(peak, 5);
    });

    test('ten tiles wanting the same picture make one request', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        return http.Response.bytes(bytes(10), 200);
      });

      final results =
          await Future.wait([for (var i = 0; i < 10; i++) l.loader.load('https://x/same')]);
      expect(calls, 1);
      expect(results.every((r) => r != null), isTrue);
    });
  });

  group('retry', () {
    test('a 503 is retried and can succeed', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        return calls < 3
            ? http.Response('busy', 503)
            : http.Response.bytes(bytes(10), 200);
      });

      expect(await l.loader.load('https://x/1'), isNotNull);
      expect(calls, 3);
      expect(l.slept.length, 2, reason: 'one wait between each attempt');
    });

    test('backoff grows and is jittered', () {
      final r = Random(42);
      final first = ImageLoader.backoffFor(1, r).inMilliseconds;
      final third = ImageLoader.backoffFor(3, r).inMilliseconds;
      expect(first, inInclusiveRange(100, 300));
      expect(third, inInclusiveRange(400, 1200));

      // Jitter: two draws for the same attempt must not be identical, or
      // sixty failed tiles would all retry on the same tick.
      final a = ImageLoader.backoffFor(2, Random(1));
      final b = ImageLoader.backoffFor(2, Random(2));
      expect(a, isNot(b));
    });

    test('gives up after maxAttempts and remembers the failure', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        return http.Response('busy', 503);
      }, maxAttempts: 3);

      expect(await l.loader.load('https://x/1'), isNull);
      expect(calls, 3);
      expect(l.loader.hasFailed('https://x/1'), isTrue);

      // A remembered failure costs nothing on the next scroll.
      expect(await l.loader.load('https://x/1'), isNull);
      expect(calls, 3);

      // ...until the user asks for a retry.
      l.loader.retryFailures();
      expect(await l.loader.load('https://x/1'), isNull);
      expect(calls, 6);
    });

    test('a 404 is an answer, not something to retry', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        return http.Response('gone', 404);
      });

      expect(await l.loader.load('https://x/missing'), isNull);
      expect(calls, 1, reason: 'a lot of sets genuinely have no logo');
      expect(l.loader.isMissing('https://x/missing'), isTrue);

      // A user-requested retry is for busy servers; it does not re-ask for
      // art the host has said it does not have.
      l.loader.retryFailures();
      expect(await l.loader.load('https://x/missing'), isNull);
      expect(calls, 1);
    });

    test('a 400 is final too — the broken symbol bucket must not hog slots', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        return http.Response('<Error><Code>InvalidBucketName</Code></Error>', 400);
      });
      expect(await l.loader.load('https://x/symbol.webp'), isNull);
      expect(calls, 1);
    });

    test('429 and 408 mean "later", so they are retried', () {
      expect(ImageLoader.isPermanentFailure(429), isFalse);
      expect(ImageLoader.isPermanentFailure(408), isFalse);
      expect(ImageLoader.isPermanentFailure(503), isFalse);
      expect(ImageLoader.isPermanentFailure(404), isTrue);
      expect(ImageLoader.isPermanentFailure(400), isTrue);
    });

    test('a 503 that gives up is a failure, not "missing"', () async {
      final l = loaderWith((req) async => http.Response('busy', 503), maxAttempts: 2);
      expect(await l.loader.load('https://x/busy'), isNull);
      expect(l.loader.isMissing('https://x/busy'), isFalse,
          reason: 'the tile should offer a retry, not say there is no art');
    });

    test('a guessed URL gets one try, not four', () async {
      // In a browser an absent file on the asset host looks like a network
      // error (no CORS headers on its 404), so a guess that fails is almost
      // always simply absent. Four backed-off tries would only waste slots.
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        throw const SocketExceptionLike();
      });
      expect(await l.loader.load('https://x/guess', speculative: true), isNull);
      expect(calls, 1);
    });

    test('an empty 200 counts as a failure', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        return calls == 1
            ? http.Response.bytes(Uint8List(0), 200)
            : http.Response.bytes(bytes(10), 200);
      });

      expect(await l.loader.load('https://x/1'), isNotNull);
      expect(calls, 2);
    });

    test('a thrown connection error is retried', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        if (calls == 1) throw const SocketExceptionLike();
        return http.Response.bytes(bytes(10), 200);
      });

      expect(await l.loader.load('https://x/1'), isNotNull);
      expect(calls, 2);
    });
  });

  group('byte cache', () {
    test('a cached url is served without touching the network', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        return http.Response.bytes(bytes(10), 200);
      });

      await l.loader.load('https://x/1');
      expect(l.loader.cached('https://x/1'), isNotNull);
      await l.loader.load('https://x/1');
      expect(calls, 1, reason: 'scrolling back must not re-request');
    });

    test('evicts least recently used once over the ceiling', () {
      final c = ImageByteCache(maxBytes: 100);
      c.put('a', bytes(40));
      c.put('b', bytes(40));
      c.get('a'); // 'a' is now the most recent, so 'b' should go first
      c.put('c', bytes(40));

      expect(c.get('a'), isNotNull);
      expect(c.get('b'), isNull);
      expect(c.get('c'), isNotNull);
      expect(c.byteCount, lessThanOrEqualTo(100));
    });

    test('replacing a url does not double-count its bytes', () {
      final c = ImageByteCache(maxBytes: 1000);
      c.put('a', bytes(40));
      c.put('a', bytes(60));
      expect(c.length, 1);
      expect(c.byteCount, 60);
    });
  });

  group('a 400 writes off the whole bucket', () {
    // TCGdex's set-symbol bucket has answered `400 InvalidBucketName` for every
    // set since 2026-09-21, old ones included. A 400 there is the bucket, not
    // the file, so the ~220 symbols in the set list are 220 requests whose
    // answer is already known — and 220 console errors.
    const symbol = 'https://assets.tcgdex.net/univ/swsh/swsh3/symbol.webp';
    const otherSymbol = 'https://assets.tcgdex.net/univ/sv/sv10/symbol.webp';
    const cardArt = 'https://assets.tcgdex.net/en/swsh/swsh3/20/low.webp';

    test('a second symbol is never requested after the first 400', () async {
      final asked = <String>[];
      final l = loaderWith((req) async {
        asked.add(req.url.toString());
        return http.Response('InvalidBucketName', 400);
      });

      expect(await l.loader.load(symbol), isNull);
      expect(await l.loader.load(otherSymbol), isNull);

      expect(asked, [symbol], reason: 'the second symbol should not be fetched');
      expect(l.loader.isUnderDeadBucket(otherSymbol), isTrue);
      expect(l.loader.hasFailed(otherSymbol), isTrue);
    });

    test('card art is unaffected: a different bucket', () async {
      final asked = <String>[];
      final l = loaderWith((req) async {
        asked.add(req.url.toString());
        return req.url.path.contains('symbol')
            ? http.Response('InvalidBucketName', 400)
            : http.Response.bytes(bytes(10), 200);
      });

      await l.loader.load(symbol);
      expect(await l.loader.load(cardArt), isNotNull);
      expect(asked, [symbol, cardArt]);
      expect(l.loader.isUnderDeadBucket(cardArt), isFalse);
    });

    test('a retry gives the bucket another chance', () async {
      var calls = 0;
      final l = loaderWith((req) async {
        calls++;
        return http.Response('InvalidBucketName', 400);
      });

      await l.loader.load(symbol);
      await l.loader.load(otherSymbol);
      expect(calls, 1);

      l.loader.retryFailures();
      await l.loader.load(otherSymbol);
      expect(calls, 2, reason: 'TCGdex may have fixed the bucket by now');
    });

    test('a 404 writes off only that file', () async {
      final asked = <String>[];
      final l = loaderWith((req) async {
        asked.add(req.url.toString());
        return http.Response('', 404);
      });

      await l.loader.load('https://assets.tcgdex.net/en/me/30th-c/001/low.webp');
      await l.loader.load('https://assets.tcgdex.net/en/me/30th-c/002/low.webp');
      expect(asked.length, 2, reason: 'absent art is per-card, not per-bucket');
    });
  });
}

/// Stand-in for a connection failure; the loader only cares that it throws.
class SocketExceptionLike implements Exception {
  const SocketExceptionLike();
}
