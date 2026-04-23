import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/widgets/species_list.dart';

import '../helpers/mock_assets.dart';

Widget _buildApp(AppState state) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: Scaffold(body: const SpeciesList()),
      ),
    );

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

void main() {
  setUpAll(setupMockAssets);

  group('SpeciesList', () {
    testWidgets('shows "Select a category" when no category is selected', (tester) async {
      await _mount(tester, AppState());
      expect(find.text('Select a category'), findsOneWidget);
      expect(find.byType(ListView), findsNothing);
    });

    testWidgets('shows CircularProgressIndicator while data loads', (tester) async {
      await tester.runAsync(() async {
        final state = AppState()..setCategory('Surgeonfish');
        await tester.pumpWidget(_buildApp(state));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    });

    testWidgets('renders species name and scientific name', (tester) async {
      final state = AppState()..setCategory('Surgeonfish');
      await _mount(tester, state);
      expect(find.text('Blue Tang'), findsOneWidget);
      expect(find.text('Acanthurus coeruleus'), findsOneWidget);
    });

    testWidgets('renders a section header for the family group', (tester) async {
      final state = AppState()..setCategory('Surgeonfish');
      await _mount(tester, state);
      // _FamilyHeader renders as a blue[700] Container
      expect(
        find.byWidgetPredicate((w) => w is Container && w.color == Colors.blue[700]),
        findsOneWidget,
      );
    });

    testWidgets('renders the correct species for Angelfish category', (tester) async {
      final state = AppState()..setCategory('Angelfish');
      await _mount(tester, state);
      expect(find.text('Queen Angelfish'), findsOneWidget);
      expect(find.text('Holacanthus ciliaris'), findsOneWidget);
    });

    testWidgets('rebuilds with new species when category changes', (tester) async {
      final state = AppState()..setCategory('Surgeonfish');
      await _mount(tester, state);
      expect(find.text('Blue Tang'), findsOneWidget);

      state.setCategory('Angelfish');
      await tester.pump(); // triggers rebuild + new FutureBuilder future
      await _settle(tester); // lets the future resolve

      expect(find.text('Queen Angelfish'), findsOneWidget);
      expect(find.text('Blue Tang'), findsNothing);
    });

    testWidgets('shows "Select a category" again after superCat change clears category', (tester) async {
      final state = AppState()..setCategory('Surgeonfish');
      await _mount(tester, state);
      expect(find.text('Select a category'), findsNothing);

      state.setSuperCat('Corals'); // clears selectedCategory
      await tester.pump();

      expect(find.text('Select a category'), findsOneWidget);
    });

    testWidgets('tapping a species card calls openSpecies on AppState', (tester) async {
      // Use a tall viewport so the card's text area is within bounds.
      // At 800px wide the 4:3 image is 600px tall; 2000px height gives room.
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final state = AppState()..setCategory('Surgeonfish');

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => ChangeNotifierProvider<AppState>.value(
              value: state,
              child: const Scaffold(body: SpeciesList()),
            ),
          ),
          GoRoute(
            path: '/browse/species/:id',
            builder: (_, __) => const SizedBox(),
          ),
        ],
      );

      await tester.runAsync(() async {
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      await tester.tap(find.text('Blue Tang'));
      await tester.pump();

      expect(state.currentSpeciesId, 'sp1');
    });
  });
}
