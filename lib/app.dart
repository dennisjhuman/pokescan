import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme.dart';
import 'features/card_detail/card_detail_screen.dart';
import 'features/collection/collection_screen.dart';
import 'features/scan/scan_screen.dart';

final _router = GoRouter(
  initialLocation: '/scan',
  // Nothing is served at "/", but a reload, a bookmark or an Add to Home
  // Screen launch can land there — and go_router answered that with its
  // "Page Not Found" screen, which looks like the app is broken.
  redirect: (_, state) => state.uri.path == '/' ? '/scan' : null,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => _HomeShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/scan', builder: (_, _) => const ScanScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/collection', builder: (_, _) => const CollectionScreen()),
        ]),
      ],
    ),
    GoRoute(
      path: '/card/:id',
      // go_router hands path parameters back decoded, so `ja%3AM6-058` arrives
      // as `ja:M6-058`. Decoding again would be harmless for every real key
      // but is not needed.
      builder: (_, state) => CardDetailScreen(cardId: state.pathParameters['id']!),
    ),
  ],
);

class PokeScanApp extends StatelessWidget {
  const PokeScanApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'PokéScan',
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        routerConfig: _router,
      );
}

class _HomeShell extends StatelessWidget {
  const _HomeShell({required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: NavigationBar(
          selectedIndex: shell.currentIndex,
          onDestinationSelected: (i) =>
              shell.goBranch(i, initialLocation: i == shell.currentIndex),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.document_scanner_outlined), label: 'Scan'),
            NavigationDestination(icon: Icon(Icons.style_outlined), label: 'Collection'),
          ],
        ),
      );
}
