import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:reefmobile/providers/app_state.dart';
import 'package:reefmobile/screens/search_screen.dart';

import '../helpers/mock_assets.dart';

// Plain MaterialApp — fine whenever context.pop() / context.push() are not called.
Widget _buildApp(AppState state) => ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(home: SearchScreen()),
    );

// GoRouter wrapper — needed for the species-card tap that calls context.push().
Widget _buildWithRouter(AppState state) {
  final router = GoRouter(
    initialLocation: '/search',
    routes: [
      GoRoute(path: '/search', builder: (_, __) => const SearchScreen()),
      GoRoute(path: '/search/species/:id', builder: (_, __) => const SizedBox()),
    ],
  );
  return ChangeNotifierProvider<AppState>.value(
    value: state,
    child: MaterialApp.router(routerConfig: router),
  );
}

// The default 800×600 test surface gives only ~470 px to the list area, which is
// less than the 27-letter sidebar needs (27×18 = 486 px).  Setting physicalSize to
// 800×700 gives ~556 px to the list — enough for the sidebar without overflow.
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

  group('SearchScreen', () {
    testWidgets('shows CircularProgressIndicator before data loads', (tester) async {
      _setTallViewport(tester);
      await tester.runAsync(() async {
        await tester.pumpWidget(_buildApp(AppState()));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
    });

    testWidgets('renders search field with hint text', (tester) async {
      await _mount(tester, AppState());
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Search by common or scientific name…'), findsOneWidget);
    });

    testWidgets('renders both Fish species after loading', (tester) async {
      await _mount(tester, AppState());
      expect(find.text('Blue Tang'), findsOneWidget);
      expect(find.text('Queen Angelfish'), findsOneWidget);
    });

    testWidgets('shows species count when no query is active', (tester) async {
      await _mount(tester, AppState());
      expect(find.text('2 species'), findsOneWidget);
    });

    testWidgets('shows "No species" when the selected superCat has no matches', (tester) async {
      final state = AppState()..setSuperCat('Corals');
      await _mount(tester, state);
      expect(find.text('No species'), findsOneWidget);
    });

    testWidgets('filters list by common name query', (tester) async {
      await _mount(tester, AppState());
      await tester.enterText(find.byType(TextField), 'blue');
      await tester.pump();
      expect(find.textContaining('Blue Tang', findRichText: true), findsOneWidget);
      expect(find.text('Queen Angelfish'), findsNothing);
    });

    testWidgets('filters list by scientific name query', (tester) async {
      await _mount(tester, AppState());
      await tester.enterText(find.byType(TextField), 'holacanthus');
      await tester.pump();
      expect(find.text('Blue Tang'), findsNothing);
      expect(find.textContaining('Queen Angelfish', findRichText: true), findsOneWidget);
    });

    testWidgets('shows singular "1 result" when one species matches', (tester) async {
      await _mount(tester, AppState());
      await tester.enterText(find.byType(TextField), 'blue');
      await tester.pump();
      expect(find.text('1 result'), findsOneWidget);
    });

    testWidgets('shows "No results" for a non-matching query', (tester) async {
      await _mount(tester, AppState());
      await tester.enterText(find.byType(TextField), 'zzz-nomatch');
      await tester.pump();
      expect(find.text('No results'), findsOneWidget);
    });

    testWidgets('clear button appears only when a query is entered', (tester) async {
      await _mount(tester, AppState());
      expect(find.byIcon(Icons.clear), findsNothing);

      await tester.enterText(find.byType(TextField), 'blue');
      await tester.pump();
      expect(find.byIcon(Icons.clear), findsOneWidget);
    });

    testWidgets('tapping clear resets query and restores the full list', (tester) async {
      await _mount(tester, AppState());
      await tester.enterText(find.byType(TextField), 'blue');
      await tester.pump();
      expect(find.text('Queen Angelfish'), findsNothing);

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pump();

      expect(find.text('Blue Tang'), findsOneWidget);
      expect(find.text('Queen Angelfish'), findsOneWidget);
      expect(find.byIcon(Icons.clear), findsNothing);
    });

    testWidgets('Scientific sort shows scientific names as primary text', (tester) async {
      await _mount(tester, AppState());
      await tester.tap(find.text('Scientific'));
      await tester.pump();
      expect(find.text('Acanthurus coeruleus'), findsOneWidget);
      expect(find.text('Holacanthus ciliaris'), findsOneWidget);
    });

    testWidgets('Scientific sort orders Acanthurus before Holacanthus', (tester) async {
      await _mount(tester, AppState());
      await tester.tap(find.text('Scientific'));
      await tester.pump();
      final aY = tester.getTopLeft(find.text('Acanthurus coeruleus')).dy;
      final hY = tester.getTopLeft(find.text('Holacanthus ciliaris')).dy;
      expect(aY, lessThan(hY));
    });

    testWidgets('Common sort orders Blue Tang before Queen Angelfish', (tester) async {
      await _mount(tester, AppState());
      final bY = tester.getTopLeft(find.text('Blue Tang')).dy;
      final qY = tester.getTopLeft(find.text('Queen Angelfish')).dy;
      expect(bY, lessThan(qY));
    });

    testWidgets('sidebar marks B and Q active in Common sort', (tester) async {
      await _mount(tester, AppState());
      // Blue Tang → B, Queen Angelfish → Q
      expect(tester.widget<Text>(find.text('B')).style?.color, Colors.blue[700]);
      expect(tester.widget<Text>(find.text('Q')).style?.color, Colors.blue[700]);
      expect(tester.widget<Text>(find.text('A')).style?.color, Colors.grey[400]);
    });

    testWidgets('sidebar marks A and H active in Scientific sort', (tester) async {
      await _mount(tester, AppState());
      await tester.tap(find.text('Scientific'));
      await tester.pump();
      // Acanthurus → A, Holacanthus → H
      expect(tester.widget<Text>(find.text('A')).style?.color, Colors.blue[700]);
      expect(tester.widget<Text>(find.text('H')).style?.color, Colors.blue[700]);
      expect(tester.widget<Text>(find.text('B')).style?.color, Colors.grey[400]);
    });

    testWidgets('tapping a species card calls openSpecies on AppState', (tester) async {
      _setTallViewport(tester);
      final state = AppState();
      await tester.runAsync(() async {
        await tester.pumpWidget(_buildWithRouter(state));
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      await tester.tap(find.text('Blue Tang'));
      await tester.pump();

      expect(state.currentSpeciesId, 'sp1');
    });
  });
}
