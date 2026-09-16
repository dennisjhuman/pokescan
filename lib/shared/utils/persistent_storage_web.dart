import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Returns whether storage is persistent after asking.
///
/// Safari grants this without a prompt for installed web apps and usually
/// refuses it for a plain tab, which is precisely the behaviour we want: the
/// home-screen install is the durable one. A refusal is not an error, so the
/// caller only logs it.
Future<bool> requestPersistentStorage() async {
  try {
    final manager = web.window.navigator.storage;
    final already = (await manager.persisted().toDart).toDart;
    if (already) return true;
    return (await manager.persist().toDart).toDart;
  } catch (_) {
    // Older browsers have no StorageManager at all.
    return false;
  }
}
