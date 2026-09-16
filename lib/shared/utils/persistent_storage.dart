/// Ask the browser to keep the collection when storage gets tight.
///
/// Browsers treat IndexedDB as evictable by default, and Safari is aggressive
/// about clearing script-writable storage. A granted persistence request means
/// the collection is only removed if the user clears it themselves. No-op
/// everywhere except the web.
library;

export 'persistent_storage_stub.dart' if (dart.library.js_interop) 'persistent_storage_web.dart';
