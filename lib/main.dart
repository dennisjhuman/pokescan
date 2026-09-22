import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'data/providers.dart';
import 'shared/utils/persistent_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Fire and forget: the app is usable either way, and a refusal only means
  // the browser may evict the collection under storage pressure.
  unawaited(requestPersistentStorage());

  final container = ProviderContainer();
  // Restores sets found on earlier launches, then checks TCGdex for new ones
  // in the background. The first frame does not wait for it.
  unawaited(container.read(setCatalogBootstrapProvider.future));
  runApp(UncontrolledProviderScope(container: container, child: const PokeScanApp()));
}
