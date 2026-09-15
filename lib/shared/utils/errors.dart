import 'dart:io';

import '../../data/tcgdex/tcgdex_client.dart';

/// Human-friendly one-liner for a thrown error.
String describeError(Object e) {
  if (e is TcgdexException) {
    return e.isNotFound ? 'Card not found. Check the set code and number.' : 'TCGdex error: ${e.message}';
  }
  if (e is SocketException) return 'No connection. Cached cards still work offline.';
  return 'Something went wrong: $e';
}
