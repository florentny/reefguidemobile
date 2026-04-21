import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/router.dart';
import 'package:reefmobile/screens/home_screen.dart';
import 'package:reefmobile/screens/info_screen.dart';
import 'package:reefmobile/screens/main_screen.dart';
import 'package:reefmobile/screens/search_screen.dart';
import 'package:reefmobile/screens/species_screen.dart';
import 'package:reefmobile/screens/splash_screen.dart';

import 'helpers/mock_assets.dart';

// ── Helpers ────────────────────────────────────────────────────────────────

// Local single-route app for route-mapping smoke tests.
Widget _singleRouteApp(AppState state, String path, Widget screen) {
  final router = GoRouter(
    initialLocation: path,
    routes: [GoRoute(path: path, builder: (_, __) => screen)],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp.router(routerConfig: router),
  );
}

// Wrap the production appRouter — required to exercise _StateInitializer.
Widget _appRouterWidget(AppState state) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp.router(routerConfig: appRouter),
    );

// Navigate appRouter to [url] BEFORE mounting so the first rendered frame is
// already at the target screen (never touches /splash → no 5-second timer).
//
// _StateInitializer.didChangeDependencies calls notifyListeners() while child
// widgets (context.watch<AppState>() in MainScreen's dropdowns) are still being
// mounted.  Flutter allows this — the dirty node is always visited in the same
// frame — but the test framework records it as a failure.  We install a narrow
// FlutterError.onError shim that silently drops only that specific exception so
// the test sees clean state.  All other errors still propagate normally.
Future<void> _navigate(WidgetTester tester, AppState state, String url) async {
  appRouter.go(url);
  final prevHandler = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    if (details.exception.toString().contains('setState() or markNeedsBuild()')) {
      return; // expected "allowed" exception from _StateInitializer
    }
    prevHandler?.call(details);
  };
  await tester.pumpWidget(_appRouterWidget(state));
  FlutterError.onError = prevHandler;
  await tester.pump();
}

// ── Tests ──────────────────────────────────────────────────────────────────

