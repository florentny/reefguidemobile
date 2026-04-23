import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/screens/species_screen.dart';

import '../helpers/mock_assets.dart';

// Plain MaterialApp — fine for display tests where context.pop() is never called.
// Portrait MediaQuery override needed: the default 800×600 test viewport is
// landscape, which causes _SpeciesDetail to render _LandscapePhotoView instead
// of the portrait Scaffold with _NameHeader and _DetailsSection.
Widget _buildApp(AppState state) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(600, 900)),
          child: const SpeciesScreen(),
        ),
      ),
    );

// GoRouter wrapper — required when speciesId is null because SpeciesScreen calls
// context.canPop() in a postFrameCallback.
Widget _buildWithRouter(AppState state) {
  final router = GoRouter(
    routes: [GoRoute(path: '/', builder: (_, __) => const SpeciesScreen())],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp.router(routerConfig: router),
  );
}

Future<void> _mount(WidgetTester tester, AppState state) async {
  await tester.runAsync(() async {
    await tester.pumpWidget(_buildApp(state));
    await Future.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  await tester.pump();
}

// Finds the ElevatedButton whose child label matches [label].
Finder _navBtn(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(ElevatedButton),
    );

void main() {
  setUpAll(setupMockAssets);

  group('SpeciesScreen', () {
    testWidgets('shows loading indicator when currentSpeciesId is null', (tester) async {
      // speciesId == null branch calls context.canPop() — requires GoRouter.
      await tester.pumpWidget(_buildWithRouter(AppState()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pump(); // flush postFrameCallback
    });

    testWidgets('shows CircularProgressIndicator while data loads', (tester) async {
      await tester.runAsync(() async {
        final state = AppState()..openSpecies('sp1', ['sp1']);
        await tester.pumpWidget(_buildApp(state));
        expect(find.byType(CircularProgressIndicator), findsAtLeastNWidgets(1));
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();
    });

    testWidgets('renders common name and scientific name', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1']);
      await _mount(tester, state);
      expect(find.text('Blue Tang'), findsOneWidget);
      expect(find.text('Acanthurus coeruleus'), findsOneWidget);
    });

    testWidgets('renders size and depth detail rows', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1']);
      await _mount(tester, state);
      expect(find.textContaining('25cm', findRichText: true), findsOneWidget);
      expect(find.textContaining('1-40m', findRichText: true), findsOneWidget);
    });

    testWidgets('renders the photo caption for the first photo', (tester) async {
      // sp1 has one photo: location "Caribbean", type "Adult".
      final state = AppState()..openSpecies('sp1', ['sp1']);
      await _mount(tester, state);
      expect(find.text('Caribbean  -  Adult'), findsOneWidget);
    });

    testWidgets('shows "Species not found" for an unknown species id', (tester) async {
      final state = AppState()..openSpecies('does-not-exist', ['does-not-exist']);
      await _mount(tester, state);
      expect(find.text('Species not found'), findsOneWidget);
    });

    testWidgets('AppBar back button is always present', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1']);
      await _mount(tester, state);
      expect(find.text('<'), findsOneWidget);
    });

    testWidgets('prev ∧ button is disabled at the start of the list', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1', 'sp2']); // index 0
      await _mount(tester, state);
      final btn = tester.widget<ElevatedButton>(_navBtn('\u2227').first);
      expect(btn.onPressed, isNull);
    });

    testWidgets('next ∨ button is disabled with only one species', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1']);
      await _mount(tester, state);
      final btn = tester.widget<ElevatedButton>(_navBtn('\u2228').first);
      expect(btn.onPressed, isNull);
    });

    testWidgets('next ∨ button is enabled when more species follow', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1', 'sp2']);
      await _mount(tester, state);
      final btn = tester.widget<ElevatedButton>(_navBtn('\u2228').first);
      expect(btn.onPressed, isNotNull);
    });

    testWidgets('tapping ∨ advances to the next species', (tester) async {
      final state = AppState()..openSpecies('sp1', ['sp1', 'sp2']);
      await _mount(tester, state);

      await tester.tap(_navBtn('\u2228').first);
      await tester.pump();
      await _settle(tester);

      expect(state.currentSpeciesId, 'sp2');
      expect(find.text('Queen Angelfish'), findsOneWidget);
    });

    testWidgets('tapping ∧ goes back to the previous species', (tester) async {
      final state = AppState()..openSpecies('sp2', ['sp1', 'sp2']); // index 1
      await _mount(tester, state);

      await tester.tap(_navBtn('\u2227').first);
      await tester.pump();
      await _settle(tester);

      expect(state.currentSpeciesId, 'sp1');
      expect(find.text('Blue Tang'), findsOneWidget);
    });
  });
}
