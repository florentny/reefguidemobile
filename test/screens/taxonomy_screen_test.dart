import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/screens/taxonomy_screen.dart';

import '../helpers/mock_assets.dart';

Widget _buildApp(AppState state) {
  final router = GoRouter(
    initialLocation: '/taxonomy',
    routes: [
      GoRoute(path: '/taxonomy', builder: (_, __) => const TaxonomyScreen()),
      GoRoute(path: '/taxonomy/species/:id', builder: (_, __) => const SizedBox()),
    ],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp.router(routerConfig: router),
  );
}

// The alphabet sidebar needs ~486px height. Use a taller viewport.
void _setTallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Future<void> _mount(WidgetTester tester, AppState state) async {
  _setTallViewport(tester);
  await tester.runAsync(() async {
    await tester.pumpWidget(_buildApp(state));
    await Future.delayed(const Duration(milliseconds: 200));
  });
  await tester.pump();
}

void main() {
  setUpAll(setupMockAssets);

  group('TaxonomyScreen', () {
    testWidgets('shows CircularProgressIndicator before data loads', (tester) async {
      _setTallViewport(tester);
      await tester.runAsync(() async {
        await tester.pumpWidget(_buildApp(AppState()));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    });

    testWidgets('AppBar has back button and blue background', (tester) async {
      await _mount(tester, AppState());
      expect(find.byIcon(Icons.arrow_back), findsOneWidget);
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.blue[700]);
    });

    testWidgets('AppBar shows superCat and region dropdowns', (tester) async {
      await _mount(tester, AppState());
      expect(find.text('Fish'), findsOneWidget);
      expect(find.text('All Regions'), findsOneWidget);
    });

    testWidgets('shows search field with hint text after loading', (tester) async {
      await _mount(tester, AppState());
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search taxonomy…'), findsOneWidget);
    });

    testWidgets('renders taxonomy tree nodes after loading', (tester) async {
      await _mount(tester, AppState());
      // Mock taxonomy: Biota → Perciformes (Order) → Acanthuridae, Pomacanthidae (Family)
      // Perciformes is auto-expanded (single visible child at root level)
      expect(find.textContaining('Perciformes', findRichText: true), findsOneWidget);
      expect(find.textContaining('Acanthuridae', findRichText: true), findsOneWidget);
      expect(find.textContaining('Pomacanthidae', findRichText: true), findsOneWidget);
    });

    testWidgets('shows species count in status row', (tester) async {
      await _mount(tester, AppState());
      expect(find.text('2 species'), findsOneWidget);
    });

    testWidgets('species list shows both fish species after loading', (tester) async {
      await _mount(tester, AppState());
      // Sorted by sciName: Acanthurus coeruleus, Holacanthus ciliaris
      expect(find.textContaining('Acanthurus coeruleus', findRichText: true), findsOneWidget);
      expect(find.textContaining('Holacanthus ciliaris', findRichText: true), findsOneWidget);
    });

    testWidgets('shows "Select a node to see species" when superCat has no matches', (tester) async {
      final state = AppState()..setSuperCat('Corals');
      await _mount(tester, state);
      expect(find.text('Select a node to see species'), findsOneWidget);
    });

    testWidgets('tapping a tree node selects it and filters species list', (tester) async {
      await _mount(tester, AppState());

      // Tap Acanthuridae to select it — only sp1 (Blue Tang) should appear
      await tester.tap(find.textContaining('Acanthuridae', findRichText: true));
      await tester.pump();

      expect(find.textContaining('Acanthurus coeruleus', findRichText: true), findsOneWidget);
      expect(find.textContaining('Holacanthus ciliaris', findRichText: true), findsNothing);
      expect(find.text('1 species'), findsOneWidget);
    });

    testWidgets('selected node name appears in status row', (tester) async {
      await _mount(tester, AppState());

      await tester.tap(find.textContaining('Acanthuridae', findRichText: true));
      await tester.pump();

      // Status row RichText shows the selected node's name; tree row also has it → at least 2
      expect(find.textContaining('Acanthuridae', findRichText: true), findsAtLeastNWidgets(2));
    });

    testWidgets('tapping Perciformes collapses its children', (tester) async {
      await _mount(tester, AppState());

      // Perciformes is expanded by default; tapping it collapses children
      await tester.tap(find.textContaining('Perciformes', findRichText: true));
      await tester.pump();

      expect(find.textContaining('Acanthuridae', findRichText: true), findsNothing);
      expect(find.textContaining('Pomacanthidae', findRichText: true), findsNothing);
    });

    testWidgets('search field clear button appears when text is entered', (tester) async {
      await _mount(tester, AppState());
      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byType(TextField), 'acanthuridae');
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('tapping clear resets search and restores both families', (tester) async {
      await _mount(tester, AppState());

      await tester.enterText(find.byType(TextField), 'acanthuridae');
      await tester.pump();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(find.byIcon(Icons.clear), findsNothing);
      // After clear, _selectedNode stays Acanthuridae → appears in tree row AND status row
      expect(find.textContaining('Acanthuridae', findRichText: true), findsAtLeastNWidgets(1));
      expect(find.textContaining('Pomacanthidae', findRichText: true), findsAtLeastNWidgets(1));
    });

    testWidgets('search navigates to matching node and selects it', (tester) async {
      await _mount(tester, AppState());

      await tester.enterText(find.byType(TextField), 'acanthuridae');
      await tester.pump();

      // Acanthuridae is now selected → only Blue Tang in species list
      expect(find.textContaining('Acanthurus coeruleus', findRichText: true), findsOneWidget);
      expect(find.textContaining('Holacanthus ciliaris', findRichText: true), findsNothing);
    });

    testWidgets('alphabet sidebar shows A and H active (sciName sort)', (tester) async {
      await _mount(tester, AppState());
      // Acanthurus → A, Holacanthus → H
      expect(tester.widget<Text>(find.text('A')).style?.color, Colors.blue[700]);
      expect(tester.widget<Text>(find.text('H')).style?.color, Colors.blue[700]);
      expect(tester.widget<Text>(find.text('B')).style?.color, Colors.grey[400]);
    });

    testWidgets('superCat dropdown shows all options on tap', (tester) async {
      await _mount(tester, AppState());
      await tester.tap(find.text('Fish'));
      await tester.pumpAndSettle();
      for (final label in ['Fish', 'Invertebrates', 'Sponges', 'Corals', 'Algae', 'Others']) {
        expect(find.text(label), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('selecting a superCat with no matches clears species list', (tester) async {
      final state = AppState();
      await _mount(tester, state);

      await tester.tap(find.text('Fish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corals').last);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      expect(state.selectedSuperCat, 'Corals');
      expect(find.text('Select a node to see species'), findsOneWidget);
    });

    testWidgets('region dropdown shows all regions on tap', (tester) async {
      await _mount(tester, AppState());
      await tester.tap(find.text('All Regions'));
      await tester.pumpAndSettle();
      for (final name in regionNames) {
        expect(find.text(name), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('selecting a region reloads taxonomy and updates AppState', (tester) async {
      final state = AppState();
      await _mount(tester, state);

      await tester.tap(find.text('All Regions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caribbean').last);
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pump();

      expect(state.selectedRegion, 1);
      expect(find.text('Caribbean'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping species card calls openSpecies on AppState', (tester) async {
      final state = AppState();
      await _mount(tester, state);

      // Blue Tang (sp1) is sorted first (Acanthurus < Holacanthus)
      await tester.tap(find.textContaining('Acanthurus coeruleus', findRichText: true));
      await tester.pump();

      expect(state.currentSpeciesId, 'sp1');
    });
  });
}
