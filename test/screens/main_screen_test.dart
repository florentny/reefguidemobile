import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/screens/main_screen.dart';
import 'package:reefmobile/widgets/app_drawer.dart';
import 'package:reefmobile/widgets/category_list.dart';
import 'package:reefmobile/widgets/species_list.dart';

import '../helpers/mock_assets.dart';

Widget _buildApp(AppState state) => ChangeNotifierProvider<AppState>.value(
  value: state,
  child: MaterialApp(home: const MainScreen()),
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

  group('MainScreen', () {
    testWidgets('renders AppBar with default superCat and region labels', (tester) async {
      await _mount(tester, AppState());
      expect(find.text('Fish'), findsOneWidget);
      expect(find.text('All Regions'), findsOneWidget);
    });

    testWidgets('AppBar background is blue', (tester) async {
      await _mount(tester, AppState());
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.backgroundColor, Colors.blue[700]);
    });

    testWidgets('has a drawer (AppDrawer)', (tester) async {
      await _mount(tester, AppState());
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.drawer, isA<AppDrawer>());
    });

    testWidgets('body contains CategoryList and SpeciesList', (tester) async {
      await _mount(tester, AppState());
      expect(find.byType(CategoryList), findsOneWidget);
      expect(find.byType(SpeciesList), findsOneWidget);
    });

    testWidgets('superCat dropdown shows all options on tap', (tester) async {
      await _mount(tester, AppState());
      // Tap the superCat dropdown (first AppBarDropdown — shows current superCat label)
      await tester.tap(find.text('Fish'));
      await tester.pumpAndSettle();
      for (final label in ['Fish', 'Invertebrates', 'Sponges', 'Corals', 'Algae', 'Others']) {
        expect(find.text(label), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('selecting a superCat updates AppState', (tester) async {
      final state = AppState();
      await _mount(tester, state);

      await tester.tap(find.text('Fish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Corals').last);
      await tester.pump();
      await _settle(tester);

      expect(state.selectedSuperCat, 'Corals');
      expect(find.text('Corals'), findsAtLeastNWidgets(1));
    });

    testWidgets('selecting a superCat clears selectedCategory', (tester) async {
      final state = AppState()..setCategory('Surgeonfish');
      await _mount(tester, state);

      await tester.tap(find.text('Fish'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Invertebrates').last);
      await tester.pump();
      await _settle(tester);

      expect(state.selectedCategory, isNull);
    });

    testWidgets('region dropdown shows all regions on tap', (tester) async {
      await _mount(tester, AppState());
      await tester.tap(find.text('All Regions'));
      await tester.pumpAndSettle();
      for (final name in regionNames) {
        expect(find.text(name), findsAtLeastNWidgets(1));
      }
    });

    testWidgets('selecting a region updates AppState', (tester) async {
      final state = AppState();
      await _mount(tester, state);

      await tester.tap(find.text('All Regions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Caribbean').last);
      await tester.pump();
      await _settle(tester);

      expect(state.selectedRegion, 1);
    });

    testWidgets('selecting a region clears selectedCategory', (tester) async {
      final state = AppState()..setCategory('Surgeonfish');
      await _mount(tester, state);

      await tester.tap(find.text('All Regions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hawaii').last);
      await tester.pump();
      await _settle(tester);

      expect(state.selectedCategory, isNull);
    });

    testWidgets('hamburger icon opens the drawer', (tester) async {
      await _mount(tester, AppState());
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // drawer animation
      expect(find.byType(AppDrawer), findsOneWidget);
    });
  });
}
