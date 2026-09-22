/// Fetching card images without getting throttled.
///
/// `assets.tcgdex.net` sheds load aggressively. Measured 2026-09-20, with
/// plain curl and no browser involved:
///
///     62 concurrent GETs  ->  18 × 200, 44 × 503
///
/// A set grid asks for roughly that many images the moment it opens, so most
/// tiles used to come back empty. Worse, the image widget cached the failure,
/// so a tile that scrolled out of view and back never recovered — the
/// "artwork disappears when I scroll past" bug.
///
/// Three things fix it, and all three are needed:
///
///  * a concurrency gate, so the host is never handed more than it will serve;
///  * retry with backoff, because a 503 here means "later", not "never";
///  * keeping the bytes, so scrolling back is free and never re-requests.
///
/// Pure Dart apart from the http client — see `test/image_loader_test.dart`.
library;

import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Bytes for one image, or null if we gave up.
typedef ImageFetch = Future<Uint8List?>;

/// LRU byte cache with a ceiling, so a long browse can't grow without bound.
class ImageByteCache {
  ImageByteCache({this.maxBytes = 48 * 1024 * 1024});

  /// Card thumbnails are ~18 KB each, so this holds a couple of thousand of
  /// them — comfortably more than anyone scrolls through in one sitting.
  final int maxBytes;

  final _entries = <String, Uint8List>{};
  int _bytes = 0;

  int get byteCount => _bytes;
  int get length => _entries.length;

  Uint8List? get(String url) {
    final hit = _entries.remove(url);
    if (hit == null) return null;
    _entries[url] = hit; // reinsert = most recently used
    return hit;
  }

  void put(String url, Uint8List bytes) {
    final existing = _entries.remove(url);
    if (existing != null) _bytes -= existing.length;
    _entries[url] = bytes;
    _bytes += bytes.length;
    while (_bytes > maxBytes && _entries.isNotEmpty) {
      final oldest = _entries.keys.first;
      _bytes -= _entries.remove(oldest)!.length;
    }
  }

  void clear() {
    _entries.clear();
    _bytes = 0;
  }
}

/// Serialises image fetches so the asset host is never flooded, retries the
/// ones it sheds, and remembers the bytes.
class ImageLoader {
  ImageLoader({
    http.Client? client,
    this.maxConcurrent = 5,
    this.maxAttempts = 4,
    ImageByteCache? cache,
    Future<void> Function(Duration)? sleep,
    Random? random,
  })  : _client = client ?? http.Client(),
        _cache = cache ?? ImageByteCache(),
        _sleep = sleep ?? Future<void>.delayed,
        _random = random ?? Random();

  final http.Client _client;
  final ImageByteCache _cache;
  final Future<void> Function(Duration) _sleep;
  final Random _random;

  /// Five at a time keeps us inside what the host will serve. It is below the
  /// browser's own six-per-host limit on purpose: the point is to be polite,
  /// not to saturate.
  final int maxConcurrent;

  /// One try plus three retries. A 503 from this host clears in a second or
  /// two; beyond four attempts we are just making its day worse.
  final int maxAttempts;

  int _inFlight = 0;
  final _waiting = Queue<Completer<void>>();

  /// In-flight requests by url, so ten tiles asking for the same picture make
  /// one request between them.
  final _pending = <String, ImageFetch>{};

  /// Urls that failed every attempt. Kept so a dead image is not retried on
  /// every scroll, but cleared by [retryFailures] when the user asks.
  final _failed = <String>{};

  /// Urls the host answered with 404: the art is not there, which retrying
  /// will not change. Kept apart from [_failed] so the UI can say "no artwork
  /// yet" instead of offering a retry, and so a retry does not re-ask.
  final _missing = <String>{};

  ImageByteCache get cache => _cache;
  bool hasFailed(String url) => _failed.contains(url) || _missing.contains(url);

  /// The host says this image does not exist.
  bool isMissing(String url) => _missing.contains(url);

  /// Bytes if we already have them, without touching the network. Lets a
  /// widget paint immediately on scroll-back instead of flashing a spinner.
  Uint8List? cached(String url) => _cache.get(url);

  /// [speculative] marks a URL we guessed (the card data listed no image).
  /// It gets fewer attempts: most guesses that fail are simply absent, and in
  /// a browser an absent file cannot be told apart from a network error —
  /// the asset host sends no CORS headers on a 404, so the browser reports a
  /// failed fetch instead of the status.
  ImageFetch load(String url, {bool speculative = false}) {
    final hit = _cache.get(url);
    if (hit != null) return Future.value(hit);
    if (_failed.contains(url) || _missing.contains(url)) return Future.value(null);
    // The braces matter: `whenComplete` waits on whatever its callback
    // returns, and `_pending.remove` hands back the very future being
    // awaited — an arrow body here deadlocks every image in the app.
    return _pending[url] ??=
        _fetch(url, attempts: speculative ? 2 : maxAttempts).whenComplete(() {
      _pending.remove(url);
    });
  }

  /// Forget past failures so the next build tries again.
  void retryFailures() => _failed.clear();

  Future<Uint8List?> _fetch(String url, {required int attempts}) async {
    for (var attempt = 1; attempt <= attempts; attempt++) {
      await _acquire();
      http.Response? res;
      try {
        res = await _client.get(Uri.parse(url));
      } catch (_) {
        // Network blip: falls through to the retry below.
      } finally {
        _release();
      }

      if (res != null && res.statusCode == 200 && res.bodyBytes.isNotEmpty) {
        final bytes = res.bodyBytes;
        _cache.put(url, bytes);
        return bytes;
      }
      // A 4xx is an answer, not a hiccup: 404 means this set has no logo or
      // this card has no scan, and 400 is what every set symbol returns while
      // TCGdex's symbol bucket is misconfigured (`InvalidBucketName`, seen
      // 2026-09-21). Retrying either only ties up a slot that card art needs —
      // with ~220 symbols in the set list, that was hundreds of doomed
      // requests queued ahead of the pictures. 408 and 429 mean "later".
      if (res != null && isPermanentFailure(res.statusCode)) {
        _missing.add(url);
        return null;
      }
      if (attempt < attempts) await _sleep(backoffFor(attempt, _random));
    }
    _failed.add(url);
    return null;
  }

  static bool isPermanentFailure(int status) =>
      status >= 400 && status < 500 && status != 408 && status != 429;

  /// Exponential with jitter: 200ms, 400ms, 800ms, each ±50%. The jitter
  /// matters more than the curve here — sixty tiles that all failed together
  /// must not all retry on the same tick, or they just re-create the flood
  /// that caused the failure.
  static Duration backoffFor(int attempt, [Random? random]) {
    final base = 200 * (1 << (attempt - 1));
    final jitter = ((random ?? Random()).nextDouble() - 0.5) * base;
    return Duration(milliseconds: (base + jitter).round());
  }

  Future<void> _acquire() {
    if (_inFlight < maxConcurrent) {
      _inFlight++;
      return Future.value();
    }
    final waiter = Completer<void>();
    _waiting.add(waiter);
    return waiter.future;
  }

  void _release() {
    if (_waiting.isNotEmpty) {
      _waiting.removeFirst().complete();
      return;
    }
    _inFlight--;
  }

  void close() => _client.close();
}

/// One loader for the whole app: the concurrency gate only works if every
/// image goes through the same one.
final imageLoader = ImageLoader();
