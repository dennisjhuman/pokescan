import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'shared/utils/persistent_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire and forget: the app is usable either way, and a refusal only means
  // the browser may evict the collection under storage pressure.
  unawaited(requestPersistentStorage());
  runApp(const ProviderScope(child: PokeScanApp()));
}
