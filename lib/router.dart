import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'screens/info_screen.dart';
import 'screens/main_screen.dart';
import 'screens/search_screen.dart';
import 'screens/species_screen.dart';
import 'screens/splash_screen.dart';

final appRouter = GoRouter(
  observers: [],
  initialLocation: kIsWeb ? '/' : '/splash',
  debugLogDiagnostics: true, // logs every route change to the console
  errorBuilder: (context, state) {
    WidgetsBinding.instance.addPostFrameCallback((_) => context.go('/'));
    return const SizedBox.shrink();
  },
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/info',
      builder: (context, state) => const InfoScreen(),
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
      routes: [
        GoRoute(
          path: 'species/:id',
          builder: (context, state) => const SpeciesScreen(),
        ),
      ],
    ),
    GoRoute(
      path: '/browse',
      builder: (context, state) {
        final p = state.uri.queryParameters;
        return _StateInitializer(
          region: int.tryParse(p['region'] ?? '') ?? 0,
          supercat: p['supercat'] ?? 'Fish',
          category: p['category'],
          child: const MainScreen(),
        );
      },
      routes: [
        GoRoute(
          path: 'species/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            final p = state.uri.queryParameters;
            return _StateInitializer(
              region: int.tryParse(p['region'] ?? '') ?? 0,
              supercat: p['supercat'] ?? 'Fish',
              category: p['category'],
              speciesId: id,
              child: const SpeciesScreen(),
            );
          },
        ),
      ],
    ),
  ],
);

/// Initialises [AppState] from URL parameters before the child screen renders.
///
/// For species routes: only calls [AppState.openSpecies] when the URL species
/// differs from what is already loaded — this preserves the ordered list that
/// was built by the species-list screen during normal in-app navigation.
class _StateInitializer extends StatefulWidget {
  final int region;
  final String supercat;
  final String? category;
  final String? speciesId;
  final Widget child;

  const _StateInitializer({
    required this.region,
    required this.supercat,
    this.category,
    this.speciesId,
    required this.child,
  });

  @override
  State<_StateInitializer> createState() => _StateInitializerState();
}

class _StateInitializerState extends State<_StateInitializer> {
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;

    final appState = context.read<AppState>();

    // setRegion / setSuperCat have built-in no-op guards.
    appState.setRegion(widget.region);
    appState.setSuperCat(widget.supercat);

    if (widget.category != null &&
        widget.category != appState.selectedCategory) {
      appState.setCategory(widget.category!);
    }

    // Only override the species list when the URL species differs from what
    // is already active (i.e. this is a deep link, not normal navigation).
    if (widget.speciesId != null &&
        appState.currentSpeciesId != widget.speciesId) {
      appState.openSpecies(widget.speciesId!, [widget.speciesId!]);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