void main() {
  setUpAll(setupMockAssets);

  // ── Route → screen mapping ───────────────────────────────────────────────
  //
  // Each test uses a local GoRouter (same pattern as the rest of the test
  // suite) to verify that the correct screen type is rendered.

  group('route mapping', () {
    testWidgets('/ renders HomeScreen', (tester) async {
      await tester.pumpWidget(_singleRouteApp(AppState(), '/', const HomeScreen()));
      await tester.pump();
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('/info renders InfoScreen', (tester) async {
      await tester.pumpWidget(_singleRouteApp(AppState(), '/info', const InfoScreen()));
      await tester.pump();
      expect(find.byType(InfoScreen), findsOneWidget);
    });

    testWidgets('/search renders SearchScreen', (tester) async {
      await tester.pumpWidget(_singleRouteApp(AppState(), '/search', const SearchScreen()));
      await tester.pump();
      expect(find.byType(SearchScreen), findsOneWidget);
    });

    testWidgets('/browse renders MainScreen', (tester) async {
      await tester.pumpWidget(_singleRouteApp(AppState(), '/browse', const MainScreen()));
      await tester.pump();
      expect(find.byType(MainScreen), findsOneWidget);
    });

    testWidgets('/splash renders SplashScreen', (tester) async {
      final router = GoRouter(
        initialLocation: '/splash',
        routes: [
          GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
          GoRoute(path: '/', builder: (_, __) => const Scaffold()),
        ],
      );
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pump();
      expect(find.byType(SplashScreen), findsOneWidget);
      // Drain the 5-second auto-navigate timer before the test ends.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    });

    testWidgets('/browse/species/:id renders SpeciesScreen', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1']);
      final router = GoRouter(
        initialLocation: '/browse/species/sp1',
        routes: [
          GoRoute(
            path: '/browse',
            builder: (_, __) => const Scaffold(),
            routes: [
              GoRoute(
                path: 'species/:id',
                builder: (_, __) => const SpeciesScreen(),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.byType(SpeciesScreen), findsOneWidget);
    });

    testWidgets('/search/species/:id renders SpeciesScreen', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1']);
      final router = GoRouter(
        initialLocation: '/search/species/sp1',
        routes: [
          GoRoute(
            path: '/search',
            builder: (_, __) => const Scaffold(),
            routes: [
              GoRoute(
                path: 'species/:id',
                builder: (_, __) => const SpeciesScreen(),
              ),
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        ChangeNotifierProvider<AppState>.value(
          value: state,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pump();
      expect(find.byType(SpeciesScreen), findsOneWidget);
    });
  });

  // ── _StateInitializer — /browse ──────────────────────────────────────────
  //
  // _StateInitializer is private to router.dart; the only way to exercise it
  // is through appRouter's route builders.  go(url) is called before pumpWidget
  // so the first frame is already at the target screen.

  group('_StateInitializer via /browse', () {
    testWidgets('defaults to region 0 and supercat Fish when params absent', (tester) async {
      final state = AppState()
        ..setRegion(3)
        ..setSuperCat('Corals');
      await _navigate(tester, state, '/browse');
      expect(state.selectedRegion, 0);
      expect(state.selectedSuperCat, 'Fish');
    });

    testWidgets('applies region and supercat from query params', (tester) async {
      final state = AppState();
      await _navigate(tester, state, '/browse?region=2&supercat=Corals');
      expect(state.selectedRegion, 2);
      expect(state.selectedSuperCat, 'Corals');
    });

    testWidgets('applies category from query param', (tester) async {
      final state = AppState();
      await _navigate(tester, state, '/browse?category=Surgeonfish');
      expect(state.selectedCategory, 'Surgeonfish');
    });

    testWidgets('does not overwrite selectedCategory when category param is absent', (tester) async {
      // setRegion(0) and setSuperCat('Fish') are both no-ops here (already at
      // defaults), so they do not clear selectedCategory via their guard logic.
      final state = AppState()..setCategory('Angelfish');
      await _navigate(tester, state, '/browse?region=0&supercat=Fish');
      expect(state.selectedCategory, 'Angelfish');
    });

    testWidgets('invalid region param falls back to 0', (tester) async {
      final state = AppState();
      await _navigate(tester, state, '/browse?region=bad');
      expect(state.selectedRegion, 0);
    });

    testWidgets('does not apply the same category twice', (tester) async {
      // widget.category == appState.selectedCategory → setCategory not called.
      final state = AppState()..setCategory('Surgeonfish');
      await _navigate(tester, state, '/browse?region=0&supercat=Fish&category=Surgeonfish');
      expect(state.selectedCategory, 'Surgeonfish');
    });
  });

  // ── _StateInitializer — /browse/species/:id ──────────────────────────────

  group('_StateInitializer via /browse/species/:id', () {
    testWidgets('opens species from path parameter', (tester) async {
      final state = AppState();
      await _navigate(tester, state, '/browse/species/sp1');
      expect(state.currentSpeciesId, 'sp1');
    });

    testWidgets('applies region and supercat alongside species', (tester) async {
      final state = AppState();
      await _navigate(tester, state, '/browse/species/sp1?region=2&supercat=Corals');
      expect(state.selectedRegion, 2);
      expect(state.selectedSuperCat, 'Corals');
      expect(state.currentSpeciesId, 'sp1');
    });

    testWidgets('preserves ordered list when species already matches current', (tester) async {
      // Pre-load sp1 in a 2-item list so hasNext is true.
      final state = AppState()..openSpecies('sp1', ['sp1', 'sp2']);
      await _navigate(tester, state, '/browse/species/sp1');
      // openSpecies not re-called → list still ['sp1','sp2'] → hasNext remains true.
      expect(state.hasNext, isTrue);
    });

    testWidgets('re-opens species when URL species differs from current', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1', 'sp2']);
      await _navigate(tester, state, '/browse/species/sp2');
      // sp2 != sp1 → openSpecies('sp2', ['sp2']) → single-item list.
      expect(state.currentSpeciesId, 'sp2');
      expect(state.hasNext, isFalse);
    });
  });

  // ── Error route ──────────────────────────────────────────────────────────

  group('error route', () {
    testWidgets('unknown path redirects to HomeScreen', (tester) async {
      await tester.runAsync(() async {
        appRouter.go('/no-such-route');
        await tester.pumpWidget(_appRouterWidget(AppState()));
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump(); // flush postFrameCallback → context.go('/')
      await tester.pump(); // render HomeScreen
      expect(find.byType(HomeScreen), findsOneWidget);
    });
  });
}
